# Story 002: 设置面板框架与音量控制

> **Epic**: 主菜单与设置
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: 1.0d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-10-05

## Context

**GDD**: `design/gdd/main-menu-system.md`
**Requirement**: AC-main-menu-007 / AC-main-menu-008
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§2.1 持久设置）
**ADR Decision Summary**: 设置值属「持久设置」——设置面板直接写设置文件，不经 GSM 不经 SaveLoadSystem。音量实时生效+手动持久化（QL-STORY-READY 2026-09-07 裁决：滑条拖动即时生效到总线，点「应用」才写文件，未保存关闭回滚）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 滑条为标准 HSlider 控件；音频总线应用经 `AudioServer.set_bus_volume_db()`。**硬依赖：audio 001（S14-7）先行**——总线命名与 audio-manager epic 001 总线表对齐（QL-STORY-READY 2026-09-19 裁决）：三条滑条 → **Master/BGM/SFX** 一一对应（非 Music——audio 001 定义 6 总线无 Music）。

**Control Manifest Rules (this layer)**:
- Required: `db_from_percent()` 纯函数单测；回滚逻辑可测
- Forbidden: 设置值经 GSM 存档链；硬编码音量映射
- Guardrail: 滑条 1% 步进；拖动中无逐帧文件写入

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu-system.md`，scoped to this story:*

- [x] 点击设置打开设置界面，含音效/画面/按键/语言 4 个分类（AC-main-menu-007）
- [x] 拖动音量滑条时对应总线音量**实时**变化（经 `db_from_percent` 转换）（AC-main-menu-008）
- [x] 三条音量滑条：总音量(Master)/音乐音量(BGM)/音效音量(SFX)（0~100%，1% 步进；键盘 ← → 可调节——UX 10a 交互声明）
- [x] 点击「应用」时音量值持久化写入设置文件；未保存关闭时回滚到已保存值
- [x] 启动音量真值 = 设置文件值覆盖总线默认 dB（QL-STORY-READY 2026-09-19 裁决：设置文件胜出——设置文件默认 100%=0dB 覆盖 bus_layout 默认 SFX -3dB；启动加载行为归 audio 005「音量控制行为」story，本 story 提供音量分类读/写/重置接口供其调用）
- [x] 设置面板打开 0.3s 滑入 / 关闭 0.2s 滑出（UX 已同步 0.3s）

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
  - Given: Master/BGM/SFX 总线存在（audio 001 交付）
  - When: 以 [BGM, SFX, Master] × [0%, 50%, 100%] 参数化轮换设置对应滑条（QL-STORY-READY 2026-10-04 修订：三滑条三总线全覆盖——SFX 漏测会成为永久盲区）
  - Then: `AudioServer.get_bus_volume_db(总线)` == db_from_percent(输入)（容差 ±0.01dB）
  - Edge cases: 总音量 0% → Master 总线 -80dB；100% → 0.0dB（is_equal_approx）

**[UI — manual verification steps]:**

- **AC-4**: 设置面板交互
  - Setup: 主菜单点击设置
  - Verify: 0.3s 滑入；4 分类可见；拖动总音量滑条时 BGM 即时可听变化；键盘 ← → 调节滑条同样实时生效；关闭 0.2s 滑出
  - Pass condition: 实时生效可感知（鼠标+键盘两路径）、动画流畅、分类标签正确
  - 可听验证降级路径（QL-STORY-READY 2026-10-04 修订）：若 audio 002（BGM 播放）未交付，「可听变化」可代之以 `AudioServer.get_bus_volume_db()` 表读数实时变化验证，可听确认推迟至 BGM 可播时补做（在证据文件中注明）

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/main_menu/test_db_from_percent.gd` + `tests/unit/main_menu/test_settings_rollback.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/main_menu/test_volume_bus_apply.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/settings-audio-evidence.md` + sign-off

**Status**: [x] Created — `production/qa/evidence/settings-audio-evidence.md`（2026-10-05 签收）

---

## Dependencies

- Depends on: Story 001（设置入口）；audio-manager 001（S14-7——总线布局先行，QL-STORY-READY 2026-09-19 裁决加 blocker）
- Unlocks: Story 003/004/005（面板框架与分类容器）；audio 005（音量控制行为——消费本 story 音量分类接口）

---

## Completion Notes

**Completed**: 2026-10-05
**Criteria**: 6/6 通过（AC-1/AC-6 UI 手动验证已签收；可听验证按降级路径以总线 dB 表读数代证）
**Deviations**:
- 未保存关闭无确认弹窗（story AC 直接回滚语义——确认弹窗归 Story 003 统一脏检测机制）
- 可听验证降级：audio-manager 002（BGM 播放）未交付，「可听变化」以 `AudioServer.get_bus_volume_db()` 表读数代证（自动化已钉死），可听确认推迟至 BGM 可播时补做
**Test Evidence**:
- 单元 51/51：test_db_from_percent（9）+ test_settings_rollback（6）+ test_settings_store（10）+ test_settings_panel_close_paths（6）
- 集成 25/25：test_volume_bus_apply（5，含 use_parameters 9 组参数化三滑条×三档）
- UI 手动证据：`production/qa/evidence/settings-audio-evidence.md`（2026-10-05 签收）
**Code Review**: APPROVED WITH SUGGESTIONS（QL-TEST-COVERAGE ADEQUATE + LP-CODE-REVIEW APPROVED WITH SUGGESTIONS）
**记账项（不阻塞，归后续 story）**:
- InputManager `tree_changed` 清栈（H-1）——归 InputManager 属主修正
- main_menu.gd 308 行超限——归 Story 003 前置拆分
- 模态关闭一致性（关闭后焦点恢复 + 锁释放时序）——与 PauseMenu 打包修复
- 滑出终点在屏内（M-2）/ 设置文件原子性（S-4）——归视觉打磨 story
