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

| 파일              | 설명                                                                              |
| ----------------- | --------------------------------------------------------------------------------- |
| `build.sh`        | 서버 배포용. vault를 staging에 빌드하고, 성공했을 때만 rsync로 사이트 폴더를 교체 |
| `ubuntu-build.sh` | 서버에서 vault를 `public/`에 빌드                                                 |
| `win-build.bat`   | Windows 로컬 미리보기 (포트 8081)                                                 |
| `default.conf`    | nginx로 서빙할 때 쓰는 설정                                                       |

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
