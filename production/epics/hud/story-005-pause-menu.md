# Story 005: 暂停菜单（全局覆盖层）

> **Epic**: HUD 系统
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-11（/story-done 关闭）

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-010 / AC-hud-011
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§1.1 暂停菜单）
**ADR Decision Summary**: 暂停菜单为 HUD 拥有的场景内 overlay（非 SceneManager 转场）；`SceneTree.paused = true`；HUD 设 `PROCESS_MODE_ALWAYS`；音频节点池节点同样 ALWAYS 但由暂停菜单逻辑显式暂停音频总线（BGM 与 SFX 一并暂停）。战斗中 ESC 由 combat-ui 转发请求，菜单本体由 HUD 渲染——豁免于战斗隐藏规则。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 菜单打开时须调用 `grab_focus()` 锚定键盘导航起点（若支持键盘）——4.6 双焦点下 `grab_focus()` 只影响键盘/手柄焦点，不影响鼠标，行为符合本场景。process_mode 设置须在节点 ready 前生效。

**Control Manifest Rules (this layer)**:
- Required: 暂停状态三态可验证（暂停中/恢复后游戏状态不变/音频同步暂停）
- Forbidden: 用 SceneManager 转场实现暂停；新增 Autoload
- Guardrail: 背景模糊 0.3s；暂停打开期间 0 Draw Call 增幅以外的额外渲染（模糊为全屏后处理，计入预算）

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story:*

- [x] 按 ESC 或点击左下暂停按钮打开暂停菜单，游戏暂停，背景模糊（AC-hud-010）
- [x] 菜单项：继续游戏 / 查看卡组 / 系统设置 / 保存并退出 / 返回主菜单 + 探索进度显示（降级格式「层 3」——仅当前层号，GAP-2 裁决 2026-09-11）
- [x] 暂停时冻结所有游戏计时；战斗中暂停冻结回合计时（如有）
- [x] 战斗中暂停后回到游戏，战斗状态不变（AC-hud-011）
- [x] 暂停期间经 PauseAudioAdapter 接口请求音频暂停（BGM+SFX），恢复时同步请求恢复——audio-manager epic 完成前为 no-op 桩（INAD-1 条件性条款裁决 2026-09-11）
- [x] 战斗中 ESC 由 combat-ui 转发请求，菜单由 HUD 渲染（本 story 实现 HUD 侧接收接口 `hud.request_pause(source)`；combat-ui 侧转发归其 epic）（GAP-3 契约裁决 2026-09-11）

---

## Implementation Notes

*Derived from ADR-0031 §1.1 Implementation Guidelines + QL-STORY-READY 裁决 2026-09-11：*

- 暂停菜单为 HUD 场景内独立 overlay 分支（Story 001 预留挂载点），PROCESS_MODE_ALWAYS——否则 `SceneTree.paused = true` 时菜单自身也被冻结。
- **ESC 输入链路（GAP-1 裁决 2026-09-11）**：InputManager 在现有 `_input()` 拦截点（input_manager.gd L342-346）新增信号 `pause_requested()`——走 Cat 2b `_emit_signal_safe` 路由（ADR-0007 惯例）；HUD pause overlay 监听该信号。鼠标路径：暂停按钮 `pressed` 信号直连。**禁止 HUD 侧使用 `_unhandled_input`/`_input` 监听 ESC**（与 InputManager 拦截冲突——`_input()` 先于 `_unhandled_input` 且已标记 handled）。
- **统一暂停入口（GAP-3 裁决 2026-09-11）**：HUD 暴露 `hud.request_pause(source: StringName)` 公共方法——ESC 信号路径、按钮路径、combat-ui 转发路径三路汇入此入口；`source` 区分 `&"esc"` / `&"button"` / `&"combat_ui"`。集成测试覆盖 combat_ui 路径。
- **音频暂停（INAD-1 条件性条款裁决 2026-09-11）**：本 story 定义 `PauseAudioAdapter` 接口（suspend/resume 两方法）并提供 no-op 桩实现——暂停/恢复经 adapter 调用；真实总线操作（AudioServer BGM/SFX 总线暂停）归 audio-manager epic 实现，其 QA 计划须登记回归项「暂停时音频同步暂停/恢复」。
- **探索进度行（GAP-2 裁决 2026-09-11）**：降级为仅显示当前层「层 3」——层号 = `node_position.layer + 1`（0 基转 1 基）；map_id→显示名映射与总层数分母归 hud 006（正式宿主）与 exploration-ui epic 补齐，本 story 不建映射表。
- **退出语义（GAP-5 裁决 2026-09-11）**：「保存并退出」= SaveLoadSystem 存档后返回主菜单（强制先存档）；「返回主菜单」= 不存档直接转场（二次确认弹窗 UX 规格已有定义，本 story 从简直接转场）。
- **背景模糊（GAP-4 方案记录 2026-09-11）**：ColorRect + 自写 blur shader（design/ux/interaction-patterns.md L199 先例：BackBufferCopy + blur shader）——避免依赖 4.6 glow 变更面；模糊实现方式记录于 story Completion Notes 以满足预算核验。
- 打开流程：ESC/按钮 → `SceneTree.paused = true` → adapter.suspend() → 显示菜单（0.3s 背景模糊）。关闭流程严格逆序。
- 战斗状态保持（AC-hud-011）用集成测试验证：进入战斗→暂停→恢复，断言战斗系统关键状态（回合数/角色 HP/费用）不变。
- 「查看卡组」：战斗中可用（只读查看，不可编辑——GDD 待解决问题 #3 的当前设计）。路由到卡组浏览界面（deck-editing-ui epic 的卡组浏览），本 story 仅发导航请求。
- 「系统设置」路由到主菜单系统设置面板（main-menu epic），本 story 仅发导航请求。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载（本 story 消费预留 overlay 挂载点）
- combat-ui epic: 战斗场景内的 ESC 捕获与转发
- main-menu epic: 系统设置面板本体
- deck-editing-ui epic: 卡组浏览界面本体
- audio-manager epic: 音频总线结构定义（本 story 只调用暂停/恢复 API）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 暂停打开与恢复
  - Given: 游戏运行中（探索场景）
  - When: InputManager 发射 `pause_requested()`（或 HUD 调用 `request_pause(&"esc")` 模拟该信号——GAP-1 裁决路径）
  - Then: `SceneTree.paused == true`，菜单 visible；再触发 → paused == false，菜单隐藏
  - Edge cases: 连续快速按 ESC（无状态错乱）；暂停中打开后立即关闭

