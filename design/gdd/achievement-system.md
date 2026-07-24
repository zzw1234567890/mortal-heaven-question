# 成就系统 (Achievement System)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-24
> **最后验证 (Last Verified)**：—
> **实现的支柱 (Implements Pillar)**：支柱1「自由组牌，策略为王」+ 支柱2「苟道成长，步步为营」+ 支柱3「机缘巧合，意外之喜」

> **快速参考** — 层级：`元 (Meta)` · 优先级：`Full Vision` · 关键依赖：`存档系统`、`游戏状态管理器`

## 概述

成就系统是游戏的跨局元进度追踪与奖励机制——它不直接影响单局游戏的战力，而是为玩家提供**长期目标、探索引导和精通证明**。系统监听游戏内 60+ 个可触发事件（首次达到某境界、首次击杀某 BOSS、收集里程碑、结局解锁等），在条件满足时解锁对应成就，并写入 `progression.dat` 的 `achievements` 域永久保存。

对玩家来说，成就系统是「我在这款游戏里做过什么」的完整记录。它不是强制任务清单——玩家可以完全忽略成就系统而正常游玩——但那些看到「已解锁 3/62」时会感到探索欲被点燃的成就者型玩家，会自然追着成就去尝试游戏的每一个角落。成就系统将游戏深度转化为可量化的收集目标。

成就设计遵循两个原则：(1) **成就引导发现，而非强制 grind**——任何需要纯粹重复劳动才能解锁的成就不超过 8 个；(2) **成就是探索的副产物，而非终点**——正常游玩即可自然解锁 70% 的成就，剩下的 30% 为深度玩家提供挑战。

## 玩家幻想

| 情感 | 触发场景 |
|------|---------|
| **发现的惊喜** | 完成一次普通战斗后突然弹出成就——「咦，这也算成就？」——原来「同时拥有5种异常状态」是个隐藏成就 |
| **精通的自豪** | 查看成就列表——「越阶渡劫」「全结局解锁」「全流派精通」三个金框并排——这是实力的勋章 |
| **收集的满足** | 成就进度条从 45/62 涨到 46/62——还差 16 个，看看缺哪些……「枯木逢春」还没做——下一局试试 |
| **挑战的刺激** | 看到「一回合击杀 BOSS」（隐藏成就，0.3% 解锁率）——「这个可能吗？让我想想怎么构筑……」 |
| **回忆的锚点** | 翻看已解锁成就的解锁日期——「2026-08-15 第一次通关」「2026-09-01 全卡牌收集」——每个成就都是一段游戏记忆 |
| **社交的谈资** | （未来如果有 Steam）成就展示在个人资料页——「全结局解锁」的稀有度框（金色边框）是硬核玩家的身份标识 |

成就系统是玩家与游戏之间**超越单局的情感契约**——即使这一局死了，成就还在。它是玩家在无数次轮回中积累的「我在这个世界中存在过的证明」。

## 详细设计

### 核心规则

#### 1. 成就数据结构

```
Achievement {
  id: String               # 唯一标识（如 "ach_first_realm_break"）
  name: String              # 显示名称（如 "踏入道途"）
  description: String       # 解锁条件描述（如 "首次突破到筑基期"）
  icon: String              # 图标资源路径
  category: Enum            # 分类：combat / progression / collection / exploration / narrative / challenge / mastery
  tier: Enum                # 稀有度：bronze / silver / gold（隐藏由 hidden_until_unlocked 独立控制）
  unlock_condition: {       # 解锁条件（由事件系统评估）
    event: String           # 触发事件名
    threshold: int          # 阈值（可选；如累计次数/数量达到此值）
    extra_checks: [String]  # 额外条件（可选；如 "no_damage_taken"）
  }
  points: int               # 成就点数（用于 Steam 集成或内部统计，无游戏内货币价值）
  hidden_until_unlocked: bool  # 隐藏成就（条件描述在解锁前显示为 "???"）
  unlocked_at: String|null  # ISO-8601 解锁时间戳（null=未解锁）
  progress: {               # 进度追踪（用于有数值目标的成就）
    current: int            # 当前进度
    target: int             # 目标值
  }|null                    # 无进度条的成就为 null
}
```

#### 2. 成就分类体系

共 **7 大类别**，覆盖游戏所有领域：

| 类别 | 数量 | 描述 | 典型触发源 |
|------|:---:|------|-----------|
| **战斗 (Combat)** | ~12 | 战斗技巧与击杀里程碑 | 战斗系统、AI系统 |
| **成长 (Progression)** | ~10 | 境界突破与属性里程碑 | 境界系统、修为养成系统、渡劫突破系统 |
| **收集 (Collection)** | ~10 | 卡牌、灵石、炼丹炼器收集 | 卡牌系统、资源系统、炼丹炼器系统 |
| **探索 (Exploration)** | ~8 | 地图与事件探索 | 探索系统、事件系统 |
| **叙事 (Narrative)** | ~8 | 剧情与结局 | 剧情系统、结局分支系统 |
| **精通 (Mastery)** | ~8 | 流派与身份精通 | 流派系统、身份选择系统 |
| **挑战 (Challenge)** | ~6 | 高难度限制条件 | 跨系统（战斗+构筑） |

#### 3. 成就详细列表

