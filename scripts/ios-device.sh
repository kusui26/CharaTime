#!/usr/bin/env bash
#
# CharaTime 実機への転送
#
# シミュレータで分かることは scripts/ios-loop.sh が全部やる。このスクリプトが要るのは
# **シミュレータでは分からないこと**を見るときだけ（プラン §8.3）。
#   ウィジェットの実際の更新間隔 / 透過ウィジェットのずれ / StandBy / 常時表示 /
#   電池と発熱 / ウィジェットの疑似アニメが実機で動くか（3-2b。Phase 0 のスパイクで成立を確かめた）
#
# Xcode.app を開かずに済ませる。メモリ 8 GB・スワップ逼迫の機械では、Xcode を
# 常駐させないことがそのまま速さになる（プラン §8.4、R-15）。
#
# 使い方:
#   scripts/ios-device.sh                    下ごしらえだけ（生成と署名の点検）
#   scripts/ios-device.sh --install          ビルドして端末へ入れて起動する
#   scripts/ios-device.sh --install --screen widgets  ウィジェットの下見の画面で開く
#   scripts/ios-device.sh --install --time 20:30     その時刻に固定して開く
#
# 初回は署名の Team ID が要る。.env.local に書いておくと、プロジェクトを生成し
# 直しても残る（project.yml の DEVELOPMENT_TEAM がこの環境変数を読む）。
#
#   cp .env.local.example .env.local
#   # CHARATIME_TEAM_ID= の行に 10 桁の Team ID を入れる
#
# **無料アカウントの署名は 7 日で切れる。** 切れたら同じコマンドで入れ直す。
# （いまは Developer Program の署名で、期限は 1 年。無料アカウントに戻したときだけ気にする）
#
set -euo pipefail

# 失敗したら、どこで落ちたかを最後にはっきり出す。
# ログの末尾だけを見て「通った」と早合点しないため。
trap 'status=$?; [[ ${status} -ne 0 ]] && printf "\033[1;31m✗ 失敗しました（終了コード %d・%s の %d 行目）\033[0m\n" "${status}" "${BASH_SOURCE[0]}" "${LINENO}" >&2; exit ${status}' ERR

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# このマシン固有の設定（署名の Team ID）を取り込む。無ければ何もしない。
source "${REPO_ROOT}/scripts/lib/local-env.sh"
load_local_env "${REPO_ROOT}"

readonly IOS_DIR="${REPO_ROOT}/ios"
readonly SCHEME="CharaTime"
readonly BUNDLE_ID="app.charatime"
readonly DERIVED_DATA="${IOS_DIR}/build"
readonly APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphoneos/${SCHEME}.app"
# 手元の Xcode 26.6 が入れられる実機の上限。これを超える端末には転送できない
# （プラン D-15、R-6）。
readonly MAX_SUPPORTED_IOS_MAJOR=26

install_app=false
screen=""
fixed_time=""
time_speed=""

log()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install) install_app=true; shift ;;
      # 何も指定しなければ待受モードで開く。指定できるのは確認用の画面だけ。
      --screen)  screen="${2:?--screen には画面の名前が必要です（room / band / dayPlan / settings / widgets）}"; shift 2 ;;
      --time)    fixed_time="${2:?--time には 20:30 のような時刻が必要です}"; shift 2 ;;
      --speed)   time_speed="${2:?--speed には倍率が必要です}"; shift 2 ;;
      -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
      *)         die "不明な引数: $1（--help で使い方を表示）" ;;
    esac
  done
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "$1 が見つかりません。'brew install $1' を実行してください。"
}

# Team ID が実在するか、手元の証明書と照らして確かめる。
#
# Xcode の Signing 画面に出る証明書名の括弧内（例: Apple Development:
# 名前 (H3CKW5TS29)）は証明書の ID であって Team ID ではない。取り違えると
# 「No Account for Team ...」という原因の分かりにくい失敗になるため、
# 長いビルドに入る前に気づけるようにする。
verify_team_id() {
  local team="$1" teams
  # 証明書の OU が Team ID にあたる。
  teams="$(security find-certificate -a -c 'Apple Develop' -p 2>/dev/null \
    | openssl storeutl -noout -text -certs /dev/stdin 2>/dev/null \
    | grep -oE 'OU=[A-Z0-9]{10}' | cut -d= -f2 | sort -u || true)"
  [[ -n "${teams}" ]] || return 0

  if ! grep -qx "${team}" <<< "${teams}"; then
    warn "Team ID「${team}」に対応する証明書が見当たりません。"
    warn "手元の証明書が示す Team ID: $(tr '\n' ' ' <<< "${teams}")"
    warn "証明書名の括弧内は証明書の ID であって Team ID ではありません。"
    warn ".env.local の CHARATIME_TEAM_ID を見直してください。"
  fi
}

