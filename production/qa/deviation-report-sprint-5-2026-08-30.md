# Sprint 5 偏差报告：GDD ↔ 实现差异

> **日期**：2026-08-30
> **范围**：Sprint 5 实现的 4 个 Feature 层系统（exploration / cultivation / tribulation / deck-editing）
> **目的**：记录 GDD 设计文档与代码实现之间的有意偏差，更新设计文档以反映实际情况

---

## 一、偏差总览

| # | 系统 | 偏差描述 | 类型 | 处理方式 |
|:--:|------|----------|:----:|----------|
| 1 | exploration | 文件超 300 行（1005 行） | 技术债务 | 后续 Sprint 拆分 |
| 2 | tribulation | 文件超 300 行（519 行） | 技术债务 | 后续 Sprint 拆分 |
| 3 | deck-editing | 文件超 300 行（436 行） | 技术债务 | 后续 Sprint 拆分 |
| 4 | tribulation | 心魔 debuff 未实现 | 桩实现 | 后续 Sprint 接线 StatusEffectSystem |
| 5 | tribulation | 天劫试炼（简单）选项未实现 | 桩实现 | 后续 Sprint 接线 Boss 配置 |
| 6 | exploration | 节点可见性规则未实现 | 延迟至 UI 层 | Presentation 阶段实现 |
| 7 | deck-editing | get_sell_price 返回 100% 而非 80% | 有意偏差 | GDD §3 ③ 已移除出售，仅保留拆解 |
| 8 | tribulation | 金卡奖励未实现 | 桩实现 | 后续 Sprint 接线 CardSystem |
| 9 | tribulation | 角色复活途径未实现 | 延迟 | 事件系统/商店系统实现时接入 |
| 10 | deck-editing | 战利品编排为桩实现 | 桩实现 | 后续 Sprint 接线 CardSystem 掉落表 |

---

## 二、详细偏差说明

### 偏差 1-3：Feature 层文件超 300 行

**涉及文件**：
- `src/feature/exploration_system.gd`（1005 行）
- `src/feature/tribulation_system.gd`（519 行）
- `src/feature/deck_editing_system.gd`（436 行）

**原因**：Sprint 5 各系统在 4 个 Story 中逐步叠加功能（状态机 → 战斗委托 → 渡劫丹 → GSM 同步），导致单文件超出编码标准 300 行限制。

**计划**：后续 Sprint 按职责拆分。exploration_system 可拆为 `dag_generator.gd`（生成逻辑）+ `navigation.gd`（导航逻辑）+ `economy.gd`（经济计算）。tribulation_system 可拆为 `state_machine.gd` + `combat_delegate.gd` + `settlement.gd`。deck_editing_system 可拆为 `validator.gd` + `shop_ops.gd` + `loot_orchestrator.gd`。

### 偏差 4：心魔 debuff 未实现

**GDD 参考**：`tribulation-system.md` §5 + §公式 2

**GDD 规定**：渡劫失败后玩家获得「心魔」debuff——所有战斗中获得修为 -20%。不可驱散，下次渡劫成功时清除。

**实现现状**：`_handle_tribulation_failure()` 执行了修为扣除 + 失败计数 + 信号发射，但未施加心魔 debuff。原因：心魔需要 StatusEffectSystem 支持「修为获取修正」类型的 debuff，当前 StatusEffectSystem 尚未实现此功能。

**计划**：后续 Sprint 接线 StatusEffectSystem 后补充。需要在 CultivationSystem.gain_cultivation 中检查心魔 debuff 并应用 0.8 系数。

### 偏差 5：天劫试炼（简单）选项未实现

**GDD 参考**：`tribulation-system.md` §5 + §公式 3

**GDD 规定**：连续 3 次渡劫失败后，渡劫台出现「天劫试炼（简单）」选项——Boss HP-30%，金卡降为蓝卡。

**实现现状**：`_handle_tribulation_failure()` 在 `failures >= 3` 时发射 `tribulation_protection_unlocked` 信号，但未实现实际的「天劫试炼」选项逻辑（Boss HP 削减、奖励降级）。