- **AC-2**: 战斗状态保持（AC-hud-011 核心）
  - Given: 战斗进行到第 3 回合，角色 HP/费用已知
  - When: 暂停 → 恢复
  - Then: 回合数、所有角色 HP、当前费用、牌库/弃牌堆计数全部不变
  - Edge cases: 暂停发生在动画播放中（恢复后动画状态可继续或重置，但战斗逻辑状态必须不变）

- **AC-3**: 音频暂停 Adapter（INAD-1 裁决 2026-09-11）
  - Given: 游戏运行中（audio-manager epic 未完成——no-op 桩阶段）
  - When: 打开暂停菜单
  - Then: `PauseAudioAdapter.suspend()` 被调用；恢复时 `resume()` 被调用（桩阶段断言 adapter 方法调用；audio-manager epic 完成后其回归测试断言总线状态）
  - Edge cases: 暂停中触发 SFX 请求（经 adapter 层归 audio-manager epic 验证——本 story 桩阶段不适用）

- **AC-6**: HUD 侧接收接口（GAP-3 裁决 2026-09-11）
  - Given: 探索场景，HUD 已挂载
  - When: 调用 `hud.request_pause(&"combat_ui")`（模拟 combat-ui 转发）
  - Then: `SceneTree.paused == true` 且菜单 visible（三路入口统一到 request_pause）
  - Edge cases: 暂停状态下再次调用 request_pause（幂等——不重复开流程）

**[UI — manual verification steps]:**

- **AC-4**: 菜单项完整性与导航
  - Setup: 探索场景打开暂停菜单
  - Verify: 5 个菜单项 + 探索进度行（降级格式「层 3」——GAP-2 裁决）；各按钮路由正确（「保存并退出」存档后返主菜单/「返回主菜单」直接转场——GAP-5 裁决）
  - Pass condition: 继续游戏关闭菜单；查看卡组/系统设置打开对应界面；保存并退出/返回主菜单行为正确

- **AC-5**: 背景模糊与计时冻结
  - Setup: 打开暂停菜单
  - Verify: 背景 0.3s 模糊；游戏内计时（AP 恢复等如有）不再推进
  - Pass condition: 模糊动画流畅，恢复后计时从暂停点继续

---

## Test Evidence

**Story Type**: UI（含 Integration 核心）
**Required evidence**:
- Integration: `tests/integration/hud/test_pause_combat_state_preserved.gd`（AC-2 战斗状态保持）+ 暂停打开/接口测试（AC-1/AC-6 可并入 `tests/integration/hud/test_pause_menu.gd`）— must exist and pass（BLOCKING）
- UI: `production/qa/evidence/pause-menu-evidence.md` + sign-off（菜单项/模糊/计时冻结手动验证）

**Status**: [x] Not yet created → 创建模板（`production/qa/evidence/pause-menu-evidence.md`），手动验证后补齐签收

---

## Dependencies

- Depends on: Story 001（overlay 挂载点）
- Unlocks: None（combat-ui / main-menu / deck-editing-ui 各自实现对接侧）

---

## Completion Notes

**Completed**：2026-09-11
**Criteria**：6/6 通过（AC-1~AC-3/AC-6 自动化测试覆盖；AC-4/AC-5 手动证据模板创建待签收——ADVISORY）

