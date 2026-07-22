---
name: changelog
description: "从 git 提交、冲刺数据和设计文档自动生成变更日志。生成内部版本和面向玩家版本。"
argument-hint: "[version|sprint-number]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write
context: |
  !git log --oneline -30 2>/dev/null
  !git tag --list --sort=-v:refname 2>/dev/null | head -5
---


## 第一阶段：解析参数

读取目标版本或冲刺编号的参数。如果提供了版本号，则使用对应的 git 标签（tag）。如果提供了冲刺编号，则使用该冲刺的日期范围。

验证仓库是否已初始化：运行 `git rev-parse --is-inside-work-tree` 以确认 git 可用。如果不是 git 仓库，通知用户并优雅地中止。

---

## 第二阶段：收集变更数据

读取自上一个标签或发布以来的 git 日志：

```
git log --oneline [last-tag]..HEAD
```

如果不存在标签，则读取完整日志或合理的最新范围（最近 100 次提交）。

从 `production/sprints/` 读取相关时期的冲刺报告，以了解计划的工作和变更背后的上下文。

读取 `design/gdd/` 中已完成的、在此期间实现的新功能的设计文档。

---

## 第三阶段：分类变更

将每个变更归入以下类别之一：

- **新功能（New Features）**：全新的游戏玩法系统、模式或内容
- **改进（Improvements）**：对现有功能的增强、用户体验改进、性能提升
- **Bug 修复（Bug Fixes）**：对异常行为的修正
- **平衡调整（Balance Changes）**：游戏数值、难度、经济系统的调优
- **已知问题（Known Issues）**：团队已知但尚未解决的问题
- **其他（Miscellaneous）**：不属于上述类别的变更，或提交信息过于模糊无法确定分类

对于每次提交，检查信息中是否包含任务 ID 或故事引用（如 `[STORY-123]`、`TR-`、`#NNN` 等）。统计缺少任务引用的提交数量，并在第四阶段的指标部分以 `Commits without task reference: [N]` 形式呈现。

---

## 第四阶段：生成内部变更日志

```markdown
# Internal Changelog: [Version]
Date: [Date]
Sprint(s): [Sprint numbers covered]
Commits: [Count] ([first-hash]..[last-hash])

## New Features
- [Feature Name] -- [Technical description, affected systems]
  - Commits: [hash1], [hash2]
  - Owner: [who implemented it]
  - Design doc: [link if applicable]

## Improvements
- [Improvement] -- [What changed technically and why]
  - Commits: [hashes]
  - Owner: [who]

## Bug Fixes
- [BUG-ID] [Description of bug and root cause]
  - Fix: [What was changed]
  - Commits: [hashes]
  - Owner: [who]

## Balance Changes
- [What was tuned] -- [Old value -> New value] -- [Design intent]
  - Owner: [who]

## Technical Debt / Refactoring
- [What was cleaned up and why]
  - Commits: [hashes]

## Miscellaneous
- [Change that didn't fit other categories, or vague commit message]
  - Commits: [hashes]

## Known Issues
- [Issue description] -- [Severity] -- [ETA for fix if known]

## Metrics
- Total commits: [N]
- Files changed: [N]
- Lines added: [N]
- Lines removed: [N]
- Commits without task reference: [N]
```

---

## 第五阶段：生成面向玩家的变更日志

```markdown
# What is New in [Version]

## New Features
- **[Feature Name]**: [Player-friendly description of what they can now do
  and why it is exciting. Focus on the experience, not the implementation.]

## Improvements
- **[What improved]**: [How this makes the game better for the player.
  Be specific but avoid jargon.]

## Bug Fixes
- Fixed an issue where [describe what the player experienced, not what was
  wrong in the code]
- Fixed [player-visible symptom]

## Balance Changes
- [What changed in player-understandable terms and the design intent.
  Example: "Healing potions now restore 50 HP (up from 30) -- we felt
  players needed more recovery options in late-game encounters."]

## Known Issues
- We are aware of [issue description in player terms] and are working on a
  fix. [Workaround if one exists.]

---
Thank you for playing! Your feedback helps us make the game better.
Report issues at [link].
```

---

## 第六阶段：输出

向用户输出两个变更日志。内部变更日志是主要工作文档。面向玩家的变更日志经审核后即可用于社区发布。

---

## 第七阶段：提供文件写入

展示变更日志后，询问用户：

> "May I write this changelog to `docs/CHANGELOG.md`?
> [A] Yes, append this entry (recommended if the file already exists)
> [B] Yes, overwrite the file entirely
> [C] No — I'll copy it manually"

- 在询问之前检查 `docs/CHANGELOG.md` 是否存在。如果存在，默认推荐的选项为 **[A] 追加（append）**。
- 如果用户选择 [A]：将新的内部变更日志条目追加到现有文件的顶部（最新条目在前）。
- 如果用户选择 [B]：用新的变更日志覆盖整个文件。
- 如果用户选择 [C]：在此停止，不写入文件。

写入成功后：结论：**CHANGELOG WRITTEN** — 变更日志已保存至 `docs/CHANGELOG.md`。
如果用户拒绝：结论：**COMPLETE** — 变更日志已生成。

---

## 第七阶段：后续步骤

- 使用 `/patch-notes [version]` 生成格式化并保存的版本，用于公开发布。
- 在公开发布变更日志之前，使用 `/release-checklist` 进行检查。

### 指南

- 永远不要在面向玩家的变更日志中暴露内部代码引用、文件路径或开发者姓名
- 将相关变更分组展示，而不是逐条列出单个提交
- 如果提交信息不明确，查看关联文件和冲刺数据以获取上下文
- 平衡调整应始终包含设计理由，而不仅仅是数值
- 已知问题应诚实披露——玩家欣赏透明度
- 如果 git 历史杂乱（包含合并提交、回退、修正提交），应整理叙述而非逐字罗列每次提交
