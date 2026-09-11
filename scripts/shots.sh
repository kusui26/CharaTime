#!/usr/bin/env bash
#
# 時刻を変えながら待受モードを撮る。
#
# ビルドはしない（`scripts/ios-loop.sh` が済ませてある前提）。同じアプリを
# 時刻だけ変えて起動し直すので、1 枚あたり数秒で撮れる。
# **夜中に開発していると寝ている姿しか見られない**ので、これが無いと見た目を直せない。
#
# 使い方:
#   scripts/shots.sh 07:10 12:30 20:45          .shots/ に 3 枚
#   scripts/shots.sh --out /tmp/x 14:00         出力先を変える
#   scripts/shots.sh --speed 240 07:00          早送りで起動して撮る
#
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUNDLE_ID="app.charatime"
readonly DEVICE="iPhone 17 Pro"
# 起動してから描画が落ち着くまでの待ち。短いと真っ白な画像になる。
readonly SETTLE_SEC=6

out_dir="${REPO_ROOT}/.shots"
speed=0
times=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)   out_dir="${2:?--out にはディレクトリが必要です}"; shift 2 ;;
    --speed) speed="${2:?--speed には倍率が必要です}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) times+=("$1"); shift ;;
  esac
done

log()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

[[ ${#times[@]} -gt 0 ]] || die "時刻を 1 つ以上渡してください（例: scripts/shots.sh 07:10 20:45）"
mkdir -p "${out_dir}"

for moment in "${times[@]}"; do
  label="$(printf '%s' "${moment}" | tr -d ':')"
  target="${out_dir}/at-${label}.png"
  xcrun simctl terminate "${DEVICE}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  xcrun simctl launch "${DEVICE}" "${BUNDLE_ID}" -CTTime "${moment}" -CTSpeed "${speed}" \
    >/dev/null || die "${moment} で起動できませんでした"
  sleep "${SETTLE_SEC}"
  xcrun simctl io "${DEVICE}" screenshot --type=png "${target}" >/dev/null 2>&1 \
    || die "${moment} のスクリーンショットを撮れませんでした"
  log "${moment} → ${target}"
done
