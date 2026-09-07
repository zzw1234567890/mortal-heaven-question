# Story 005: 语言切换与本地化即时生效

> **Epic**: 主菜单与设置
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI + Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/main-menu-system.md`
**Requirement**: AC-main-menu-019
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§2.1 持久设置）
**ADR Decision Summary**: 语言属持久设置。QL-STORY-READY 2026-09-07 裁决：刷新机制采用 **locale 变更信号 + 已显示控件重取翻译**（非场景重载）——Godot 切换 locale 不会自动刷新已显示文本，须显式刷新。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: `TranslationServer.set_locale()` + 自定义 locale 变更信号；翻译资源管线（.csv/.po → .translation → 注册）须先建立。缺失翻译键时按 Godot 回退序（locale→默认语言）显示。

**Control Manifest Rules (this layer)**:
- Required: 探针控件文本断言（≥3 处）锁定「即时生效」可测试性
- Forbidden: 场景重载实现刷新；硬编码双语文本（全部走翻译键）
- Guardrail: 切换刷新在 1 帧内完成（无逐控件逐帧延迟刷新）

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu-system.md`，scoped to this story:*

- [ ] 设置中切换语言（中文/英文）点应用后界面文字即时更新为新语言，无需重启（AC-main-menu-019）
- [ ] locale 变更信号 + 控件重取翻译机制（非场景重载）
- [ ] 刷新覆盖主菜单、设置面板、制作人员界面的全部显示文本
- [ ] 语言选择持久化到设置文件；缺失翻译键回退到默认语言显示
- [ ] 全局「恢复默认」经 Story 003 调用时语言重置为简体中文

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- 翻译资源管线：主菜单/设置相关字符串提取为翻译键，建立 zh/en 两语言资源（.csv → .translation 导入并注册）——**本 story 内完成主菜单作用域的字符串**，游戏内其他界面字符串由各 epic 自行提取（本 story 建立管线与规范）。
- 刷新机制：`locale_changed` 自定义信号 → 各显示文本控件监听并重取 `tr(key)`。注册机制建议统一 helper（如 `register_localized_label(label, key)`），避免逐控件手写。
- 切换流程：下拉选择 → 点「应用」→ `TranslationServer.set_locale()` + 发信号 + 写设置文件。语言变更受「应用」门控（与画面一致，非实时——音量是唯一实时例外）。
- 缺失键回退：Godot 翻译回退序（locale → 默认语言），测试中用故意缺失键验证。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002/003: 面板框架与应用门控机制（本 story 消费）
- 游戏内界面（HUD/战斗/探索）的字符串本地化：各 epic 自行提取（消费本 story 建立的管线）
- 字体本地化（中英文字体选择）：归 art/字体资产任务，非本 story

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: locale 切换即时生效（BLOCKING）
  - Given: 语言为 zh，界面已显示中文
  - When: 切换 en 并应用
  - Then: `TranslationServer.get_locale()` 前缀 == "en"；探针控件文本（主菜单按钮/设置分类标签/制作人员标题各 1 处）全部变为英文
  - Edge cases: 切回 zh 往返一致；刷新在 1 帧内完成（无中间状态可见）

- **AC-2**: 缺失翻译键回退
  - Given: 故意缺失某 en 翻译键
  - When: 切换 en
  - Then: 该键显示默认语言（zh）文本，无空白/键名裸露
  - Edge cases: 全部键齐全（正常切换）

**[UI — manual verification steps]:**

- **AC-3**: 语言切换全界面核对
  - Setup: 主菜单/设置/制作人员三个界面分别在 zh 下截图
  - Verify: 切换 en 后三界面所有文本（5 按钮、4 分类、按键表、制作人员列表）逐屏核对更新
  - Pass condition: 无残留中文、无空白、无需重启；重启后语言保持 en

---

## Test Evidence

**Story Type**: UI + Integration
**Required evidence**:
- Integration: `tests/integration/main_menu/test_locale_switch.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/locale-switch-evidence.md` + sign-off（探针字符串清单附于证据文档）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（设置面板框架与应用门控）
- Unlocks: 各 epic 的界面字符串本地化（消费翻译管线）
