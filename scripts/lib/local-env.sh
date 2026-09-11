# このマシン固有の設定を読み込む。
#
# リポジトリ直下の .env.local に書かれた値を環境変数として取り込む。
# 無ければ何もしない（シミュレータでの確認には要らないため）。
#
# 各スクリプトの先頭で読み込んで使う:
#   source "${REPO_ROOT}/scripts/lib/local-env.sh"
#   load_local_env "${REPO_ROOT}"

load_local_env() {
  local repo_root="$1"
  local env_file="${repo_root}/.env.local"
  [[ -f "${env_file}" ]] || return 0

  # KEY=VALUE の行だけを取り込む。コメントと空行は無視する。
  # source や eval は使わない。設定ファイルに書いた文字列をそのまま
  # 実行してしまうため。
  local key value
  while IFS='=' read -r key value; do
    key="${key// /}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [[ -n "${value}" ]] || continue
    # すでに環境にあるものは上書きしない。その場限りの指定を優先させる。
    [[ -n "${!key:-}" ]] && continue
    export "${key}=${value}"
  done < "${env_file}"
}
