#!/usr/bin/env bash
# 서버 배포: 최신 커밋을 받아 vault를 빌드하고, 검사를 통과하면 Caddy가 서빙하는 폴더를 교체한다
# 사용법: deploy/deploy.sh [--dry-run | --ci]   (--dry-run: 교체하지 않음, --ci: pull 없이 테스트 vault로 빌드·검사만)
set -euo pipefail

VAULT_DIR=/home/techbara/obsidian-vault
STAGING=/data/quartz/.staging
LIVE=/data/caddy/site/wiki
CADDY_SNIPPET=/home/techbara/homelab/docker/caddy/conf/conf.d/03-quartz.caddy

case "$#:${1-}" in
  0:) mode=deploy ;;
  1:--dry-run) mode=dry-run ;;
  1:--ci) mode=ci ;;
  *)
    echo "사용법: deploy/deploy.sh [--dry-run | --ci]" >&2
    exit 2
    ;;
esac

if [[ $mode == ci ]]; then
  VAULT_DIR=deploy/test-vault
  STAGING=public
fi

# root로 돌리면 root 소유 파일이 남아 다음 배포가 실패한다
if [[ $EUID -eq 0 ]]; then
  echo "✗ root가 아닌 본인 계정으로 실행하세요" >&2
  exit 1
fi

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."

# 동시에 돌면 한쪽이 다른 쪽의 빌드 결과를 지워 rsync가 사이트 파일을 지울 수 있다
exec 9>/tmp/quartz-deploy.lock
if ! flock -n 9; then
  echo "✗ 다른 배포가 실행 중입니다" >&2
  exit 75 # cron.sh는 다음 실행에서 다시 시도한다
fi

# pull로 바뀐 이 스크립트를 이번 실행부터 쓰도록 다시 실행한다
if [[ $mode != ci && ${DEPLOY_PULLED:-} != 1 ]]; then
  timeout -v 2m git pull --ff-only 9>&- # 네트워크가 멈춰도 잠금을 문 채 기다리지 않게, git이 띄운 gc가 잠금을 물고 남지 않게
  DEPLOY_PULLED=1 exec bash deploy/deploy.sh "$@"
fi
commit=$(git rev-parse HEAD) # 끝에서 HEAD를 다시 읽으면 빌드 중에 생긴 커밋까지 배포된 것으로 기록된다

mise install
eval "$(mise env -s bash)"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# 의존성·플러그인은 잠금 파일이 바뀌었을 때만 다시 설치한다 (플러그인 빌드에 몇 분 걸림)
stamp=.quartz/.install-stamp
lock_hash="$(cat package-lock.json quartz.lock.json | sha256sum | cut -d' ' -f1)"
if [[ ! -d node_modules || "$(cat "$stamp" 2>/dev/null)" != "$lock_hash" ]]; then
  rm -f "$stamp"
  rm -rf .quartz/plugins # 기존 폴더는 원격 최신 커밋이 아니면 갱신에 실패한다
  npm ci
  # plugin install은 실패해도 종료 코드가 0이라 출력으로 판단한다
  npx quartz plugin install 2>&1 | tee "$log"
  if grep -q "✗" "$log"; then
    echo "✗ 플러그인 설치에 실패해 중단합니다" >&2
    exit 1
  fi
  echo "$lock_hash" > "$stamp"
fi

# 플러그인을 못 불러와도 빌드는 계속되므로(explicit-publish가 빠지면 비공개 노트까지 빌드됨) 출력으로 판단한다
# -v는 쓰지 않는다: 걸러낸 비공개 노트 경로가 로그에 남는다
npx quartz build -d "$VAULT_DIR" -o "$STAGING" 2>&1 | tee "$log"
if grep -qE "Failed to (install|instantiate) plugin|Could not (load|determine category for) plugin|did not return a valid plugin|missing the required methods|has no factory function|declares (components|frames) but failed to load|declared in manifest but not found|not a valid PageFrame" "$log"; then
  echo "✗ 플러그인을 불러오지 못해 배포를 중단합니다" >&2
  exit 1
fi
# vault에는 비공개 노트가 늘 있으므로, 하나도 안 걸렀다면 publish 필터가 동작하지 않은 것
if grep -q "Filtered out 0 files" "$log"; then
  echo "✗ publish 필터가 노트를 하나도 거르지 않아 배포를 중단합니다" >&2
  exit 1
fi
node deploy/check-publish.mjs "$VAULT_DIR" "$STAGING"

if [[ $mode != ci ]]; then
  if [[ ! -f $CADDY_SNIPPET ]]; then
    echo "⚠ 서버 Caddy 설정($CADDY_SNIPPET)이 없습니다. Caddy가 wiki를 서빙하지 않습니다" >&2
  elif ! cmp -s deploy/Caddyfile "$CADDY_SNIPPET"; then
    echo "⚠ deploy/Caddyfile이 서버 Caddy 설정($CADDY_SNIPPET)과 다릅니다. 둘을 같게 맞추세요" >&2
  fi
fi
for f in index.html 404.html; do
  if [[ ! -s "$STAGING/$f" ]]; then
    echo "✗ 빌드 결과에 $f 파일이 없어 배포를 중단합니다" >&2
    exit 1
  fi
done

if [[ $mode != deploy ]]; then
  echo "✓ 검사 통과 ($1: 사이트는 교체하지 않음)"
  exit 0
fi

# 내용이 같은 파일은 mtime(=Caddy ETag)을 유지하고(--checksum --no-times), 바뀐 파일은 끝에 한꺼번에 교체한다
# 끊긴 실행이 남긴 임시 폴더(.~tmp~)는 다음 실행에서 지운다
rsync -a --no-times --checksum --delay-updates --delete-after --filter='R .~tmp~/' "$STAGING/" "$LIVE/"

mkdir -p deploy/logs
echo "$commit" > deploy/logs/deployed-commit # cron.sh가 이미 배포한 커밋인지 판단하는 데 쓴다
echo "✅ $(date -Is) — $(find "$LIVE" -name '*.html' | wc -l) pages"
