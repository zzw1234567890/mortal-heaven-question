# Story 006: 探索 HUD 右下信息组（AP/地图名/层数）

> **Epic**: HUD 系统
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 0.5d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-10-20（QL-STORY-READY 复核修订：总层数数据源收窄为 DAG 缓存推导 + AC-2 补域信号用例 + 地图名回退定义；LP 跨域预协调 APPROVED WITH CONDITIONS 五条件并入层数条目）

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-001（探索场景维度）+ §5 探索中 HUD
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权；事件驱动更新（Cat 1 信号 `action_points_changed` / `batch_updated`）。AP 颜色阈值判定实现为共享纯函数（HUD 与 exploration-ui 双消费），helper 落地须先于 exploration-ui 的 AP story（QL-STORY-READY 裁决）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 本组件纯显示，无焦点交互。**GSM 信号语义**（QL-STORY-READY 2026-09-20 查证修正）：`action_points_changed(delta, current, max_val)` 实存但 **max_val 恒为 0**（gsm_signal_router.gd L81-83——AP 上限归 ExplorationSystem，ADR-0014，GSM 不跟踪）；且 `set_exploration_ap(current, max_ap)` 单帧双写（action_points + max_action_points）触发 **batch_updated 而非域信号**。实现须**双路径订阅**：域信号取 current；`batch_updated` 过滤 `exploration.action_points`/`exploration.max_action_points` 两条路径（hud story 002 G6 同型先例）；max 从 `GSM.exploration.max_action_points` 读取。

**Control Manifest Rules (this layer)**:
- Required: AP 阈值判定为共享纯函数（HUD 与 exploration-ui 共用），单测一次双消费
- Forbidden: UI 脚本内联阈值；UI 写入 GSM
- Guardrail: AP 变更刷新即时（信号驱动），无逐帧轮询

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md` §5，scoped to this story:*

- [ ] 探索场景右下显示：当前地图名（map_id→显示名经本 story 附建的最小常量表，QL-STORY-READY 2026-09-20 归属裁决——数据驱动放配置，第一张地图即起步，exploration-ui 扩展）、AP（当前/最大）、当前层/总层数（如 3/5——`node_position.layer` 0 基需 +1 换算）
- [ ] AP 变更时显示即时更新（双路径信号驱动，非轮询——见 Engine Notes）
- [ ] AP 颜色阈值判定使用共享纯函数（HUD 与 exploration-ui 同一实现；**阈值数值 provisional**——GDD 未定义，game-designer 签批后锁定）
- [ ] AP 分段格显示（每格 = 1 AP，已消耗格子熄灭）——与 exploration-ui UX 规范的 AP 强化显示共用判定逻辑
- [ ] 离开探索场景（进战斗/商店）该区域隐藏或按 Story 001 可见性规则处理

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`get_ap_color_threshold(current: int, max_val: int) -> Dictionary` 共享纯函数——返回 AP 颜色状态（正常/警告/紧急，阈值数据驱动）。该 helper 是 HUD 与 exploration-ui 的共享判定源——**落地须先于 exploration-ui 的 AP story**，本 story 是它的第一消费者与归属实现方。共享位置建议 `src/ui/shared/` 或等效公共模块（具体由实现时架构确认，须在两 epic 间可见）。

- 信号绑定：**双路径订阅**——`action_points_changed(delta, current, max_val)` 仅取 current（max_val 恒 0）；`batch_updated` 过滤 `exploration.action_points`/`exploration.max_action_points`（set_exploration_ap 单帧双写走此路径）。max 从 `GSM.exploration.max_action_points` 读取。
- 地图名：本 story 附建最小 `map_id → 显示名` 常量表（数据驱动配置，起始仅青云剑宗；exploration-ui epic 扩展为完整表）。**回退定义**（QL 复核 2026-10-20 GAP-3）：未知 map_id 显示占位文本「未知地域」+ `push_warning`——同 hud 通知系统未知类型安全默认裁决（2026-09-10）；炼气章推进链（血渊秘境/云澜城/丹霞谷）在 exploration-ui 扩表前走此回退路径。
- 层数：当前层 = `GSM.exploration.node_position.layer + 1`（0 基换算 1 基）；**总层数数据源收窄为单一路径**（QL 复核 2026-10-20 GAP-1 + LP 跨域预协调 2026-10-20 APPROVED WITH CONDITIONS）：ExplorationSystem 补 `get_total_layers()` 只读方法，从 **DAG 缓存推导**——节点 ID 编码 `layer * 100 + idx`（exploration_dag_builder.gd L46-50），总层数 = `max(_node_details.keys()) / 100 + 1`。~~原备选「map_states[map_id].layers 取数组长度」不可行~~（`update_exploration_map_state` 只写 entry_count/graph/nodes，layers 键从未写入）；~~`_map_config[map_id].layers` 亦不可行~~（`_map_config` 为扁平难度配置无 map_id 键，且读档路径 `rebuild_dag_cache` 清空后不回填——读档场景恒 0）。**LP 跨域五条件**：①空集防御（BLOCKING）——`_dag_ready` 之外显式判 `_node_details.is_empty()` → `push_warning` + 返回安全默认值 1（`_ready()` 有三条 `_dag_ready=true` 但缓存空的路径 L384/L402-404）；②完整 doc 注释（ADR-0014 R7 + ID 编码来源 + Story 006 引用）；③**HUD 禁止调用 `get_node_graph()`/`get_node_details()` 测试桩 API 取层数**（无守卫的测试桩区块）；④exploration 侧单测（BLOCKING）——空缓存返回 1 / generate_map 后返回配置层数 / rebuild 后返回快照层数，`tests/unit/exploration/` 现有文件追加；⑤守卫先例引用 `move_to_node`/`can_move_to`/`resolve_node`（ADR-0014 R7）——`get_node_graph` 是无守卫测试桩非先例。
- AP 分段格渲染（每格 1 AP、已消耗熄灭）为 UI 手动验证部分；分段判定（当前/最大/已消耗）可并入纯函数返回。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载与可见性
- exploration-ui epic: 探索场景中央节点图、AP 强化显示组件本体（消费本 story 的共享 helper）、AP 悬停详情浮窗
- 战斗中右下费用/牌库显示：归 combat-ui（HUD 战斗中不渲染）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: AP 颜色阈值判定（共享纯函数）
  - Given: AP current/max_val
  - When: 调用共享 `get_ap_color_threshold(current, max_val)`
  - Then: 按阈值返回颜色状态（阈值来自配置常量，如 ≤20% 紧急、≤50% 警告、>50% 正常——以配置为准）
  - Edge cases: 0/5、1/5、3/5、5/5、max_val=0（防除零）、current>max_val（临时 AP 超上限的防御性处理）

- **AC-2**: AP 数据绑定（双路径——QL 复核 2026-10-20 GAP-2 补域信号用例）
  - Given: HUD 已挂载且显示当前 AP
  - When: 调用 `GSM.set_exploration_ap(2, 5)`（单帧双写 → 走 batch_updated 路径）
  - Then: HUD AP 显示更新为 2/5（自动化断言显示文本——经 batch_updated 过滤 `exploration.action_points`/`exploration.max_action_points`）
  - When ②: 调用 `gsm.restore_action_points(2)`（单写 action_points → 帧末 flush 单条变更 → 走域信号 `action_points_changed` 路径——行动力恢复节点事件的真实路径，gsm_atomic_writes.gd L349）
  - Then ②: HUD AP 显示更新（域信号路径——对齐 story 002 LingshiDeckBar 双路径对偶先例；max_val 恒 0 不消费）
  - Edge cases: 连续变更（最后一次生效）、进战斗隐藏期间变更（恢复可见后显示最新值）

**[UI — manual verification steps]:**

- **AC-3**: 探索右下信息组完整性
  - Setup: 进入探索场景（如青云剑宗 层3/5）
  - Verify: 显示地图名「青云剑宗」、AP「3/5」、层数「层3/5」
  - Pass condition: 三项信息与游戏状态一致，布局不遮挡中央内容区

- **AC-4**: AP 分段格显示
  - Setup: AP 从 5 消耗到 3
  - Verify: 5 格分段中 3 格点亮、2 格熄灭
  - Pass condition: 已消耗格子熄灭明显可辨，颜色阈值状态正确

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/hud/test_ap_color_threshold.gd`（共享 helper）— must exist and pass（BLOCKING）
- Integration: AP 数据绑定断言并入 `tests/integration/hud/test_gsm_signal_binding.gd`（与 Story 003 共用文件，追加用例——含 batch 与域信号双路径，见 QA AC-2）— must exist and pass（BLOCKING）
- Exploration 侧: `get_total_layers()` 单测追加 `tests/unit/exploration/` 现有文件（LP 条件④——空缓存/生成后/重建后三例）— must exist and pass（BLOCKING）
- UI: `production/qa/evidence/exploration-hud-info-evidence.md` + sign-off（信息组/分段格手动验证）

