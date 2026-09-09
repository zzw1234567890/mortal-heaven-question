# Story 001: HUD CanvasLayer 挂载与场景可见性切换

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 1.5d（原 1.0d + 0.5d——GAP-2 裁决扩 scope：含 SceneManager PersistentLayer/register_persistent 补齐）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-08（/dev-story 开始实现）

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-001 / AC-hud-004（可见性维度）+ 边界澄清（2026-09-05/09-07）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: HUD 为场景内 CanvasLayer 结构、零新增 Autoload、零状态所有权（UI 只读）、事件驱动更新（仅 Cat 1/Cat 2b 信号）。战斗场景 HUD 整体不渲染；暂停菜单为 HUD 拥有的全局 overlay 分支（§1.1——2026-09-08 修订），挂 SceneManager PersistentLayer（§1.2）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（双焦点风险已由 R-01 spike 关闭——本 story 纯可见性切换不涉及焦点交互；剩余风险为 CanvasLayer 在 SceneManager 转场管线中的挂载时序）
**Engine Notes**: S13-1 R-01 spike（2026-09-08，10/10 PASS）确认双焦点行为。本 story 须验证 CanvasLayer 经 register_persistent 挂载后在 change_scene_to_file() 转场中的存活行为。

**Control Manifest Rules (this layer)**:
- Required: UI 场景以 Control/CanvasLayer 节点挂载于场景内（非 Autoload）
- Forbidden: 新增 Autoload；UI 写入 GSM 或各系统状态
- Guardrail: 场景切换期间不得产生额外 Draw Call 峰值（转场本身 <200 DC）

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story（含 2026-09-08 QL-STORY-READY 裁决）:*

- [ ] SceneManager 启动时创建 PersistentLayer（root 直挂 Node）并暴露 `register_persistent(node: Node)` API（ADR-0031 §1.2 契约——GAP-2 裁决纳入本 story）
- [ ] HUD 以 CanvasLayer 场景经 `register_persistent()` 挂载，在探索/商店/事件场景中渲染（AC-hud-001 / AC-hud-004 可见性前提；地图选择为探索内部状态、随 EXPLORATION 显示）
- [ ] 进入战斗/渡劫场景时 HUD 内容分支整体不渲染（含所有内容子元素；PauseOverlay 分支豁免——GAP-1 裁决：HUD 拥有暂停菜单，ADR-0031 §1.1 已修订）
- [ ] 战斗中暂停菜单仍可由 HUD PauseOverlay 分支渲染（PROCESS_MODE_ALWAYS 独立分支——本 story 仅搭骨架：挂载点节点存在且 process_mode 正确，菜单本体归 Story 005）
- [ ] 场景切换由 SceneManager 信号驱动（`pre_transition` / `post_transition`），非轮询
- [ ] HUD 不持有任何游戏状态副本——显示时从 GSM/源系统直接读取

### SceneID → HUD 可见性矩阵（GAP-3 裁决——按 GDD 收紧，2026-09-08）

| SceneID | HUD 内容分支 | 依据 |
|---------|:---:|------|
| EXPLORATION（含地图选择内部状态） | 显示 | GDD §状态与转换 |
| SHOP | 显示 | GDD §状态与转换 |
| EVENT_PANEL | 显示 | GDD §状态与转换 |
| DECK_EDITING | 显示 | GDD 边界澄清（2026-09-05） |
| CULTIVATION | 显示 | GDD 边界澄清（2026-09-05） |
| COMBAT | 隐藏 | GDD 边界澄清（2026-09-05）——combat-ui 接管 |
| TRIBULATION | 隐藏 | 战斗型场景（GAP-3 裁决——渡劫为战斗变体） |
| RESULT_SCREEN | 隐藏 | 结算画面独立全屏（GAP-3 裁决） |
| DEFEAT_SCREEN | 隐藏 | 战败画面独立全屏（GAP-3 裁决） |
| MAIN_MENU | 隐藏 | 主菜单自含导航（GAP-3 裁决；转场失败回退 MAIN_MENU 后 HUD 隐藏——`_cleanup_on_error` 路径） |
| IDENTITY_SELECT | 隐藏 | 开局流程独立（GAP-3 裁决） |
| LOADING | 保持前一状态 | 内部中间态（GAP-3 裁决——确定性规则：LOADING 不可见性目标态，按 `to` 目标在 post_transition 落定） |

