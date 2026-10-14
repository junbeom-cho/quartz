#!/usr/bin/env bash
# 서버 배포: 최신 설정을 받아 vault를 빌드하고, 검사를 통과하면 Caddy가 서빙하는 폴더를 교체한다
# 사용법: bash build.sh [--dry-run]   (--dry-run: 빌드와 검사만 하고 교체하지 않음)
set -euo pipefail

QUARTZ_DIR=/home/techbara/quartz
VAULT_DIR=/home/techbara/obsidian-vault
STAGING=/data/quartz/.staging
LIVE=/data/caddy/site/wiki

cd "$QUARTZ_DIR"

# 최신 설정 받기 (서버에서 직접 고친 내용 때문에 merge가 필요하면 여기서 멈춤)
# bash는 이미 연 build.sh를 계속 읽으므로, pull로 바뀐 내용이 이번 실행부터 적용되게 다시 실행한다
if [[ "${BUILD_SH_PULLED:-}" != 1 ]]; then
  git pull --ff-only
  BUILD_SH_PULLED=1 exec bash "$QUARTZ_DIR/build.sh" "$@"
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

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "✓ 검사 통과 (--dry-run이라 배포하지 않음)"
  exit 0
fi

rsync -a --delete "$STAGING/" "$LIVE/"

echo "✅ $(date -Is) — $(find "$LIVE" -name '*.html' | wc -l) pages"
