#!/usr/bin/env bash
#
# CharaTime iOS 検証ループ
#
# docs/260910_dev_plan.md §8.3 の①〜⑥を 1 コマンドで実行する。
#   ① xcodegen generate     project.yml から .xcodeproj を生成
#   ② scripts/check.sh      品質ゲート（lint → 警告ゼロのビルド → テスト。数秒）
#   ③ xcodebuild build      シミュレータ向けビルド
#   ④ simctl install/launch シミュレータへ導入して起動
#   ⑤ status_bar override   スクリーンショット用にステータスバーを固定
#   ⑥ io screenshot         スクリーンショット取得
#
# ⑥で出力した PNG を Claude Code が Read で確認することで、UI の修正ループを
# Xcode を開かずに回せる。メモリ 8 GB の機械では Xcode.app を開かないことが効く。
#
# 使い方:
#   scripts/ios-loop.sh                        全ステップ
#   scripts/ios-loop.sh --test-only            ②だけ（ロジックを直したとき）
#   scripts/ios-loop.sh --skip-test            ②を飛ばす（描画だけ見たいとき）
#   scripts/ios-loop.sh --shot-only            ⑥だけ（起動中のシミュレータを撮る）
#   scripts/ios-loop.sh --device "iPhone 17"
#   scripts/ios-loop.sh --time 14:30           その時刻の姿を撮る
#   scripts/ios-loop.sh --time 07:00 --speed 240   7:00 から 240 倍速で動かす
#
set -euo pipefail

# 失敗したら、どこで落ちたかを最後にはっきり出す。
# ログの末尾だけを見て「通った」と早合点しないため。
trap 'status=$?; [[ ${status} -ne 0 ]] && printf "\033[1;31m✗ 失敗しました（終了コード %d・%s の %d 行目）\033[0m\n" "${status}" "${BASH_SOURCE[0]}" "${LINENO}" >&2; exit ${status}' ERR

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/scripts/lib/local-env.sh"
load_local_env "${REPO_ROOT}"

readonly IOS_DIR="${REPO_ROOT}/ios"
readonly SCHEME="CharaTime"
readonly BUNDLE_ID="app.charatime"
readonly DERIVED_DATA="${IOS_DIR}/build"
readonly APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
readonly SHOT_DIR="${REPO_ROOT}/.shots"
# スクリーンショットを毎回同じ見た目にするための固定値
readonly SHOT_TIME="08:30"
readonly SHOT_BATTERY_LEVEL=100
readonly SIMCTL_TIMEOUT_SEC=25
readonly BOOT_TIMEOUT_SEC=180
readonly LAUNCH_SETTLE_SEC=5

device_name="iPhone 17 Pro"
# 確認のために時刻をずらす（プラン §9 Phase 1 の 1-5）。空なら実時刻。
fixed_time=""
time_speed=""
skip_test=false
shot_only=false
test_only=false

log()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# macOS には timeout(1) が無い。simctl は応答しなくなることがあるので、
# perl の alarm で時間を区切る。終了コードはそのまま伝わる。
run_with_timeout() {
  local seconds="$1"; shift
  perl -e 'my $limit = shift; alarm $limit; exec @ARGV or exit 127;' "${seconds}" "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device)    device_name="${2:?--device には端末名が必要です}"; shift 2 ;;
      --time)      fixed_time="${2:?--time には 14:30 のような時刻が必要です}"; shift 2 ;;
      --speed)     time_speed="${2:?--speed には倍率が必要です}"; shift 2 ;;
      --skip-test) skip_test=true; shift ;;
      --shot-only) shot_only=true; shift ;;
      --test-only) test_only=true; shift ;;
      -h|--help)   sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
      *)           die "不明な引数: $1（--help で使い方を表示）" ;;
    esac
  done
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "$1 が見つかりません。'brew install $1' を実行してください。"
}

generate_project() {
  log "① プロジェクト生成（xcodegen）"
  ( cd "${IOS_DIR}" && xcodegen generate )
}

# 品質ゲートは scripts/check.sh に一本化してある（lint・警告ゼロのビルド・テスト）。
# CI も同じものを見るので、二重に書かない。
run_checks() {
  log "② 品質ゲート（scripts/check.sh）"
  "${REPO_ROOT}/scripts/check.sh"
}