##### 3.1 战斗成就 (Combat) —— 12 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_first_elite_kill` | 初出茅庐 | 首次击杀精英敌人 | 铜 | — |
| `ach_elite_hunter` | 精英猎手 | 累计击杀 50 个精英敌人（跨局累计） | 银 | — |
| `ach_elite_slayer` | 精英屠夫 | 累计击杀 200 个精英敌人 | 金 | — |
| `ach_first_boss_kill` | 弑师 | 首次击杀章末 BOSS（任意章节） | 铜 | — |
| `ach_all_bosses` | 八荒荡魔 | 击杀全部 5 个章末 BOSS（跨局累计，不要求同一局） | 金 | — |
| `ach_no_damage_boss` | 枯木逢春 | 无伤击败任意章末 BOSS（全局 HP 净损失为 0——受伤但被治疗回满仍算无伤） | 金 | ✅ |
| `ach_one_turn_kill` | 一击灭敌 | 在 1 回合内击杀任意 BOSS | 金 | ✅ |
| `ach_status_stack_5` | 五毒俱全 | 单个敌人身上同时拥有 5+ 种不同异常状态 | 银 | ✅ |
| `ach_overkill_100` | 伤害溢出 | 单次攻击造成超过 100 点溢出伤害（敌方 HP < 实际伤害×0.3） | 银 | — |
| `ach_first_formation_trigger` | 阵法初成 | 首次触发阵法效果 | 铜 | — |
| `ach_formation_master` | 阵法大师 | 一局游戏中触发过全部已拥有阵法的效果 | 银 | — |
| `ach_deploy_6` | 六合归一 | 同时上场 6 个角色（需化神期） | 银 | — |

##### 3.2 成长成就 (Progression) —— 10 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_first_realm_break` | 踏入道途 | 首次突破到筑基期 | 铜 | — |
| `ach_realm_golden_core` | 金丹大成 | 首次突破到金丹期 | 银 | — |
| `ach_realm_nascent_soul` | 元婴出世 | 首次突破到元婴期 | 银 | — |
| `ach_realm_deity` | 半步飞升 | 首次突破到化神期 | 金 | — |
| `ach_first_tribulation` | 天劫降临 | 首次完成渡劫突破 | 铜 | — |
| `ach_transcend_tribulation` | 越阶渡劫 | 在修为未满 80% 时成功渡劫（境界压制下获胜） | 金 | ✅ |
| `ach_tribulation_no_hp_loss` | 天劫无伤 | 渡劫战中 HP 从未低于 50% | 银 | — |
| `ach_cultivation_overflow` | 修为如海 | 跨局累计修为溢出转化为属性丹 ≥10 次 | 银 | — |
| `ach_action_points_max` | 行遍天下 | 单局游戏中行动力上限达到最大值（化神期=13） | 铜 | — |
| `ach_reincarnation_10` | 轮回百转 | 累计轮回 10 次（即完成 10 局游戏） | 银 | — |

##### 3.3 收集成就 (Collection) —— 10 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_cards_50` | 初涉卡道 | 全局图鉴中收录 50 种不同卡牌 | 铜 | — |
| `ach_cards_100` | 百卡争鸣 | 全局图鉴中收录 100 种不同卡牌 | 银 | — |
| `ach_cards_200` | 万法归藏 | 全局图鉴中收录 200 种不同卡牌 | 金 | — |
| `ach_cards_all` | 仙途问道 | 全局图鉴中收录全部 222 张卡牌 | 金 | — |
| `ach_first_dark_gold` | 暗金初现 | 首次获得暗金品质卡牌 | 银 | — |
| `ach_dark_gold_5` | 五行暗金 | 全局图鉴中拥有 5 张不同暗金卡牌 | 金 | — |
| `ach_ling_shi_10000` | 富甲一方 | 单局游戏中灵石累计消费 ≥5000 | 银 | — |
| `ach_alchemy_50` | 丹道宗师 | 累计完成 50 次炼丹（跨局累计） | 银 | — |
| `ach_craft_50` | 炼器宗师 | 累计完成 50 次炼器（跨局累计） | 银 | — |
| `ach_inscription_20` | 铭文大师 | 累计完成 20 次法宝铭刻（跨局累计） | 银 | — |

##### 3.4 探索成就 (Exploration) —— 8 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_all_maps_ch1` | 青云剑宗全境 | 第 1 章的全部 4 张地图均至少通关 1 次（跨局累计） | 铜 | — |
| `ach_all_maps_all` | 踏遍九州 | 全部 18 张地图均至少通关 1 次（跨局累计） | 金 | — |
| `ach_secret_room` | 别有洞天 | 首次发现隐藏房间（探索地图上的隐藏节点） | 银 | ✅ |
| `ach_event_100` | 阅历丰富 | 累计触发 100 个事件（跨局累计） | 银 | — |
| `ach_all_events_map` | 一地洞悉 | 单张地图上触发过该地图的全部可能事件（跨局累计） | 银 | — |
| `ach_no_damage_map` | 闲庭信步 | 在一张地图上全程未触发任何战斗（只走安全节点+事件） | 银 | ✅ |
| `ach_map_full_clear` | 扫荡一空 | 单局游戏中清空一张地图的全部节点（所有节点均已访问） | 铜 | — |
| `ach_node_50_single_run` | 行者无疆 | 单局游戏中累计访问 50 个地图节点 | 铜 | — |

##### 3.5 叙事成就 (Narrative) —— 8 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_chapter_1_clear` | 青云入世 | 首次通关第 1 章 | 铜 | — |
| `ach_chapter_3_clear` | 苍玄之争 | 首次通关第 3 章 | 银 | — |
| `ach_chapter_5_clear` | 归墟探索 | 首次通关第 5 章（即首次通关游戏） | 金 | — |
| `ach_ending_ascension` | 飞升仙界 | 解锁「飞升仙界」结局线（任意变体） | 银 | — |
| `ach_ending_guardian` | 归墟守护 | 解锁「留在归墟」结局线（任意变体） | 银 | — |
| `ach_ending_return` | 归乡之人 | 解锁「归隐东域」结局线（任意变体） | 银 | — |
| `ach_all_endings` | 超凡入圣 | 解锁全部 6 个结局 | 金 | — |
| `ach_story_flag_30` | 因果交织 | 跨局累计收集 25 个不同 story_flag | 金 | ✅ |

