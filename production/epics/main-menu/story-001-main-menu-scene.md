# Story 001: 主菜单场景与按钮组

> **Epic**: 主菜单与设置
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Integration 核心）
> **Estimate**: 1.0d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-19（QL-STORY-READY 裁决修订：4 按钮/损坏语义收窄/存档摘要降级）

## Context

**GDD**: `design/gdd/main-menu-system.md`
**Requirement**: AC-main-menu-001~004 + AC-main-menu-006 + AC-main-menu-020~022（性能）+ 存档摘要（边界澄清 2026-09-19）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 场景内 Control 零新增 Autoload；零状态所有权（存档存在性从 SaveLoadSystem 读取，UI 不缓存）；场景导航经 SceneManager `request_scene_change`；双焦点双视觉（焦点环/悬停）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: **前置：双焦点 spike（R-01）须在本 story 前完成**——本 epic 首个 UI story，菜单按钮需键盘导航焦点环。4.6 中 `grab_focus()` 只影响键盘/手柄焦点。

**Control Manifest Rules (this layer)**:
- Required: 存档存在性判定提取纯函数；场景导航走 SceneManager API
- Forbidden: UI 缓存存档列表；新增 Autoload
- Guardrail: Draw Call ≤50（主菜单专项预算，严于全局 <200）

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu-system.md`，scoped to this story:*

- [ ] 启动加载完成显示主菜单：标题 + 4 按钮（新游戏/继续游戏/设置/退出）+ 版本号（AC-main-menu-001；制作人员界面已移除——QL-STORY-READY 2026-09-19 裁决，整合到通关片尾）
- [ ] 无存档时继续游戏按钮灰色不可用（AC-main-menu-002）
- [ ] 有存档时点击继续游戏加载**最近**存档进入游戏（AC-main-menu-003）
- [ ] 存档损坏时点击继续游戏弹「存档损坏，无法读取」提示并返回主菜单；提示关闭后继续按钮恢复可用态（GDD 边缘情况）
- [ ] 点击新游戏进入身份选择界面（AC-main-menu-004）
- [ ] 点击退出游戏关闭（AC-main-menu-006）
- [ ] 有存档时继续按钮旁显示存档摘要「上次：[境界] · 游玩 [时长]」（realm+playtime 取自 meta.json；无存档时摘要行隐藏，布局占位保留）
- [ ] 主菜单背景动画 D3D12 下 60fps（AC-main-menu-020）；1280×720 不溢出（AC-main-menu-021，支持下限）；Draw Call ≤50（AC-main-menu-022）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `has_continuable_save(save_meta_list) -> bool`——以 meta.json 槽位条目 `exists == true` 判定（QL-STORY-READY 2026-09-19 裁决：收窄语义——meta 列表无损坏字段，损坏检测在 `load_game()` 读档时发生；损坏存档按钮亮起，点击走损坏路径弹提示，与 AC-3 自洽）。空列表 → false；≥1 存在 → true。
- 最近存档选取——多存档按时间戳取最新；时间戳相同的 tie-break 定义为存档槽序号升序（实现时写入常量注释）。
- 存档摘要文本组装——「上次：[境界] · 游玩 [时长]」从 meta.json 的 `realm` + `playtime` 字段组装（chapter 不在 meta.json，本 MVP 不引入）。

- 存档存在性/列表从 SaveLoadSystem 公共接口读取（启动时 + 返回主菜单时刷新），UI 不缓存。
- 场景导航：新游戏→身份选择经 `SceneManager.request_scene_change(MAIN_MENU, IDENTITY_SELECT, ...)`；继续游戏走 SaveLoadSystem 读档流程。
- 按钮键盘导航：焦点顺序 新游戏→继续→设置→退出；初始焦点 = 继续游戏（无存档时回退新游戏）；焦点环+悬停双视觉（ADR-0031 §4）。
- 版本号从 ProjectSettings 读取，不硬编码。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002~005: 设置面板全部内容
- 通关片尾（game-flow/ending story）: 制作人员界面——已从 MVP 主菜单移除（QL-STORY-READY 2026-09-19 裁决，整合到通关片尾）
- audio-manager epic: 场景切换音频 `set_state(MAIN_MENU)`（主菜单仅触发音频事件）
- 身份选择界面本体：identity-selection-system（Feature 层已 Complete，含 UI 入口归其 UI story）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 存档存在性判定
  - Given: 存档元数据列表
  - When: 调用 `has_continuable_save()`
  - Then: ≥1 槽位 exists==true → true；空列表 → false（损坏感知收窄——meta 层不可判定，损坏在点击后由 load_game 检测）
  - Edge cases: 单存档槽存在、多槽位混合存在/不存在、空列表

- **AC-2**: 最近存档选取
  - Given: 多个存档（时间戳不同）
  - When: 请求最近存档
  - Then: 返回时间戳最新者；时间戳相同时按槽序号 tie-break
  - Edge cases: 单存档、时间戳完全相同

**[Integration — automated test specs]:**

- **AC-3**: 存档损坏路径
  - Given: 有效存档存在且按钮亮起，存档文件被人为损坏
  - When: 点击继续游戏
  - Then: 弹「存档损坏，无法读取」→确认→返回主菜单；提示关闭后继续按钮恢复可用态
  - Edge cases: 损坏存档 + 无其他存档（按钮仍亮起——meta 层 exists==true，点击走损坏路径）

- **AC-4**: 场景导航
  - Given: 主菜单
  - When: 点击新游戏
  - Then: `request_scene_change` 调用且目标为身份选择场景；无 GSM 直接写

**[UI — manual verification steps]:**

- **AC-5**: 主菜单完整性
  - Setup: 启动游戏
  - Verify: 0.8s 淡入+标题滑落；4 按钮存在（新游戏/继续/设置/退出）；版本号显示；退出按钮关闭进程；初始焦点落在继续游戏（无存档时新游戏）
  - Pass condition: 动画流畅、按钮全可达（鼠标+键盘 Tab/方向键）、无 UI 溢出、有存档时摘要行显示「上次：[境界] · 游玩 [时长]」且无存档时摘要行隐藏

- **AC-6**: 性能
  - Setup: 主菜单背景动画运行（D3D12 渲染器）
  - Verify: 帧时间 ≤16.6ms（引擎监控器实测）；Draw Call ≤50（`get_rendering_info` 采样）；1280×720 布局不溢出
  - Pass condition: 三项指标全部达标

---

## Test Evidence

**Story Type**: UI（含 Logic 内核 + Integration）
**Required evidence**:
- Logic 内核: `tests/unit/main_menu/test_continue_button_state.gd` + `tests/unit/main_menu/test_latest_save_selection.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/main_menu/test_corrupt_save_continue.gd` + `test_menu_navigation.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/main-menu-scene-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 双焦点 spike（R-01，Sprint 13 首周前置 story——非本 epic 内 story）
- Unlocks: Story 002~005（设置面板从主菜单入口打开）