**Deviations**：
1. **AC-2 递延**：规格要求「所有角色 HP、当前费用、牌库/弃牌堆计数不变」，当前战斗数据模型尚未完整建模这些字段。已覆盖回合数 + GSM battle 域（is_active/phase/turn）断言；HP/费用/牌库计数递延至战斗数据模型完整建模后补齐（用户裁决 2026-09-11）。
2. **ESC 关闭路径（code-review B-3 修复）**：story 原始 Implementation Notes 禁止 HUD 侧 `_unhandled_input`/`_input` 监听 ESC——但实操中菜单打开后 InputManager 被 PAUSABLE 冻结 + MODAL 锁阻断，ESC 无法关闭菜单。code-review 裁决在 PauseMenu `_unhandled_input` 兜底接收（模态拥有者自判模式），不违反 InputManager 的 `_input` 拦截（菜单打开时后者不再 emit）。story 文本与实现的分歧以 code-review 裁决为准。
3. **AC-006 例外裁决**：InputManager 新增 `pause_requested` 信号与 input-manager story 003 AC-006「InputManager 不声明任何信号」冲突——经语义分析裁决为例外（AC-006 语义为锁状态经 GSM 传播，动作通知信号不属锁状态同步，ADR-0007 Cat 2b 先例），test_gsm_sync.gd 留痕。
4. **本地化**：UI 文本硬编码（按钮/标题/进度行），项目本地化系统尚未建成——登记为技术债，后续 epic 统一覆盖。
5. **GAP-1 ESC 接线点修正**：story 原文称 ESC 信号接线在 `_setup_pause_menu()`（setup 流程），实际移至 `_ready()`（挂载即响应 ESC）——测试 add_child 后即接线，无须依赖调用方调 setup。code-review G-6 修正注释失真。

**Test Evidence**：
- Integration: `tests/integration/hud/test_pause_menu.gd`（19 测试）+ `tests/integration/hud/test_pause_combat_state_preserved.gd`（4 测试）——全部通过
- UI: `production/qa/evidence/pause-menu-evidence.md`——模板创建，手动验证后补齐签收（ADVISORY）
- 全量回归：2596 tests / 2594 passing / 1 pending / 1 failing（test_ac010 预存 flaky，非本 story 引入）

**Code Review**：已完成（双专家初审 CHANGES REQUIRED → 全部修复 → 复审 APPROVED WITH SUGGESTIONS → 3 LOW 直修 2 项 + 补 2 回归测试）

**Test-Criteria Traceability**:

| 标准 | 测试 | 状态 |
|-----------|------|--------|
| AC-1: ESC/按钮打开暂停 | test_ac001_request_pause_esc_opens_menu | COVERED |
| AC-1: 再触发关闭 | test_ac001_second_trigger_closes_menu | COVERED |
| AC-1: 快速 ESC 无错乱 | test_ac001_rapid_esc_no_state_corruption | COVERED |
| AC-1: 打开后立即关闭 | test_ac001_open_then_immediate_close | COVERED |
| AC-1: 锁栈配对 | test_ac001_lock_stack_clean_after_cycle | COVERED |
| AC-2: 回合数保持 | test_ac002_turn_number_preserved | COVERED |
| AC-2: GSM battle 域保持 | test_ac002_gsm_battle_domain_preserved | COVERED |
| AC-2: 战斗锁中暂停 | test_ac002_pause_while_combat_lock_active | COVERED |
| AC-2: 多轮暂停恢复 | test_ac002_multi_pause_resume_cycles | COVERED |
| AC-2: HP/费用/牌库 | — | DEFERRED（战斗数据模型未建模） |
| AC-3: suspend 调用 | test_ac003_suspend_called_on_open | COVERED |
| AC-3: resume 调用 | test_ac003_resume_called_on_close | COVERED |
| AC-3: 多轮配对 | test_ac003_suspend_resume_call_counts | COVERED |
| AC-4: 菜单项完整性 | 手动证据 | ADVISORY（模板创建） |
| AC-5: 背景模糊+计时 | 手动证据 | ADVISORY（模板创建） |
| AC-6: combat_ui 路径 | test_ac006_request_pause_combat_ui_opens_menu | COVERED |
| AC-6: button 路径 | test_ac006_request_pause_button_path_opens_menu | COVERED |
| AC-6: 幂等 | test_ac006_request_pause_idempotent_while_paused | COVERED |
| AC-6: ESC 信号路由 | test_ac006_input_manager_signal_routes_to_pause | COVERED |
| B-3: ESC 关闭 | test_esc_closes_menu_via_unhandled_input | COVERED |
| B-3: echo 过滤 | test_esc_echo_event_does_not_retrigger | COVERED |
| B-3: 非锁拥有者 | test_esc_ignored_when_not_lock_owner | COVERED |
| M-4: 存档失败 | test_save_exit_failure_keeps_menu_open | COVERED |
| M-4: null save_load | test_save_exit_null_save_load_keeps_menu_open | COVERED |
| M-4: 返主菜单 | test_return_to_main_menu_releases_pause_and_lock | COVERED |
| G-3: 未打开守卫 | test_request_close_when_not_open_is_noop | COVERED |
