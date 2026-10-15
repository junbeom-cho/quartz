#!/usr/bin/env bash
# cron용: 아직 배포하지 않은 커밋(origin의 새 커밋이나 서버에서 한 커밋)이 있으면 deploy.sh로 배포하고 deploy/logs/에 남긴다
set -uo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
mkdir -p deploy/logs
log="deploy/logs/$(date +%Y-%m).log"

# origin/HEAD는 remote를 다시 추가하면 없어지고 fetch로는 다시 생기지 않으므로 origin에 물어 만든다
git symbolic-ref -q refs/remotes/origin/HEAD >/dev/null || timeout 2m git remote set-head origin -a >/dev/null 2>&1
# origin 기본 브랜치(quartz는 v5, astro-paper는 main)를 체크아웃하고 있을 때만 배포한다
[[ origin/$(git symbolic-ref --short -q HEAD) == "$(git symbolic-ref --short -q refs/remotes/origin/HEAD)" ]] || exit 0

if ! err=$(timeout -v 2m git fetch --quiet 2>&1); then
  echo "$(date -Is) ✗ git fetch 실패: ${err//$'\n'/ }" >> "$log"
  exit 1
fi

# origin에 HEAD에 없는 커밋이 있으면 origin 쪽, 아니면 HEAD가 배포할 커밋
target=$(git rev-parse HEAD)
if ! git merge-base --is-ancestor '@{u}' HEAD 2>/dev/null; then
  target=$(git rev-parse '@{u}' 2>/dev/null) # upstream이 없으면 cron 메일 대신 deploy.sh의 pull 오류로 로그에 남는다
fi
deployed=$(cat deploy/logs/deployed-commit 2>/dev/null)
[[ $target == "$deployed" ]] && exit 0
# 실패한 커밋은 1시간마다 다시 시도한다 (네트워크 오류처럼 저절로 풀리는 실패 대비)
[[ $target == "$(cat deploy/logs/failed-commit 2>/dev/null)" && -n $(find deploy/logs/failed-commit -mmin -60 2>/dev/null) ]] && exit 0

# 커밋하지 않은 변경도 그대로 빌드돼 사이트에 올라가므로, 작업 트리가 깨끗해질 때까지 미룬다 (로그는 커밋마다 한 번)
if [[ -n $(git --no-optional-locks status --porcelain) ]]; then
  if [[ $target != "$(cat deploy/logs/skipped-commit 2>/dev/null)" ]]; then
    echo "$(date -Is) ⚠ 커밋하지 않은 변경이 있어 ${target:0:7} 배포를 미룹니다" >> "$log"
    echo "$target" > deploy/logs/skipped-commit
  fi
  exit 0
fi

echo "===== $(date -Is) ${deployed:0:7} → ${target:0:7}" >> "$log"
deploy/deploy.sh >> "$log" 2>&1
rc=$?
case $rc in
  0) rm -f deploy/logs/failed-commit ;;
  75) ;; # 다른 배포가 실행 중: 다음 실행에서 다시 시도한다
  *)
    echo "$target" > deploy/logs/failed-commit
    echo "$(date -Is) ✗ 배포 실패 (exit $rc)" >> "$log"
    ;;
esac
exit "$rc"
