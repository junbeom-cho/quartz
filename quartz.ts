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

export default config
export const layout = await loadQuartzLayout()
