#!/usr/bin/env bash
#
# シミュレータのホーム画面で、ウィジェットを「置く・撮る・数える」
#
# プラン §9 Phase 3 の 3-0d（Q-16）。ホーム画面の操作は UI テストのターゲット
# HomeScreenRobot（以下ロボット）が受け持ち、撮る・数えるはこのスクリプトが受け持つ。
# ロボットの操作 1 回は、xcodebuild の立ち上げを含めて 30 秒〜1 分半ほど。
#
# 使い方:
#   scripts/home-screen.sh build                     アプリとロボットをビルドし、アプリを入れ直す
#   scripts/home-screen.sh gallery                   置けるウィジェットの名前と大きさを並べる
#   scripts/home-screen.sh place "スパイク F 4 本@小" …   置く（表示名@大きさ。--clear で先に全部外す）
#   scripts/home-screen.sh clear                     CharaTime のウィジェットを全部外す
#   scripts/home-screen.sh shot [名前]               ウィジェットのあるページを撮る
#   scripts/home-screen.sh record <秒> [名前]        そのページを画面収録して、点滅を数える
#   scripts/home-screen.sh record --resume <回> [名前]   設定アプリへ行って戻る、を挟んで収録する
#   scripts/home-screen.sh count <動画> [--widget 表題]  数えるだけ（実機の画面収録は --slots small6）
#   scripts/home-screen.sh edit [名前]               編集モードに入って撮り、元に戻す（3-0c）
#   scripts/home-screen.sh look light|dark           端末の外観（ライト・ダーク）を切り替える
#   scripts/home-screen.sh style default|dark|clear|tinted   ホーム画面の外観（カスタマイズ）を切り替える
#   scripts/home-screen.sh icons large|normal        アプリアイコンの大きさ（large はラベルなし）
#   scripts/home-screen.sh dump                      画面の要素を書き出す（ロボットが止まったとき）
#
# どのコマンドにも --device "iPhone 17 Pro"（既定）を付けられる。
#
# 出力は .shots/home/（git に入らない）。
#   <名前>.png            撮った画面
#   <名前>.mp4 / .json    画面収録と、数えた結果
#   widgets.json          ロボットが最後に見たウィジェットの枠と文字
#   robot.log             ロボットの最後の実行記録（止まったときに読む）
#
# **アプリを直したら build から。** ロボットはアプリを入れ直さない。入っているのが古いと、
# 新しく足したウィジェットがギャラリーに出てこない。
#
set -euo pipefail

# 失敗したら、どこで落ちたかを最後にはっきり出す。
# ログの末尾だけを見て「通った」と早合点しないため。
trap 'status=$?; [[ ${status} -ne 0 ]] && printf "\033[1;31m✗ 失敗しました（終了コード %d・%s の %d 行目）\033[0m\n" "${status}" "${BASH_SOURCE[0]}" "${LINENO}" >&2; exit ${status}' ERR

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/scripts/lib/local-env.sh"
load_local_env "${REPO_ROOT}"

readonly IOS_DIR="${REPO_ROOT}/ios"
readonly PROJECT="${IOS_DIR}/CharaTime.xcodeproj"
readonly SCHEME="HomeScreenRobot"
readonly TEST_CLASS="HomeScreenRobot/HomeScreenRobot"
readonly BUNDLE_ID="app.charatime"
readonly DERIVED_DATA="${IOS_DIR}/build"
readonly APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/CharaTime.app"
readonly OUT_DIR="${REPO_ROOT}/.shots/home"
readonly ROBOT_LOG="${OUT_DIR}/robot.log"
readonly ROBOT_RECORDS="${OUT_DIR}/robot.jsonl"
readonly WIDGETS_JSON="${OUT_DIR}/widgets.json"
readonly COUNTER="${REPO_ROOT}/scripts/lib/count-frames.py"
readonly SIMCTL_TIMEOUT_SEC=25
readonly BOOT_TIMEOUT_SEC=180
# 収録が始まるまでの待ちの上限。simctl は「Recording started」と出してから撮り始める。
readonly RECORD_START_TIMEOUT_SEC=15
# 収録の終わりに足す余白。最後の「戻った直後」を切らないため。
readonly RECORD_TAIL_SEC=2
# ロボットが「用意ができた」を知らせるまでの待ちの上限。xcodebuild の立ち上げとページめくりを含む。
readonly ROBOT_READY_TIMEOUT_SEC=180

