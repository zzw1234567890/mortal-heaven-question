# Story 006: 备战面板交互流（瞬态+一次性提交）

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 备战阶段 AC 6 条（交互侧）+ 边界澄清补充二（瞬态+一次性提交/替换二次选择/battle_start config 扩展）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0016: 上场阵位系统
**ADR Decision Summary**: `setup_field(character_ids, layout)` 备战阶段一次性初始化（验证人数≤max_deploy、角色可用、自动前排优先或手动 layout）——`character_deployed` 是 setup_field/deploy 发射的系统信号，非 UI 点选信号。

**ADR 次要参考**: ADR-0031（§2.1 瞬态交互状态——选择集/阵位布局 UI 本地合法）、ADR-0008（battle_start 生命周期）
**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: 阵位拖拽 1 帧更新（≤16ms）为渲染侧目标；layout 007 已建阵位映射纯函数。

**Control Manifest Rules (this layer)**:
- Required: 点选/阵位调整全程 UI 瞬态；确认出战一次性调用系统 API
- Forbidden: 逐次点选发射 character_deployed/undeployed 系统信号（触发 BindingManager/阵法无意义重查——B3 裁决）
- Guardrail: 阵位预览更新 ≤1 帧

---

## Acceptance Criteria

*From GDD 备战 AC + 边界澄清补充二，scoped to this story:*

- [ ] 角色点选/取消：纯 UI 瞬态（复用 layout 007 的 `deploy_selection_state()` 4 态判定）——**零系统写入**（点选过程无 character_deployed/undeployed 信号断言）
- [ ] 名额满点击 ⊕ → **弹出已选角色列表供二次选择**（B5 裁决——列表含各已选角色概要信息；玩家选择替换对象后确认）→ 确认后替换瞬态集内角色
- [ ] 阵位预览拖拽调整前后排（GDD §8 两种方式：预览区拖拽调整 + 拖角色到头像区自动排位——A4）→ 布局预览 ≤1 帧更新；调整全程瞬态
- [ ] 确认出战（≥1 已选可点——layout 007 判定）→ 一次性调用 `battle_start(扩展 config)`：config 含 `character_ids` + `layout`（由 UI 瞬态集组装；B4 裁决）→ 系统侧 `setup_field(character_ids, layout)` 落地 → character_deployed × N 由系统发射
- [ ] 「返回探索」→ SceneManager 转场（request_scene_change）
- [ ] 渡劫战前 warning（layout 008 弹窗本体）按钮流：[确认进战] → 进入备战面板；[返回] → 返回探索
- [ ] **键盘/手柄路径（B7 补）**：数字键/Tab+Enter 选择取消、方向键+A 全操作、B 取消、Start 确认出战（UX #8）
- [ ] 确认出战后进入阶段 0（准备）→ 阶段 1（抽牌）——以 ADR-0008 battle_start→Phase 0 为准（A8 注记：UX「进入阶段 1」措辞系简化表述）

---

## Implementation Notes

*Derived from ADR-0016/0008/0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`DeployDraftModel`（或等效纯类）——瞬态选择集操作：`toggle_select(id, selected, max_deploy)`、`apply_replacement(new_id, replaced_id)`、`build_layout(preview_grid) -> Dictionary`（阵位→{char_id: is_front}）。

- 确认调用链：`battle_start({enemy_deck_id, is_tribulation, character_ids, layout})`——character_ids/layout 从瞬态集组装；B4 裁决的 config 扩展（如 CombatSystem 现有签名不含，本 story 变更集须同步其参数与单测——回归影响申报）。
- 替换二次选择：⊕ 点击 → 已选角色列表弹窗（复用 layout 008 弹窗框架 + story 001 MODAL 锁封装）。
- 阵位拖拽的 1 帧更新：UI 布局容器直接重排（无信号往返——瞬态操作不出发系统调用）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- layout story 007: 备战面板视觉框架与 4 态判定纯函数（本 story 消费）
- layout story 008: 渡劫 warning 弹窗本体渲染
- CombatSystem/DeploymentSystem 域: setup_field/battle_start 的系统侧执行逻辑（本 story 仅扩展 config 传递并同步单测）
- audio-manager epic: 选择/确认音

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_deploy_draft_model.gd`）

- **AC-1**: 瞬态选择集操作
  - Given: max_deploy=3，已选 2
  - When: toggle_select 第 3/4 个 / apply_replacement
  - Then: 第 3 个加入（3/3）；第 4 个不加入（满）；apply_replacement(新, 旧) → 集合大小不变、成员替换
  - Edge cases: 取消已选（2/3→1/3）；替换不存在的旧角色（无操作）；空集 build_layout → {}；全前排列

**[Integration — automated test specs]:**

- **AC-2**: 瞬态零写入+一次性提交
  - Given: 备战面板，3 个可选角色
  - When: 点选 2 个（含 1 次取消+替换）→ 确认出战
  - Then: 点选/取消/替换全程无 character_deployed/undeployed/repositioned 信号（监听断言零发射）；确认时 battle_start 恰调用 1 次且 config 含正确 character_ids+layout
  - Edge cases: 0 已选点确认 → 无调用（按钮禁用）；返回探索 → SceneManager.request_scene_change 调用断言

**[UI — manual verification steps]:**

- **AC-3**: 备战交互走查
  - Setup: 五境界各进一次备战；构造满员+阵亡场景
  - Verify: 4 态点击反馈、⊕ 替换二次选择列表、阵位拖拽流畅 1 帧更新、渡劫 warning 按钮流
  - Pass condition: 键盘手柄全路径可用、确认后正常入战

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_deploy_draft_model.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_deploy_confirm_flow.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/deploy-interaction-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（MODAL 锁封装）、layout story 007/008（面板框架与判定函数）
- Unlocks: 无直接下游（battle_start 链路被 007 结算流复用）
