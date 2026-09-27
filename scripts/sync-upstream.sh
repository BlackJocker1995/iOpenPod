#!/usr/bin/env bash
# Sync upstream iOpenPod into this fork.
#
# Branch model:
#   origin/main            upstream (TheRealSavi/iOpenPod) — source of truth for upstream work
#   feat/subsonic-source   PR branch (#139) — kept clean, only Subsonic-PR commits
#   main                   this fork's default line = PR branch + fork-only commits (README notice, this script)
#
# Flow:  origin/main -> feat/subsonic-source (merge) -> main (rebase fork-only commits on top)
# main is rebased, so its push needs --force-with-lease; safe because this line is only pushed here.
set -euo pipefail

UPSTREAM=origin
ORIGIN=fork
PR_BRANCH=feat/subsonic-source
MAIN=main

cd "$(git rev-parse --show-toplevel)"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "✗ 有未提交的改动，先 commit 或 stash 再同步。" >&2
  exit 1
fi

git fetch "$UPSTREAM" main
git fetch "$ORIGIN"

BEHIND=$(git rev-list --count "$PR_BRANCH..$UPSTREAM/main")
if [ "$BEHIND" -eq 0 ]; then
  echo "✓ 上游没有新内容，检查 fork 分支是否一致…"
else
  echo "→ 上游有 $BEHIND 个新提交，开始同步…"
  git switch "$PR_BRANCH"
  if git merge --no-edit "$UPSTREAM/main"; then
    git push "$ORIGIN" "$PR_BRANCH"
    echo "✓ $PR_BRANCH 已并入上游并推送（PR #139 自动更新）。"
  else
    echo "✗ $PR_BRANCH 合并冲突。解决后: git add -A && git commit && git push $ORIGIN $PR_BRANCH" >&2
    exit 1
  fi
fi

git switch "$MAIN"
if git rebase "$PR_BRANCH"; then
  git push --force-with-lease "$ORIGIN" "$MAIN"
  echo "✓ 同步完成：$UPSTREAM/main → $PR_BRANCH → $MAIN"
else
  echo "✗ main 上 fork 专属提交 rebase 冲突（通常是 README 提示块附近）。" \
       "解决后: git add -A && git rebase --continue && git push --force-with-lease $ORIGIN $MAIN" >&2
  exit 1
fi
