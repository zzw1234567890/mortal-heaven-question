# 一场完整战斗 —— 端到端验收记录

| 字段 | 值 |
|------|-----|
| **日期** | 2026-11-10 |
| **基线提交** | `e415828` feat: 敌方行动逐条播报 + 玩家防御字段建模 |
| **验收人** | 主会话（自动化集成测试驱动） |
| **判定** | **PASS**（链路已跑通；遗留问题见 §5） |
| **有效范围** | 本记录锁定 2026-11-10 的代码状态；战斗 / 交互层若继续改动需复跑 §2 的用例 |

---

## 1. 验收目标与判定方式

要求是「从进入战斗场景开始，用真实出牌路径连续打若干回合，直到一方全灭」。
因此验收不看单点函数，而是看**真实场景 + 真实系统 + 真实输入事件**的接缝：

- 起点：`res://src/feature/combat/combat_scene.tscn` 实例化进树；
- 开战：备战面板 `toggle_selection` → `confirm_button.pressed`（不直接调 `battle_start`）；
- 出牌：`CombatInputLayer._handle_button` 收 `InputEventMouseButton`，命中手牌与敌方角色卡的**真实屏幕坐标**；
- 结束回合：底部条「结束出牌」按钮 `pressed`（生产节点）；
- 敌方：真实 `AISystem.execute_turn` 决策 → `combat_enemy_turn.gd` 落库 → `enemy_action_resolved` 广播；
- 判定：Phase 6 END → `battle_ended` → `SceneManager.request_scene_change` → 结算/战败场景读 `CombatResultView`。

用例：`tests/integration/combat_ui/test_full_battle_end_to_end.gd`
夹具：`full_battle_fixture.gd` / `full_battle_click_driver.gd` / `full_battle_seed.gd`

## 2. 覆盖到的链路

| # | 链路 | 断言落点 |
|---|------|----------|
| 1 | 场景装配 | `CombatRoot` 五区域 + 备战面板读到角色名册 |
| 2 | 备战确认 | 点选 → 确认按钮 → `battle_start`；`is_battle_active == true` |
| 3 | 布阵 / 牌堆 / 敌方 | 阵位 2 人、开局手牌 4 张、敌方 HP 来自模板（16 / 30） |
| 4 | 点击出牌 | 点卡选中 → 点敌方卡出牌：手牌 −1、弃牌堆 +1、敌方掉血 |
| 5 | 结束回合按钮 | `pressed` 使阶段 2 → 3（此前按钮无处理者） |
| 6 | 敌方行动 | 每次行动 `known=true`、伤害 = ATK − DEF、目标为我方角色 |
| 7 | 回合循环 | 跨多回合（胜利 4 回合 / 战败 3 回合），费用与手牌按回合重置 |
| 8 | 敌方全灭 → 胜利 | `battle_ended(result=1)`；战绩 `enemy.remaining_hp == 0` |
| 9 | 我方全灭 → 战败 | `battle_ended(result=2)`；战绩 `player.remaining_hp == 0` |
| 10 | 结算转场 | 胜利 → `SceneID.RESULT_SCREEN(8)`；战败 → `DEFEAT_SCREEN(9)` |
| 11 | 结算场景消费 | 标题「战斗胜利 / 战斗失败」、摘要含回合数与双方剩余 HP |
| 12 | 长局可持续 | 打出基础攻击数 > 初始张数 6（依赖弃牌堆回收） |

## 3. 发现并修复的断链

按「玩家能不能打完这一场」的阻断程度排序。

### F-1 敌方阵容无来源（阻断：没有敌人）

`combat_scene._start_battle` 只传 `character_ids`，`enemy_roster` 靠 `AISystem` 里可能为空的
残留名册。真实对局里不存在「谁在打你」的数据来源。

- **修复**：新增 `assets/enemies/enemy_encounter.gd`（`EnemyEncounter` Resource，只存模板 ID
  列表）+ `src/feature/combat/combat_scene_battle_setup.gd`（开战前置：布阵 / 牌堆 / 敌方阵容）。
  场景开战前读遭遇战资源 → `AISystem.create_enemy_roster` → 写回 AISystem（AI 决策读的就是它）。
- **优先级**：注入覆盖 > 遭遇战资源 > AISystem 现有名册。

### F-2 牌堆从未初始化（阻断：一张牌都发不出来）

`battle_start` 的开局手牌从牌堆发，而 `CombatScene` 从未调用 `init_deck`——玩家开局空手。

- **修复**：开战前置从 `DeckEditingSystem.get_deck_cards()` 取本局卡组实例 ID，在
  `battle_start` **之前** `init_deck`（顺序不可换：开战内发牌）。

### F-3 打出的牌不进弃牌堆（阻断：长局卡死）

`play_card` 只把卡从手牌删除。弃牌堆永远为空 → 牌堆抽空后 GDD 的「抽空返还」无牌可返 →
第 N 回合起永久无牌可出。

- **修复**：`combat_card_resolver._remove_card_from_hand` 改走既有 `discard_card`
  （手牌移除 + 弃牌堆追加的唯一实现）。回归用例：
  `tests/unit/combat_system/test_deck_management.gd::test_played_card_moves_to_discard`。

### F-4 0 费卡出牌后手牌区不刷新（阻断：重复提交同一张卡）

手牌区只在 `phase_changed` / `cost_changed` 刷新；0 费卡出牌不改费用 → 手牌区继续显示
已打出的卡，再点它会再次提交同一张卡。

