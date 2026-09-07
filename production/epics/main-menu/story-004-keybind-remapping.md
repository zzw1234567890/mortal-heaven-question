# Story 004: 按键绑定界面（含启动加载）

> **Epic**: 主菜单与设置
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/main-menu-system.md`
**Requirement**: AC-main-menu-015~018 + 键位持久化加载（GDD 边界澄清 2026-09-07）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§2.1 持久设置）
**ADR Decision Summary**: 按键绑定属持久设置——重绑定经 `InputMap.action_set_event` 应用、写设置文件；启动时从设置文件加载应用 InputMap（否则重启失效，QL-STORY-READY 补充）。ESC 在等待输入状态 = 取消等待（不作为可绑定键）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 等待输入用 `_unhandled_input`/`_gui_input` 捕获；重绑定的动作列表含鼠标类动作（确认=Enter/左键、取消=右键/Back、布阵移动=鼠标拖拽）——鼠标动作的重绑定语义（QL-STORY-READY 遗留）按「同类输入可互换」（键盘↔键盘、鼠标↔鼠标）实现并注释。

**Control Manifest Rules (this layer)**:
- Required: 冲突检测纯函数单测；绑定往返（保存→重置→加载）集成测试
- Forbidden: 硬编码动作列表（从 InputMap 枚举或配置生成）；设置经 GSM
- Guardrail: 等待输入状态不阻塞主线程（无忙等循环）

---

## Acceptance Criteria

*From GDD `design/gdd/main-menu-system.md`，scoped to this story:*

- [ ] 点击按键格进入等待输入状态（闪烁「等待输入...」）（AC-main-menu-015）
- [ ] 等待输入时按新键完成绑定+弹出确认（AC-main-menu-016）；按 ESC 取消等待返回列表（GDD 边界澄清 2026-09-07）
- [ ] 新键已被其他功能绑定时提示「该键已绑定 [功能名]，是否覆盖？」覆盖/取消两分支（AC-main-menu-017）
- [ ] 恢复默认按键（AC-main-menu-018；全局按钮经 Story 003 调用本 story 的分类重置接口）
- [ ] 自定义按键写入设置文件后，**游戏启动时从设置文件加载并应用 InputMap**（重启不失效）
- [ ] 按键绑定成功 0.15s 弹出新键名；冲突时低沉警告音（音频事件触发）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `find_conflicts(new_event, bindings) -> Array[String]`——新输入事件 vs 现有绑定映射，返回占用该事件的全部 action 列表；无占用返回空。相同 action 内的重复（自己绑自己）不算冲突。
- 绑定应用往返：`apply_bindings(map)` → 写设置文件；启动加载 `load_bindings()` → `InputMap.action_set_event`——往返等价性用集成测试锁定。

- 等待输入状态机：点击按键格 → 监听输入（ESC=取消）→ 键盘/鼠标同类互换判定 → 冲突检测（纯函数）→ 无冲突直接绑定 / 有冲突弹「覆盖/取消」→ 应用+持久化。
- 动作列表从 InputMap 枚举或数据驱动配置生成（GDD 按键绑定表为初始默认）。
- 启动加载：主菜单场景 `_ready` 时调用 `load_bindings()`（在首个游戏场景前生效）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002/003: 设置面板框架、全局恢复默认按钮（本 story 提供按键分类重置接口）
- audio-manager epic: 冲突警告音本体（本 story 仅触发音频事件）
- 游戏内（战斗/探索中）的实时按键重映射提示：非 MVP

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 冲突检测
  - Given: 现有绑定映射 {action: event} + 新输入事件 E
  - When: 调用 `find_conflicts(E, bindings)`
  - Then: 返回占用 E 的全部 action；无占用返回空数组
  - Edge cases: E 与多 action 同绑（GDD 确认=Enter/左键本就多绑定）、相同 action 自己绑自己（不算冲突）、键盘↔鼠标混绑（按同类互换规则判定）、E 为 ESC（等待输入层已拦截，纯函数层防御性处理）

**[Integration — automated test specs]:**

- **AC-2**: 绑定应用与持久化往返（BLOCKING）
  - Given: 绑定 F1→出牌1 并应用
  - When: 保存 → 重置 InputMap 为默认 → 从设置文件加载
  - Then: 该 action 的事件 == F1
  - Edge cases: 多键多 action 同时保存加载；恢复默认后 InputMap == 初始定义

**[UI — manual verification steps]:**

- **AC-3**: 重绑定交互流
  - Setup: 设置→按键绑定→点击「出牌-卡牌1」按键格
  - Verify: 「等待输入...」闪烁 → 按 Q → 0.15s 弹出 Q；再对「出牌-卡牌2」按 Q → 弹「该键已绑定 出牌-卡牌1，是否覆盖？」
  - Pass condition: 覆盖/取消两分支行为正确；ESC 在等待中取消返回列表；重启游戏后自定义键仍生效

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/main_menu/test_keybind_conflict.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/main_menu/test_keybind_roundtrip.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/keybind-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（设置面板框架）
- Unlocks: None
