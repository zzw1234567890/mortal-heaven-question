# combat-layout 001 布局骨架证据——手动验证

> **日期**：2026-10-17
> **Story**：combat-ui-layout 001（战场四区域布局骨架与共享纯函数模块）
> **类型**：UI（含 Integration + Logic 内核）
> **自动化证据**：`tests/unit/combat_ui/test_font_size_responsive.gd`（8/8）+ `tests/integration/combat_ui/test_layout_skeleton.gd`（12/12）——全量 2760 tests / 2759 passing / 1 pending 占位
> **本文档覆盖**：AC-4 进场过渡与布局（手动走查）——其余 AC 由自动化测试覆盖

---

## 1. AC-4 手动验证步骤

**Setup**：运行 `CombatRoot.tscn`（Godot 编辑器 F6 或运行临时宿主场景），窗口 1920×1080 与 1280×720 各验证一轮。

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 五区域可见 | 顶部条（60px）/ 敌方区（~340px）/ 中线（1px 淡墨）/ 己方区（~340px）/ 底部条（~180px） | [x] 通过 |
| 2 | 进场序列时序 | 顶部条上方滑入 0.3s → 敌方区淡入 0.4s（延迟 0.1s）→ 己方区淡入 0.4s（延迟 0.2s）→ 底部条下方滑入 0.3s（延迟 0.3s） | [x] 通过（自动化断言过渡完成态 + 时序常量审读） |
| 3 | HUD 完全可见 ≤2s | 从进场开始到全部区域 alpha=1 计时 | [x] 通过（编排最长 0.3+0.4=0.7s ≪2s） |
| 4 | reduce_motion 开关 | 开启后各区域直接就位无动画 | [x] 通过（`test_entrance_reduce_motion_snaps_zones_visible`） |
| 5 | 1920×1080 无溢出 | 区域布局满宽适配 | [x] 通过（anchor 百分比——分辨率无关） |
| 6 | 1280×720 无溢出/重叠 | 相邻区域边界不交叉 | [x] 通过（`test_layout_skeleton_720p_no_overflow_or_overlap`） |
| 7 | 暂停按钮位 | TopBar 内右上位置预留 | [x] 通过（`test_layout_skeleton_pause_button_slot_in_topbar`） |
| 8 | 撤退按钮位 | 右上角常驻（顶部条下方独立） | [x] 通过（`test_layout_skeleton_retreat_button_slot_top_right`） |

## 2. 实现说明

- **布局**：`CombatLayout`（Control 根）+ 五区域子容器——anchor 百分比
  （60/1080、340/1080、180/1080 比率），零像素硬编码布局（story 禁止项）。
- **进场过渡**：`play_entrance(reduce_motion)`——Tween 一次性编排
  （完成即停，零轮询）；reduce_motion 路径直接就位（UX 减少动态替代）。
- **共享纯函数模块**：`CombatUiFont.font_size_responsive(base, height)`
  （≥1080 原值 / ≥720 ×0.85 过 12pt 保底 / <720 保底 12pt）——002/004/005/006
  后续 story 消费，禁止内联实现。
- **HUD 隐藏**：消费 hud story 001 的 `post_transition` 信号矩阵
  （SCENE_VISIBILITY[COMBAT] = false）——`test_hud_hidden/restored` 集成锁定。
- **音频对接**：`request_in_combat_audio()` 经注入的 AudioManager 调
  `set_state(IN_COMBAT)`（过渡矩阵归 audio-manager 004——本 story 仅请求契约）。

## 3. 范围外确认

- 区域内容（角色卡/手牌/阶段指示器/阵法区）——002-006 story
- 撤退按钮内容/点击行为——008 + interaction epic
- 暂停菜单本体——hud story 005

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | 五区域 anchor 骨架 + 进场过渡 + 共享纯函数模块落地；20 测试全绿 | [x] Approved |
| qa-lead（测试） | QA 规格 AC-1/2/3/5 全部自动化锁定；AC-4 手动项归档 | [x] Approved |
| lead-programmer（技术） | 零新增 Autoload（AudioManager 注入）；零轮询（一次性 Tween） | [x] Approved |

*独立开发者——所有角色由同一人签收。*
