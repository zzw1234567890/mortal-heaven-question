# Story 004: 身份选择 UI 场景——6 卡 2×3 + 确认流程 + SCENE_PATHS 串联

> **Epic**: 开局身份选择系统
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: 2.0d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-10-24（story-done 关闭——S16-1 实现完成）

## Context

**GDD**: `design/gdd/identity-selection-system.md`（§用户界面需求 L587-597 + §验收标准 L599-625）
**Requirement**: 身份选择屏幕 + 身份详情弹窗 + 确认弹窗 + 开局叙事展示 + 未解锁提示（5 界面）+ 6 卡 2×3 网格
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0022（身份选择系统——`get_available_identities()` / `get_identity_preview()` / `apply_identity()` 数据源）+ ADR-0031（表现层架构基线——场景内 Control + 零状态所有权 + 双焦点双视觉）
**ADR Decision Summary**: 本 story 消费 IdentitySelectionSystem Autoload（#21）的查询与编排 API——UI 不持有任何游戏状态，选择结果经 `apply_identity()` 写入 GSM；场景导航经 SceneManager `request_scene_change`；读档跳过身份选择（`is_identity_selected()` true → 直接进入游戏）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后——焦点环/悬停双视觉）
**Engine Notes**: 前置——双焦点 spike（R-01，Sprint 13）已完成，焦点导航模式可复用 main-menu story 001 的键盘焦点环实现。场景文件 `identity_select.tscn` 落盘后接入 `SceneManager.SCENE_PATHS`（当前 IDENTITY_SELECT → 占位路径，冒烟留桩「新游戏无法开始」根因）。

**Control Manifest Rules (this layer)**:
- Required: 解锁判定纯函数可单测（消费 story 001 `get_available_identities` 的 `is_unlocked`，不自算）；确认按钮启用态判定纯函数
- Forbidden: UI 缓存身份选择状态（选中态经场景内局部状态，最终结果仅经 `apply_identity()` 落 GSM）；UI 直接写 GSM（选择结果必须经 `apply_identity()` 原子操作）
- Guardrail: 6 卡 2×3 网格 Draw Call ≤50（主菜单专项预算同量级）

---

## Acceptance Criteria

*From GDD §用户界面需求 + §验收标准，scoped to this story:*

- [ ] 新游戏点击后经 SceneManager 导航进入身份选择场景（SCENE_PATHS 目标场景落盘，消除冒烟留桩「新游戏无法开始」）
- [ ] 6 张身份卡片 2×3 网格渲染（5 默认可解锁 + 1 阵道双杰），每卡含名称 + 风格标签 + 角色头像 + 灵石数 + 解锁状态
- [ ] 阵道双杰未解锁时卡片显示半透明 🔒 遮罩；点击显示「该身份需要轮回天赋『苍玄行者』解锁」提示
- [ ] 点击任意身份卡牌 → 底部详情面板展示该身份完整信息（卡组概览 / 角色属性 / 天赋描述）
- [ ] 未选中身份时「确认选择」按钮不可用；选中后可用
- [ ] 点击「确认选择」→ 确认弹窗（身份名 + 两名初始角色头像 +「确定选择？本局不可更改」+ [确定]/[返回重选]）
- [ ] [返回重选] → 弹窗关闭，返回身份选择界面，之前选择保留
- [ ] [确定] → 调用 `apply_identity(identity_id)` → 成功后经开局叙事展示（flavor_text 逐行显示，任意键跳过）→ 进入探索地图（导航归后续 story 编排，本 story 发射 `identity_selected` 后等待导航）
- [ ] 读档时 `is_identity_selected()` true → 跳过身份选择场景，直接进入游戏（导航分支）
- [ ] 开场入场动画 0.6s（6 卡依次飞入）+ 编钟/古琴开场音事件触发

---

## Implementation Notes

*Derived from ADR-0022 关键接口 + ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `confirm_button_enabled(selected_id: StringName) -> bool` 纯函数——空选中 → false，非空 → true。
- `is_identity_unlocked(entry: Dictionary) -> bool` 纯函数——消费 story 001 `get_available_identities()` 返回的 `is_unlocked` 字段（不自算解锁条件）。

