// 빌드 결과에 publish: true가 아닌 노트가 들어갔으면 실패한다.
// Quartz는 explicit-publish 플러그인을 불러오지 못해도 경고만 찍고 모든 노트를 빌드하므로, 배포 전에 막는다.
// 사용법: node deploy/check-publish.mjs <vault 경로> <빌드 결과 경로>
import fs from "node:fs"
import path from "node:path"
import { globby } from "globby"
import YAML from "yaml"

const [vaultDir, outputDir] = process.argv.slice(2)
if (!vaultDir || !outputDir) {
  console.error("사용법: node deploy/check-publish.mjs <vault 경로> <빌드 결과 경로>")
  process.exit(2)
}

function fail(message, files = []) {
  console.error(`✗ ${message}`)
  for (const file of files) console.error(`  - ${file}`)
  process.exit(1)
}

// explicit-publish 플러그인과 같은 기준: frontmatter의 publish가 true 또는 "true"
function isPublished(text) {
  const frontmatter = text.replace(/^﻿/, "").match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)
  if (!frontmatter) return false
  try {
    const publish = YAML.parse(frontmatter[1])?.publish
    return publish === true || publish === "true"
  } catch {
    return false
  }
}

function readVaultFile(relativePath) {
  try {
    return fs.readFileSync(path.join(vaultDir, relativePath), "utf8")
  } catch {
    return ""
  }
}

// 1. 빌드 결과의 모든 페이지가 publish: true 노트에서 나왔는지
const indexPath = path.join(outputDir, "static", "contentIndex.json")
if (!fs.existsSync(indexPath)) {
  fail(`${indexPath}가 없어 공개 노트를 확인할 수 없습니다 (content-index 플러그인 확인)`)
}
const pages = Object.values(JSON.parse(fs.readFileSync(indexPath, "utf8")))
if (pages.length === 0) {
  fail("공개 페이지가 하나도 없습니다 (vault 경로 확인)")
}
const leaked = pages
  .map((page) => page.filePath)
  .filter((filePath) => filePath && !isPublished(readVaultFile(filePath)))
if (leaked.length > 0) {
  fail(
    `publish: true가 아닌 노트 ${leaked.length}개가 빌드 결과에 들어 있어 배포를 중단합니다:`,
    leaked,
  )
}

// Quartz와 같은 방식으로 vault를 읽는다 (quartz/util/glob.ts: 점 파일 제외, ignorePatterns, .gitignore)
const config = YAML.parse(fs.readFileSync("quartz.config.yaml", "utf8"))
const ignorePatterns = config.configuration?.ignorePatterns ?? []
const vaultGlob = (pattern, ignore = []) =>
  globby(pattern, { cwd: vaultDir, ignore: [...ignorePatterns, ...ignore], gitignore: true })

// 2. canvas/base 페이지는 frontmatter가 없어 publish 설정과 상관없이 모두 공개된다
const unfiltered = await vaultGlob(["**/*.canvas", "**/*.base"])
if (unfiltered.length > 0) {
  fail(
    "canvas/base 파일은 publish 설정과 상관없이 공개됩니다. private/ 폴더로 옮기거나 quartz.config.yaml의 ignorePatterns에 추가하세요:",
    unfiltered,
  )
}

// 3. Quartz는 md가 아닌 파일을 publish 여부와 상관없이 모두 복사한다. 공개 노트가 참조하지 않는 첨부는 경고만 한다
const publishedTexts = (await vaultGlob("**/*.md"))
  .map(readVaultFile)
  .filter((text) => isPublished(text))
const attachments = await vaultGlob("**/*", ["**/*.md"])
const unreferenced = attachments.filter((file) => {
  const name = path.posix.basename(file)
  const variants = [name, encodeURI(name), name.replaceAll(" ", "%20")]
  return !publishedTexts.some((text) => variants.some((variant) => text.includes(variant)))
})
if (unreferenced.length > 0) {
  console.warn(
    `⚠ 공개 노트가 참조하지 않는 첨부 ${unreferenced.length}개도 배포됩니다 (비공개 노트의 첨부라면 private/ 폴더로 옮기세요):`,
  )
  for (const file of unreferenced) console.warn(`  - ${file}`)
}

console.log(`✓ 공개 페이지 ${pages.length}개 모두 publish: true`)
