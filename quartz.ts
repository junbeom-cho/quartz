import fs from "node:fs/promises"
import { loadQuartzConfig, loadQuartzLayout } from "./quartz/plugins/loader/config-loader"
import { registerCondition } from "./quartz/plugins/loader/conditions"
import { FilePath, joinSegments } from "./quartz/util/path"

registerCondition("is-index", (props) => props.fileData.slug === "index")

const config = await loadQuartzConfig()

// quartz/static/은 /static/ 아래로 복사되므로, robots.txt는 사이트 루트에 따로 복사
config.plugins.emitters.push({
  name: "RootRobotsTxt",
  async emit({ argv }) {
    const dest = joinSegments(argv.output, "robots.txt") as FilePath
    await fs.copyFile("quartz/static/robots.txt", dest)
    return [dest]
  },
})

// Umami: 설정 파일의 analytics로는 data-domains·data-exclude-hash를 못 넣어, 로컬 미리보기와 #앵커 클릭까지 페이지뷰로 센다
// Umami가 느리거나 닿지 않아도 페이지 load가 기다리지 않게 load 뒤에 넣는다
config.plugins.emitters.push({
  name: "UmamiAnalytics",
  async emit() {
    return []
  },
  externalResources: () => ({
    js: [
      {
        loadTime: "afterDOMReady",
        contentType: "inline",
        spaPreserve: true,
        script: `(() => {
          const loadUmami = () => {
            const umamiScript = document.createElement("script")
            umamiScript.src = "https://umami.techbara.dev/script.js"
            Object.assign(umamiScript.dataset, {
              websiteId: "d81838c0-0c8f-4d30-ad7a-dbcceb2552a0",
              domains: "wiki.techbara.dev",
              excludeHash: "true",
            })
            document.head.append(umamiScript)
          }
          if (document.readyState === "complete") loadUmami()
          else addEventListener("load", loadUmami, { once: true })
        })()`,
      },
    ],
  }),
})

export default config
export const layout = await loadQuartzLayout()
