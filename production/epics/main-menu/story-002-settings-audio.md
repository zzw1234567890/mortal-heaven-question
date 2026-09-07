# Story 002: 设置面板框架与音量控制

> **Epic**: 主菜单与设置
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/main-menu-system.md`
**Requirement**: AC-main-menu-007 / AC-main-menu-008
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§2.1 持久设置）
**ADR Decision Summary**: 设置值属「持久设置」——设置面板直接写设置文件，不经 GSM 不经 SaveLoadSystem。音量实时生效+手动持久化（QL-STORY-READY 2026-09-07 裁决：滑条拖动即时生效到总线，点「应用」才写文件，未保存关闭回滚）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 滑条为标准 HSlider 控件；音频总线应用经 `AudioServer.set_bus_volume_db()`。**前置：音频总线布局（Master/Music/SFX 三总线）依赖 audio-manager epic 定义**——若该 epic 未先行，本 story 以 default_bus_layout 现有总线实现并在接口层留适配点。

**Control Manifest Rules (this layer)**:
- Required: `db_from_percent()` 纯函数单测；回滚逻辑可测
- Forbidden: 设置值经 GSM 存档链；硬编码音量映射
- Guardrail: 滑条 1% 步进；拖动中无逐帧文件写入

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu-system.md`，scoped to this story:*

- [ ] 点击设置打开设置界面，含音效/画面/按键/语言 4 个分类（AC-main-menu-007）
- [ ] 拖动音量滑条时对应总线音量**实时**变化（经 `db_from_percent` 转换）（AC-main-menu-008）
- [ ] 三条音量滑条：总音量/音乐音量/音效音量（0~100%，1% 步进）
- [ ] 点击「应用」时音量值持久化写入设置文件；未保存关闭时回滚到已保存值
- [ ] 设置面板打开 0.3s 滑入 / 关闭 0.2s 滑出

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `db_from_percent(percent) -> float` 纯函数——percent ≤ 0 → -80.0dB；否则 `linear_to_db(percent / 100.0)`。超界输入（<0 或 >100）钳制到 [0,100]（QL-STORY-READY 裁决采纳）。
- 未保存回滚逻辑——面板关闭未应用时总线音量恢复到已保存值（与 Story 003 共用脏检测/回滚机制）。

- **生效/持久化时机**（GDD 边界澄清 2026-09-07）：拖动 `value_changed` 信号 → 实时 `set_bus_volume_db()`（即时可听）；「应用」按钮 → 写设置文件；未保存关闭 → 回滚。
- 设置文件读写：持久设置直写（ADR-0031 §2.1），文件格式与全局「恢复默认」接口由 Story 003 统一定义——本 story 提供音量分类的读/写/重置接口实现。
- 面板框架（4 分类标签页结构）在本 story 搭建，画面/按键/语言分类内容由 003/004/005 填充。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 主菜单场景与入口按钮
- Story 003: 画面分类内容、应用/回退机制、全局恢复默认按钮
- Story 004: 按键绑定分类
- Story 005: 语言分类
- audio-manager epic: 音频总线布局定义、BGM/SFX 播放逻辑

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 音量转换公式
  - Given: percent
  - When: 调用 `db_from_percent(percent)`
  - Then: 0 → -80.0；负值 → -80.0；100 → 0.0（is_equal_approx）；50 → ≈-6.02dB；1 → 非 -80 的有限负值；超界（101/-1）钳制后按边界值处理
  - Edge cases: 0、1、50、100、-1、101、浮点步进值

- **AC-2**: 未保存回滚
  - Given: 已保存音量为 80%，当前拖动到 30%
  - When: 未点应用直接关闭面板
  - Then: 总线音量回滚到 db_from_percent(80)，设置文件未被修改
  - Edge cases: 拖动后点应用（保留）；拖动→关闭→重开（显示已保存值非拖动值）

**[Integration — automated test specs]:**

- **AC-3**: 滑条→总线端到端
  - Given: 三条总线存在
  - When: 音乐滑条设为 50%
  - Then: `AudioServer.get_bus_volume_db(Music)` == db_from_percent(50)（容差 ±0.01dB）
  - Edge cases: 总音量 0% → Master 总线 -80dB

**[UI — manual verification steps]:**

- **AC-4**: 设置面板交互
  - Setup: 主菜单点击设置
  - Verify: 0.3s 滑入；4 分类可见；拖动总音量滑条时 BGM 即时可听变化；关闭 0.2s 滑出
  - Pass condition: 实时生效可感知、动画流畅、分类标签正确

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/main_menu/test_db_from_percent.gd` + `tests/unit/main_menu/test_settings_rollback.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/main_menu/test_volume_bus_apply.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/settings-audio-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（设置入口）
- Unlocks: Story 003/004/005（面板框架与分类容器）