##### 3.6 精通成就 (Mastery) —— 8 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_school_win_zhengdao` | 正道砥柱 | 使用正道发育流通关（主力卡组中正道阵营卡≥60%） | 银 | — |
| `ach_school_win_modao` | 魔道至尊 | 使用魔道快攻流通关（主力卡组中魔道阵营卡≥60%） | 银 | — |
| `ach_school_win_hybrid` | 正邪兼修 | 使用正邪混合流通关（由流派系统的正邪混合流判定决定，不自行计算流派比例） | 银 | — |
| `ach_school_win_spirit` | 真灵之主 | 使用归墟真灵流通关（主力卡组中归墟阵营卡≥60%） | 银 | — |
| `ach_school_win_alchemy` | 百艺宗师 | 使用百艺炼丹流通关（本局完成≥5次炼丹/炼器操作+丹药/法宝卡≥30%） | 银 | — |
| `ach_all_schools` | 万法归宗 | 全部 5 种流派各通关 1 次 | 金 | — |
| `ach_identity_win_3` | 三生万物 | 使用 3 种不同开局身份各通关 1 次 | 银 | — |
| `ach_deck_minimal` | 极简之道 | 使用不超过 25 张卡牌的卡组通关（不含角色卡） | 金 | ✅ |

##### 3.7 挑战成就 (Challenge) —— 6 个

| ID | 名称 | 条件 | 稀有度 | 隐藏 |
|----|------|------|:------:|:----:|
| `ach_speed_run` | 元婴速通 | 在 2 小时内通关（游戏内计时，不含暂停/菜单/加载时间） | 金 | — |
| `ach_no_talent_win` | 凡人之躯 | 不激活任何轮回天赋的情况下通关 | 金 | — |
| `ach_no_shop` | 自给自足 | 一局游戏中从未在商店购买任何物品 | 银 | ✅ |
| `ach_no_death` | 不死不灭 | 一局游戏中角色从未阵亡（所有角色从开局存活到通关） | 金 | — |
| `ach_realm_1_boss` | 以凡弑仙 | 以炼气期击败第 1 章的章末 BOSS（墨渊·夺舍形态）——即不修炼到筑基直接挑战 | 金 | ✅ |
| `ach_win_rate_100` | 百战百胜 | 通关的一局中胜率 100%（所有可避免的战斗均胜利，无逃跑/撤退/战败后读档；剧情强制事件如第2章正魔大战·剧情杀不计入战败统计） | 金 | — |

#### 4. 成就触发机制

##### 4.1 事件驱动架构

成就系统不主动轮询——它订阅 GSM 的信号总线，在关键事件发生时检查成就条件：

```
# 成就系统初始化的伪代码
func _ready():
  GSM.connect("realm_upgraded", _on_realm_upgraded)
  GSM.connect("tribulation_completed", _on_tribulation_completed)
  GSM.connect("boss_defeated", _on_boss_defeated)
  GSM.connect("elite_defeated", _on_elite_defeated)
  GSM.connect("card_obtained", _on_card_obtained)
  GSM.connect("game_victory", _on_game_victory)
  GSM.connect("chapter_completed", _on_chapter_completed)
  GSM.connect("ending_unlocked", _on_ending_unlocked)
  GSM.connect("map_cleared", _on_map_cleared)
  GSM.connect("node_visited", _on_node_visited)
  GSM.connect("event_triggered", _on_event_triggered)
  GSM.connect("craft_completed", _on_craft_completed)
  GSM.connect("alchemy_completed", _on_alchemy_completed)
  GSM.connect("inscription_completed", _on_inscription_completed)
  GSM.connect("ling_shi_changed", _on_ling_shi_changed)
  GSM.connect("cultivation_changed", _on_cultivation_changed)
  GSM.connect("formation_triggered", _on_formation_triggered)
  GSM.connect("battle_ended", _on_battle_ended)
  GSM.connect("status_applied", _on_status_applied)
```

##### 4.2 条件评估器

```
evaluate_achievement(ach_id, event_data):
  ach = ACHIEVEMENTS[ach_id]
  if ach.unlocked_at != null: return  # 已解锁，跳过
  
  condition = ach.unlock_condition
  
  # 事件名不匹配 → 跳过
  if condition.event != event_data.event_name: return
  
  # 阈值检查
  if condition.threshold:
    current = get_current_progress(ach_id, event_data)
    if current < condition.threshold: return
  
  # 额外条件检查（如 no_damage_taken 等）
  if condition.extra_checks:
    for check in condition.extra_checks:
      if not evaluate_extra_check(check, event_data): return
  
  # 全部满足 → 解锁
  unlock_achievement(ach_id)
```

##### 4.3 跨局累计型成就

部分成就需要跨局累计（如「累计击杀 50 个精英敌人」）。这些数值存储在 `progression.achievements` 中：

```
# progression.dat 中成就进度的存储结构
{
  "achievements": {
    "unlocked": ["ach_first_realm_break", "ach_first_elite_kill", ...],
    "progress": {
      "ach_elite_hunter": 23,        # 已击杀 23/50 精英
      "ach_cards_100": 67,           # 已收录 67/100 卡牌
      "ach_event_100": 42,           # 已触发 42/100 事件
      "ach_alchemy_50": 15,          # 已炼丹 15/50 次
      ...
    },
    "unlocked_dates": {
      "ach_first_realm_break": "2026-08-01T12:00:00Z",
      ...
    }
  }
}
```

