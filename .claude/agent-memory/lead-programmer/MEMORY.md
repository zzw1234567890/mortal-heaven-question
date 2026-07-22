
# 主程 —— 智能体记忆

## 技能编写约定

### Frontmatter
- 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- 在隔离环境中运行的只读分析技能还会携带 `context: fork` 和 `agent:`
- 交互式技能（写文件、提问）不使用 `context: fork`
- `AskUserQuestion` 是技能正文中描述的使用模式——它不会出现在 `allowed-tools` frontmatter 中（没有现有技能这样做）

### 文件布局
- 技能位于 `.claude/skills/<name>/SKILL.md`（每个技能一个子目录，不使用扁平 .md 文件）
- 章节标题使用 `##` 表示阶段，`###` 表示子章节
- 阶段名称遵循"Phase N: Verb Noun"模式（例如"Phase 1: Find the Story"）
- 输出格式模板放在围栏代码块中

### 已知规范路径（在新技能中引用前请验证）
- 技术债务登记册：`docs/tech-debt-register.md`（不是 `production/tech-debt.md`）
- 冲刺文件：`production/sprints/`
- Epic 故事文件：`production/epics/[epic-slug]/story-[NNN]-[slug].md`
- 控制清单：`docs/architecture/control-manifest.md`
- 会话状态：`production/session-state/active.md`
- 系统索引：`design/gdd/systems-index.md`
- 引擎参考：`docs/engine-reference/[engine]/VERSION.md`

### 已完成技能
- `story-done`——故事结束完成确认（Phase 1-8，写入故事文件）
