---
# ── 이 frontmatter 자체가 예시입니다. 각 키의 설명은 본문을 보세요. ──
title: Frontmatter 가이드
description: 이 사이트(Quartz v5)에서 쓸 수 있는 frontmatter 키와 페이지별 OG 이미지 설정법
socialDescription: Quartz frontmatter 키 정리와 OG 이미지 설정법
tags:
  - quartz
  - 가이드
aliases:
  - frontmatter 정리
publish: true
modified: 2026-10-12
lang: ko
enableToc: true
cssclasses:
  - frontmatter-guide
# 아래는 필요할 때 주석을 풀어서 쓰세요.
# socialImage: og/frontmatter-guide.png   # quartz/static/og/ 아래 파일. 키를 쓰면 자동 생성 안 함 (파일이 없으면 이미지 깨짐)
# unlisted: true                          # 목록·검색·그래프에서 숨김
# password: "1234"                        # 본문 암호화 (반드시 따옴표)
# stealth: true                           # 암호 페이지를 잠금 해제 후에도 숨김
# permalink: fm-guide                     # 이 경로에 리다이렉트 추가
# quartz-properties: false                # 속성 패널 숨김
# quartz-properties-collapse: true        # 속성 패널을 접힌 채 시작
# related: "[[다른 노트]]"                 # 아무 키에나 링크를 넣으면 백링크·그래프 연결 (따옴표 필수)
---

이 노트는 **실제로 동작하는 frontmatter 예시**이자 레퍼런스입니다. 맨 위 frontmatter를 그대로 복사해서 쓰면 됩니다.

> [!info] 기준
> Quartz v5 + 현재 `quartz.config.yaml` 설정 + 2026-10-12 기준 설치된 플러그인 소스 코드. Quartz 공식 문서와 실제 코드가 다른 부분은 코드 기준으로 적었습니다.

## 빠른 템플릿

```yaml
---
title: 글 제목
description: 한두 문장 요약 (검색 결과·SNS 미리보기에 쓰임)
tags: [태그1, 태그2]
publish: true
---
```

이 네 개만 있어도 충분합니다. 나머지는 필요할 때만 추가하세요.

## OG 이미지 (SNS 미리보기)

### 기본 동작: 자동 생성

`og-image` 플러그인이 켜져 있어서 **모든 페이지에 OG 이미지가 자동으로 만들어집니다** (`<slug>-og-image.webp`, 1200×630). 이미지에는 다음이 들어갑니다.

- 제목 (`title`)
- 설명 (`socialDescription` → `description` → 본문 자동 요약 순)
- 수정일, 읽는 시간
- 태그 앞 3개
- `quartz/static/icon.png`

### 페이지별로 직접 지정: `socialImage`

`socialImage`를 넣으면 자동 생성을 건너뛰고 그 이미지를 씁니다. `image`나 `cover`로 써도 똑같이 동작합니다.

경로 규칙: `http://`나 `https://`로 시작하면 그대로 쓰고, **그 외에는 무조건 앞에 `https://wiki.techbara.dev/static/`을 붙입니다.**

| 이미지 위치                            | 쓰는 법                                                          |
| -------------------------------------- | ---------------------------------------------------------------- |
| quartz 저장소 `quartz/static/og/a.png` | `socialImage: og/a.png`                                          |
| vault 첨부 `assets/Docker Cover.png`   | `socialImage: https://wiki.techbara.dev/assets/docker-cover.png` |
| 외부 이미지                            | `socialImage: https://example.com/a.png`                         |

vault 첨부 파일은 `/static/` 아래가 아니라 **경로를 slug로 바꾼 위치**에 배포됩니다. 공백은 `-`가 되고, **확장자를 뺀 부분만** 소문자가 됩니다 (`IMG 1.PNG` → `img-1.PNG`). 정확한 주소는 배포된 사이트에서 이미지 주소를 복사하는 게 가장 확실합니다.

