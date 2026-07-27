# 垂直切片：仙途问道 —— 战斗原型

> **状态**：进行中（第 1 天）
> **假设**：玩家能在 3 分钟内无需引导完成一场卡牌战斗——打出卡牌、看到效果结算、击败/被击败
> **创建**：2026-07-27

## 如何运行

1. 在 Godot 4.6 中打开项目
2. 将 `prototypes/cultivation-card-battle-vertical-slice/scenes/main_menu.tscn` 设为主场景（项目设置 → 运行 → 主场景）
3. 按 F5 运行
4. 点击「新游戏」进入战斗

## 测试的假设

- 卡牌点击→效果结算→敌方响应 的完整回合循环在架构上是可行的
- 玩家无需指导即可理解：点击卡牌 = 打出
- 5 张卡牌 + 按类型着色 + 费用灰度足以传达核心决策

## 文件清单

| 文件 | 行数 | 用途 |
|------|:--:|------|
| `scripts/player_state.gd` | 92 | 玩家 HP/灵力/护盾/回合状态 |
| `scripts/enemy_ai.gd` | 53 | 敌方属性 + 行为序列 |
| `scripts/card_data.gd` | 42 | 5 张卡牌定义 + 起始卡组 |
| `scripts/battle_controller.gd` | 183 | 战斗编排——状态机 + 抽牌 + 结算 |
| `scripts/battle_hud.gd` | 270 | 全 UI 布局——程序化创建 |
| `scripts/card_widget.gd` | 99 | 手牌控件——点击打出 |
| `scripts/main_menu.gd` | 17 | 主菜单逻辑 |
| `scenes/main_menu.tscn` | — | 主菜单场景 |
| `scenes/battle.tscn` | — | 战斗场景 |
| **总计** | **757 行** | 9 文件 |

## 当前状态

**已完成**——2026-07-27 完整流程验证通过：
- 主菜单 → 角色选择 → 战斗(双方6阵位上下分栏 + 5卡牌 + 回合循环) → 胜利奖励 → 返回
- Godot 4.6.3 无报错运行，所有布局面板居中

## 发现

1. **核心循环可行**：卡牌点击→效果结算→敌方响应的回合制架构在 Godot 4.6 中顺畅运行
2. **阵位系统**：双方 6 阵位（前3后3）、伤害优先前排的设计合理——治疗/护盾卡需点击目标增加了策略深度
3. **UI 居中**：PanelContainer + anchors 在父节点为普通 Node 时不可靠，需手动 `get_viewport().get_visible_rect().size` 计算居中位置
4. **GDScript 类型推断**：Dictionary 索引访问返回 Variant，不能用 `:=` 推断，必须显式 `: Dictionary`
5. **MOUSE_FILTER**：卡牌子节点默认 STOP 导致点击渗透失败，需全体设 IGNORE
6. **战斗平衡**：3回合内可结束战斗（60HP 敌人 vs 3-6角色 × 10-18ATK），节奏良好
