#!/usr/bin/env bash
# 서버 배포: 최신 커밋을 받아 vault를 빌드하고, 검사를 통과하면 Caddy가 서빙하는 폴더를 교체한다
# 사용법: deploy/deploy.sh [--dry-run | --ci]
#   --dry-run  최신 커밋을 받아 빌드와 검사까지만 하고 사이트는 교체하지 않음
#   --ci       CI용. checkout한 커밋 그대로 테스트 vault(deploy/test-vault)를 빌드하고 검사만 함
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

# CI는 테스트 vault를 Quartz 기본 출력 폴더(public/)에 빌드한다
if [[ $mode == ci ]]; then
  VAULT_DIR=deploy/test-vault
  STAGING=public
fi

# sudo로 실행하면 root 소유 파일(node_modules 등)이 남아 다음 배포가 실패한다
if [[ $EUID -eq 0 ]]; then
  echo "✗ root가 아닌 본인 계정으로 실행하세요" >&2
  exit 1
fi

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."

# 두 실행이 겹치면 한쪽의 pull·빌드가 다른 쪽이 복사 중인 빌드 결과를 바꿔, rsync가 사이트 파일까지 지울 수 있다
exec 9>/tmp/quartz-deploy.lock
if ! flock -n 9; then
  echo "✗ 다른 배포가 실행 중입니다" >&2
  exit 1
fi

# 최신 커밋 받기 (서버에서 직접 고친 내용 때문에 merge가 필요하면 여기서 멈춤)
# bash는 이미 연 스크립트를 계속 읽으므로, pull로 바뀐 내용이 이번 실행부터 적용되게 다시 실행한다
if [[ $mode != ci && ${DEPLOY_PULLED:-} != 1 ]]; then
  git pull --ff-only 9>&- # git이 백그라운드로 띄우는 gc가 잠금(fd 9)을 물고 남지 않게 닫는다
  DEPLOY_PULLED=1 exec bash deploy/deploy.sh "$@"
fi

# mise.toml의 Node 버전 사용 (스크립트에서는 mise가 자동으로 켜지지 않음)
mise install
eval "$(mise env -s bash)"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# 의존성·플러그인은 잠금 파일이 바뀌었을 때만 다시 설치한다 (플러그인 44개 빌드에 몇 분 걸림)
# 설치에 실패하면 stamp를 남기지 않으므로 다음 실행에서 다시 설치한다
stamp=.quartz/.install-stamp
lock_hash="$(cat package-lock.json quartz.lock.json | sha256sum | cut -d' ' -f1)"
if [[ ! -d node_modules || "$(cat "$stamp" 2>/dev/null)" != "$lock_hash" ]]; then
  # 플러그인 폴더는 지우고 잠금 파일의 커밋으로 새로 받는다 (기존 폴더 갱신은 원격 최신 커밋이 아니면 실패함)
  rm -f "$stamp"
  rm -rf .quartz/plugins
  npm ci
  # plugin install은 일부 플러그인이 실패해도 종료 코드 0으로 끝나므로 출력으로 판단한다
  npx quartz plugin install 2>&1 | tee "$log"
  if grep -q "✗" "$log"; then
    echo "✗ 플러그인 설치에 실패해 중단합니다" >&2
    exit 1
  fi
  echo "$lock_hash" > "$stamp"
fi

# 사이트는 STAGING에 빌드하고, 아래 검사를 모두 통과해야 LIVE로 교체한다 (빌드 중에도 기존 사이트는 그대로)
# 플러그인을 불러오지 못해도 빌드는 계속되므로 (explicit-publish가 빠지면 비공개 노트까지 빌드됨) 출력으로 판단한다
# -v는 쓰지 않는다: 걸러낸 비공개 노트 경로가 로그에 찍힌다
npx quartz build -d "$VAULT_DIR" -o "$STAGING" 2>&1 | tee "$log"
if grep -qE "Failed to (install|instantiate) plugin|Could not (load|determine category for) plugin|did not return a valid plugin|missing the required methods|has no factory function|declares (components|frames) but failed to load|declared in manifest but not found|not a valid PageFrame" "$log"; then
  echo "✗ 플러그인을 불러오지 못해 배포를 중단합니다" >&2
  exit 1
fi
# vault에는 비공개 노트가 항상 있으므로, 하나도 걸러지지 않았다면 publish 필터가 동작하지 않은 것
if grep -q "Filtered out 0 files" "$log"; then
  echo "✗ publish 필터가 노트를 하나도 거르지 않아 배포를 중단합니다" >&2
  exit 1
fi
node deploy/check-publish.mjs "$VAULT_DIR" "$STAGING"

# deploy/Caddyfile은 서버 Caddy 설정의 사본이다. 서버 설정이 없거나 한쪽만 고쳤으면 알려준다 (배포는 계속함)
if [[ $mode != ci ]]; then
  if [[ ! -f $CADDY_SNIPPET ]]; then
    echo "⚠ 서버 Caddy 설정($CADDY_SNIPPET)이 없습니다. Caddy가 wiki를 서빙하지 않습니다" >&2
  elif ! cmp -s deploy/Caddyfile "$CADDY_SNIPPET"; then
    echo "⚠ deploy/Caddyfile이 서버 Caddy 설정($CADDY_SNIPPET)과 다릅니다. 둘을 같게 맞추세요" >&2
  fi
fi
# Caddy 설정은 index.html과 404.html이 있다고 보고 서빙하므로, 없으면 빌드가 잘못된 것
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

# 빌드는 매번 모든 파일을 새로 쓰므로, 내용이 같은 파일은 건드리지 않아(--checksum, --no-times) mtime을 유지한다
# Caddy의 ETag는 mtime으로 만들어지므로, 그래야 바뀌지 않은 페이지·폰트·이미지를 브라우저가 304로 다시 쓴다
# 바뀐 파일은 다 받은 뒤 마지막에 연달아 제자리로 옮기고(--delay-updates), 없어진 파일은 그다음에 지운다(--delete-after)
# 중간에 끊기면 다시 실행하면 된다. 끊긴 실행이 남긴 임시 폴더(.~tmp~)는 다음 실행에서 지운다 (--filter R)
rsync -a --no-times --checksum --delay-updates --delete-after --filter='R .~tmp~/' "$STAGING/" "$LIVE/"

echo "✅ $(date -Is) — $(find "$LIVE" -name '*.html' | wc -l) pages"
