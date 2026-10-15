#!/usr/bin/env bash
# cron용: 실행할 때마다 결과를 deploy/logs/deploy-<날짜>.log에 한 줄로 남긴다
# 아직 배포하지 않은 커밋(origin의 새 커밋이나 서버에서 한 커밋)이 있으면 deploy.sh로 배포하고, 그 출력은 deploy/logs/builds/에 따로 남긴다
# quartz와 astro-paper가 같은 파일을 쓴다
set -uo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
mkdir -p deploy/logs/builds
now=$(date '+%F %T')
log="deploy/logs/deploy-${now% *}.log" # 날마다 새 파일

# 이번 실행의 결과를 시작 시각과 함께 한 줄로 남긴다
note() { echo "$now $*" >> "$log"; }

# 일별 로그와 배포 출력은 2주만 남긴다
find deploy/logs -maxdepth 1 -name 'deploy-*.log' -mtime +13 -delete
find deploy/logs/builds -name '*.log' -mtime +13 -delete

# 실패 원인 한 줄. 위에서부터 처음 찾은 것을 쓴다
fail_reason() {
  local text r
  text=$(sed 's/\x1b\[[0-9;]*m//g' "$1") # 색 코드 제거
  r=$(grep -A 3 ' ERROR ' <<< "$text" | grep -v -e 'ERROR' -e '^[[:space:]]*$' | sed -n 1p) # Quartz 빌드 오류 (ERROR 다음 줄)
  [[ -n $r ]] || r=$(grep -m 1 -E '^\[[A-Za-z]*Error\] | - error | ERR_PNPM_' <<< "$text")  # Astro·astro check·pnpm 오류
  [[ -n $r ]] || r=$(grep '✗' <<< "$text" | tail -n 1)                                        # deploy.sh가 막은 이유
  [[ -n $r ]] || r=$(grep -v -e '^[[:space:]]*$' -e 'ELIFECYCLE' <<< "$text" | tail -n 1)   # 그 밖에는 출력의 마지막 줄
  r=${r##*✗ }
  sed 's/^[[:space:]]*//' <<< "$r"
}

# origin/HEAD는 remote를 다시 추가하면 없어지고 fetch로는 다시 생기지 않으므로 origin에 물어 만든다
git symbolic-ref -q refs/remotes/origin/HEAD >/dev/null || timeout 2m git remote set-head origin -a >/dev/null 2>&1
# origin 기본 브랜치(quartz는 v5, astro-paper는 main)를 체크아웃하고 있을 때만 배포한다
branch=$(git symbolic-ref --short -q HEAD)
default=$(git symbolic-ref --short -q refs/remotes/origin/HEAD)
if [[ -z $default ]]; then
  note "origin 기본 브랜치를 알 수 없음 (git remote set-head origin -a 실패)"
  exit 1
fi
if [[ origin/$branch != "$default" ]]; then
  note "건너뜀: ${branch:-detached HEAD} 체크아웃 중 (배포는 ${default#origin/}에서만)"
  exit 0
fi

if ! err=$(timeout -v 2m git fetch --quiet 2>&1); then
  note "fetch 실패: ${err//$'\n'/ }"
  exit 1
fi

# origin에 HEAD에 없는 커밋이 있으면 origin 쪽, 아니면 HEAD가 배포할 커밋
target=$(git rev-parse HEAD)
if ! git merge-base --is-ancestor '@{u}' HEAD 2>/dev/null; then
  target=$(git rev-parse '@{u}' 2>/dev/null) # upstream이 없으면 deploy.sh의 pull 오류로 실패가 남는다
fi
deployed=$(cat deploy/logs/deployed-commit 2>/dev/null)
if [[ -n $target && $target == "$deployed" ]]; then
  note "변화없음 (${deployed:0:7})"
  exit 0
fi
# 실패한 커밋은 1시간마다 다시 시도한다 (네트워크 오류처럼 저절로 풀리는 실패 대비)
if [[ $target == "$(cat deploy/logs/failed-commit 2>/dev/null)" && -n $(find deploy/logs/failed-commit -mmin -60 2>/dev/null) ]]; then
  note "재시도 대기: ${target:0:7} 배포 실패 (1시간마다 다시 시도)"
  exit 0
fi

# 커밋하지 않은 변경도 그대로 빌드돼 사이트에 올라가므로, 작업 트리가 깨끗해질 때까지 미룬다
if [[ -n $(git --no-optional-locks status --porcelain) ]]; then
  note "배포 미룸: 커밋하지 않은 변경이 있음 (${target:0:7})"
  exit 0
fi

# deploy.sh의 출력(git pull, 설치, 빌드)은 배포마다 파일 하나에 남기고, 로그에는 결과만 적는다
stamp=${now/ /_}
output="deploy/logs/builds/${stamp//:/}_${target:0:7}.log"
range="${deployed:+${deployed:0:7} → }${target:0:7}"
SECONDS=0
deploy/deploy.sh > "$output" 2>&1
rc=$?
case $rc in
  0)
    rm -f deploy/logs/failed-commit
    pages=$(grep '^✅' "$output" | grep -o '[0-9]* pages') # deploy.sh 끝의 "✅ <시각> — <N> pages"
    note "pull 및 빌드 성공: $range${pages:+, $pages}, ${SECONDS}초"
    ;;
  75) # 다른 배포가 실행 중: 아무것도 하지 않았으므로 출력은 지우고 다음 실행에서 다시 시도한다
    rm -f "$output"
    note "건너뜀: 다른 배포가 실행 중"
    exit "$rc"
    ;;
  *)
    echo "$target" > deploy/logs/failed-commit
    note "pull 및 빌드 실패: $range (exit $rc, ${SECONDS}초): $(fail_reason "$output")"
    ;;
esac
# Caddy 설정 불일치 같은 deploy.sh의 경고는 배포가 성공해도 알 수 있게 결과 줄 아래에 옮긴다
grep '^⚠' "$output" | while IFS= read -r line; do note "$line"; done
exit "$rc"
