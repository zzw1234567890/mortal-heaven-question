---
name: project-exploration-ui-ql-review
description: exploration-ui epic 10-story 分解 QL-STORY-READY 审查（2026-09-08）——3 ADEQUATE / 7 GAPS，9 项 BLOCKING，整体 NO-GO
metadata:
  type: project
---

2026-09-08 对 exploration-ui epic 的 10-story 分解草案执行 QL-STORY-READY 对抗性审查。

**裁决**：NO-GO。001/009/010 ADEQUATE；002-008 GAPS。**9 项 BLOCKING**（story 写入前须裁决/修正）：

1. B1 回复点回复量跨 GDD 矛盾：exploration-ui-system 全文 30% vs exploration-system 公式7/类型表 50%——倾向 50%（机制 GDD 为真理源），修 UI GDD。
2. B2 AP 颜色恰界：详细规则「<30%」vs 公式/AC「≤30%」（0.3 恰界黄/红归属）；AP=0 同时命中「红色」与「变灰」两条规则，公式 2 无灰色分支——story 004 单测边界无法编写。
3. B3 Boss 弹窗警示数值张冠李戴：UX 写「80% 修为损失」实为渡劫撤退惩罚（combat-ui L323）；Boss 撤退=战败=保留 50% 修为。且战力展示双规格（角色数 vs 数值对比）。
4. B4 弹窗触发时序歧义：GDD L118「先弹确认框」vs AC/UX「移动后弹出」——AP 消耗时点未定，005/006 边界撞车。建议按 ADR-0014 信号流裁决为「先移动后弹窗」。
5. B5 弹窗枚举缺口：渡劫台弹窗（UX 有 AC、GDD §4 无规格）、传送节点弹窗（ADR interaction_type 有、无 AC）在 story 006 未枚举；事件节点排除规则未声明。
6. B6 map_cleared 信号名双语义：ADR-0014（ExplorationSystem 于 Boss 击败时发射、奖励已入账）vs UX Events（UI 于结算确认点击时发射、标注持久变更）→ 双重入账风险。story 008 必须绑定 ADR 信号、确认按钮不得重发 map_cleared。
7. B7 地图选择布局矛盾（GDD 网格 2~4 列 vs UX 横向滚动）+ 重入「费用明细（基础价×倍率）」API 缺口（calculate_reentry_cost 只返回 int，UI 自行拆算违反零状态所有权）。
8. B8 战败/撤退返回路径三说（回地图选择 vs UX「返回节点图或主菜单」vs DEFEAT_SCREEN 存在）+ 战斗/事件/商店返回节点图的恢复流无 story 认领。
9. B9 教程覆盖（UX AC 579）无 story 归属，文案待 writer。

**Why**: 先例标准（[[project-qa-conventions]]、[[project-combat-ui-interaction-ql-review]]）：GDD 矛盾须 story 创建前裁决；信号契约以 ADR 为权威源（UX 事件表是设计层表述，同名不同发射者即撞车）；确定性逻辑纯函数单测 BLOCKING。
**How to apply**: /create-stories exploration-ui 重跑时逐项核对 B1-B9；B1-B4 属 game-designer 勘误，B6-B8 属架构协调（lead-programmer 扩 get_map_list 载荷、story 008 绑 ADR-0014 信号）。story 001 无 BLOCKING 可先行，但后继链在 B4 裁决前不动工。
