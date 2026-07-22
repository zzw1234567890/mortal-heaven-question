
# 为 Claude Code Game Studios 贡献

CCGS 是一个使用 Claude Code 进行独立游戏开发的协调框架。欢迎贡献——bug 修复、填补真实缺口的新技能、智能体改进以及钩子修复。不符合框架方向的 PR 会被关闭，恕不详述理由。

## 什么样的 PR 是好的

- **Bug 修复**——某些东西坏了，这是修复
- **新技能**，解决了尚未覆盖的工作流缺口
- 对现有智能体、技能或钩子的**改进**
- **文档更正**——错误信息、失效引用、过时步骤

作为 PR 提交的功能请求会被关闭。请改为开一个 issue。

**这个仓库不是什么：**
CCGS 是帮助你构建游戏的系统，而不是存放你用它构建的游戏的地方。GDD、ADR、PRD、游戏概念、关卡设计、叙事文档，或 CCGS 为你自己的项目生成的任何其他输出都不会在这里合并——请把它们保存在你自己的仓库中。

## 不可妥协的技术规则

这些是如果你遗漏就会导致 PR 被拒绝的事项。

**技能文件**
- 技能位于 `.claude/skills/<name>/SKILL.md`——子目录格式是必需的。扁平的 `.md` 文件会被 Claude Code 静默忽略。
- SKILL.md 必须包含 YAML frontmatter：`name`、`description`、`argument-hint`、`allowed-tools` 和 `model`
- 模型层级：`haiku` 用于只读状态检查，`opus` 用于多文档综合和阶段门禁，`sonnet` 用于其他一切

**钩子**
- 使用 `grep -E`——绝不使用 `grep -P`（Perl 正则在 Windows Git Bash 上会出问题）
- 为没有安装 `jq` 或 `python` 的系统提供回退
- 钩子在每次会话启动时运行——它们必须在不适用时快速优雅地退出（`exit 0`）

**智能体**
- 新智能体必须包含一个**协作协议**章节，描述智能体如何提问并将决定权交给用户
- 智能体不得在没有明确用户委派的情况下修改其文档化领域之外的文件

**参考文档**
- 如果你的 PR 添加或更改了技能、智能体或钩子，请更新对应的参考文档（agent-roster、skills-reference、hooks-reference 或 rules-reference）。添加内容但不更新索引的 PR 会被退回。

## 协作原则

CCGS 不是一个自治系统。每个工作流都遵循：
**提问 → 选项 → 决定 → 草稿 → 批准 → 写入**

技能和智能体必须在行动前询问。没有明确的用户确认，不得向文件写入任何内容。如果你的贡献中有智能体单方面做出决定或写入文件，它不会被合并。

## 测试你的更改

在 Claude Code 会话中运行它并确认它端到端工作。对于技能，调用该技能并验证输出与技能声称的一致。对于钩子，触发相关事件并确认钩子正确触发并干净退出。

在你的 PR 描述中包含一段简短说明，描述你测试了什么以及输出是什么样的。

## 提交格式

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat: add /retrospective skill for end-of-sprint reviews
fix: correct grep -P usage in session-start hook
docs: update skills-reference with new /qa-plan entry
```

类型：`feat`、`fix`、`docs`、`chore`、`refactor`、`test`

## PR 流程

- 你的 PR 会通过 CODEOWNERS 自动分配给维护者
- 评审会在有空时进行——这是一个单人维护的项目
- 如果你的 PR 挂了几周没有反馈，发一条催促评论是可以的
- 合并的贡献者会在发布说明中署名

## 平台兼容性

CCGS 必须在 Windows（Git Bash）、macOS 和 Linux 上工作。如果你的钩子或脚本使用了任何平台特定的内容，它会被拒绝。不确定时，在 Windows 上测试。