device_name="iPhone 17 Pro"
# 裏で動かしている画面収録。EXIT の片づけで止める。
recorder_pid=""

log()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }

# macOS には timeout(1) が無い。simctl は応答しなくなることがあるので、
# perl の alarm で時間を区切る。終了コードはそのまま伝わる。
run_with_timeout() {
  local seconds="$1"; shift
  perl -e 'my $limit = shift; alarm $limit; exec @ARGV or exit 127;' "${seconds}" "$@"
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "$1 が見つかりません。'brew install $1' を実行してください。"
}

# ---------------------------------------------------------------------------
# シミュレータとビルド
# ---------------------------------------------------------------------------

boot_simulator() {
  xcrun simctl boot "${device_name}" 2>/dev/null || true
  run_with_timeout "${BOOT_TIMEOUT_SEC}" xcrun simctl bootstatus "${device_name}" -b >/dev/null \
    || die "シミュレータが起動しませんでした: ${device_name}"
}

xctestrun_path() {
  find "${DERIVED_DATA}/Build/Products" -maxdepth 1 -name "${SCHEME}_*.xctestrun" 2>/dev/null | head -1
}

# アプリとロボットをビルドし、アプリを入れ直す。
#
# ロボット（UI テスト）の実行はアプリを入れ直さないので、ここで入れる。
# 入れ直すと WidgetKit がウィジェットの一覧を読み直し、置いてあるウィジェットも描き直される。
build_all() {
  require_tool xcodegen
  require_tool xcbeautify
  log "プロジェクト生成（xcodegen）"
  ( cd "${IOS_DIR}" && xcodegen generate >/dev/null )
  log "ビルド（アプリとロボット。${device_name}）"
  xcodebuild build-for-testing \
    -project "${PROJECT}" -scheme "${SCHEME}" -configuration Debug \
    -destination "platform=iOS Simulator,name=${device_name}" \
    -derivedDataPath "${DERIVED_DATA}" \
    | xcbeautify --quiet
  boot_simulator
  log "アプリを入れ直す（${BUNDLE_ID}）"
  run_with_timeout "${SIMCTL_TIMEOUT_SEC}" xcrun simctl install "${device_name}" "${APP_PATH}" \
    || die "アプリを入れられませんでした: ${APP_PATH}"
  ok "ビルドと導入が済みました"
}

ensure_built() {
  [[ -n "$(xctestrun_path)" && -d "${APP_PATH}" ]] && return 0
  warn "ロボットがまだビルドされていません。先にビルドします。"
  build_all
}

# ---------------------------------------------------------------------------
# ロボット
# ---------------------------------------------------------------------------

# ロボットの操作を 1 つ実行して、終わるまで待つ。引数は「テスト名」と「CT_ROBOT_…=値」の組。
run_robot() {
  start_robot "$@"
  finish_robot
}

# ロボットを裏で走らせる（画面収録と並べるため）。終わりは finish_robot で待つ。
#
# xcodebuild は TEST_RUNNER_ で始まる環境変数を、頭を外してテストに渡す。
robot_pid=""
robot_test=""
start_robot() {
  robot_test="$1"; shift
  local assignment
  local -a environment=()
  for assignment in "$@"; do
    environment+=("TEST_RUNNER_${assignment}")
  done
  ensure_built
  boot_simulator
  mkdir -p "${OUT_DIR}"
  : > "${ROBOT_LOG}"
  log "ロボット: ${robot_test}（30 秒〜1 分半）"
  env "${environment[@]+"${environment[@]}"}" xcodebuild test-without-building \
    -project "${PROJECT}" -scheme "${SCHEME}" \
    -destination "platform=iOS Simulator,name=${device_name}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -only-testing:"${TEST_CLASS}/${robot_test}" >"${ROBOT_LOG}" 2>&1 &
  robot_pid=$!
}

