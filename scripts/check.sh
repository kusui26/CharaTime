#!/usr/bin/env bash
#
# CharaTime 品質ゲート
#
# .claude/CLAUDE.md §3 が要求する 3 つを、この順に回す。
#   ① lint       swiftlint --strict（規約のうち機械が見張れる部分）
#   ② typecheck  swift build（警告を 1 件も残さない）
#   ③ test       swift test（4 パッケージの単体テスト）
#
# コミットの前に必ずこれを通す。CI（.github/workflows/ios.yml）も同じものを見る。
# シミュレータを起動しないので数秒で終わる。メモリ 8 GB の機械ではこれが主戦場。
#
# 使い方:
#   scripts/check.sh              ①②③
#   scripts/check.sh --no-lint    swiftlint が入っていない環境で②③だけ
#
set -euo pipefail

# 失敗したら、どこで落ちたかを最後にはっきり出す。
# ログの末尾だけを見て「通った」と早合点しないため。
trap 'status=$?; [[ ${status} -ne 0 ]] && printf "\033[1;31m✗ 失敗しました（終了コード %d・%s の %d 行目）\033[0m\n" "${status}" "${BASH_SOURCE[0]}" "${LINENO}" >&2; exit ${status}' ERR

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IOS_DIR="${REPO_ROOT}/ios"

run_lint=true
[[ "${1:-}" == "--no-lint" ]] && run_lint=false

log()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

lint() {
  if ! command -v swiftlint >/dev/null 2>&1; then
    die "swiftlint がありません。brew install swiftlint で入れるか --no-lint を付けてください。"
  fi
  log "① lint（製品コード）"
  swiftlint lint --strict --quiet --config "${REPO_ROOT}/.swiftlint.yml"
  log "① lint（テスト）"
  swiftlint lint --strict --quiet --config "${REPO_ROOT}/.swiftlint-tests.yml"
}

# SwiftPM は、**依存パッケージにファイルが増えた**ことを取りこぼす。
#
# 増えた型を使うと「value of type 'X' has no member 'y'」という、原因から遠い形で
# 落ちる。ファイルを直しただけなら取りこぼさないので、**顔ぶれが変わったときだけ**
# 作り直す。顔ぶれは各パッケージの Sources のファイル一覧の指紋で見る。
prune_stale_builds() {
  local fingerprint marker pkg
  fingerprint="$(find "${IOS_DIR}"/Packages/*/Sources -name '*.swift' | sort | shasum | cut -d' ' -f1)"
  for pkg in "${IOS_DIR}"/Packages/*/; do
    marker="${pkg}.build/.ct-sources"
    [[ -d "${pkg}.build" ]] || continue
    if [[ "$(cat "${marker}" 2>/dev/null)" != "${fingerprint}" ]]; then
      rm -rf "${pkg}.build"
      printf '   └ %s を作り直します（ファイルの顔ぶれが変わりました）\n' "$(basename "${pkg}")"
    fi
  done
  for pkg in "${IOS_DIR}"/Packages/*/; do
    mkdir -p "${pkg}.build" && printf '%s' "${fingerprint}" > "${pkg}.build/.ct-sources"
  done
}

# 警告を 1 件でも出したら落とす。「警告は後で直す」を溜めないため。
build() {
  log "② ビルド（警告ゼロ）"
  local pkg output
  for pkg in "${IOS_DIR}"/Packages/*/; do
    [[ -f "${pkg}/Package.swift" ]] || continue
    output="$(swift build --package-path "${pkg}" 2>&1)" || { echo "${output}"; die "$(basename "${pkg}") のビルドが失敗しました。"; }
    if grep -q 'warning:' <<<"${output}"; then
      grep 'warning:' <<<"${output}"
      die "$(basename "${pkg}") に警告があります。"
    fi
    printf '   └ %s\n' "$(basename "${pkg}")"
  done
}

test_packages() {
  log "③ テスト"
  local pkg
  for pkg in "${IOS_DIR}"/Packages/*/; do
    [[ -f "${pkg}/Package.swift" ]] || continue
    printf '   └ %-10s ' "$(basename "${pkg}")"
    swift test --package-path "${pkg}" 2>&1 | grep -oE 'Test run with [0-9]+ tests.*' | tail -1
  done
}

[[ "${run_lint}" == true ]] && lint
prune_stale_builds
build
test_packages
printf '\033[1;32m✓ 品質ゲートを通過\033[0m\n'