generate_project() {
  log "プロジェクト生成（xcodegen）"
  if [[ -z "${CHARATIME_TEAM_ID:-}" ]]; then
    warn "CHARATIME_TEAM_ID が未設定です。実機ビルドは署名で止まります。"
    warn "cp .env.local.example .env.local して Team ID を書いてください。"
  else
    verify_team_id "${CHARATIME_TEAM_ID}"
  fi
  ( cd "${IOS_DIR}" && xcodegen generate )
}

# 接続中の端末を 1 台調べる。UDID・名前・機種・デベロッパモード・OS の版を
# タブ区切りで返す。取り出しは scripts/lib/first-device.py に任せる。
readonly DEVICE_JSON="${TMPDIR:-/tmp}/charatime-devices.json"

describe_device() {
  xcrun devicectl list devices --json-output "${DEVICE_JSON}" >/dev/null 2>&1 || return 1
  python3 "${REPO_ROOT}/scripts/lib/first-device.py" "${DEVICE_JSON}"
}

# デベロッパモードが有効でないと、開発用のビルドを端末に入れられない。
# iOS 16 以降で必要になった手順で、初回は必ず引っかかる。
require_developer_mode() {
  local status="$1" name="$2"
  [[ "${status}" == "enabled" ]] && return 0
  warn "「${name}」でデベロッパモードが有効になっていません（現在: ${status}）。"
  warn "端末で次の順に進んでください:"
  warn "  設定 → プライバシーとセキュリティ → デベロッパモード → オン → 再起動"
  warn "項目が見当たらない場合は、一度 Xcode から実行すると現れます。"
  die "デベロッパモードを有効にしてからやり直してください。"
}

# 実機の iOS が手元の Xcode より新しいと、そもそも入らない（R-6）。
# 「入らない」という失敗は原因が分かりにくいので、先に読んで伝える。
require_supported_os() {
  local version="$1" major
  major="${version%%.*}"
  [[ "${major}" =~ ^[0-9]+$ ]] || return 0
  (( major <= MAX_SUPPORTED_IOS_MAJOR )) && return 0
  warn "端末は iOS ${version} で、手元の Xcode（iOS ${MAX_SUPPORTED_IOS_MAJOR} 系の SDK）より新しいものです。"
  warn "この組み合わせでは実機に入れられません（プラン R-6）。"
  warn "macOS と Xcode を上げるか、実機検証を止めてシミュレータで進めてください。"
  die "対応していない iOS の版です: ${version}"
}

build_and_install() {
  local described
  described="$(describe_device)" || die "端末を調べられませんでした。"
  [[ -n "${described}" ]] || die "端末が見つかりません。USB で接続し、端末側で「信頼」を選んでください。"

  local udid name model mode version
  IFS=$'\t' read -r udid name model mode version <<< "${described}"
  log "端末: ${name}（${model} / iOS ${version}）"
  require_developer_mode "${mode}" "${name}"
  require_supported_os "${version}"

  log "ビルド（実機向け）"
  # 端末は開発者アカウントに登録されていないとプロファイルに含められない。
  # -allowProvisioningDeviceRegistration が無いと、Xcode から一度実行するまで
  # 「isn't registered in your developer account」で止まる。
  ( cd "${IOS_DIR}" && xcodebuild build \
      -project "${SCHEME}.xcodeproj" -scheme "${SCHEME}" -configuration Debug \
      -destination "platform=iOS,id=${udid}" -derivedDataPath build \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration | xcbeautify )

  [[ -d "${APP_PATH}" ]] || die "ビルド成果物が見つかりません: ${APP_PATH}"

  # ウィジェット拡張はアプリに同梱されるので、入れるのはアプリ 1 つでよい。
  log "端末へインストール"
  xcrun devicectl device install app --device "${udid}" "${APP_PATH}"

  log "起動"
  # 確認のための指定（画面・時刻）は、実行引数としてアプリに渡す。
  local launch_args=()
  [[ -n "${screen}" ]]     && launch_args+=(-CTScreen "${screen}")
  [[ -n "${fixed_time}" ]] && launch_args+=(-CTTime "${fixed_time}")
  [[ -n "${time_speed}" ]] && launch_args+=(-CTSpeed "${time_speed}")
  xcrun devicectl device process launch --device "${udid}" \
    "${BUNDLE_ID}" "${launch_args[@]+"${launch_args[@]}"}" >/dev/null

  printf '\033[1;32m✓ 入りました\033[0m\n'
}

main() {
  parse_args "$@"
  require_tool xcodegen
  [[ -f "${IOS_DIR}/project.yml" ]] || die "${IOS_DIR}/project.yml がありません。"
  generate_project

  if [[ "${install_app}" == false ]]; then
    log "下ごしらえができました。端末へ入れるには --install を付けてください。"
    return 0
  fi

  require_tool xcbeautify
  build_and_install
}

main "$@"
