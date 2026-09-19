---
name: main-menu-story001-ql-review
description: QL-STORY-READY 对 main-menu Story 001 的裁决（2026-09-12，GAPS 3 BLOCKING）——制作人员按钮 GDD/UX 矛盾、has_continuable_save 损坏数据源矛盾、存档摘要未入 scope
metadata:
  type: project
---

2026-09-12 对 `production/epics/main-menu/story-001-main-menu-scene.md`（Sprint 14 预备）执行 QL-STORY-READY 复审，裁决 **GAPS**（3 BLOCKING + 4 ADVISORY）。主会话初步判定 NEEDS WORK（2 项）被推翻加严。

**Why:** 复审发现主会话遗漏的规格矛盾：UX spec `design/ux/main-menu.md` L129 已将「制作人员」从 MVP 主菜单移除（4 按钮），GDD 与 story 仍是 5 按钮；且 SaveLoadSystem.list_slots() 的 meta.json 只有 `exists` 标志、无损坏字段，story 的 `has_continuable_save` "全损坏→false" 测试用例无数据源（同 [[hud-story002-ql-review]] 的 is_fallen 先例）。

**How to apply:** story 修复后需复审 3 个 BLOCKING 是否解决：
1. 制作人员按钮去留——GDD L40/L51/L124 vs UX L129/L118-127（UX 更新 2026-07-26 晚于 GDD 2026-07-22，倾向 UX 胜出=4 按钮，但需设计侧明确裁决并回写 GDD）
2. has_continuable_save 输入语义——裁决 (a) meta exists 即 true、删除"全损坏→false"用例，或 (b) SaveLoadSystem 新增校验接口
3. 存档摘要「上次：元婴期·第 2 章」（UX AC-EMPTY-01 + L97/L120/L145）入 scope，含无存档时摘要行隐藏规则

2026-09-07 的 4 项 epic 级阻塞裁决（[[main-menu-ql-review-2026-09]]）确认均不直接阻塞 Story 001（#1/#2 归 Story 002、#3 归 Story 003、#4 归 EPIC）。
