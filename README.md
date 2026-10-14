# Techbara Wiki

Obsidian 노트를 [Quartz v5](https://quartz.jzhao.xyz/)로 정적 사이트로 만들어 <https://wiki.techbara.dev>에 게시하는 저장소입니다.
[jackyzha0/quartz](https://github.com/jackyzha0/quartz)의 fork이며, 업스트림을 그대로 따라가면서 설정과 스타일만 바꿔 씁니다.

## 셋업

필요 환경: Node.js 22 이상 (이 프로젝트는 [mise](https://mise.jdx.dev/)로 Node 24 사용), npm 10.9.2 이상

```bash
git clone git@github.com:junbeom-cho/quartz.git
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

| 파일              | 설명                              |
| ----------------- | --------------------------------- |
| `ubuntu-build.sh` | 서버에서 vault를 `public/`에 빌드 |
| `mac-build.sh`    | macOS 로컬 미리보기 (포트 8080)   |
| `win-build.bat`   | Windows 로컬 미리보기 (포트 8081) |
| `default.conf`    | nginx로 서빙할 때 쓰는 설정       |

## 배포

서버에서 vault를 빌드하고, 서버의 Caddy(Docker 컨테이너)가 결과물을 정적 파일로 서빙합니다. 배포에 쓰는 파일은 `deploy/`에 있습니다.

| 파일                                                   | 설명                                                                                                                                                         |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`deploy/deploy.sh`](deploy/deploy.sh)                 | 서버 배포. 최신 커밋을 받아 빌드하고, 검사를 통과하면 `/data/caddy/site/wiki`(Caddy 컨테이너의 `/srv/wiki`)를 교체                                           |
| [`deploy/Caddyfile`](deploy/Caddyfile)                 | 서버 Caddy의 wiki 설정(homelab `docker/caddy/conf/conf.d/03-quartz.caddy`) 사본 (URL 처리, 404, 네이버 소유확인 파일, 캐시). 서버 설정과 다르면 배포 때 경고 |
| [`deploy/check-publish.mjs`](deploy/check-publish.mjs) | `deploy.sh`가 쓰는 검사. 비공개 노트나 `.canvas`·`.base`가 빌드 결과에 들어가면 배포를 막음                                                                  |
| [`deploy/test-vault/`](deploy/test-vault)              | CI가 빌드하는 테스트 vault (공개 노트와, 걸러져야 하는 비공개 노트)                                                                                          |

처음 한 번:

1. 서버에 저장소를 clone하고 `mise install`
2. `wiki.techbara.dev` DNS를 서버 공인 IP로 연결 (HTTPS는 Caddy의 `*.techbara.dev` 와일드카드 인증서로 처리)
3. 첫 배포: `deploy/deploy.sh`
4. homelab의 Caddy 설정을 반영: `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`

배포할 때마다 서버의 저장소 폴더에서 실행합니다. 둘 다 먼저 `git pull --ff-only`로 최신 커밋을 받습니다.

```bash
deploy/deploy.sh            # 빌드·검사 후 사이트 교체
deploy/deploy.sh --dry-run  # 빌드·검사까지만 (사이트는 그대로)
```

Caddy 설정을 바꿀 때는 `deploy/Caddyfile`과 homelab의 `conf.d/03-quartz.caddy`를 똑같이 고친 뒤 `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`로 반영합니다.

CI([`.github/workflows/wiki-ci.yaml`](.github/workflows/wiki-ci.yaml))는 `v5` push와 PR마다 `deploy/deploy.sh --ci`(테스트 vault로 설치·빌드·검사), `npm run check`, `npm test`를 실행합니다. upstream의 workflow들은 `jackyzha0/quartz`에서만 실행되므로 손대지 않습니다.

## 커스터마이징 규칙

업스트림을 따라가기 위해 아래 파일만 수정합니다. 그 밖의 `quartz/` 코어 파일을 고치면 `upgrade` 때 충돌이 납니다.

| 파일                        | 용도                                                |
| --------------------------- | --------------------------------------------------- |
| `quartz.config.yaml`        | 사이트 설정, 플러그인, 폰트 지정 (`fonts` 플러그인) |
| `quartz/styles/custom.scss` | 커스텀 스타일, `@font-face` 선언                    |
| `quartz/static/`            | 폰트 파일, `robots.txt` 등 정적 파일                |
| `quartz.ts`                 | 커스텀 조건 등록 (`is-index`)                       |

## 업그레이드 참고

- `npx quartz upgrade` 중 충돌이 나면 충돌을 해결하고 커밋한 뒤 `npm i`와 `npx quartz plugin install`을 직접 실행합니다. 충돌이 나면 upgrade가 이 두 단계 전에 멈추기 때문입니다.
- 업스트림이 esbuild 버전을 올리면 `npm install` 때 설치 스크립트 경고가 뜹니다. `npm install-scripts approve esbuild`로 새 버전을 허용합니다.
