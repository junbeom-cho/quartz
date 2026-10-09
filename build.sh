#!/usr/bin/env bash
set -euo pipefail

QUARTZ_DIR=/home/techbara/quartz
VAULT_DIR=/home/techbara/obsidian-vault
STAGING=/data/quartz/.staging
LIVE=/data/caddy/site/wiki

cd "$QUARTZ_DIR"

# 최신 설정 받기 (서버에서 직접 고친 내용 때문에 merge가 필요하면 여기서 멈춤)
BEFORE=$(git rev-parse HEAD)
git pull --ff-only

# mise.toml의 Node 버전 사용 (스크립트에서는 mise가 자동으로 켜지지 않음)
mise install
eval "$(mise env -s bash)"

# 의존성·플러그인 잠금 파일이 바뀌었을 때만 다시 설치
if ! git diff --quiet "$BEFORE" HEAD -- package-lock.json quartz.lock.json; then
  npm ci
  npx quartz plugin install
fi

npx quartz build -d "$VAULT_DIR" -o "$STAGING"

# 빌드가 성공했을 때만 교체 (set -e)
rsync -a --delete "$STAGING/" "$LIVE/"

echo "✅ $(date -Is) — $(find "$LIVE" -name '*.html' | wc -l) pages"