# Quartz Wiki

Obsidian vault에서 `publish: true`인 노트만 골라 [Quartz v5](https://quartz.jzhao.xyz/)로 정적 사이트를 만들고, 자기 서버의 Caddy로 게시하는 저장소입니다.
[jackyzha0/quartz](https://github.com/jackyzha0/quartz)의 fork이며, 업스트림은 그대로 따라가고 설정과 스타일만 바꿔 씁니다.

아래 설명에서 `wiki.example.com`은 사이트 도메인, `<사용자>`는 GitHub 계정, `<저장소 경로>`는 서버에서 이 저장소를 clone한 폴더입니다. 자기 값으로 바꿔 읽으세요.

## 셋업

필요 환경: Node.js 22 이상 (이 프로젝트는 [mise](https://mise.jdx.dev/)로 Node 24 사용), npm 10.9.2 이상

```bash
git clone git@github.com:<사용자>/quartz.git   # 이 저장소를 fork한 본인 저장소
cd quartz
mise install                # mise.toml → Node 24
npm ci                      # 의존성 설치
npx quartz plugin install   # quartz.lock.json 기준 플러그인 설치 (.quartz/plugins)
```

## 사용 명령어

| 명령어                                     | 설명                                                                |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `npx quartz build --serve -d <vault 경로>` | 로컬 미리보기 (<http://localhost:8080>, 파일 변경 시 자동 새로고침) |
| `npx quartz build -d <vault 경로>`         | `public/`에 정적 사이트 빌드                                        |
| `npx quartz upgrade`                       | 업스트림 최신 버전 반영                                             |
| `npx quartz plugin install`                | lockfile 기준 플러그인 설치                                         |
| `npx quartz plugin list`                   | 설치된 플러그인 목록                                                |
| `npm run docs`                             | Quartz 공식 문서(`docs/`)를 로컬에서 보기                           |
| `npm run check`                            | 타입 검사 + 포맷 검사                                               |

### 빌드 스크립트

로컬 미리보기용입니다. 안에 적힌 vault 경로를 자기 vault 경로로 바꿔서 씁니다.

| 파일            | 설명                              |
| --------------- | --------------------------------- |
| `mac-build.sh`  | macOS 로컬 미리보기 (포트 8080)   |
| `win-build.bat` | Windows 로컬 미리보기 (포트 8081) |

## 내 환경에 맞게 바꾸기

fork한 뒤 아래 값을 자기 것으로 바꿉니다. 사이트 주소가 들어간 곳은 `baseUrl`을 바꾸기 **전에** 이 명령으로 한 번에 찾을 수 있습니다.

```bash
git grep -nF "$(sed -n 's/^  baseUrl: //p' quartz.config.yaml)" -- ':!docs'
```

| 파일                                                     | 바꿀 값                                                                                                                                             |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`quartz.config.yaml`](quartz.config.yaml)               | `pageTitle`(사이트 이름), `baseUrl`(`wiki.example.com`, `https://` 없이), `ignorePatterns`(vault에서 빌드하지 않을 폴더), footer 플러그인의 `links` |
| [`quartz/static/robots.txt`](quartz/static/robots.txt)   | `Sitemap: https://wiki.example.com/sitemap.xml`                                                                                                     |
| [`quartz.ts`](quartz.ts)                                 | Umami 추적 스크립트의 `src`(Umami 서버 주소), `websiteId`, `domains`(사이트 도메인). Umami를 쓰지 않으면 `UmamiAnalytics` 블록을 통째로 지움        |
| [`quartz/styles/custom.scss`](quartz/styles/custom.scss) | footer 링크를 아이콘으로 바꾸는 `a[href*="…"]` 선택자. footer `links`의 주소와 맞춰야 아이콘이 나옴                                                 |
| [`deploy/deploy.sh`](deploy/deploy.sh) 맨 위 변수        | 아래 [배포](#배포)의 변수 표                                                                                                                        |
| [`deploy/Caddyfile`](deploy/Caddyfile)                   | `@quartz host wiki.example.com`, `.html` 주소를 리다이렉트하는 두 `redir`의 `https://wiki.example.com`                                              |
| [`guide/`](guide)                                        | 사이트 주소가 들어간 예시 (사이트 동작에는 영향 없음)                                                                                               |

## 배포

서버에서 vault를 빌드하고, 서버의 Caddy(Docker 컨테이너)가 결과물을 정적 파일로 서빙합니다. 배포에 쓰는 파일은 `deploy/`에 있습니다.

| 파일                                                   | 설명                                                                                                            |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| [`deploy/deploy.sh`](deploy/deploy.sh)                 | 서버 배포. 최신 커밋을 받아 빌드하고, 검사를 통과하면 사이트 폴더(`LIVE`)를 교체                                |
| [`deploy/cron.sh`](deploy/cron.sh)                     | cron용. 아직 배포하지 않은 커밋이 있으면 `deploy.sh`로 배포하고 `deploy/logs/`에 기록 ([자동 배포](#자동-배포)) |
| [`deploy/Caddyfile`](deploy/Caddyfile)                 | 서버 Caddy 설정(`CADDY_SNIPPET`)의 사본 (URL 처리, 404, 캐시). 서버 설정과 다르면 배포 때 경고                  |
| [`deploy/check-publish.mjs`](deploy/check-publish.mjs) | `deploy.sh`가 쓰는 검사. 비공개 노트나 `.canvas`·`.base`가 빌드 결과에 들어가면 배포를 막음                     |
| [`deploy/test-vault/`](deploy/test-vault)              | `deploy/deploy.sh --ci`가 빌드하는 테스트 vault (공개 노트와, 걸러져야 하는 비공개 노트)                        |

`deploy/deploy.sh` 맨 위의 경로를 서버에 맞게 고칩니다.

| 변수            | 뜻                                                                                 | 예                                      |
| --------------- | ---------------------------------------------------------------------------------- | --------------------------------------- |
| `VAULT_DIR`     | 서버에 있는 Obsidian vault                                                         | `/home/<계정>/obsidian-vault`           |
| `STAGING`       | 빌드 결과를 임시로 두는 폴더                                                       | `/data/quartz/.staging`                 |
| `LIVE`          | Caddy가 서빙하는 사이트 폴더. Caddy 컨테이너에서 `/srv/wiki`로 보이도록 마운트     | `/data/caddy/site/wiki`                 |
| `CADDY_SNIPPET` | 서버 Caddy가 불러오는 wiki 설정 파일. `deploy/Caddyfile`과 같은지 배포 때마다 비교 | `<Caddy 설정 폴더>/conf.d/quartz.caddy` |

`deploy/Caddyfile`은 사이트 블록 안에서 `import`하는 조각입니다. 서버의 메인 Caddyfile에 `(security)` 스니펫(404 응답에 보안 헤더를 다시 붙일 때 씀)과, 이 조각을 불러오는 사이트 블록이 있어야 합니다.

```caddy
(security) {
	header {
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
		-Server
	}
}

wiki.example.com {   # 와일드카드(*.example.com) 블록 하나에 여러 서비스를 import해도 됨
	import security
	import conf.d/*.caddy
}
```

처음 한 번:

1. 서버에 `git`, `rsync`, `flock`(util-linux), mise가 있는지 확인하고, 저장소를 clone한 뒤 `mise install`
2. [내 환경에 맞게 바꾸기](#내-환경에-맞게-바꾸기)를 반영해 커밋·push
3. `wiki.example.com` DNS를 서버 공인 IP로 연결 (HTTPS 인증서는 Caddy가 발급)
4. `deploy/Caddyfile`을 서버의 `CADDY_SNIPPET` 위치에 복사하고, Caddy 컨테이너에 `LIVE`의 상위 폴더를 `/srv`로 마운트 (예: `/data/caddy/site:/srv:ro`)
5. `deploy/deploy.sh --dry-run`으로 빌드·검사가 통과하는지 확인한 뒤 첫 배포: `deploy/deploy.sh`
6. Caddy 설정 반영: `docker exec caddy caddy reload --config /etc/caddy/Caddyfile` (컨테이너 이름이 `caddy`일 때)
7. [자동 배포](#자동-배포)의 crontab 등록

직접 배포할 때는 서버의 저장소 폴더에서 본인 계정으로 실행합니다(root로 실행하면 막음). 둘 다 먼저 `git pull --ff-only`로 최신 커밋을 받습니다.

```bash
deploy/deploy.sh            # 빌드·검사 후 사이트 교체
deploy/deploy.sh --dry-run  # 빌드·검사까지만 (사이트는 그대로)
```

배포 전 검사:

- 사이트에는 frontmatter에 `publish: true`가 있는 노트만 올라갑니다 (`explicit-publish` 플러그인 + `check-publish.mjs`).
- 빌드가 노트를 하나도 거르지 않으면 publish 필터가 고장 난 것으로 보고 배포를 막습니다. vault에 비공개 노트가 하나도 없으면 이 검사에 걸리므로, 공개하지 않을 노트가 최소 하나는 있어야 합니다.
- 플러그인을 불러오지 못했거나 `index.html`·`404.html`이 없어도 배포를 막습니다.

Caddy 설정을 바꿀 때는 `deploy/Caddyfile`과 서버의 `CADDY_SNIPPET`을 똑같이 고친 뒤 Caddy를 reload합니다.

CI는 따로 없습니다. 배포할 때마다 `deploy.sh`가 위의 배포 전 검사를 하고, 하나라도 걸리면 사이트를 바꾸지 않습니다. 미리 확인하려면 `npm run check`(타입·포맷), `npm test`를 실행하고, 서버에서는 `deploy/deploy.sh --ci`로 테스트 vault 설치·빌드·검사까지 돌려 볼 수 있습니다 (`flock`이 없는 Windows에서는 실행되지 않음). `.github/workflows/`의 upstream workflow들은 `jackyzha0/quartz`에서만 실행되므로 손대지 않습니다.

### 자동 배포

cron이 5분마다 [`deploy/cron.sh`](deploy/cron.sh)를 실행합니다. origin에 새 커밋이 있거나 서버에서 한 커밋이 아직 배포되지 않았으면 `deploy/deploy.sh`로 배포하고, 결과를 `deploy/logs/`에 남깁니다. 배포할 게 없으면 아무것도 남기지 않습니다.

- origin의 기본 브랜치(이 저장소는 `v5`)를 체크아웃하고 있을 때만 배포합니다.
- 커밋하지 않은 변경(새 파일 포함)이 있으면 그것까지 사이트에 올라가므로, 작업 트리가 깨끗해질 때까지 배포를 미룹니다.
- 배포에 실패한 커밋은 1시간마다 다시 시도합니다. 새 커밋 없이 원인을 고쳤다면(예: 네트워크 문제, 서버 커밋을 버리고 origin에 맞춤) `deploy/deploy.sh`를 직접 실행하면 바로 배포됩니다.
- origin을 force-push해 커밋을 되돌렸다면(예: 잘못 올린 글 지우기) 서버 저장소에 남은 옛 커밋 때문에 사이트가 그대로이므로, 서버에서 `git reset --hard origin/v5 && deploy/deploy.sh`로 맞춥니다.

vault 노트는 git으로 관리하지 않으므로, 노트만 바뀐 경우에는 자동으로 배포되지 않습니다. 이때는 `deploy/deploy.sh`를 직접 실행합니다.

crontab(`crontab -e`):

```
*/5 * * * * <저장소 경로>/deploy/cron.sh
```

cron에는 SSH 에이전트가 없어서, origin은 HTTPS로 받고 push만 SSH로 합니다 (public 저장소라 받을 때는 인증이 필요 없음).

```bash
git remote set-url origin https://github.com/<사용자>/quartz.git
git remote set-url --push origin git@github.com:<사용자>/quartz.git
```

#### 실행 결과 (`deploy/logs/`)

`deploy/logs/`는 `.gitignore`에 들어 있어서 커밋되지 않고, 작업 트리 검사에도 걸리지 않습니다.

| 파일              | 쓰는 곳                                   | 내용                                                                                                        |
| ----------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `<연-월>.log`     | `cron.sh`                                 | 월별 로그 (예: `2026-10.log`). 배포를 시도했거나 문제가 있었을 때만 줄이 생기고, 오래된 파일은 직접 지움    |
| `deployed-commit` | `deploy.sh` (사이트 교체에 성공했을 때만) | 사이트에 마지막으로 올린 커밋. 직접 실행한 배포도 기록하며, `--dry-run`·`--ci`는 기록하지 않음              |
| `failed-commit`   | `cron.sh`                                 | 마지막으로 배포에 실패한 커밋. 파일 수정 시각으로부터 1시간 동안은 다시 시도하지 않고, 배포에 성공하면 지움 |
| `skipped-commit`  | `cron.sh`                                 | 커밋하지 않은 변경 때문에 미뤘다고 로그에 쓴 커밋. 같은 커밋으로 5분마다 로그가 쌓이지 않게 함              |

배포를 시도하면 `=====` 줄 아래에 `deploy.sh`의 출력(pull, 잠금 파일이 바뀌었을 때의 `npm ci`·플러그인 설치, `quartz build`)이 그대로 이어집니다.

```
===== 2026-10-15T03:30:01+09:00 8a95eaf → 70bfbce
Updating 8a95eaf..70bfbce
Fast-forward
…(빌드 출력)…
✅ 2026-10-15T03:31:12+09:00 — 412 pages
```

| 로그 줄                                                     | 뜻                                                                                                             | 할 일                                                                   |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `===== <시각> <배포된 커밋> → <배포할 커밋>`                | 배포 시작. 처음 배포할 때는 `<배포된 커밋>`이 비어 있음                                                        | 없음                                                                    |
| `✅ <시각> — <N> pages`                                     | 사이트 교체 완료. `<N>`은 사이트의 HTML 파일 수                                                                | 없음                                                                    |
| `⚠ deploy/Caddyfile이 서버 Caddy 설정(…)과 다릅니다`        | 배포는 계속됨                                                                                                  | 두 파일을 같게 맞추고 Caddy reload                                      |
| `✗ 다른 배포가 실행 중입니다`                               | 직접 실행한 배포 등이 잠금을 잡고 있음. 실패로 치지 않음                                                       | 없음 (5분 뒤 다시 시도)                                                 |
| `<시각> ✗ 배포 실패 (exit <코드>)`                          | 위쪽 `deploy.sh` 출력의 `✗` 줄이 원인                                                                          | 원인을 고치고 `deploy/deploy.sh` 직접 실행, 아니면 1시간 뒤 자동 재시도 |
| `<시각> ✗ git fetch 실패: <오류>`                           | origin에 닿지 못함 (네트워크, remote 주소). 실패 커밋으로 기록하지 않으므로 고쳐질 때까지 5분마다 한 줄씩 남음 | 네트워크·`git remote -v` 확인                                           |
| `<시각> ⚠ 커밋하지 않은 변경이 있어 <커밋> 배포를 미룹니다` | 작업 트리에 변경이 있음. 같은 커밋에는 한 번만 남김                                                            | `git status`로 확인하고 커밋하거나 되돌림                               |

자주 쓰는 확인:

```bash
tail -f deploy/logs/$(date +%Y-%m).log                    # 이번 달 로그 보기
git rev-parse HEAD; cat deploy/logs/deployed-commit       # 서버 커밋과 배포된 커밋 비교
rm deploy/logs/failed-commit                              # 실패한 커밋을 1시간 기다리지 않고 다음 cron에서 다시 시도
```

## 커스터마이징 규칙

업스트림을 따라가기 위해 아래 파일만 수정합니다. 그 밖의 `quartz/` 코어 파일을 고치면 `upgrade` 때 충돌이 납니다.

| 파일                        | 용도                                                                       |
| --------------------------- | -------------------------------------------------------------------------- |
| `quartz.config.yaml`        | 사이트 설정, 플러그인, 폰트 지정 (`fonts` 플러그인)                        |
| `quartz/styles/custom.scss` | 커스텀 스타일, `@font-face` 선언                                           |
| `quartz/static/`            | 폰트 파일, `robots.txt` 등 정적 파일                                       |
| `quartz.ts`                 | 커스텀 조건 등록 (`is-index`), 루트 `robots.txt` 복사, Umami 추적 스크립트 |

노트 작성법은 [`guide/frontmatter-guide.md`](guide/frontmatter-guide.md)(frontmatter 키, OG 이미지)를 봅니다.

## 업그레이드 참고

- 서버에서 `npx quartz upgrade`, `npm i`, `npx quartz plugin install`은 `flock -o /tmp/quartz-deploy.lock npx quartz upgrade`처럼 배포 잠금을 잡고 실행합니다. 잠금 파일이 바뀐 커밋을 배포할 때 cron이 `node_modules`와 `.quartz/plugins`를 다시 설치하므로, 겹치면 양쪽 설치가 모두 깨집니다. upgrade의 merge 커밋은 push하기 전이라도 다음 cron 실행 때 배포됩니다.
- `npx quartz upgrade` 중 충돌이 나면 충돌을 해결하고 커밋한 뒤 `flock -o /tmp/quartz-deploy.lock sh -c 'npm i && npx quartz plugin install'`을 실행합니다. 충돌이 나면 upgrade가 이 두 단계 전에 멈추기 때문입니다.
- 업스트림이 esbuild 버전을 올리면 `npm install` 때 설치 스크립트 경고가 뜹니다. `npm install-scripts approve esbuild`로 새 버전을 허용합니다.