> [!warning] 이렇게 쓰면 이미지가 조용히 깨집니다
>
> - `image: "[[cover.png]]"` 같은 위키링크 → `/static/[[cover.png]]`가 됨 (공식 문서 예시가 이 형태지만 코드에서 동작하지 않음)
> - vault 기준 상대 경로 `assets/a.png` → `/static/assets/a.png`를 찾아 404
> - 앞에 `/` 붙이기 `/og/a.png` → `/static//og/a.png`
> - `socialImage:`를 **빈 값**으로 두기 → 자동 생성은 건너뛰는데 메타 태그는 만들어지지 않은 파일을 가리킴
> - `socialImage: ""` → 자동 생성은 건너뛰고 이미지 주소가 빈 값이 됨
> - 안 쓸 거면 `socialImage` 키를 지우세요. (`image:`, `cover:`를 비워 두는 건 괜찮습니다.)
> - 파일명의 공백·한글 → URL 인코딩이 안 되므로 영문과 하이픈으로 된 이름 권장

> [!tip]
>
> - 직접 지정한 이미지에는 크기 메타 태그(`og:image:width/height`)가 붙지 않습니다. **1200×630**으로 맞춰 두면 SNS에서 잘리지 않습니다.
> - `socialDescription`을 쓰면 `description` 대신 이 값이 SNS 미리보기 설명, 자동 생성 이미지 속 설명, **검색엔진용 meta description**에 쓰입니다. RSS에는 계속 `description`이 쓰입니다.
> - 플러그인 옵션 `excludeRoot`(루트 페이지 이미지 생성 끄기)는 문서에는 있지만 코드에서 읽지 않아 동작하지 않습니다.

## 공개·노출

| 키         | 기능                                                                                              | 값 주의                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `publish`  | `true`여야 노트가 사이트에 올라감. **없으면 비공개**                                              | `true` 또는 `"true"`만. `published`(날짜)와 헷갈리지 말 것                     |
| `unlisted` | 페이지는 만들되 검색·탐색기·그래프·RSS·sitemap·백링크·최근 노트·폴더/태그 목록·Bases에서 숨김     | YAML boolean만 (`"true"`는 무시됨). URL을 알면 열리고, 검색엔진 차단도 아님    |
| `password` | 빌드할 때 본문을 AES로 암호화해서 배포. 방문자가 비밀번호를 입력하면 브라우저에서 복호화해 보여줌 | **문자열만.** `password: 1234`는 숫자라서 암호화되지 않음 → `password: "1234"` |
| `stealth`  | 암호 페이지 전용. 잠금 해제 후에도 탐색기·그래프·검색에 나타나지 않음                             | `true`만. 암호 없는 페이지에서는 아무 효과 없음                                |

> [!warning] `publish`는 `.md` 노트에만 적용됩니다
> 이미지·PDF 같은 첨부 파일과 `.canvas`·`.base` 파일은 `publish`와 상관없이 vault에 있으면 배포 대상이 됩니다. 배포 스크립트(`deploy/check-publish.mjs`)가 `.canvas`·`.base`는 막고, 공개 노트가 참조하지 않는 첨부는 경고만 합니다. 비공개 노트의 첨부는 `quartz.config.yaml`의 `ignorePatterns`에 들어 있는 폴더(예: `01. Project`)에 두세요.

## 제목·설명·분류