**进度重置规则：**
- 跨局累计进度**永不重置**——它是 progression 的一部分
- 单局型成就的进度（如 `ach_ling_shi_10000`）在每局开始时重置为 0
- 成就的 `progress` 字段为 `null` 表示该成就无进度条（一次性触发）

##### 4.4 单局 vs 跨局成就区分

| 判定方式 | 成就数量 | 存储位置 | 特征 |
|----------|:------:|---------|------|
| **单局内触发** | ~20 | 直接写入 `achievements.unlocked`（不需要进度追踪） | 一次性事件：击杀 BOSS、通关章节、渡劫成功 |
| **跨局累计** | ~25 | 进度写入 `achievements.progress`；达到阈值后写入 `unlocked` | 累计数值：击杀数、收集数、炼丹次数 |
| **单局条件判定** | ~17 | 每局结束时评估（不累计） | 限制条件：无伤、速通、100% 胜率 |

#### 5. 成就 UI 与展示

##### 5.1 解锁弹窗

成就解锁时，在游戏内（非主菜单）弹出非阻断式通知：

```
┌──────────────────────────────────┐
│  🏆 成就解锁！                    │
│                                  │
│  [成就图标 48×48]                 │
│  成就名称（稀有度配色）            │
│  成就描述                         │
│                                  │
│  +{points} 成就点                 │
└──────────────────────────────────┘
```

- 弹出位置：屏幕上方偏右（不遮挡核心玩法区域）
- 持续时间：4 秒自动消失（可点击提前关闭）
- 稀有度配色：铜=棕褐色、银=银灰色、金=金色辉光、隐藏=紫色（解锁后显示正常色）
- 多个成就同时触发时：依次弹出（每个间隔 0.5s），而非堆叠
- 战斗中不弹成就通知（延后到战斗结算后统一弹出）

##### 5.2 成就列表（主菜单）

主菜单「成就」入口打开完整成就列表：

```
┌────────────────────────────────────────────┐
│  成就 · 已解锁 32/62                         │
│  ┌──────────────────────────────────────┐  │
│  │ [分类标签] 全部 | 战斗 | 成长 | 收集 |...│  │
│  ├──────────────────────────────────────┤  │
│  │ ┌──────────────────────────────────┐ │  │
│  │ │ [图标] 成就名称                    │ │  │
│  │ │ 成就描述 · 解锁日期                │ │  │
│  │ │ ████████░░ 23/50（进度条）         │ │  │
│  │ └──────────────────────────────────┘ │  │
│  │ ┌──────────────────────────────────┐ │  │
│  │ │ [???] ???                         │ │  │
│  │ │ ???                               │ │  │
│  │ │ （隐藏成就·暗色剪影）               │ │  │
│  │ └──────────────────────────────────┘ │  │
│  │ ...                                  │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  总计成就点：1,230                           │
└────────────────────────────────────────────┘
```

**成就列表面板设计细节：**
- 7 个分类标签横向排列，默认显示「全部」
- 每个成就卡片显示：图标+名称+描述+解锁日期（已解锁）或暗色剪影+「???」（隐藏未解锁）或灰色图标+条件描述（可见未解锁）
- 有进度的成就显示进度条（current/target）
- 已解锁的成就在排序中置顶（按解锁日期倒序），未解锁的按 ID 排序
- 成就统计摘要：已解锁数/总数、成就点总数、最近解锁（最多显示 3 个）

##### 5.3 Steam 集成预留

成就数据结构中的 `id` 和 `points` 字段预留 Steam Stats/ Achievements API 对接：

```
# Godot 中 Steam 成就对接（未来，若上架 Steam）
# 使用 godotsteam 插件或自定义 GDExtension

func sync_steam_achievement(ach_id: String):
  if not SteamManager.enabled: return
  # Steam.setAchievement(ach_id)
  # Steam.storeStats()
```

- 每个成就的 `id` 即为 Steam 后台配置的 API Name
- Steam 成就名称和描述与游戏内保持一致
- 成就点数用于 Steam 全球成就百分比展示（Steam 自动计算）

#### 6. 成就与轮回天赋的交互

成就系统与轮回天赋系统之间存在单向数据流：

| 方向 | 数据流 |
|------|--------|
| 成就 → 天赋 | 某些轮回天赋节点可能关联成就作为解锁条件（如「超脱轮回」天赋需要 `ach_chapter_5_clear`）。但当前设计中轮回天赋解锁条件已由轮回天赋系统独立定义——这里预留接口 |
| 天赋 → 成就 | 轮回天赋系统有独立的「解锁 N 个轮回天赋」成就(`ach_reincarnation_10`)。如果未来扩展天赋树，可新增对应成就 |

**设计原则：** 成就和轮回天赋保持松耦合——成就解锁不自动给轮回点，轮回天赋解锁不自动给成就。两者的关联仅通过条件引用（一个成就可以检查天赋数量，一个天赋节点可以检查成就ID），不形成循环依赖。

#### 7. 成就数据持久化

成就数据存储在 `progression.dat` 的 `achievements` 域中（详见 §4.3）：

```
# 存储时机
- 成就解锁 → 立即写入 progression.dat（异步，不阻塞游戏）
- 累计进度更新 → 在以下时机批量写入：
  · 战斗结算后
  · 探索节点完成后
  · 章节完成后
  · 游戏退出前（自动保存）

# 写入策略
- 成就数据量小（<10KB），全量覆写而非增量追加
- 写入失败时：重试 3 次（间隔 0.5s）→ 最终失败记录到 error.log → 下次启动时从内存恢复
```

