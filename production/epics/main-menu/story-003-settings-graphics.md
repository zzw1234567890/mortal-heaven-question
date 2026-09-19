# Story 003: 画面设置与应用/回退机制（含全局恢复默认）

> **Epic**: 主菜单与设置
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: 1.0d（不含分辨率 spike——独立条目 S14-4a 前置）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-19（QL-STORY-READY 裁决修订：生效时机统一/减少动效入 scope/恢复默认注册机制/spike 独立排期）

## Context

**GDD**: `design/gdd/main-menu-system.md`
**Requirement**: AC-main-menu-009~014
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§2.1 持久设置）
**ADR Decision Summary**: 持久设置直写设置文件不经 GSM。QL-STORY-READY 2026-09-07 裁决：全局「恢复默认」按钮（一次重置全部设置）；分辨率枚举 API 实现前查证引擎参考（查不到安排 spike）；720p 为支持下限。

**Engine**: Godot 4.6 | **Risk**: HIGH（4.6 分辨率枚举 API 待查证——`screen_get_resolutions()` 为 4.6 可能新增，在 LLM 知识截止后）
**Engine Notes**: **前置：分辨率枚举 spike（S14-4a，0.5d 独立条目）**——引擎参考已查证零覆盖（QL-STORY-READY 2026-09-19），spike 确定触发；spike 产出回写 `docs/engine-reference/godot/`（DisplayServer 小节）。分辨率不可用时回退链终止到安全默认 1920×1080（与 control-manifest 基准一致）。

