#!/usr/bin/env bash
# 通用 Git 远程推送重试脚本：以脚本所在目录为仓库根，失败则持续重试直到成功。
#
# 用法:
#   ./push-retry.sh                  # 等价于: git push -u origin HEAD
#   ./push-retry.sh origin main      # 推指定远程与分支
#   ./push-retry.sh -- --tags        # 额外参数原样传给 git push
#
# 环境变量:
#   PUSH_RETRY_INTERVAL  失败后等待秒数，默认 1
#   PUSH_REMOTE          默认远程名，默认 origin

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || {
  echo "ERROR: cannot cd to script directory: $SCRIPT_DIR" >&2
  exit 1
}

INTERVAL="${PUSH_RETRY_INTERVAL:-1}"
REMOTE="${PUSH_REMOTE:-origin}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not a git repository: $SCRIPT_DIR" >&2
  exit 1
fi

# 解析参数：无参则推当前 HEAD；否则把参数交给 git push
PUSH_ARGS=()
if [[ $# -eq 0 ]]; then
  PUSH_ARGS=(-u "$REMOTE" HEAD)
elif [[ "$1" == "--" ]]; then
  shift
  PUSH_ARGS=("$@")
elif [[ $# -eq 1 ]]; then
  PUSH_ARGS=(-u "$1" HEAD)
elif [[ $# -ge 2 && "$1" != -* ]]; then
  PUSH_ARGS=(-u "$1" "$2")
  shift 2
  if [[ $# -gt 0 ]]; then
    PUSH_ARGS+=("$@")
  fi
else
  PUSH_ARGS=("$@")
fi

attempt=1
echo "Repo: $SCRIPT_DIR"
echo "Command: git push ${PUSH_ARGS[*]}"
echo "Retry interval: ${INTERVAL}s"
echo

while true; do
  echo "======== attempt #${attempt} @ $(date '+%Y-%m-%d %H:%M:%S') ========"
  if git push "${PUSH_ARGS[@]}"; then
    echo
    echo "Push succeeded after ${attempt} attempt(s)."
    exit 0
  fi
  status=$?
  echo
  echo "Push failed (exit=${status}). Retry in ${INTERVAL}s... (Ctrl+C to abort)"
  sleep "$INTERVAL"
  attempt=$((attempt + 1))
done