| 키                  | 기능                                                                                           | 값 주의                                                                                               |
| ------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `title`             | 페이지 제목 (브라우저 탭, 본문 상단, 탐색기, 그래프, 브레드크럼, OG 이미지)                    | 없거나 비어 있으면 파일명                                                                             |
| `description`       | meta description·OG 설명 (`socialDescription`이 있으면 그쪽이 우선), RSS                       | 없으면 본문 앞부분을 자동 요약. **문자열만**: `description: 2024`처럼 숫자면 빌드 전체 실패           |
| `tags` / `tag`      | 태그 페이지, 그래프, 검색, 속성 패널, OG 이미지                                                | 리스트 또는 `"a, b"`. 자동으로 소문자, 공백 → `-`. `/`로 계층 (`dev/docker`)                          |
| `aliases` / `alias` | 다른 이름으로 `[[링크]]` 연결 + 그 이름의 URL(사이트 루트 기준)에 리다이렉트 페이지 생성       | 문자열 하나에 콤마가 있으면 둘로 쪼개짐. `[[별칭]]`으로 건 링크는 원본 노트의 백링크·그래프에 안 잡힘 |
| `permalink`         | **URL을 바꾸지 않음.** 그 경로에 리다이렉트만 추가 (공식 문서의 "Custom URL slug" 설명과 다름) | slug 변환이 안 되므로 `my-post`처럼 소문자·하이픈으로                                                 |

폴더의 `index.md`나 `tags/<태그>.md`처럼 목록 페이지를 꾸미는 노트는, 본문이 비어 있을 때 `description`이 그 페이지 상단 설명으로 나옵니다. 목록의 각 글 옆에는 설명이 나오지 않습니다.

## 날짜

현재 설정은 **수정일(modified)** 을 화면에 표시하고, 날짜를 `frontmatter → git → 파일 시스템` 순으로 찾습니다. 다만 이 사이트의 vault는 git 저장소가 아니라서(Syncthing 동기화) git 단계는 건너뜁니다. 그래서 **frontmatter에 날짜가 없으면 파일 수정 시각**을 씁니다.

| 키                                                   | 기능                                                                                |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `modified` / `lastmod` / `updated` / `last-modified` | **화면에 보이는 날짜.** 본문 상단, 최근 노트 정렬, RSS, OG 이미지, 폴더 정렬에 쓰임 |
| `created` / `date`                                   | 생성일. 수정일 키가 없으면 **이 값이 수정일로 복사되어 파일 수정 시각이 무시됨**    |
| `published` / `publishDate` / `date`                 | 발행일. 현재 설정에서는 화면에 나오지 않음                                          |

> [!note] 날짜 형식
>
> - `2026-10-12` 형식을 쓰세요.
> - `2026년 10월 12일`, `25/10/2026`(일/월/년)은 해석에 실패해서 경고 후 **빌드한 시각**으로 대체됩니다 (최근 노트 맨 위로 올라감).
> - `05/01/2026`은 미국식으로 읽혀 5월 1일이 됩니다.
> - 따옴표 없는 숫자 `20261012`는 1970년이 됩니다.
> - 날짜를 파일 수정 시각에 맡기고 싶으면 날짜 키(`modified`류, `created`, `date`)를 아예 쓰지 마세요.

## 화면 표시

| 키                           | 기능                                    | 값 주의                                                                                                                       |
| ---------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `enableToc`                  | `false`면 목차 숨김 (기본은 표시)       | **진짜 boolean만.** `"false"`, `no`, `off`는 문자열이라 목차가 그대로 보임. 제목(H1~H3) 2개 이상이어야 나옴                   |
| `cssclasses` / `cssclass`    | 본문 `<article>` 요소에 CSS 클래스 추가 | 공식 문서는 body라고 하지만 실제로는 article                                                                                  |
| `lang`                       | `<html lang>` 값만 바꿈 (예: `ko`)      | UI 문구는 그대로. SPA로 페이지를 이동하면 처음 연 페이지의 값이 유지됨                                                        |
| `quartz-properties`          | 속성 패널 표시(`true`)/숨김(`false`)    | 패널은 태그가 있는 페이지·데스크톱에서만 나오므로, 사실상 `false`로 숨기는 용도                                               |
| `quartz-properties-collapse` | 속성 패널을 접힌 채(`true`) 시작할지    | 첫 방문 기본값일 뿐. 방문자가 아무 페이지에서든 패널을 한 번 접거나 펴면 그 상태가 브라우저에 저장되어 모든 페이지에서 우선함 |

