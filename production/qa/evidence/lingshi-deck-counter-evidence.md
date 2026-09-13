# HUD Story 003 灵石+卡组计数——视觉手动验证证据

> **故事**：production/epics/hud/story-003-lingshi-deck-counter.md（AC-4 / AC-5）
> **技术债**：TD-013（QL 关卡 GAP-2——手动验证路径补齐；与 TD-006 共用 debug 宿主）
> **验证日期**：2026-09-12
> **验证方式**：编辑器 F6 运行 `tests/manual/hud_debug.tscn` debug 宿主（挂载 HUD.tscn，Autoload 真实生效），数字键 6-9/0 驱动状态
> **判定**：通过

## 验证环境

- Godot 4.6.3.stable，Forward+ 渲染器，编辑器 F6 运行 hud_debug.tscn
- HUD.tscn 经 debug 宿主实例化；GameStateManager / DeckEditingSystem Autoload 真实生效
- 灵石驱动走 GSM `_set_resource_ling_shi` 原子写入；卡组走 GSM `_set_deck_cards` 直写（刻意绕过 `add_cards_to_deck` 的 can_add_to_deck 守卫——超限档位须直写才可达，专测 UI 三态渲染）；上限经 `get_deck_limit()` 动态取（炼气期 20）

## AC-4：灵石变更动画

| # | 键 | 验证项 | 预期 | 结果 |
|---|---|--------|------|------|
| 1 | 6 | 灵石 +100 滚动 | 0.3s 数字滚动（SINE/EASE_OUT 插值） | [x] 通过 |
| 2 | 6 | 正值 delta 浮动 | (+100) 标签向下浮 18px + 0.8s 淡出，墨色 | [x] 通过 |
| 3 | 7 | 灵石 -50 浮动 | (-50) 标签向下浮 + 淡出，**朱砂红 #B3424A**（2026-09-12 TD-013 验证裁决：仅 ± 前缀辨识度不足，负值复用警报色） | [x] 通过 |
| 4 | 6→7 连按 | 连续变更 | 上一浮动/滚动中断后从当前位置重启，无漂移累积（B-3） | [x] 通过 |

## AC-5：卡组三态计数

| # | 键 | 验证项 | 预期 | 结果 |
|---|---|--------|------|------|
| 5 | 9 | 达上限 | 计数变黄 #C8A84E（count == cap） | [x] 通过 |
| 6 | 8 | 超限 | 计数变红 #B3424A + 0.8s 循环闪烁 + 「超限！」标记显示 | [x] 通过 |
| 7 | 0 | 恢复 normal | 重置后计数回墨色 #1A1A1A，闪烁停止，「超限！」隐藏 | [x] 通过 |
| 8 | 8→9 | 超限回落 | 超限→达上限翻转时闪烁 Tween 正确停启（H-1 无误重建） | [x] 通过 |

## 附注

- 🪙/📜 emoji 占位图标依赖系统字体回退——已登记 TD-011，图标图集 story 替换
- 三类动画无 reduce-motion 读取——已登记 TD-008 追加（animate 开关已就绪待接线）
- 负值红色已补回归测试 `test_ac004_negative_delta_shows_red_color`（提交 6b20687）

## 签收

| 角色 | 签收 | 日期 |
|------|------|------|
| 独立开发者（全部角色，含 lead-programmer） | [x] Approved | 2026-09-12 |
