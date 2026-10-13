#!/usr/bin/env bash
# vault를 빌드하고 검사한 뒤 public/을 Cloudflare Workers에 올린다. 서버의 build.sh와 PC에서 같이 쓴다.
#
# 사용법: VAULT_DIR=<vault 경로> bash cloudflare/deploy.sh [wrangler deploy 옵션]
#   업로드 없이 빌드와 검사만: VAULT_DIR=<vault 경로> bash cloudflare/deploy.sh --dry-run
# 인증: PC는 npx wrangler login 한 번. 서버는 quartz 폴더의 .env (.env.example 참고)
set -euo pipefail

# 상대 경로로 받은 VAULT_DIR은 아래 cd 전에 절대 경로로 바꾼다 (없는 경로면 여기서 실패)
: "${VAULT_DIR:?VAULT_DIR에 vault 경로를 지정하세요}"
VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"
cd "$(dirname "$0")/.."

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

# 플러그인을 불러오지 못해도 빌드는 계속되므로 (explicit-publish가 빠지면 비공개 노트까지 빌드됨) 출력으로 판단한다
# -v는 쓰지 않는다: 걸러낸 비공개 노트 경로가 로그에 찍힌다
npx quartz build -d "$VAULT_DIR" -o public 2>&1 | tee "$log"
if grep -qE "Failed to (install|instantiate) plugin|Could not (load|determine category for) plugin|did not return a valid plugin|missing the required methods|has no factory function|declares (components|frames) but failed to load|declared in manifest but not found|not a valid PageFrame" "$log"; then
  echo "✗ 플러그인을 불러오지 못해 배포를 중단합니다" >&2
  exit 1
fi
# vault에는 비공개 노트가 항상 있으므로, 하나도 걸러지지 않았다면 publish 필터가 동작하지 않은 것
if grep -q "Filtered out 0 files" "$log"; then
  echo "✗ publish 필터가 노트를 하나도 거르지 않아 배포를 중단합니다" >&2
  exit 1
fi

node cloudflare/check-publish.mjs "$VAULT_DIR" public
cp cloudflare/_headers public/_headers
cp cloudflare/_redirects public/_redirects

# .env의 토큰은 wrangler가 직접 읽는다 (빌드 중 플러그인 코드의 환경 변수에는 들어가지 않음)
npx wrangler@4 deploy "$@"