# ロボットが終わるのを待ち、出力のうち「CTROBOT 」を付けた行だけを robot.jsonl に取り出す。
finish_robot() {
  local pid="${robot_pid}"
  robot_pid=""
  if ! wait "${pid}"; then
    report_robot_failure
    die "ロボットが止まりました（${robot_test}）。記録: ${ROBOT_LOG}"
  fi
  sed -n 's/^CTROBOT //p' "${ROBOT_LOG}" > "${ROBOT_RECORDS}"
}

# ロボットが「用意ができた」と知らせるまで待つ（ページを出し終えた合図）。
wait_for_robot_ready() {
  local waited=0
  until grep -q '^CTROBOT .*"kind":"ready"' "${ROBOT_LOG}" 2>/dev/null; do
    if ! kill -0 "${robot_pid}" 2>/dev/null; then
      finish_robot
      die "ロボットが「用意ができた」を知らせる前に終わりました"
    fi
    sleep 1
    waited=$((waited + 1))
    (( waited < ROBOT_READY_TIMEOUT_SEC )) || die "ロボットが「用意ができた」を知らせません"
  done
}

stop_robot() {
  [[ -n "${robot_pid:-}" ]] || return 0
  kill "${robot_pid}" 2>/dev/null || true
  robot_pid=""
}

# 止まった理由を短く出す。XCTest の失敗の文と、ロボットが書き出した画面の要素の置き場所。
report_robot_failure() {
  grep -E "error: -\[|: failed - " "${ROBOT_LOG}" | sed -E 's/.*failed - //' | sort -u | head -5 >&2 || true
  if grep -q "CTROBOT-DUMP-BEGIN" "${ROBOT_LOG}"; then
    extract_dump "${OUT_DIR}/dump-failure.txt"
    warn "止まったときの画面の要素: ${OUT_DIR}/dump-failure.txt"
  fi
}

extract_dump() {
  awk '/^CTROBOT-DUMP-BEGIN/{keep=1; next} /^CTROBOT-DUMP-END/{keep=0} keep' "${ROBOT_LOG}" > "$1"
}

# ロボットの報告から、ページとウィジェットを widgets.json にまとめて、短く表示する。
save_widgets() {
  python3 - "${ROBOT_RECORDS}" "${WIDGETS_JSON}" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
page = next((r for r in records if r["kind"] == "page"), None)
widgets = [r for r in records if r["kind"] == "widget"]
json.dump({"page": page, "widgets": widgets}, open(sys.argv[2], "w", encoding="utf-8"),
          ensure_ascii=False, indent=2)
where = f"{page['page']}/{page['pages']} ページ" if page and page.get("page") else "ページ不明"
print(f"   {where}・CharaTime のウィジェット {len(widgets)} 個")
for widget in widgets:
    x, y, w, h = widget["frame"]
    title = widget["texts"][0] if widget["texts"] else "（文字なし）"
    print(f"   └ {widget['family']:<6} {x:6.1f},{y:6.1f}  {w:6.1f}×{h:6.1f}pt  {title}")
PY
}

# ---------------------------------------------------------------------------
# コマンド
# ---------------------------------------------------------------------------

cmd_gallery() {
  run_robot testGallery
  python3 - "${ROBOT_RECORDS}" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
previews = [r for r in records if r["kind"] == "preview"]
print(f"   ギャラリーの CharaTime の見本 {len(previews)} 枚（place には「表示名@大きさ」で渡す）")
for preview in previews:
    print(f"   └ {preview['name']}@{preview.get('family') or '?'}")
PY
}