속성 패널에는 현재 설정상 `description`, `tags`, `aliases`만 표시됩니다.

## 그 밖의 키

- **아무 키에나 링크 넣기**: 값에 `[[노트]]`나 `[텍스트](url)`가 있으면 백링크와 그래프 연결로 잡힙니다. 예: `related: "[[Docker]]"`. **따옴표가 꼭 필요합니다.** `related: [[Docker]]`는 YAML 중첩 리스트로 읽혀 링크로 인식되지 않습니다.
- **Bases**: 노트 안의 `base` 코드 블록에서 frontmatter 키를 `note.키이름`으로 조회·필터할 수 있습니다. 단 필터·수식에서 한글이나 `-`가 들어간 키는 `note["상태"]`처럼 대괄호로 써야 합니다 (`note.상태`는 조용히 0건, `note.last-modified`는 빼기로 해석됨). 태그는 소문자·하이픈으로 바뀐 값으로 비교됩니다.
- 위에 없는 키는 Quartz가 무시합니다 (Obsidian 메모용으로 자유롭게 써도 됨).

## 지금은 효과 없는 키

해당 플러그인이 `quartz.config.yaml`에서 꺼져 있습니다.

| 키                              | 플러그인     | 참고                                          |
| ------------------------------- | ------------ | --------------------------------------------- |
| `draft`                         | remove-draft | `draft: true` + `publish: true`면 **공개됨**  |
| `comments`                      | comments     | 켜더라도 `comments: false`로 끄는 기능만 있음 |
| `bibliography`, `csl`, `noCite` | citations    |                                               |

## YAML 값 규칙

이 프로젝트는 frontmatter를 엄격한 규칙(js-yaml JSON_SCHEMA)으로 읽습니다.

- **boolean**은 `true` / `false` (`True`, `TRUE`도 됨)만 인정합니다. `yes`, `no`, `on`, `off`는 **문자열**입니다.
- **날짜**는 문자열로 읽힌 뒤 따로 해석됩니다.
- **별칭 우선순위**: 앞 키가 `""`(빈 문자열)이면 뒤 키는 무시됩니다. 예: `lastmod: ""` + `updated: 2026-10-12`이면 `updated`가 무시됩니다. (빈 값 `lastmod:`은 괜찮습니다.)
- 노트 **하나**의 YAML 오류만으로도 **전체 빌드와 배포가 멈춥니다.**

## 암호 페이지 주의

`password`는 **본문 HTML만** 암호화합니다. 다음은 누구나 볼 수 있습니다.

- 제목
- `description` (meta 태그와 OG 이미지에 그대로 들어감)
- 태그, 별칭 (속성 패널, 태그 페이지)
- 목차의 제목들 → `enableToc: false`를 같이 쓰세요
- 본문에 넣은 이미지·PDF 같은 첨부 파일 → 암호화되지 않고 원래 경로에 그대로 배포됨
- frontmatter 값 전체, **`password` 포함** → Bases 표에 열로 나올 수 있음 (열 순서를 안 정하면 첫 노트의 모든 키가 열이 됨)

또 암호 페이지는 본문이 비어 있는 것으로 처리되어 **검색·탐색기·그래프·RSS에 나오지 않습니다** (`includeEmptyFiles: false` 설정 때문). 백링크·최근 노트·폴더/태그 목록·Bases에는 나옵니다. 여기서 `unlisted: true`를 붙이면 그 목록들에서 빠지는 대신, 방문자가 잠금을 풀면 그때부터 탐색기·그래프·검색에 나타납니다. 끝까지 숨기려면 `stealth: true`를 쓰세요.

```yaml
---
title: 비공개 메모
publish: true
password: "my-secret"
enableToc: false
stealth: true
---
```