> PauseOverlay 分支不受本矩阵控制（豁免——由暂停逻辑独立管理，Story 005）。

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines（含 2026-09-08 裁决）:*

- **PersistentLayer 补齐**（GAP-2 裁决）：SceneManager `_ready()` 创建 `PersistentLayer`（root 直挂 Node，`process_mode` 默认），实现 `register_persistent(node: Node) -> void`（add_child 到 PersistentLayer）。HUD 在首次游戏场景启动时经此 API 挂载。此 API 同时是 audio 001（S13-14）的前置——audio story 测试将依赖它。
- HUD 场景结构：`HUD.tscn` 根节点 CanvasLayer，两个一级分支：`ContentLayer`（Control——按区域分容器：左上/右上/右下/顶部通知，由后续 story 填充）与 `PauseOverlay`（Control，`process_mode = PROCESS_MODE_ALWAYS`——Story 005 填充）。可见性切换只作用于 `ContentLayer.visible`，PauseOverlay 不受战斗隐藏影响（GAP-1 裁决）。
- 可见性切换：订阅 SceneManager `post_transition(from, to)`，按上方 SceneID→可见性矩阵设置 `ContentLayer.visible`。`pre_transition` 期间保持当前状态（LOADING 行为——确定性规则）。
- 信号到达时从源系统读取，不在 UI 内缓存游戏状态（瞬态交互状态除外，须命名 `_cache`/`_last` 前缀并注释）。
- 不新增任何 Autoload——HUD 场景经 `register_persistent()` 挂 PersistentLayer。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 境界+修为条组件内容
- Story 003: 灵石+卡组计数组件内容
- Story 005: 暂停菜单本体（本 story 仅预留 PauseOverlay 挂载点骨架）
- Story 007: 过渡提示（订阅同一 pre_transition 信号但为独立组件）
- 敌方境界标记（⬆）：归 combat-ui，HUD 不实现（边界澄清 2026-09-07）
- AudioManager 节点池挂载（PersistentLayer API 本 story 提供，池挂载归 audio 001）

---

## QA Test Cases

*Written by qa-lead at story creation（2026-09-08 按 GAP 裁决修订——测试规格与裁决对齐）. The developer implements against these — do not invent new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 探索场景 HUD 渲染（信号驱动挂载验证——场景 .tscn 多数未创建，不按字面加载探索场景）
  - Given: HUD 已经 `register_persistent()` 挂载，SceneManager 存在于测试场景树
  - When: 手动 emit `post_transition(SceneID.MAIN_MENU, SceneID.EXPLORATION)`（参照 `tests/integration/scene_manager/test_loading_screen.gd` 先例——mock 依赖 + 手动信号）
  - Then: HUD CanvasLayer 存在于 PersistentLayer 下且 `ContentLayer.visible == true`
  - Edge cases: SHOP/EVENT_PANEL/DECK_EDITING/CULTIVATION 同样可见；EXPLORATION 转场中途（pre 已发 post 未发）ContentLayer 保持前一状态

- **AC-2**: 战斗场景 HUD 内容分支不渲染
  - Given: HUD 已挂载且处于 EXPLORATION 可见状态
  - When: 手动 emit `post_transition(SceneID.EXPLORATION, SceneID.COMBAT)`
  - Then: `ContentLayer.visible == false`；PauseOverlay 不受影响（`visible` 独立控制，骨架下为 false 但不受矩阵约束）
  - Edge cases: TRIBULATION/RESULT_SCREEN/DEFEAT_SCREEN/MAIN_MENU/IDENTITY_SELECT 同样隐藏（矩阵全 12 值逐一断言）；战斗→探索返回后恢复可见；`_cleanup_on_error` 回退 MAIN_MENU 后隐藏

- **AC-3**: PauseOverlay 挂载点骨架（GAP-1 裁决——本 story 可测形态）
  - Given: HUD.tscn 实例化
  - When: 检查节点树结构
  - Then: `PauseOverlay` 节点存在、为 CanvasLayer 直接子节点、`process_mode == PROCESS_MODE_ALWAYS`；菜单本体与交互归 Story 005