cmd_place() {
  local clear_first=0 spec
  local -a specs=()
  for spec in "$@"; do
    case "${spec}" in
      --clear) clear_first=1 ;;
      *)       specs+=("${spec}") ;;
    esac
  done
  [[ ${#specs[@]} -gt 0 ]] || die "置くウィジェットを「表示名@大きさ」で渡してください（一覧は gallery）"
  local joined
  joined="$(IFS='|'; printf '%s' "${specs[*]}")"
  run_robot testPlace "CT_ROBOT_WIDGETS=${joined}" "CT_ROBOT_CLEAR_FIRST=${clear_first}"
  save_widgets
}

cmd_clear() {
  run_robot testClear
  save_widgets
}

# ロボットにウィジェットのあるページを出させてから撮る。
cmd_shot() {
  local name="${1:-latest}"
  run_robot testShow
  save_widgets
  take_screenshot "${name}"
}

take_screenshot() {
  local target="${OUT_DIR}/$1.png"
  run_with_timeout "${SIMCTL_TIMEOUT_SEC}" xcrun simctl io "${device_name}" screenshot --type=png "${target}" \
    >/dev/null 2>&1 || die "スクリーンショットを撮れませんでした"
  ok "${target}"
}

# 画面収録して数える。
#
# --resume を付けると、ロボットに「設定アプリへ行って戻る」を繰り返させ、その間を収録する。
# 戻った直後に点滅がすぐ動き出すかを測る（3-0b）。付けなければ、ただ <秒> だけ収録する。
cmd_record() {
  local seconds="" cycles="" name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --resume) cycles="${2:?--resume には回数が必要です}"; shift 2 ;;
      *)        if [[ -z "${seconds}" && -z "${cycles}" && "$1" =~ ^[0-9]+$ ]]; then seconds="$1"; else name="$1"; fi
                shift ;;
    esac
  done
  [[ -n "${seconds}" || -n "${cycles}" ]] || die "収録する秒数か --resume <回> を渡してください"
  require_tool ffmpeg
  name="${name:-rec-$(date +%Y%m%d-%H%M%S)}"
  local video="${OUT_DIR}/${name}.mp4"
  if [[ -n "${cycles}" ]]; then
    # ロボットがページを出し終えてから収録を始める（xcodebuild の立ち上げとページめくりを撮らない）。
    start_robot testResume "CT_ROBOT_CYCLES=${cycles}"
    wait_for_robot_ready
    start_recording "${video}"
    finish_robot
    sleep "${RECORD_TAIL_SEC}"
  else
    run_robot testShow
    start_recording "${video}"
    sleep "${seconds}"
  fi
  stop_recording
  save_widgets
  ok "収録: ${video}"
  count_video "${video}" --json "${OUT_DIR}/${name}.json"
}

# 収録を裏で始め、「Recording started」が出るまで待つ。
#
# simctl を xcrun 越しでなく直接呼ぶ。止めるときに送る SIGINT を、確実に simctl に届けるため
# （SIGINT で止めないと、動画の最後の書き込みが済まず、壊れたファイルになる）。
start_recording() {
  local video="$1" simctl started_log
  simctl="$(xcrun -f simctl)"
  started_log="${OUT_DIR}/recorder.log"
  "${simctl}" io "${device_name}" recordVideo --codec=h264 --force "${video}" >"${started_log}" 2>&1 &
  recorder_pid=$!
  local waited=0
  until grep -q "Recording started" "${started_log}" 2>/dev/null; do
    sleep 0.2
    waited=$((waited + 1))
    (( waited < RECORD_START_TIMEOUT_SEC * 5 )) || { kill -INT "${recorder_pid}" 2>/dev/null || true; die "収録が始まりません"; }
  done
  log "収録を始めました"
}

stop_recording() {
  [[ -n "${recorder_pid:-}" ]] || return 0
  kill -INT "${recorder_pid}" 2>/dev/null || true
  wait "${recorder_pid}" 2>/dev/null || true
  recorder_pid=""
}

count_video() {
  python3 "${COUNTER}" "$1" --widgets "${WIDGETS_JSON}" "${@:2}"
}

