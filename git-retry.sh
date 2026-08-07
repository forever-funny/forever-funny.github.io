#!/usr/bin/env bash
# git-retry.sh — 网络不稳时无限重试 git push / clone(pull)
# 用法见 --help

set -u

# 默认参数
INTERVAL=1          # 失败后等待秒数
TIMEOUT=120         # 单次操作超时秒数（0 表示不超时）
MAX_RETRIES=0       # 0 = 无限重试
REMOTE=origin
BRANCH=""
DEPTH=0             # clone 深度，0 = 完整克隆
TARGET_DIR=""

usage() {
  cat <<'EOF'
用法:
  git-retry.sh push  [选项] [remote] [branch]
  git-retry.sh clone [选项] <仓库URL> [目标目录]
  git-retry.sh pull  [选项] [remote] [branch]

命令:
  push   在当前仓库目录无限重试 git push
  clone  从指定 URL 拉取（clone）；失败/超时后继续重试
  pull   在当前仓库目录无限重试 git pull

选项:
  -i, --interval <秒>   失败后等待时间，默认 1
  -t, --timeout <秒>    单次操作超时，默认 120；0 表示不限时
  -n, --max-retries <N> 最大重试次数，默认 0（无限）
  -d, --depth <N>       clone 时浅克隆深度（仅 clone）
  -h, --help            显示帮助

示例:
  # 当前目录不停重试 push
  ./git-retry.sh push
  ./git-retry.sh push origin main
  ./git-retry.sh push -i 10 -t 60

  # 不停重试从仓库地址 clone
  ./git-retry.sh clone https://github.com/org/repo.git
  ./git-retry.sh clone -t 180 git@github.com:org/repo.git my-repo

  # 不停重试 pull
  ./git-retry.sh pull -i 8
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  log "错误: $*"
  exit 1
}

# 带超时执行命令；无 timeout 命令时退化为直接执行
run_with_timeout() {
  local timeout_sec=$1
  shift

  if [[ "$timeout_sec" -le 0 ]]; then
    "$@"
    return $?
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground "${timeout_sec}s" "$@"
    return $?
  fi

  # Git Bash / 无 GNU timeout：用后台进程 + kill 模拟
  "$@" &
  local pid=$!
  (
    sleep "$timeout_sec"
    if kill -0 "$pid" 2>/dev/null; then
      log "操作超时 (${timeout_sec}s)，终止进程 $pid"
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
    fi
  ) &
  local watchdog=$!
  wait "$pid"
  local rc=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return $rc
}

retry_loop() {
  local attempt=0
  local rc=0
  local desc=$1
  shift

  while true; do
    attempt=$((attempt + 1))
    log "第 ${attempt} 次尝试: ${desc}"

    if run_with_timeout "$TIMEOUT" "$@"; then
      log "成功: ${desc}"
      return 0
    fi
    rc=$?

    if [[ "$MAX_RETRIES" -gt 0 && "$attempt" -ge "$MAX_RETRIES" ]]; then
      die "已达最大重试次数 ${MAX_RETRIES}，最后退出码=${rc}"
    fi

    log "失败 (exit=${rc})，${INTERVAL}s 后重试..."
    sleep "$INTERVAL"
  done
}

do_push() {
  local remote=${1:-$REMOTE}
  local branch=${2:-$BRANCH}
  local -a args=(git push "$remote")

  if [[ -n "$branch" ]]; then
    args+=("$branch")
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "当前目录不是 git 仓库"
  fi

  retry_loop "git push ${remote}${branch:+ ${branch}}" "${args[@]}"
}

do_clone() {
  local url=${1:-}
  local dir=${2:-$TARGET_DIR}

  [[ -n "$url" ]] || die "clone 需要仓库 URL，例如: git-retry.sh clone <url> [dir]"

  local -a args=(git clone)
  if [[ "$DEPTH" -gt 0 ]]; then
    args+=(--depth "$DEPTH")
  fi
  args+=("$url")
  if [[ -n "$dir" ]]; then
    args+=("$dir")
  fi

  # 目标目录已存在且非空：改为在该目录 pull
  local dest="$dir"
  if [[ -z "$dest" ]]; then
    dest=$(basename "$url" .git)
  fi

  if [[ -d "$dest/.git" ]]; then
    log "目录已存在且为 git 仓库: $dest，改为 pull"
    (
      cd "$dest" || exit 1
      retry_loop "git pull (in $dest)" git pull
    )
    return $?
  fi

  if [[ -e "$dest" ]]; then
    die "目标路径已存在且不是空仓库: $dest"
  fi

  retry_loop "git clone ${url}${dir:+ -> ${dir}}" "${args[@]}"
}

do_pull() {
  local remote=${1:-$REMOTE}
  local branch=${2:-$BRANCH}
  local -a args=(git pull "$remote")

  if [[ -n "$branch" ]]; then
    args+=("$branch")
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "当前目录不是 git 仓库"
  fi

  retry_loop "git pull ${remote}${branch:+ ${branch}}" "${args[@]}"
}

# ---- 参数解析 ----
CMD=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -i|--interval)
      INTERVAL=$2
      shift 2
      ;;
    -t|--timeout)
      TIMEOUT=$2
      shift 2
      ;;
    -n|--max-retries)
      MAX_RETRIES=$2
      shift 2
      ;;
    -d|--depth)
      DEPTH=$2
      shift 2
      ;;
    push|clone|pull)
      CMD=$1
      shift
      ;;
    --)
      shift
      POSITIONAL+=("$@")
      break
      ;;
    -*)
      die "未知选项: $1（用 --help 查看用法）"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

[[ -n "$CMD" ]] || { usage; exit 1; }

command -v git >/dev/null 2>&1 || die "未找到 git，请先安装并加入 PATH"

case "$CMD" in
  push)
    do_push "${POSITIONAL[@]+"${POSITIONAL[@]}"}"
    ;;
  clone)
    do_clone "${POSITIONAL[@]+"${POSITIONAL[@]}"}"
    ;;
  pull)
    do_pull "${POSITIONAL[@]+"${POSITIONAL[@]}"}"
    ;;
  *)
    die "未知命令: $CMD"
    ;;
esac