- 数据源：`IdentitySelectionSystem.get_available_identities()`（6 条目含 `is_unlocked`/`is_recommended`/`initial_ling_shi`/`talent_name`）+ `get_identity_preview(id)`（完整模板含卡组/角色/天赋）。
- 确认流程：`apply_identity(identity_id)` 成功 → 发射 `identity_selected` 信号 → 开局叙事展示（消费 `GSM.player.identity_id` 对应 flavor_text，或从 `get_identity_preview` 的 `flavor_text` 读取）→ 导航到探索地图（SceneManager `request_scene_change(IDENTITY_SELECT, EXPLORATION, ...)`——但探索场景为占位路径，导航接通留待 exploration story 002 场景落盘后自动生效，本 story 只保证导航请求发出）。
- 焦点导航：6 卡 + 确认按钮键盘焦点环（复用 main-menu story 001 模式），初始焦点落在第一张已解锁卡；悬停高亮（墨色边框加粗）与焦点环（松石青 2px）双视觉。
- 读档跳过：场景 `_ready()` 检查 `is_identity_selected()`——true 则直接请求导航到探索地图，不渲染选择 UI。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story 001/002/003: 模板表 / apply_identity 原子操作 / 查询 API（本 story 消费）
- 开局叙事逐行展示的完整动画曲线与音频（本 story 仅基础展示 + 任意键跳过；正式叙事演出归叙事 epic）
- 开局叙事展示底部的「开始游戏」按钮（本 story 以「任意键跳过即触发导航请求」实现；按钮归叙事 epic）
- 探索地图场景本体（exploration-ui story 002 落盘后导航自然接通）
- 「不再显示推荐」选项（GDD 待解决问题 #4——UX 设计时裁决）
- focus/gamepad/a11y 三项细化规格（正式 UX 规格后续补——GDD §597 标记「预生产中运行 /ux-design」，本次按 GDD §用户界面需求直接实现，Deviations 登记）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/identity_selection_system/test_identity_unlock_gate.gd`）

- **AC-1**: 确认按钮启用态
  - Given: selected_id 为空 / 非空
  - When: 调用 `confirm_button_enabled()`
  - Then: 空 → false；非空 → true
  - Edge cases: 未选中 → 选中 → 返回重选（选中保留）

- **AC-2**: 解锁判定透传
  - Given: story 001 返回的 6 条目（5 unlocked + 1 locked）
  - When: 调用 `is_identity_unlocked(entry)`
  - Then: 阵道双杰 → false；其余 5 → true（透传 `is_unlocked` 字段，不自算）

- **AC-3**: 读档跳过判定
  - Given: `is_identity_selected()` true / false（mock GSM）
  - When: 场景初始化
  - Then: true → 请求导航探索地图（跳过选择 UI）；false → 渲染 6 卡网格

**[Integration — automated test specs]**

- **AC-4**: 场景导航目标
  - Given: 主菜单点击新游戏
  - When: `request_scene_change` 调用
  - Then: 目标为 IDENTITY_SELECT 场景，且 `identity_select.tscn` 场景文件存在断言（存在性断言**仅针对本 story 自己落盘的 IDENTITY_SELECT 场景**；EXPLORATION 场景文件存在性是 exploration story 002 的延迟项，不在本 story 断言范围）
  - Edge cases: 读档路径绕过身份选择（目标为 EXPLORATION——仅断言导航请求发出 + 目标 SceneID 正确，不断言其场景文件存在）

**[UI — manual verification steps]**

- **AC-5**: 身份选择全流程走查
  - Setup: 新游戏进入身份选择
  - Verify: 6 卡 2×3 网格 + 🔒 遮罩 + 底部详情面板 + 确认弹窗两分支 + 入场动画 0.6s
  - Pass condition: 与 GDD §用户界面需求表逐条一致 + 签批

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/identity_selection_system/test_identity_unlock_gate.gd` — must exist and pass（BLOCKING）
- Integration: 导航目标断言并入 `tests/integration/main_menu/test_menu_navigation.gd`（追加用例）— must pass（BLOCKING）
- UI: `production/qa/evidence/identity-select-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（模板表 + 查询 API）、Story 002（apply_identity 原子操作）、Story 003（is_identity_selected 读档判定）、R-01 双焦点 spike（Sprint 13 已完成）
- Unlocks: 探索地图导航（exploration-ui story 002 落盘后自动接通）、开局叙事演出（叙事 epic）

## Completion Notes
**Completed**：2026-10-24
**Criteria**：10/10 通过（导航 / 6 卡网格 / 锁定遮罩 / 详情面板 / 确认按钮启用 / 确认弹窗两分支 / 返回重选保留 / apply_identity→叙事→导航 / 读档跳过 / 入场动画+音频）
**Deviations**：
- 音频最小接入——无确切编钟/古琴 SFX id，以 `AudioManager.set_state(AudioState.IDENTITY_SELECT)` 替代，音频资产归属 audio story 004（Out of Scope 已登记）。
- 固定 UI 词条 `TEXT_*` const 块集中管理——项目暂无本地化系统，沿用 main_menu 先例豁免注记。
- UI 手动证据 `production/qa/evidence/identity-select-evidence.md` 待补（ADVISORY，随 /team-qa 签收流程一并补齐）。
**Test Evidence**：Logic `tests/unit/identity_selection_system/test_identity_unlock_gate.gd`（10 例：AC-1/2/3 + 锁定遮罩 2 条回归）— 全过；Integration `tests/integration/main_menu/test_menu_navigation.gd` 追加 2 例（AC-4 场景落盘 + 读档绕过）— 全过；全量 2933 tests / 2932 passing / 1 pending 存量（save_load 占位，非本次引入）。
**Code Review**：lead-programmer 两轮——首轮 CHANGES REQUIRED（锁定卡遮罩丢失 / ESC 双重触发 / 确认弹窗缺头像 / docstring 漂移 / 超 40 行），修复后复审闭环（含入场动画遮罩同源缺陷）。引擎专家 godot-specialist 前置验证（读档跳过 defer / FOCUS_ALL / is_input_allowed 设备区分）。
**Test Evidence (UI manual)**：[ ] Not yet created——待 /team-qa 签收时补 `production/qa/evidence/identity-select-evidence.md`。