# 数えるだけ。枠は、引数で渡さなければ、ロボットが最後に見たウィジェットの枠（widgets.json）を使う。
# **実機の画面収録には --slots small6 を付ける**（シミュレータで最後に見た並びと、実機の並びは違うため）。
cmd_count() {
  local video="${1:?数える動画を渡してください}"; shift
  [[ -f "${video}" ]] || die "動画がありません: ${video}"
  require_tool ffmpeg
  local arg own_frames=false
  for arg in "$@"; do
    [[ "${arg}" == --slots || "${arg}" == --region ]] && own_frames=true
  done
  if [[ -f "${WIDGETS_JSON}" && "${own_frames}" == false ]]; then
    count_video "${video}" "$@"
  else
    python3 "${COUNTER}" "${video}" "$@"
  fi
}

# 編集モードに入って撮り、元に戻す（透過の確かめ。プラン §9 Phase 3 の 3-0c）。
cmd_edit() {
  local name="${1:-edit}"
  run_robot testEdit
  save_widgets
  take_screenshot "${name}"
  run_robot testSettle
}

cmd_look() {
  local appearance="${1:?light か dark を渡してください}"
  [[ "${appearance}" == light || "${appearance}" == dark ]] || die "外観は light か dark です: ${appearance}"
  boot_simulator
  xcrun simctl ui "${device_name}" appearance "${appearance}"
  ok "外観: ${appearance}"
}

# ホーム画面の外観（編集 → カスタマイズ）。クリアと着色（色合い調整）では、ウィジェットは
# accented で描かれる（背景が外れ、中身が単色になる）。梯子の決まり（プラン §9 Phase 3 の 3-C ⑤）を確かめる。
cmd_style() {
  local label
  case "${1:?default・dark・clear・tinted のどれかを渡してください}" in
    default) label="デフォルト" ;;
    dark)    label="ダーク" ;;
    clear)   label="クリア" ;;
    tinted)  label="色合い調整" ;;
    *)       die "外観は default・dark・clear・tinted のどれかです: $1" ;;
  esac
  run_robot testStyle "CT_ROBOT_STYLE=${label}"
  save_widgets
}

# アプリアイコンの大きさ。large（大きいアプリアイコン）では名前のラベルが消え、ウィジェットの位置も変わる
# （透過の初期値表の「ラベルなし」を測る。プラン §9 Phase 3 の 3-C ①）。
cmd_icons() {
  local state
  case "${1:?large か normal を渡してください}" in
    large)  state=on ;;
    normal) state=off ;;
    *)      die "アイコンの大きさは large か normal です: $1" ;;
  esac
  run_robot testStyle "CT_ROBOT_LARGE_ICONS=${state}"
  save_widgets
}

cmd_dump() {
  run_robot testDump
  extract_dump "${OUT_DIR}/dump.txt"
  ok "${OUT_DIR}/dump.txt"
}

main() {
  # 途中で止まっても、裏で回している画面収録とロボットは必ず止める
  # （止めないと、動くままのシミュレータを録り続け、ロボットも操作を続ける）。
  trap 'stop_recording; stop_robot' EXIT
  local -a rest=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device)  device_name="${2:?--device には端末名が必要です}"; shift 2 ;;
      -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}"; exit 0 ;;
      *)         rest+=("$1"); shift ;;
    esac
  done
  [[ ${#rest[@]} -gt 0 ]] || { sed -n '2,33p' "${BASH_SOURCE[0]}"; exit 1; }
  require_tool xcrun
  local command="${rest[0]}"
  local -a args=("${rest[@]:1}")
  case "${command}" in
    build)   build_all ;;
    gallery) cmd_gallery ;;
    place)   cmd_place "${args[@]+"${args[@]}"}" ;;
    clear)   cmd_clear ;;
    shot)    cmd_shot "${args[@]+"${args[@]}"}" ;;
    record)  cmd_record "${args[@]+"${args[@]}"}" ;;
    count)   cmd_count "${args[@]+"${args[@]}"}" ;;
    edit)    cmd_edit "${args[@]+"${args[@]}"}" ;;
    look)    cmd_look "${args[@]+"${args[@]}"}" ;;
    style)   cmd_style "${args[@]+"${args[@]}"}" ;;
    icons)   cmd_icons "${args[@]+"${args[@]}"}" ;;
    dump)    cmd_dump ;;
    *)       die "不明なコマンド: ${command}（--help で使い方を表示）" ;;
  esac
}

main "$@"
