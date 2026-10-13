---
title: 네이버 서치어드바이저 소유확인
description: 네이버 소유확인 HTML 파일이 배포되는 방식과, 확인 파일이나 사이트 주소가 바뀌었을 때 고칠 곳
tags:
  - cloudflare
  - 가이드
modified: 2026-10-14
---

네이버 서치어드바이저의 **HTML 파일 업로드** 방식 소유확인을 이 사이트에서 어떻게 처리하는지, 그리고 확인 파일이나 사이트 주소가 바뀌었을 때 무엇을 고치면 되는지 정리했습니다.

> [!info] 기준
> 2026-10-14 설정 기준. 지금 쓰는 확인 파일명은 `cloudflare/_redirects`의 규칙 줄에서 볼 수 있습니다.

## 동작 방식

네이버는 `https://wiki.techbara.dev/naver<코드>.html`을 요청해서 **리다이렉트 없이 200**으로 **받은 파일 내용이 그대로** 와야 소유확인을 해 줍니다. 이 사이트에서는 아래 세 곳이 함께 이 응답을 만듭니다.

| 위치                            | 역할                                                                                      |
| ------------------------------- | ----------------------------------------------------------------------------------------- |
| vault 최상단 `naver<코드>.html` | 네이버에서 받은 원본 파일. Quartz가 빌드할 때 `.html`을 떼고 `public/naver<코드>`로 복사  |
| `cloudflare/_redirects`         | `/naver<코드>.html` 요청에 `/naver<코드>` 파일을 **같은 주소에서 200으로** 응답 (rewrite) |
| `cloudflare/_headers`           | 그 주소의 Content-Type을 `text/plain`으로 지정                                            |

`_redirects`와 `_headers`는 `cloudflare/deploy.sh`가 빌드 후 `public/`에 복사해서 함께 배포됩니다. 사이트의 다른 주소에는 영향이 없습니다.

> [!warning] 이렇게 바꾸면 소유확인이 깨집니다
>
> - **`.html` 파일을 그대로 배포하기**: Cloudflare `html_handling`(auto-trailing-slash)이 `/naver<코드>.html`을 `/naver<코드>`로 **307 리다이렉트**합니다. 네이버는 리다이렉트를 따라간다고 보장하지 않습니다.
> - **Content-Type을 `text/html`로 바꾸기**: Cloudflare가 HTML 응답 끝에 봇 감지 스크립트(`/cdn-cgi/challenge-platform/...`)를 덧붙여 **파일 내용이 달라집니다.**
> - **vault 파일을 옮기거나 지우기**: 규칙이 가리키는 파일이 없어져 404가 됩니다.

## 확인 파일이 바뀌었을 때

다른 네이버 계정으로 등록하거나 사이트를 다시 등록해서 **확인 파일명(`naver` 뒤의 코드)이 바뀌면** 이 순서로 고칩니다.

1. **새 파일 받기**: 서치어드바이저에서 소유확인 방식으로 `HTML 파일 업로드`를 고르고 확인 파일을 내려받습니다. 소유확인 버튼을 누를 **같은 네이버 계정**으로 받아야 합니다 (계정마다 파일이 다름).
2. **vault에 넣기**: 받은 파일을 **그대로** vault 최상단에 넣고, 예전 `naver….html`은 지웁니다.
   - 에디터로 열어 저장하지 마세요. 끝에 줄바꿈이 붙는 것처럼 내용이 조금만 바뀌어도 실패합니다.
   - 하위 폴더나 `private/`, `ignorePatterns` 폴더(`98-templates`, `01. Project`)에 두면 사이트 루트에 배포되지 않습니다.