- **AC-4**: 可见性切换由信号驱动
  - Given: HUD 已挂载
  - When: emit `post_transition` 各参数组合，观测 `ContentLayer.visible` 变化
  - Then: 每次变化均由信号回调触发——行为断言为主（emit → visible 变化）；辅以源码检查：HUD 脚本 `_process`（若存在）中无 SceneID 轮询（检查范围：`src/ui/hud/hud.gd` 单文件，模式：`get_current_scene\(|current_scene ==`）

- **AC-5**: PersistentLayer API（GAP-2 裁决）
  - Given: SceneManager 实例化
  - When: `_ready()` 后检查 root 子节点
  - Then: `PersistentLayer` 节点存在；`register_persistent(node)` 调用后 node 的父节点为 PersistentLayer；重复注册同名节点记录警告（防呆）
  - Edge cases: 场景转场（change_scene_to_file）后 PersistentLayer 及其子节点仍存在

- **AC-6**: HUD 零状态副本
  - Given: HUD 脚本源码（`src/ui/hud/hud.gd`——检查范围限本 story 实现文件）
  - When: grep 检查成员变量
  - Then: 无对 GSM 域的赋值语句（模式：`GameStateManager\.\w+\s*=` 与 `GSM\.\w+\s*=`——声明 `var x = GSM.y` 的读取式初始化除外，仅查赋值）；`_cache`/`_last` 前缀成员均有瞬态交互状态注释

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/hud/test_hud_scene_visibility.gd` — must exist and pass

**Status**: [x] Created 2026-09-08——20 个测试函数全部通过（GUT 全量套件中 20/20）

> 注：文件名从 QA 规格中的 `hud_scene_visibility_test.gd` 调整为 `test_hud_scene_visibility.gd`——
> GUT 以 `test_` 前缀发现测试脚本（.gutconfig.json prefix），原命名不被发现（实现期发现，非规格变更）。

**Code review 修复（2026-09-09，CHANGES REQUIRED → 复审）**——测试从 20 个扩至 27 个，全部通过（全量 2481/2482，1 为预先存在的 realm flake）：
- BLOCKING：补 `test_persistent_layer_survives_real_change_scene_to_file`（关闭 `_test_mode`，真实 `change_scene_to_file` + await，验证 ADR-0031 §1.2 等价性依赖的引擎行为）
- HIGH：补 `test_hud_initial_visibility_matches_boot_scene`（setup 后 MAIN_MENU 不可见）、`test_hud_visibility_matrix_keys_match_registered_scene_ids`（矩阵键集守卫）、`test_hud_unknown_scene_id_keeps_previous_state_and_warns`（未注册 ID 警告）
- GAP：PauseOverlay 豁免断言强化（先手动置 visible=true 再 emit COMBAT——可证伪形态）、`test_register_persistent_node_with_other_parent_pushes_error`、`test_register_persistent_same_name_different_node_warns_and_adds`、`test_hud_setup_called_twice_does_not_duplicate_connection`、`test_register_persistent_null_pushes_error` 改 push_error 计数断言
- Mock 迁移：GSM/IM/SL mock 提取至 `tests/integration/scene_manager/mocks/`（preload 静态编译共享 fixture，消除与 test_loading_screen.gd 的双份拷贝漂移）

**实现修复（对应项）**：
- HUD.tscn CanvasLayer 显式 `layer = 90`（绘制顺序预算——PauseOverlay 置顶保证）
- hud.gd `setup()` 末尾按 `get_current_scene_id()` 一次性同步初始可见性；`is_connected` 防重复连接；未注册 SceneID `push_warning`
- hud.gd/scene_persistent_layer.gd 补 `class_name`（Hud/ScenePersistentLayer——类型链收紧，scene_manager.gd 持久层引用随之强类型）
- ADR-0031 §1.2 修订（挂载位置 Autoload 子节点+layer 补偿）；scene_persistent_layer.gd 头注释错误论证（root 时序理由）修正

---

## Dependencies

- Depends on: None（SceneManager/GSM Foundation 层已 Complete；PersistentLayer/register_persistent 由本 story 补齐——GAP-2 裁决）
- Unlocks: Story 002、003、005、006（挂载点与可见性骨架）、audio 001（register_persistent API）
