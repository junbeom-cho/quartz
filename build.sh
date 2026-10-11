#!/usr/bin/env bash
# 서버 배포: 최신 설정을 받고 cloudflare/deploy.sh로 빌드·검사·업로드한다
# 사용법: bash build.sh [--dry-run]
set -euo pipefail

QUARTZ_DIR=/home/techbara/quartz
VAULT_DIR=/home/techbara/obsidian-vault

cd "$QUARTZ_DIR"

# 업로드에 쓸 Cloudflare 토큰 (wrangler가 자동으로 읽음). 없으면 빌드 전에 멈춘다
if [[ ! -f .env ]]; then
  echo "✗ $QUARTZ_DIR/.env가 없습니다. .env.example을 복사해서 토큰을 넣으세요" >&2
  exit 1
fi

# 최신 설정 받기 (서버에서 직접 고친 내용 때문에 merge가 필요하면 여기서 멈춤)
# bash는 이미 연 build.sh를 계속 읽으므로, pull로 바뀐 내용이 이번 실행부터 적용되게 다시 실행한다
if [[ "${BUILD_SH_PULLED:-}" != 1 ]]; then
  git pull --ff-only
  BUILD_SH_PULLED=1 exec bash "$QUARTZ_DIR/build.sh" "$@"
fi

# mise.toml의 Node 버전 사용 (스크립트에서는 mise가 자동으로 켜지지 않음)
mise install
eval "$(mise env -s bash)"

# 빌드와 비공개 노트 검사가 통과했을 때만 Cloudflare에 올린다 (set -e)
VAULT_DIR="$VAULT_DIR" bash cloudflare/deploy.sh "$@"

echo "✅ $(date -Is) — $(find public -name '*.html' | wc -l) pages"