**endings.dat 与成就的关系：**
- 结局图鉴数据存储在独立的 `endings.dat`（由结局分支系统管理）
- 成就系统**读取** `endings.dat` 来检测「全结局解锁」成就
- 成就系统**不写入** `endings.dat`——数据流单向（结局系统 → 成就系统）

### 状态与转换

```
成就生命周期：

[未解锁] —— 条件未满足，progress=0（如有进度条）
    ↓ 进度累积（跨局累计型）
[进行中] —— progress 递增，但未达阈值
    ↓ 阈值达成 / 一次性事件触发
[已解锁] —— unlocked_at 写入时间戳，弹出通知
    ↓ （永不倒退——成就永久解锁）
```

**成就不可逆：** 一旦解锁，成就永久保持。即使 progression.dat 损坏，成就数据应尽可能从备份或 Steam Cloud 恢复。如果无法恢复（progression.dat 完全损坏+无备份），成就归零——但与结局图鉴一样，建议 `achievements` 数据有独立校验文件 `achievements.dat`（可选——Full Vision 阶段评估必要性）。

**成就与存档槽位的关系：**
- 成就数据属于 progression（跨局元进度），不属于任何存档槽位
- 删除存档槽位不影响成就
- 删除 progression.dat → 成就归零（所有进度丢失）

### 与其他系统的交互

| 系统 | 数据流入（本系统→目标） | 数据流出（目标→本系统） |
|------|----------------------|---------------------|
| **游戏状态管理器** | 写入 `progression.achievements`（解锁状态+进度） | GSM 信号总线（15+ 信号订阅）；读取 `progression` 域 |
| **存档系统** | 成就数据作为 progression.dat 的一部分持久化 | progression.dat 的读写接口 |
| **战斗系统** | — | `boss_defeated`、`elite_defeated`、`battle_ended` 信号（含战斗元数据：no_damage、one_turn_kill 等） |
| **状态效果系统** | — | `status_applied` 信号（用于检测敌人身上异常状态数量） |
| **境界系统** | — | `realm_upgraded` 信号 |
| **渡劫突破系统** | — | `tribulation_completed` 信号（含是否越阶、HP 状态） |
| **卡牌系统** | — | `card_obtained` 信号（含稀有度）；全局图鉴查询接口 |
| **剧情系统** | — | `chapter_completed` 信号 |
| **结局分支系统** | 读取 endings.dat 检测全结局解锁 | `ending_unlocked` 信号 |
| **探索系统** | — | `map_cleared`、`node_visited` 信号 |
| **事件系统** | — | `event_triggered` 信号 |
| **炼丹炼器系统** | — | `alchemy_completed`、`craft_completed` 信号 |
| **法宝铭刻系统** | — | `inscription_completed` 信号 |
| **轮回天赋系统** | 读取天赋解锁数量（用于 `ach_reincarnation_10`） | — |
| **流派系统** | — | 当前卡组流派分布数据（用于流派精通成就判定） |
| **身份选择系统** | — | 本局身份 ID（用于身份通关成就） |
| **UI 系统** | 成就解锁通知数据、成就列表数据 | 玩家交互（查看成就列表） |

### 上游依赖设计顺序

存档系统 + 游戏状态管理器（均已设计）→ **成就系统**

成就系统是「最下游」的元系统——它只读几乎所有系统的信号，只写 progression 的一个子域。所有依赖项均已设计完成。

## 公式

### 1. 成就稀有度分配原则

成就稀有度采用**手工标注**（非算法生成），基于以下设计原则综合判断：

| 稀有度 | 设计原则 | 典型条件 |
|--------|---------|---------|
| **铜 (bronze)** | 自然获取——首次完成某操作或低门槛里程碑 | 首次击杀精英/BOSS、首次渡劫、首次触发阵法 |
| **银 (silver)** | 中等投入——需要跨局累计或一定技巧 | 累计50次操作、收集50-100张卡牌、通关特定章节 |
| **金 (gold)** | 高投入——需要全收集、极限限制条件或深度掌握 | 全结局、全流派、速通、无伤、禁用天赋 |

隐藏标记独立于稀有度——任何稀有度的成就都可以是隐藏的。隐藏成就适用于「惊喜发现」场景（如 `ach_status_stack_5`、`ach_secret_room`），而非「有志挑战」场景（如速通、禁用天赋——这些应收为可见以激励尝试）。

### 2. 成就点数计算

```
calculate_points(tier, is_hidden) → int:
  base = {bronze: 5, silver: 15, gold: 30}
  hidden_bonus = 10 if is_hidden else 0
  return base[tier] + hidden_bonus
```

| 稀有度 | 基础点数 | 隐藏加成 | 最高点数 | 成就数量 |
|--------|:------:|:------:|:------:|:------:|
| 铜 (bronze) | 5 | +10 | 15 | 11 |
| 银 (silver) | 15 | +10 | 25 | 32 |
| 金 (gold) | 30 | +10 | 40 | 19 |
| **总计** | — | — | — | **62** |

预计成就总点数：11×5 + 32×15 + 19×30 + (隐藏加成 12×10) = 55 + 480 + 570 + 120 = **1,230 点**

### 3. 成就完成度

```
completion_rate() → float:
  return unlocked_count / total_count  # 62 个成就

category_completion(category) → float:
  return category_unlocked / category_total
```

用于 UI 进度展示（百分比+进度条）。Steam 全球成就百分比由 Steam 自动计算，游戏内无需实现。

### 4. 进度追踪更新公式