**计划**：后续 Sprint 接线 RealmSystem 天劫 Boss 配置后实现。需要在 `trigger_tribulation` 中增加简单模式参数，在 `_build_tribulation_config` 中应用 HP 削减。

### 偏差 6：节点可见性规则未实现

**GDD 参考**：`exploration-system.md` §4 节点导航

**GDD 规定**：当前层及下方 2 层节点可见，更深层显示为迷雾节点。

**实现现状**：`ExplorationSystem` 实现了 `move_to_node` / `can_move_to` / `resolve_node` 等导航逻辑，但未实现可见性规则。原因：可见性是 UI 渲染层的职责——需要 UI 系统根据当前节点位置和 DAG 结构决定哪些节点显示为迷雾。

**计划**：Presentation 阶段在 UI 层实现。GDD 规则保留不变，作为 UI 实现的规格。

### 偏差 7：get_sell_price 返回 100% 而非 80%

**GDD 参考**：`deck-editing-system.md` §3 ③ + §公式 3

**GDD §3 ③**：「拆解产出 = 卡牌系统拆解产出公式计算的值 × 1.0（100%回收率）」「注意：拆解是卡牌→灵石的唯一途径（出售卡牌操作已移除）」

**GDD §公式 3**：`sell_price(card) = floor(base × 0.8)  # 坊市抽成20%`

**偏差说明**：GDD 内部存在不一致——§3 ③ 已移除「出售」操作，仅保留「拆解」（100%），但 §公式 3 仍保留旧的出售公式（80%）。实现遵循 §3 ③（更新规则），`get_sell_price` 返回 `dismantle_value`（100%），不应用 0.8 系数。

**处理方式**：更新 GDD §公式 3，标注其已被 §3 ③ 取代。实现为有意偏差——遵循更具体的 §3 ③ 规则。

### 偏差 8：金卡奖励未实现

**GDD 参考**：`tribulation-system.md` §4

**GDD 规定**：渡劫成功后必定获得 1 张金色稀有度卡牌（从新境界卡池选取）。越阶渡劫额外 +1 张。

**实现现状**：`_handle_tribulation_success()` 中有 `# TODO: CardSystem 未接线` 注释。原因：CardSystem 的卡牌生成/稀有度权重功能尚未接线。

**计划**：后续 Sprint 接线 CardSystem 后补充。

### 偏差 9：角色复活途径未实现

**GDD 参考**：`tribulation-system.md` §5.5

**GDD 规定**：两条复活途径——随机事件「仙人指路」（消耗 20% 修为）和商店道具「涅槃丹」（300 灵石）。

**实现现状**：未实现。原因：复活途径依赖事件系统和商店系统，这些系统尚未实现相关功能。

**计划**：事件系统和商店系统实现时接入。

### 偏差 10：战利品编排为桩实现

**GDD 参考**：`deck-editing-system.md` §2

**GDD 规定**：战斗战利品为混合三选一（2卡+1灵石 / 1卡+2灵石 / 1卡+1灵石+1消耗品），按战斗难度决定模式。

**实现现状**：`generate_loot_options` 返回固定 3 选项（2卡+1灵石），`apply_loot_choice` 根据 type 执行添加卡牌或增加灵石。原因：CardSystem 掉落规则未接线。

**计划**：后续 Sprint 接线 CardSystem 掉落表后替换桩实现。

---

## 三、GDD 更纪要

以下设计文档需要更新以反映实现现状：

| GDD | 更新内容 | 状态 |
|-----|----------|:----:|
| `exploration-system.md` | 状态改为「已实现（桩阶段）」；标注节点可见性规则延迟至 UI 层 | 待更新 |
| `cultivation-system.md` | 状态改为「已实现」 | 待更新 |
| `tribulation-system.md` | 状态改为「已实现（桩阶段）」；标注心魔/天劫试炼/金卡/复活为桩实现 | 待更新 |
| `deck-editing-system.md` | 状态改为「已实现（桩阶段）」；更新 §公式 3 标注被 §3 ③ 取代 | 待更新 |