- **修复**：`CombatInputLayer` 新增 `play_committed` 信号（出牌成功即发）；
  `combat_scene_interaction.gd` 订阅后刷新手牌供给并同步选中态。

### F-5 「结束出牌」按钮无处理者（阻断：无法结束回合）

按钮只有渲染（layout story 005 把点击流转划给 interaction epic 但未落地），真实对局里点了没反应。

- **修复**：`combat_scene_interaction.gd` 把按钮 `pressed` 接到 `CombatSystem.confirm_end_turn`；
  阶段与活跃判定全部现读（按钮只在阶段 2 生效），退场时断开连接。

### F-6 真实卡牌的费用恒为 0（阻断：费用系统失效）

`_get_card_instance` 在生产路径返回 `CardTemplate`（Resource），而 `_get_card_cost` 只认
Dictionary 与 `get_cost()`——模板卡落「未知格式，按 0 处理」：所有卡免费、每张卡刷一条 warning。

- **修复**：`_get_card_cost` 支持 `Object.get("cost")`（`CardTemplate.cost` 是 @export 属性）。
  回归用例：`tests/unit/combat_system/test_card_cost_resolution.gd`（3 例，含三种卡形态）。

### F-7 结算转场不可测（非阻断，测试接缝缺失）

`battle_end` 的转场走 `/root/SceneManager` Autoload，测试无法断言「胜利 → RESULT / 失败 → DEFEAT」。

- **修复**：`CombatSystem.set_scene_manager(node)` 注入点（null = 恢复 Autoload 查找）。
  生产路径行为不变。

## 4. 补齐的最小可用数据（取值来源）

| 资源 | 内容 | 取值来源 |
|------|------|----------|
| `assets/enemies/san_xiu.tres` | 散修：HP 16 / ATK 2 / DEF 0，技能「基础攻击」weight 50 | GDD `ai-system.md` §2「普通敌人「散修」技能池」① 基础攻击；HP/ATK 取炼气期普通敌人基线（玩家初始角色 7~10 HP / 2~4 ATK 的对位） |
| `assets/enemies/mo_xiu.tres` | 魔修：HP 30 / ATK 9 / DEF 0，技能「魔气斩」 | 同上（精英档位的对手，用于验证战败方向；HP 30 保证不会被我方一击打空） |
| `assets/enemies/encounters/default_encounter.tres` | 默认遭遇战：`[san_xiu]` | 单敌人前排（GDD §3「敌方仅 1~2 人 → 全部分配前排」） |

**说明**：GDD 只给了技能池形状与示例，没有逐敌人的 HP/ATK 数值表。以上数值按
「炼气期普通敌人 vs 初始角色」的最小可玩对位取值，**属占位配置**，正式数值应以
`design/gdd/ai-system.md` 补表或策划调优为准（见 §5 遗留 ①）。

## 5. 遗留问题（未修，不阻断本次验收）

1. **敌方数值是占位数**：GDD 无逐敌人 HP/ATK 表，`san_xiu` / `mo_xiu` 是本次为跑通链路取的
   最小可用值，需策划确认或补 GDD 数值表。
2. **敌方技能效果只有「平A」**：`skill_pool` 只挂一条 0 费攻击技。治疗 / 防御 / 阵法等技能类型
   仍无执行端（同一遗留：`combat_enemy_turn._damage_of` 只做 `max(0, ATK − DEF)`）。
3. **探索系统未把阵容带进战斗**：`ExplorationSystem.combat_node_reached` 有载荷，但
   `NodeInteractionPopupHost` 只请求转场、不传 `enemy_roster`。本次用「默认遭遇战资源」兜底；
   探索 → 战斗的阵容传递仍需 interaction story 006 落地。
4. **`enemy_broadcast` 的锁告警**：播报组件在 `battle_ended` 里 `pop_lock`，而
   `CharacterCard` / 场景出树触发的 `tree_changed` 已把整个锁栈清空 → 一条
   `pop_lock ... source not found` 警告。功能无影响（锁确实已释放），属日志噪音，
   建议后续让 `_release_lock` 先查 `has_lock` 再弹。
5. **战败后 `character_hp` 持久化为 0**：阵亡角色下一场按 0 HP 开局（既有行为，
   `test_battle_result_end_to_end.gd` 已锁定该口径）。是否需要「复活 / 恢复」由后续 epic 决定。
6. **测试夹具的两个前置依赖**：`full_battle_seed.gd` 在 GSM 校验模板库被其它用例换过时，
   直接落收藏（绕过 `add_card_to_collection`）。这是测试隔离手段，不影响生产路径；
   若将来 GSM 校验改为可重入，可删掉该回退分支。

## 6. 回归结果

```
Godot 4.6.3 headless + GUT 9.6.1，全量：
Scripts 264 / Tests 3931 / Passing 3930 / Failing 0
Pending 1（save_load 多步迁移占位，存量）
Orphans 3（存量）
```

本次新增用例 7 条（3924 → 3931）：`test_full_battle_end_to_end.gd`（3）+
`test_card_cost_resolution.gd`（3）+ `test_deck_management.gd::test_played_card_moves_to_discard`（1）。
既有断言强度未降低：修改的既有用例只有
`tests/unit/ai_system/test_enemy_template_factory.gd::test_load_templates_empty_dir`
——真实目录已落地模板后，改为注入空目录，断言语义（空目录 → 0 个模板）不变。