**Control Manifest Rules (this layer)**:
- Required: 分辨率过滤/回退逻辑、脏检测逻辑提取纯函数单测
- Forbidden: 硬编码分辨率列表（须运行时枚举+过滤）；设置经 GSM
- Guardrail: 应用分辨率变更不触发场景重载

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu-system.md`，scoped to this story:*

- [ ] 修改分辨率点应用后画面分辨率改变；不支持时回退+提示「该分辨率不支持，已恢复」（AC-main-menu-009）
- [ ] 全屏/窗口切换点应用后生效（AC-main-menu-010；QL-STORY-READY 2026-09-19 裁决：画面类各项统一「点应用」生效——含分辨率/全屏/帧率/画质，UX 已同步）
- [ ] 帧率限制应用后 `Engine.max_fps` 更新（30/60/120/不限→0）（AC-main-menu-011）
- [ ] 画质预设应用后渲染质量更新（低/中/高——映射表数据驱动）（AC-main-menu-012）
- [ ] 有未保存变更时点关闭弹「未保存的设置将丢失，确认退出？」（AC-main-menu-013）
- [ ] 全局「恢复默认」重置**已实现分类**设置（QL-STORY-READY 2026-09-19 裁决：注册机制——本 story 实现分类注册+逐个调用已注册分类的重置接口；未实现分类（004 按键/005 语言）占位不崩溃，其落地后自动纳入）（AC-main-menu-014）
- [ ] 「减少动态效果」切换开关（UX 10d——QL-STORY-READY 2026-09-19 裁决入本 story scope）：画面分类内，含持久化 + 动效减少模式全局生效（水墨动画降级简单淡入淡出/视差静态/标题动画跳过，功能性反馈保留）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `filter_resolutions(requested, available) -> Dictionary`——请求分辨率 ∈ 可用列表 → 通过；∉ → 回退目标（上一个可用设置；上一设置也不可用则回退链终止到 1920×1080）。
- `has_unsaved_changes(pending, saved) -> bool`——待应用字典 vs 已保存字典逐键比较（类型归一：int 60 == float 60.0）。

- 可用分辨率列表：运行时枚举（**前置 S14-4a spike**）+ 宽高比过滤（规则：保留桌面宽高比——与当前显示器一致的比例；1280×720 下限以下剔除）；不硬编码列表。
- 「不限」帧率映射 `Engine.max_fps = 0`（枚举映射写入数据驱动常量）。
- 画质预设映射表（低/中/高 → 渲染缩放/效果开关组合）由本 story 定义并数据驱动化（GDD 边界澄清 2026-09-07）——映射表作为数据文件提交，集成测试断言「应用预设 N → 映射表逐键生效」而非硬编码值。
- 全局恢复默认（注册机制）：设置分类重置接口注册表——本 story 注册画面分类、002 已注册音量分类；恢复默认 = 遍历已注册分类逐个调用重置接口 + 设置文件重写为默认值后各面板刷新。004/005 落地时各自注册，无需回归本 story。
- 未保存关闭确认弹窗：确认=丢弃变更（回滚，复用 002 回滚机制）/取消=回到面板。
- 「显示模式」下拉与全屏开关字段重叠（2026-09-07 epic 审查遗留）：本 story 仅实现全屏开关（Fullscreen/Windowed 二态），「显示模式」独立下拉移出 MVP——无边框窗口等模式归后续 story（记 GDD 边界澄清）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 音量滑条与总线应用（本 story 消费其重置接口）
- Story 004: 按键绑定内容（消费其重置接口）
- Story 005: 语言切换（消费其重置接口）
- Steam Deck / 其他平台的分辨率适配：非 MVP

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 分辨率过滤与回退
  - Given: 请求分辨率 R + 可用列表 L
  - When: 调用 `filter_resolutions(R, L)`
  - Then: R∈L → 通过；R∉L → 返回上一可用设置；上一设置不可用 → 回退到 1920×1080
  - Edge cases: L 为空（回退链终止）、R 恰为 L 最小项、宽高比不匹配项剔除（16:9 列表 vs 4:3 请求）

- **AC-2**: 未保存变更检测
  - Given: 待应用字典与已保存字典
  - When: 调用 `has_unsaved_changes(pending, saved)`
  - Then: 任一键不同 → true；全同 → false
  - Edge cases: int 60 vs float 60.0（视为相同）、空字典、单键变更

**[Integration — automated test specs]:**

- **AC-3**: 画面设置应用
  - Given: 待应用的 graphics 设置字典（如 max_fps=120）
  - When: 调用应用
  - Then: `Engine.max_fps == 120`（枚举映射 30/60/120/0 全覆盖断言）；画质预设对应 ProjectSettings/RenderingServer 值变更
  - Edge cases: 「不限」→ 0；不支持分辨率 → 回退值生效+不崩溃

**[UI — manual verification steps]:**

- **AC-4**: 分辨率回退提示
  - Setup: 构造不支持的分辨率请求（如列表外值）
  - Verify: 弹「该分辨率不支持，已恢复」，画面保持上一可用分辨率
  - Pass condition: 提示可见、无黑屏/崩溃；应用 1280×720 后设置面板与主菜单布局不溢出（720p 下限兼容检查）

- **AC-5**: 未保存关闭确认与全局恢复默认
  - Setup: 修改画面设置不应用→点关闭；再恢复默认
  - Verify: 弹「未保存的设置将丢失，确认退出？」确认/取消两分支行为正确；恢复默认后已注册分类（音量/画面）全部归位、未实现分类（按键/语言）占位不崩溃
  - Pass condition: 确认丢弃回滚、取消保留面板；已实现分类默认值全部正确恢复

- **AC-6**: 减少动态效果
  - Setup: 设置面板开启「减少动态效果」并应用
  - Verify: 主菜单水墨晕染动画降级为简单淡入淡出；背景视差为静态；标题动画跳过；按钮悬停/按下反馈保留
  - Pass condition: 动效减少模式全局生效且功能性反馈不损失

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/main_menu/test_resolution_filter_fallback.gd` + `tests/unit/main_menu/test_unsaved_changes_detection.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/main_menu/test_graphics_apply.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/settings-graphics-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（面板框架与回滚机制共用）；S14-4a 分辨率枚举 spike（前置——引擎参考零覆盖，QL-STORY-READY 2026-09-19 裁决独立排期）
- Unlocks: None（004/005 可并行，落地时向恢复默认注册机制注册各自分类）