build_app() {
  # ロジックのテストは②で済んでいる。アプリのスキームはそれらを束ねる薄い入れ物なので、
  # ここで確かめるのはビルドが通ることだけ。テストターゲットは持たせていない。
  log "③ ビルド（iOS Simulator / ${device_name}）"
  xcodebuild build \
    -project "${IOS_DIR}/${SCHEME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=${device_name}" \
    -derivedDataPath "${DERIVED_DATA}" \
    | xcbeautify
}

boot_simulator() {
  log "④ シミュレータ起動（${device_name}）"
  xcrun simctl boot "${device_name}" 2>/dev/null || true
  run_with_timeout "${BOOT_TIMEOUT_SEC}" \
    xcrun simctl bootstatus "${device_name}" -b >/dev/null \
    || die "シミュレータが起動しませんでした: ${device_name}"
}

install_and_launch() {
  [[ -d "${APP_PATH}" ]] || die "ビルド成果物が見つかりません: ${APP_PATH}"
  log "   └ インストールと起動（${BUNDLE_ID}）"
  run_with_timeout "${SIMCTL_TIMEOUT_SEC}" \
    xcrun simctl terminate "${device_name}" "${BUNDLE_ID}" 2>/dev/null || true
  run_with_timeout "${SIMCTL_TIMEOUT_SEC}" \
    xcrun simctl install "${device_name}" "${APP_PATH}" \
    || die "アプリをインストールできませんでした"
  # 時刻を固定・早送りするときは、実行引数でアプリに渡す。
  local launch_args=()
  [[ -n "${fixed_time}" ]] && launch_args+=(-CTTime "${fixed_time}")
  [[ -n "${time_speed}" ]] && launch_args+=(-CTSpeed "${time_speed}")
  if ! run_with_timeout "${SIMCTL_TIMEOUT_SEC}" \
      xcrun simctl launch "${device_name}" "${BUNDLE_ID}" "${launch_args[@]+"${launch_args[@]}"}" \
      >/dev/null; then
    warn "launch が時間内に返りませんでした。起動はしている可能性が高いので続行します。"
  fi
  # 起動直後は描画が終わっていない。待たないと真っ黒な画像になる。
  sleep "${LAUNCH_SETTLE_SEC}"
}

override_status_bar() {
  log "⑤ ステータスバーを固定（時刻 ${SHOT_TIME}）"
  # 見た目を揃えるだけの工程なので、失敗してもループは続ける。
  if ! run_with_timeout "${SIMCTL_TIMEOUT_SEC}" \
    xcrun simctl status_bar "${device_name}" override \
    --time "${SHOT_TIME}" \
    --batteryState charged --batteryLevel "${SHOT_BATTERY_LEVEL}" \
    --cellularMode active --cellularBars 4 \
    --wifiMode active --wifiBars 3
  then
    warn "ステータスバーの固定に失敗しました。スクリーンショットは続行します。"
  fi
}

take_screenshot() {
  mkdir -p "${SHOT_DIR}"
  local stamp shot latest
  stamp="$(date +%Y%m%d-%H%M%S)"
  shot="${SHOT_DIR}/${stamp}.png"
  latest="${SHOT_DIR}/latest.png"
  log "⑥ スクリーンショット"
  run_with_timeout "${SIMCTL_TIMEOUT_SEC}" \
    xcrun simctl io "${device_name}" screenshot "${shot}" \
    || die "スクリーンショットを取得できませんでした"
  cp "${shot}" "${latest}"
  printf '\033[1;32m✓ %s\033[0m\n' "${latest}"
}

main() {
  parse_args "$@"

  if [[ "${test_only}" == true ]]; then
    run_checks
    return 0
  fi

  require_tool xcrun
  if [[ "${shot_only}" == true ]]; then
    take_screenshot
    return 0
  fi

  require_tool xcodegen
  require_tool xcbeautify
  [[ -f "${IOS_DIR}/project.yml" ]] || die "${IOS_DIR}/project.yml がありません。"

  generate_project
  [[ "${skip_test}" == false ]] && run_checks
  build_app
  boot_simulator
  install_and_launch
  override_status_bar
  take_screenshot
}

main "$@"
