# Story 005: 暂停菜单（全局覆盖层）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

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

- [ ] 按 ESC 或点击左下暂停按钮打开暂停菜单，游戏暂停，背景模糊（AC-hud-010）
- [ ] 菜单项：继续游戏 / 查看卡组 / 系统设置 / 保存并退出 / 返回主菜单 + 探索进度显示
- [ ] 暂停时冻结所有游戏计时；战斗中暂停冻结回合计时（如有）
- [ ] 战斗中暂停后回到游戏，战斗状态不变（AC-hud-011）
- [ ] 暂停期间音频总线（BGM+SFX）显式暂停，恢复时同步恢复
- [ ] 战斗中 ESC 由 combat-ui 转发请求，菜单由 HUD 渲染（本 story 实现 HUD 侧接收接口；combat-ui 侧转发归其 epic）

---

## Implementation Notes

*Derived from ADR-0031 §1.1 Implementation Guidelines:*

- 暂停菜单为 HUD 场景内独立 overlay 分支（Story 001 预留挂载点），PROCESS_MODE_ALWAYS——否则 `SceneTree.paused = true` 时菜单自身也被冻结。
- 打开流程：ESC/按钮 → `SceneTree.paused = true` → 显式暂停音频总线 → 显示菜单（0.3s 背景模糊）。关闭流程严格逆序。
- 战斗状态保持（AC-hud-011）用集成测试验证：进入战斗→暂停→恢复，断言战斗系统关键状态（回合数/角色 HP/费用）不变。
- 「查看卡组」：战斗中可用（只读查看，不可编辑——GDD 待解决问题 #3 的当前设计）。路由到卡组浏览界面（deck-editing-ui epic 的卡组浏览），本 story 仅发导航请求。
- 「系统设置」路由到主菜单系统设置面板（main-menu epic），本 story 仅发导航请求。
- 「保存并退出」「返回主菜单」调用 SaveLoadSystem / SceneManager 既有 API。

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
  - When: 触发 ESC（模拟输入事件）
  - Then: `SceneTree.paused == true`，菜单 visible；再按 ESC → paused == false，菜单隐藏
  - Edge cases: 连续快速按 ESC（无状态错乱）；暂停中打开后立即关闭

- **AC-2**: 战斗状态保持（AC-hud-011 核心）
  - Given: 战斗进行到第 3 回合，角色 HP/费用已知
  - When: 暂停 → 恢复
  - Then: 回合数、所有角色 HP、当前费用、牌库/弃牌堆计数全部不变
  - Edge cases: 暂停发生在动画播放中（恢复后动画状态可继续或重置，但战斗逻辑状态必须不变）

- **AC-3**: 音频同步暂停
  - Given: BGM 播放中
  - When: 打开暂停菜单
  - Then: 音频总线暂停（BGM+SFX 静音/暂停）；恢复后继续播放
  - Edge cases: 暂停中触发 SFX 请求（不播放）

**[UI — manual verification steps]:**

- **AC-4**: 菜单项完整性与导航
  - Setup: 探索场景打开暂停菜单
  - Verify: 5 个菜单项 + 探索进度行（「青云剑宗 · 层3/5」格式）；各按钮路由正确
  - Pass condition: 继续游戏关闭菜单；查看卡组/系统设置打开对应界面；保存并退出/返回主菜单行为正确

- **AC-5**: 背景模糊与计时冻结
  - Setup: 打开暂停菜单
  - Verify: 背景 0.3s 模糊；游戏内计时（AP 恢复等如有）不再推进
  - Pass condition: 模糊动画流畅，恢复后计时从暂停点继续

---

## Test Evidence

**Story Type**: UI（含 Integration 核心）
**Required evidence**:
- Integration: `tests/integration/hud/test_pause_combat_state_preserved.gd`（AC-2 战斗状态保持）— must exist and pass（BLOCKING）
- UI: `production/qa/evidence/pause-menu-evidence.md` + sign-off（菜单项/模糊/计时冻结手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（overlay 挂载点）
- Unlocks: None（combat-ui / main-menu / deck-editing-ui 各自实现对接侧）