3. **규칙 두 파일 고치기**: 예전 코드를 새 코드로 바꿉니다. `_redirects`는 규칙 줄에 2군데, `_headers`는 경로 줄에 1군데입니다.

   ```text
   # cloudflare/_redirects
   /naver<새 코드>.html /naver<새 코드> 200

   # cloudflare/_headers
   /naver<새 코드>.html
     Content-Type: text/plain; charset=utf-8
   ```

   quartz 폴더에서 한 번에 바꾸려면 아래처럼 합니다. `NEW`에는 **`.html`을 뺀** 새 파일명을 넣습니다. macOS에서는 `sed -i` 대신 `sed -i ''`를 쓰세요.

   ```bash
   OLD=$(grep -v '^#' cloudflare/_redirects | grep -oE 'naver[0-9a-z]+' | head -1)
   NEW=naver<새 코드>
   sed -i "s/$OLD/$NEW/g" cloudflare/_redirects cloudflare/_headers
   grep -n "$NEW" cloudflare/_redirects cloudflare/_headers   # 2줄이 나오면 정상
   ```

4. **커밋·배포**: 고친 두 파일을 커밋해서 push한 뒤, 서버에서 `bash build.sh`로 배포합니다.
5. **배포 확인**: 아래 결과가 맞는지 본 다음 서치어드바이저에서 소유확인을 누릅니다.

   ```bash
   curl -sI https://wiki.techbara.dev/naver<새 코드>.html
   # HTTP/2 200, content-type: text/plain; charset=utf-8, location 헤더 없음

   curl -s https://wiki.techbara.dev/naver<새 코드>.html | cmp - <vault 경로>/naver<새 코드>.html && echo 일치
   ```

## 사이트 주소가 바뀌었을 때

규칙은 경로(`/naver<코드>.html`)만 보기 때문에 **도메인이 바뀌어도 규칙은 고칠 필요가 없습니다.** 서치어드바이저에 새 주소를 `https://`로 등록한 뒤 다음처럼 합니다.

- 기존과 같은 확인 파일을 주면: 새 주소에도 이미 배포되어 있으니 그대로 소유확인을 누릅니다.
- 새 확인 파일을 주면: 위의 "확인 파일이 바뀌었을 때" 순서대로 합니다.

사이트 주소 자체를 옮기는 설정(`quartz.config.yaml`의 `baseUrl`, `wrangler.jsonc`의 `routes`, `quartz/static/robots.txt`의 Sitemap 주소)은 이 문서에서 다루지 않습니다.

## 유지 관리

- 소유확인은 **1년마다 연장**해야 합니다. 만료가 다가오면 서치어드바이저 사이트 목록에 `소유확인 연장하기` 버튼이 생기는데, **처음 소유확인한 파일이 사이트에 그대로 있어야** 연장됩니다. 파일이 없으면 만료 후 처음부터 다시 소유확인해야 합니다.
- 서치어드바이저 도구 설정에서 소유확인 만료 알림을 켜 두면 만료 30일 전에 메일이 옵니다.
- 배포할 때 `check-publish`의 "공개 노트가 참조하지 않는 첨부" 경고에 확인 파일이 나오는 건 정상입니다. 경고 문구대로 `private/`로 옮기면 소유확인이 깨집니다.

## 소유확인이 안 될 때

먼저 `curl -sI https://wiki.techbara.dev/naver<코드>.html`로 응답을 봅니다.

| 응답                                           | 원인                                                   | 확인할 것                                                                                                                                              |
| ---------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `404`                                          | 규칙이 가리키는 파일이나 규칙 자체가 배포되지 않음     | vault 최상단의 파일명, `_redirects`의 코드 오타, `deploy.sh`의 `_redirects` 복사 줄                                                                    |
| `307` (`location: /naver<코드>`)               | `public/`에 `.html` 파일이 있고 `_redirects`가 안 맞음 | `_redirects`의 코드                                                                                                                                    |
| `200`인데 `content-type`이 `text/plain`이 아님 | `_headers` 경로가 안 맞음                              | `_headers`의 코드                                                                                                                                      |
| `200`, `text/plain`인데 소유확인 실패          | 응답 밖의 문제                                         | 파일을 받은 계정과 소유확인한 계정이 같은지, 등록 주소가 `https://`인지, `cmp`로 내용이 같은지, Cloudflare 보안 설정이 네이버 로봇(Yeti)을 막지 않는지 |