**Status**: [x] Created — `production/qa/evidence/exploration-hud-info-evidence.md`（AC-3/AC-4 手动走查 9 项全通过 + 三角色签收）

---

## Dependencies

- Depends on: Story 001（挂载点）
- Unlocks: exploration-ui epic 的 AP 显示 story（消费共享 helper）

---

## Completion Notes
**Completed**：2026-10-20
**Criteria**：5/5 通过（AC-1 阈值纯函数 13 单测 / AC-2 双路径 15 集成 / AC-3 信息组完整性 5 项手动 / AC-4 分段格 4 项手动 / AC-5 可见性规则由 Story 001 矩阵覆盖）
**Deviations**：H-2 墨字可见性修复——原 LabelSettings 墨黑 #1A1A1A 在深色探索背景上不可见，根节点补 PanelBackground 米白 #F5F0E3 @85%（对齐美术圣经 §4.1，normal 态文字保持墨黑）。H-1 容器锚点（preset 3 无偏移 → preset 2 + 显式负偏移）、M-1 幂等守卫先行（push_warning 前先判 last_map_key）均已在 LP 复审前闭合。
**Test Evidence**：Logic `tests/unit/hud/test_ap_color_threshold.gd`（13）+ Integration `tests/integration/hud/test_gsm_signal_binding.gd`（15）+ Exploration `tests/unit/exploration/test_get_total_layers.gd`（6）+ UI `production/qa/evidence/exploration-hud-info-evidence.md`（签收）；全量 2899 passing / 1 pending 存量
**Code Review**：已完成（LP-CODE-REVIEW APPROVED——H-1 修复后定向复审通过；QL-TEST-COVERAGE ADEQUATE）