```
update_progress(ach_id, event_data):
  ach = ACHIEVEMENTS[ach_id]
  if ach.progress == null: return  # 无进度条成就
  
  increment = get_increment(ach_id, event_data)
  ach.progress.current = min(ach.progress.current + increment, ach.progress.target)
  
  if ach.progress.current >= ach.progress.target:
    unlock_achievement(ach_id)
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|:----:|------|
| ach_id | String | — | 成就 ID |
| increment | int | [0, target] | 本次事件贡献的进度增量（通常为 1） |
| ach.progress.current | int | [0, target] | 累计当前进度 |
| ach.progress.target | int | — | 目标阈值 |

## 边界情况

- **成就触发在战斗中**：战斗中的成就通知延后到战斗结算后统一弹出。如果玩家在战斗中死亡（战败），该次战斗中产生的成就仍然有效（已解锁的成就不会因战败撤销）
- **同一事件触发多个成就**：依次解锁，通知队列依次弹出（每个间隔 0.5s），最多同时显示 5 个通知（超出 5 个的合并为一个「+N 个成就」通知）
- **已解锁成就反复触发**：忽略——条件评估器第一步检查 `unlocked_at != null` 即跳过
- **跨局累计成就在 progression.dat 损坏时**：进度归零——但如果 `achievements.dat` 独立备份存在，启动时检测两者的 checksum，差异>0 则从备份恢复
- **Steam 未连接时成就解锁**：正常本地解锁——Steam 成就同步失败时，将待同步成就写入 `pending_steam_achievements` 列表，下次 Steam 连接可用时批量同步
- **修改系统时间导致解锁日期异常**：不处理——单机游戏不校验系统时间。但解锁顺序可能因时间错乱而看起来不对劲（不会影响功能）
- **玩家在成就解锁通知弹出时按 Alt+F4 退出**：成就已写入 progression.dat（写入在解锁瞬间完成，通知是异步的）。下次启动时成就已存在——「解锁通知」不会重新弹出（因为成就已标记为已解锁且通知已展示过，但无法确认。保守处理：下次启动时不补弹通知）
- **同一成就同时被多个信号触发（竞态）**：成就解锁加锁（`unlock_in_progress` 标志位），防止重复解锁。第一次 unlock_achievement() 写入后，后续同一成就的触发被锁拦截
- **满成就玩家在新版本新增成就后**：新增成就自动加入成就列表，未解锁状态。已解锁成就不受影响。总成就数从 62 变为 62+N
- **成就中的「通关」定义**：以 `game_victory` 信号为准（即结局展示完成并进入轮回结算），而非第 5 章 BOSS 击败瞬间
- **「无伤击败 BOSS」如何判定**：战斗中 `player.total_hp_lost == 0`（全局 HP 净损失为 0——角色可以在战斗中受伤只要被治疗回满，净 HP 损失仍为 0。这与成就名称「枯木逢春」一致——象征恢复力而非完美无伤）。但如果角色阵亡过（即使被复活），`total_hp_lost` 非 0
- **「一回合击杀 BOSS」判定**：从战斗开始到 BOSS HP 归零，`turn_count == 1`。如果 BOSS 有多阶段（形态切换），只要所有阶段在同一回合内完成即可
- **「使用 X 流派通关」的卡组判定**：`主力卡组中该流派卡牌数量 / 总卡牌数量 ≥ 60%`（仅计功法/法宝/法术卡，不含角色卡）。判定时机：通关时检查最终卡组
- **成就通知语言**：成就名称和描述使用当前语言设置。如果语言中途切换，已解锁成就的显示语言不回溯更新（保持解锁时的语言快照——简化实现）
- **「百战百胜」成就与剧情强制事件**：第 2 章「正魔大战」剧情杀等标记为 `scripted_defeat=true` 的强制事件不计入战败统计。成就仅统计玩家可避免的战斗——剧情杀是叙事工具，非玩家失误
- **灵石消费成就的累计范围**：`ach_ling_shi_10000` 统计单局中所有灵石支出（商店购买、删牌费用、炼丹炼器材料购买等）。饰品/消耗品直接购买亦计入

## 依赖关系

| 依赖系统 | 性质 | 说明 |
|----------|:----:|------|
| **游戏状态管理器** | 硬依赖 | progression.achievements 域读写；GSM 信号总线订阅 |
| **存档系统** | 硬依赖 | progression.dat 的持久化（成就数据在此文件中） |
| **战斗系统** | 硬依赖 | 战斗相关信号（Boss/精英击杀、战斗结束元数据） |
| **状态效果系统** | 硬依赖 | status_applied 信号（ach_status_stack_5 检测 5+ 异常状态） |
| **境界系统** | 软依赖 | realm_upgraded 信号（成长成就） |
| **渡劫突破系统** | 软依赖 | tribulation_completed 信号 |
| **卡牌系统** | 硬依赖 | card_obtained 信号；全局图鉴查询（收集成就） |
| **剧情系统** | 软依赖 | chapter_completed 信号 |
| **结局分支系统** | 软依赖 | ending_unlocked 信号；endings.dat 读取 |
| **探索系统** | 软依赖 | map_cleared、node_visited 信号 |
| **事件系统** | 软依赖 | event_triggered 信号 |
| **炼丹炼器系统** | 软依赖 | alchemy/craft_completed 信号 |
| **法宝铭刻系统** | 软依赖 | inscription_completed 信号 |
| **轮回天赋系统** | 软依赖 | 天赋解锁数量查询（ach_reincarnation_10） |
| **流派系统** | 软依赖 | 卡组流派分布查询（流派精通成就） |
| **身份选择系统** | 软依赖 | 本局身份 ID（身份通关成就） |
| **UI 系统** | 硬依赖 | 成就解锁通知弹窗、成就列表界面渲染 |

## 调优参数

| 参数 | 默认值 | 安全范围 | 过低影响 | 过高影响 |
|------|:-----:|:--------:|---------|---------|
| 成就总数 | 62 | 40~80 | 成就太少缺少收集动力 | 成就太多稀释价值感 |
| 铜/银/金比例 | 11/32/19 | 可调整 | 铜太少=初期无成就感；金太多=缺乏挑战梯度 | — |
| 隐藏成就数量 | 12 | 5~15 | 惊喜太少 | 太多「?? ?」让玩家困惑 |
| 跨局累计成就数量 | ~25 | 15~35 | 单局没有积累感 | 累计太多=新玩家看不到进度 |
| 成就通知持续时间 | 4s | 2~6s | 来不及看清内容 | 遮挡游戏太久 |
| 战斗中通知延后 | true | — | — | — |
| 进度条写入间隔 | 事件节点完成后 | — | — | — |
| Steam 同步重试次数 | 3 | 2~5 | 同步可靠性差 | 重试浪费时间 |

## 视觉/音频需求

| 事件 | 动画 | 时长 |
|------|------|:----:|
| 成就解锁通知·出现 | 从屏幕右上方滑入 + 图标缩放弹跳（scale 0→1.2→1.0） | 0.4s |
| 成就解锁通知·停留 | 图标微呼吸（scale 1.0↔1.03） + 稀有度辉光（金=金色光晕旋转） | 3.6s |
| 成就解锁通知·消失 | 向右上方滑出 + 淡出 | 0.4s |
| 成就列表·分类切换 | 卡片横向滑动（左进右出） | 0.3s |
| 成就列表·解锁瞬间 | 暗色剪影翻转→彩色卡片+粒子爆散（首次查看时） | 0.6s |
| 隐藏成就·揭示 | 紫色「?? ?」卡片炸裂→真实成就卡片浮现（仅在游戏内通知中，列表中是即时切换） | 0.5s |

### 音频需求
- 成就解锁音效：根据稀有度不同——铜=清脆「叮」、银=金属回响、金=管弦短乐句+低音鼓点、隐藏=神秘琶音
- 成就不堆叠音效：多个成就连续解锁时，后续成就只用简化短音（避免声音重叠刺耳）
- 成就列表 BGM：轻量的氛围音乐（与主菜单共用或使用主菜单音乐的变奏）

## 用户界面需求

| 界面 | 触发场景 | 核心功能 |
|------|----------|----------|
| **成就解锁通知** | 游戏内满足成就条件时（战斗中的延后到结算后） | 非阻断式弹窗：图标+名称+描述+稀有度辉光；4s 自动消失或点击关闭；最多 5 个通知同时可见（超出合并） |
| **成就列表（主菜单）** | 主菜单「成就」按钮 | 完整成就浏览：7 个分类标签+全部；已解锁/未解锁/隐藏三种卡片样式；进度条（跨局累计型）；解锁日期显示；统计摘要（X/62 + 总成就点） |
| **成就详情卡片** | 点击成就列表中的任意卡片 | 展开大卡片：大图标+完整名称+完整描述+解锁日期+稀有度标签+进度条（如有）；底部「返回列表」 |
| **成就统计概览** | 成就列表底部固定区域 | 已解锁数/总数、百分比进度环、总成就点、最近解锁 3 个（图标+名称+日期） |

> **📌 用户体验标记—成就系统**：此系统有 UI 需求。在预生产中运行 `/ux-design` 为成就解锁通知和成就列表界面创建用户体验规格。

## 验收标准

- **GIVEN** 玩家首次突破到筑基期，**WHEN** realm_upgraded 信号携带 new_realm="筑基期"，**THEN** `ach_first_realm_break` 标记为已解锁（unlocked_at 写入当前时间戳），通知加入弹出队列
- **GIVEN** 玩家在战斗中首次击杀精英敌人，**WHEN** battle_ended 信号触发且本场累计 elite_kills >= 1（首次），**THEN** `ach_first_elite_kill` 解锁，通知延后到战斗结算完成后弹出
- **GIVEN** 跨局精英敌人累计击杀数达到 50，**WHEN** 第 50 个精英击杀完成，**THEN** `ach_elite_hunter` 解锁
- **GIVEN** 跨局精英敌人累计击杀数达到 200，**WHEN** 第 200 个精英击杀完成，**THEN** `ach_elite_slayer` 解锁
- **GIVEN** 玩家首次获得暗金卡牌，**WHEN** card_obtained 信号携带 rarity=dark_gold，**THEN** `ach_first_dark_gold` 解锁
- **GIVEN** 全局图鉴中拥有 5 张不同暗金卡牌，**WHEN** 不同暗金卡牌数从 4 变为 5，**THEN** `ach_dark_gold_5` 解锁
- **GIVEN** 玩家首次通关第 5 章，**WHEN** game_victory 信号触发且 chapter_id="5" 且为首次通关，**THEN** `ach_chapter_5_clear` 解锁
- **GIVEN** 玩家已解锁 5 个不同结局，**WHEN** ending_unlocked 信号触发后已解锁结局总数达到 6，**THEN** `ach_all_endings` 解锁
- **GIVEN** 玩家使用魔道快攻流卡组通关，**WHEN** game_victory 触发且最终卡组中魔道阵营卡占比 ≥60%（仅计功法/法宝/法术卡），**THEN** `ach_school_win_modao` 解锁
- **GIVEN** 玩家全部 5 种流派各通关 1 次（跨局累计），**WHEN** game_victory 触发后已解锁的流派通关成就集合包含全部 5 种流派 ID，**THEN** `ach_all_schools` 解锁
- **GIVEN** 玩家一局内灵石累计消费达到 5000，**WHEN** ling_shi_spent 累计值 >= 5000，**THEN** `ach_ling_shi_10000` 在当前局内解锁
- **GIVEN** 玩家无伤击败章末 BOSS（total_hp_lost=0），**WHEN** boss_defeated 信号触发且战斗元数据 total_hp_lost==0，**THEN** `ach_no_damage_boss` 解锁
- **GIVEN** 玩家在 1 回合内击杀 BOSS，**WHEN** boss_defeated 信号触发且战斗元数据 turn_count==1，**THEN** `ach_one_turn_kill` 解锁
- **GIVEN** 玩家同时触发 3 个成就，**WHEN** 通知依次弹出，**THEN** 3 个通知各间隔 0.5s 出现，不堆叠
- **GIVEN** 战斗中满足成就条件，**WHEN** battle_in_progress 状态为 true，**THEN** 解锁通知加入 pending 队列（不在屏幕上渲染）；WHEN battle_ended 信号触发，**THEN** pending 队列释放并渲染通知
- **GIVEN** 未解锁的隐藏成就，**WHEN** 在成就列表中查看，**THEN** 显示暗色剪影+「???」；隐藏成就的进度条亦隐藏（仅显示「?? ?」不显示数字），避免泄露累计型属性
- **GIVEN** 玩家删除存档槽位，**WHEN** 检查成就列表，**THEN** 所有成就保持原状（成就数据在 progression.dat 中，不受存档删除影响）
- **GIVEN** progression.dat 损坏且无备份，**WHEN** 启动游戏，**THEN** achievements 域初始化为空（所有 62 个成就 status=locked, progress=0），并在 error.log 中记录 "ACHIEVEMENT_RESET" 事件
- **GIVEN** 玩家查看成就列表，**WHEN** 选择 category="combat" 分类标签，**THEN** 仅显示 category="combat" 的成就（已解锁按 unlocked_at 倒序置顶，未解锁按 id 升序追加）
- **GIVEN** 玩家以炼气期挑战并击败第 1 章 BOSS（realm_level=1），**WHEN** boss_defeated 信号触发且玩家 realm_level==1 且 boss 为第 1 章章末 BOSS，**THEN** `ach_realm_1_boss` 解锁
- **GIVEN** 玩家当前轮回天赋激活数为 0，**WHEN** game_victory 触发，**THEN** `ach_no_talent_win` 解锁
- **GIVEN** 本局累计游戏时间（playtime_seconds，不含暂停/菜单/加载时间）<= 7200，**WHEN** game_victory 触发，**THEN** `ach_speed_run` 解锁
- **GIVEN** 玩家跨局累计收集 25 个不同 story_flag，**WHEN** story_flag_collected 触发后 unique_flag_count 达到 25，**THEN** `ach_story_flag_30` 解锁
- **GIVEN** 玩家跨局累计修为溢出达到 10 次，**WHEN** cultivation_overflow 信号触发后 total_overflow_count 达到 10，**THEN** `ach_cultivation_overflow` 解锁
- **GIVEN** 已解锁 `ach_first_elite_kill` 且 `ach_elite_hunter` progress=23，**WHEN** 重启游戏，**THEN** `ach_first_elite_kill` 保持已解锁状态 AND `ach_elite_hunter` progress=23
- **GIVEN** 6 个成就同时解锁，**WHEN** 通知队列处理，**THEN** 前 5 个依次弹出 AND 第 6 个触发合并通知「+1 个成就」（合并通知可点击展开查看完整列表）
- **GIVEN** 单局成就 `ach_ling_shi_10000` 在第 N 局灵石消费达到 4000（未达 5000），**WHEN** 开始第 N+1 局新游戏，**THEN** `ach_ling_shi_10000` 的单局进度重置为 0（跨局累计成就的 progress 保持不变）
- **GIVEN** v1.0 中玩家已解锁 32/62 成就，**WHEN** 升级到 v1.1（新增 3 个成就），**THEN** 成就列表显示 32/65，新增成就均为未解锁状态
- **GIVEN** 成就系统初始化完成，**WHEN** 统计 ACHIEVEMENTS 注册表，**THEN** 注册表包含恰好 62 个条目；铜色 tier_count=11，银色 tier_count=32，金色 tier_count=19

## 待解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | 是否需要 `achievements.dat` 独立备份（类似 `endings.dat`）？当前设计依赖 progression.dat，损坏即丢失。但成就数据有 Steam Cloud 作为远程备份（若上架 Steam） | 数据可靠性 | Steam 集成决策时 |
| 2 | 成就总数 62——预生产阶段是否需要增减？当前设计覆盖 7 个领域，每个领域 6~12 个，感觉均衡。但实际开发中可能发现某些领域缺少有趣的成就设计 | 成就设计质量 | 预生产阶段根据实际内容调整 |
| 3 | 「百战百胜」成就（100% 胜率通关）——如果玩家使用战斗快照（pre_battle 快照）重试，是否算「战败」？当前设计：读档（战斗重来）算战败——该成就要求原始通关过程中从未触发战败+从未读档重来 | 公平性 | 成就实现时与存档系统确认 |
| 4 | 成就系统是否需要「成就追踪」功能——玩家可以标记 3~5 个未解锁成就为「追踪中」，在游戏中 HUD 显示进度？类似 Steam 的成就追踪 | 用户体验 | 预生产 UX 设计时 |
| 5 | Steam 成就 API 对接——Godot 中使用 godotsteam 插件还是自写 GDExtension？本系统预留了接口但未选择实现方案 | 技术选型 | Steam 上架决策后 |
| 6 | 成就图标——62 个成就需要 62 个图标吗？还是按稀有度使用通用图标（铜/银/金/隐藏 4 种通用图标+成就分类小标记）？独立游戏预算建议后者 | 美术预算 | 预生产美术资源规划时 |