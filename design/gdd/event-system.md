# 事件系统 (Event System)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-22
> **最后验证 (Last Verified)**：—
> **实现的支柱 (Implements Pillar)**：支柱3「机缘巧合，意外之喜」

## 概述

事件系统是探索阶段的核心交互机制，负责管理地图节点触发的事件流程——包括事件的定义、条件判定、选项展示、结果结算以及连锁事件的串联。系统维护一个事件数据库，每种事件类型有独立的模板结构，事件实例在生成地图时由探索系统创建。事件系统不直接处理地图布局（那是探索系统的职责），也不直接管理资源数值修改（通过GSM完成），而是作为**决策逻辑层**：给定事件和玩家的选择，计算并执行结果。

对玩家来说，事件是探索中每一次「停下脚步」时面对的选择——「灵脉采掘是挖还是走？」「坊市交易买什么？」「洞府里选宝物还是选功法？」。每个事件是一次2~4选1的决策，决策结果直接影响资源、修为、卡牌收藏或剧情走向。事件系统的质量决定了探索阶段的重复可玩性——同一张地图，不同的决策路径和随机结果让每局体验不同。

暂无相关ADR。

## 玩家幻想

事件系统的核心情感是**选择的重量**——不是在战斗中的即时反应，而是在探索中面对未知时做出判断的审慎感。

「灵脉采掘」让玩家在「稳稳拿灵石」和「赌博拿更多」之间抉择——这是权衡，计算风险。

「洞府奇遇」让玩家在「功法」、「法宝」、「丹药」中选一个——获得感，但选择的瞬间总觉得其他的可能更好。

「杀人夺宝」让玩家在「看看他的东西」和「当作没看见」之间选——这是道德的灰色地带，随机奖励才刺激。

「斜月三星洞」的隐藏奇遇让玩家觉得「我发现了特别的东西」——专属感，这局这图的独有体验。

事件系统不做平衡——它做**意外**。意外才是探索的灵魂。

## 详细设计

### 核心规则

#### 1. 事件定义结构

每个事件实例由事件模板生成，包含以下数据：

```
EventTemplate {
  id: String                       # 事件模板ID（如 "ling_mai_caijue_001"）
  type: Enum [采掘, 坊市, 洞府, 夺宝, 炼丹, 斜月三星洞]
  title: String                    # 事件标题（显示在UI）
  description: String              # 事件描述文本
  min_realm: int                   # 最低境界要求（1=炼气~4=元婴）
  weight: int                      # 出现权重（用于随机池）
  chain_next: String|null          # 连锁事件ID
  is_hidden: bool                  # 是否为隐藏奇遇（斜月三星洞）
  nodes: [
    Option {
      id: String
      text: String                 # 选项文本
      condition: Condition|null    # 可选条件（阵营/境界/资源）
      outcomes: [Outcome]          # 结果列表（可能多个）
      weight_override: int|null    # 选项的出现权重（部分事件有随机结果）
    }
  ]
}

Condition {
  type: Enum [realm, faction, resource, card_owned]
  operator: Enum [>=, ==, <]
  value: Variant                   # 如 realm_level=2, faction="zhengdao"
}

Outcome {
  type: Enum [add_resource, add_cultivation, add_card, remove_card,
              heal, damage, set_flag, gain_talent, trigger_battle,
              advance_chapter, restore_ap, nothing]
  target: String                   # 目标ID（资源类型/卡牌ID/标记名等）
  value: Variant                   # 数值或布尔值
  min: int|null                    # 随机范围下限
  max: int|null                    # 随机范围上限
  chance: float                    # 概率 0.0~1.0
}
```

#### 2. 事件类型大全

| 类型 | 决策结构 | 核心冲突 | 出现频率 | 相关Pillar |
|------|---------|---------|:-------:|:---------:|
| **灵脉采掘** | 2选1：稳妥采 vs 深挖（风险高回报） | 安全 vs 贪婪 | 常见 | P3「机缘」 |
| **坊市交易** | 2~3选1：购买不同物品（消耗灵石） | 这一件还是那一件 | 常见 | P1「策略」 |
| **洞府奇遇** | 2~3选1：选择宝物（免费但互斥） | 哪个最有价值 | 中频 | P3「机缘」 |
| **杀人夺宝** | 2选1：动手 vs 放过 | 道德 vs 利益 | 中频 | P3「机缘」 |
| **炼丹/炼器台** | 2选1：消耗资源炼制 vs 让过 | 消耗还是放弃 | 中频 | P2「成长」 |
| **斜月三星洞** | 3选1：独特奖励（每图仅出现1次） | 无冲突（全是惊喜） | 低频/图 | P3「机缘」 |

#### 3. 事件触发流程

```
① 玩家移动到地图节点
② 探索系统检查节点类型 → 确定触发事件
③ 事件系统获取事件模板 → 实例化事件
④ 检查 min_realm 和任何附加条件：
   - 不满足条件 → 跳过该事件，显示"无事件发生"或更换为备选事件
   - 满足条件 → 继续
⑤ 显示事件标题 + 描述文本 → 展示选项列表
⑥ 玩家选择一个选项
⑦ 结算每个 Outcome（可能多个，按顺序执行）：
   a. 带概率的 Outcome → 判定 chance
   b. 带随机范围的 Outcome → 在 [min, max] 间取随机值
   c. 执行结果：通过GSM修改状态
   d. 如果 Outcome 触发战斗 → 加载战斗场景
⑧ 如果 template.chain_next 不为空 → 加载连锁事件（连锁时不重新消耗行动力）
⑨ 事件结束 → 玩家停留在当前节点（可继续查看地图）
```

#### 4. 概率结果结算

```
resolve_outcome(outcome):
  if outcome.chance < 1.0:
    roll = random(0.0, 1.0)
    if roll > outcome.chance: return NULL  # 未触发
  if outcome.min != null AND outcome.max != null:
    value = random(outcome.min, outcome.max)  # 随机值范围
  else:
    value = outcome.value
  return execute_effect(outcome.type, outcome.target, value)
```

#### 5. 连锁事件

连续触发的多个事件，无需重新选择节点或消耗行动力：

```
# 链式定义示例：灵脉采掘 → 深挖成功 → 洞府入口
Event chain:
  ling_mai_caijue_001:
    chain_next: null  # 选项中的特定结果触发连锁
    Option A (稳妥):  outcome = add_resource(灵石, 50)
    Option B (深挖):  outcome = add_resource(灵石, 100~300) + trigger_chain(shen_wa_chenggong)
  shen_wa_chenggong:
    chain_next: dongfu_rukou_event
    描述: "你深挖灵脉时发现了一条隐秘通道..."
    选项 A: "进去看看" → dongfu_rukou_event
    选项 B: "算了回去" → nothing
```

连锁规则：
- 连锁事件在成功触发后续事件前**不消耗额外行动力**
- 连锁深度最多3层（防止无限嵌套）
- 连锁事件的结果是累积的（前一个事件的结果不影响后一个事件的选项——除非显式定义了条件分支）

#### 6. 事件条件分支

部分事件选项根据玩家当前状态动态显示/隐藏：

```
# 示例：杀人夺宝事件
事件：杀人夺宝
描述："你看到一个受伤的修士倒在山路边，他的储物袋就在身旁..."

选项 A: "救人一命" → 条件：realm >= 2（筑基期以上才有的选项）
选项 B: "拿了储物袋就走" → 条件：阵营=魔道（魔道角色才显示）
选项 C: "当作没看见" → 无条件（始终显示）
```

条件判定规则：
- 不满足条件的选项**完全不可见**（不是灰色）
- 如果所有选项都不满足条件 → 显示"你选择了谨慎行事，离开此地"（安全默认）
- 条件在事件实例化时判定一次（而非每次预览时）

#### 7. 事件权重与随机选择

当地图生成多个候选事件时，事件系统使用权重随机：

```
select_event(candidates, realm_level):
  # 过滤：筛掉 min_realm > realm_level 的事件
  eligible = [e for e in candidates if e.min_realm <= realm_level]
  # 加权随机
  total_weight = sum(e.weight for e in eligible)
  roll = random(0, total_weight)
  cumulative = 0
  for event in eligible:
    cumulative += event.weight
    if roll < cumulative:
      return event
```

同一类事件在同一地图中**不重复出现**（每种事件类型每图最多触发1次，斜月三星洞例外——每图且仅触发1次）。

#### 8. 事件结果执行器

Outcome 类型的具体执行映射：

| Outcome 类型 | 执行操作 | 通过GSM |
|-------------|---------|---------|
| add_resource | spend_resource 的反向：GSM.set("player.resources.{target}", new_value) | ✅ |
| add_cultivation | GSM.add_cultivation(value) | ✅ |
| add_card | GSM.add_card_to_collection(card_id) | ✅ |
| remove_card | 从收藏和当前卡组移除卡牌 | ✅ |
| heal | 治疗队伍（战斗相关，战斗中生效） | 战斗系统 |
| damage | 伤害队伍（事件中的战斗陷阱） | 战斗系统 |
| set_flag | GSM.set("narrative.story_flags.{flag}", true) | ✅ |
| gain_talent | 临时/永久解锁天赋 | GSM.progression |
| trigger_battle | 加载战斗场景 | 探索系统 |
| advance_chapter | 推动剧情章节 | GSM.narrative |
| restore_ap | GSM.set("exploration.action_points", min(current+value, max)) | ✅ |
| nothing | 无效果（仅叙事文本） | — |

#### 9. 斜月三星洞——隐藏奇遇（特殊规则）

- 每张地图**最多触发1次**
- 触发条件：地图上特定节点（固定位置），玩家到达该节点时自动触发
- 触发时不需要消耗额外资源
- 奖励固定为3选1，每种奖励类型在数据库中预配置
- 已经被触发的斜月三星洞节点变为"已探索"（不可再触发）
- 玩家如果错过了该节点（行动力不足以到达），该地图的斜月三星洞机会永久丢失
- 奖励品质随境界提升：炼气→蓝色，筑基→紫色，金丹→金色，元婴→暗金

### 状态与转换

事件系统自身不维护状态。事件实例在触发时创建，结算后销毁。

地图生成时的状态（由探索系统管理）：
```
地图节点 → 分配到节点类型（普通/事件/Boss/传送/行动力泉）
         ↓
事件系统分配事件模板到事件节点
         ↓
玩家到达事件节点 → 创建事件实例 → 选择选项 → 结算 → 销毁实例
```

已触发事件不存储到存档中（存档时保存的是地图状态 `exploration.map_state`，探索系统通过 `revealed_nodes` 和节点状态记录哪些事件已被触发）。

### 与其他系统的交互

| 系统 | 数据流入（本系统→目标） | 数据流出（目标→本系统） |
|------|----------------------|---------------------|
| **游戏状态管理器** | 读取 player/collection/progression 状态（条件判定）；写入事件结果 | 事件触发时读取条件所需的状态 |
| **探索系统** | 事件模板ID列表（地图配置）；事件结果（触发战斗/推进剧情） | 玩家到达事件节点事件；当前地图数据 |
| **战斗系统** | trigger_battle 时携带的敌方阵容信息 | 战斗结果（胜利/失败→影响事件后续） |
| **卡牌系统** | 需要卡牌ID验证（add_card/remove_card 时的引用完整性） | 卡牌模板数据（用于验证事件奖励的卡牌是否存在） |
| **资源系统/修为系统** | 事件结果中的资源/修为数值变更 | — |
| **叙事/剧情系统** | set_flag / advance_chapter 状态变更 | 剧情条件（部分事件需要先完成某章节） |
| **UI系统** | 事件标题/描述/选项列表 | 玩家选择结果回调 |

## 公式

### 1. 加权随机选择

```
select_weighted(candidates) → Event:
  total = sum(e.weight for e in candidates)
  roll = randf_range(0, total)
  cumulative = 0
  for e in candidates:
    cumulative += e.weight
    if roll < cumulative: return e
  return candidates[-1]  # fallback
```

### 2. 概率结算

```
resolve_chance(outcome) → bool:
  return outcome.chance >= 1.0 or randf() < outcome.chance
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| chance | float | [0.0, 1.0] | 事件结果的触发概率 |
| randf() | float | [0.0, 1.0) | Godot 随机函数 |

### 3. 随机值范围

```
resolve_value(outcome) → Variant:
  if outcome.min != null and outcome.max != null:
    return randi_range(outcome.min, outcome.max)
  return outcome.value
```

### 4. 触发条件判定

```
check_condition(condition, gsm_state) → bool:
  match condition.type:
    realm:     return gsm_state.player.realm_level >= operator_value(condition)
    faction:   return has_tag(gsm_state, condition.value)  # 调用阵营系统
    resource:  return gsm_state.player.resources[condition.target] >= condition.value
    card_owned: return condition.value in gsm_state.collection.owned_cards
```

## 边界情况

- **所有选项都满足条件**：正常展示，玩家任选
- **部分选项不满足条件**：不满足条件的选项完全隐藏（不显示灰色选项），玩家仅能看到可用选项
- **所有选项都不满足条件**：显示安全默认选项「你决定谨慎行事，离开了这里」→ `Outcome.nothing`
- **事件奖励随机到0（最小值=0）**：显示「你什么都没有得到」— 真实的随机感
- **玩家在事件中触发战斗**：战斗结束后回到探索地图（如果在战斗中死亡→按死亡处理）
- **战斗胜利后事件继续**：战斗后可能触发连锁事件或直接结束事件
- **玩家在事件进行中退出游戏**：下次读档回到事件前的节点（事件进度不保存），需要重新触发
- **同一地图多个同类型事件**：不允许（同一地图每种事件类型最多触发1次）
- **斜月三星洞被玩家错过**：行动力不足以走到该节点时，该地图的斜月三星洞机会永久丢失——鼓励玩家规划路线
- **连锁事件嵌套超过3层**：系统在3层后强制截断（最后层自动执行`nothing`）
- **事件奖励的卡牌已存在**：GSM允许重复卡牌的引用校验（卡牌可叠加，同名允许但非重复），事件系统不做去重，但UI应提示"已有此卡"
- **事件修改的境界/资源值超出上限**：GSM的校验会自动处理（修为溢出→存溢出字段；资源超过上限→截断到上限且日志警告）

## 依赖关系

| 依赖系统 | 性质 | 说明 |
|----------|------|------|
| **游戏状态管理器** | 硬依赖 | 所有事件条件判定和结果执行都通过GSM完成 |
| **探索系统** | 硬依赖 | 事件节点由探索系统在地图上分配和触发 |
| **战斗系统** | 软依赖 | 事件中的 trigger_battle 跳转到战斗场景 |
| **阵营系统** | 软依赖 | 事件条件可能涉及阵营判定（如魔道特定选项） |

### 上游依赖设计顺序

无上游依赖（事件系统独立设计）。但实际集成顺序建议：
游戏状态管理器 → 事件系统 + 探索系统（并行设计）

## 调优参数

| 参数 | 默认值 | 安全范围 | 过低影响 | 过高影响 |
|------|:-----:|:--------:|---------|---------|
| 连锁事件最大深度 | 3层 | 1-5 | 连锁叙事太短 | 事件内嵌太多失去节奏 |
| 同图同类型事件上限 | 1次 | 1-2 | 事件多样性受限 | 重复事件审美疲劳 |
| 事件权重基准范围 | 10-50 | 5-100 | 某类事件过于频繁 | 某类事件几乎不出现 |
| 斜月三星洞每图限次 | 1次 | 1 | — | 会导致核心奖励稀释 |
| 概率结果 chance 基准 | 0.6 | 0.3-0.9 | 玩家经常空手而归挫败感强 | 全概率事件=必然事件无惊喜 |
| 随机值范围波动 | ±30% | ±10%~±50% | 结果可预测无心跳感 | 方差太大影响平衡 |

## 视觉/音频需求

| 事件 | 动画 | 时长 |
|------|------|:----:|
| 事件面板弹出 | 从节点位置向上弹起的卡片式面板 | 0.3s |
| 选项选中 | 选中的选项高亮+其他选项淡出 | 0.2s |
| 结果展示 | 文本浮现+对应资源图标飞出到HUD | 0.5s |
| 随机值滚轮 | 在结果数值上快速滚动的数字动画（出随机奖励时） | 0.4s |
| 战斗触发 | 面板碎裂、淡出到战斗加载 | 0.5s |

### 音效需求
- 事件弹出：神秘的揭幕/卷轴展开声
- 选项选中：轻快的确认音
- 获得奖励：对应资源获取音效（灵石叮当、书页翻动）
- 未获得奖励：空荡的叹息声

## 用户界面需求

| 界面 | 触发场景 | 核心功能 |
|------|----------|----------|
| **事件面板** | 玩家到达事件节点 | 左上角事件类型标签（如"灵脉采掘"）；中央描述文本区域；底部2~4个选项按钮；背景为事件对应的氛围插画 |
| **结果提示** | 选项结算后 | 资源图标+数值变化动画；叙事文本输出（1~2行描述结果）；"继续"按钮 |
| **随机奖励动画** | 结果包含随机范围 | 带数字滚轮效果的中奖式展示；低概率高价值奖励使用金色/紫色特效 |
| **连锁事件提示** | 连锁触发时 | 事件面板不关闭，直接替换内容为连锁事件；顶部显示"连锁事件"标记 |

> **📌 用户体验标记—事件系统**：此系统有UI需求。在预生产中运行 `/ux-design` 为事件面板创建用户体验规格。

## 验收标准

- **GIVEN** 玩家移动到事件节点，**WHEN** 节点事件已配置，**THEN** 事件面板弹出，显示标题+描述+至少2个选项
- **GIVEN** 事件选项有阵营条件（魔道专属），**WHEN** 玩家阵营非魔道，**THEN** 该选项不可见
- **GIVEN** 事件选项有境界条件（筑基以上），**WHEN** 玩家为炼气，**THEN** 该选项不可见
- **GIVEN** 所有选项都不满足条件，**WHEN** 事件触发，**THEN** 显示默认"谨慎行事"选项
- **GIVEN** 玩家选择一个选项，**WHEN** 选项包含确定性结果（chance=1.0），**THEN** 结果必定执行
- **GIVEN** 玩家选择一个选项，**WHEN** 选项包含概率结果（chance=0.5），**THEN** 概率判定正确执行（多次测试中约50%触发）
- **GIVEN** 选项结果包含随机值范围（如灵石 50~150），**WHEN** 结算，**THEN** 值在范围内
- **GIVEN** 事件结果触发战斗，**WHEN** 选择该选项，**THEN** 加载战斗场景，战斗后回到探索
- **GIVEN** 事件结果 add_card，**WHEN** 结算，**THEN** 卡牌添加到GSM收藏
- **GIVEN** 事件结果 add_cultivation，**WHEN** 结算，**THEN** GSM修为增加对应值
- **GIVEN** 连锁事件触发，**WHEN** 当前事件结束，**THEN** 连锁事件立即弹出（不消耗行动力）
- **GIVEN** 连锁事件深度超过3层，**WHEN** 达到第4层，**THEN** 强制截断
- **GIVEN** 同一地图的斜月三星洞触发过一次，**WHEN** 再次到达该节点，**THEN** 节点显示为"已探索"
- **GIVEN** 事件触发后玩家退出游戏，**WHEN** 读档，**THEN** 未完成的事件不保存

## 待解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | 事件模板的数据存储方式——使用JSON配置文件（外部加载）还是Godot Resource（引擎原生）？JSON更易编辑和维护，Resource更有类型安全 | 数据架构 | 架构阶段决定 |
| 2 | 地图生成时事件池的配置方式——每个地图预定义一个事件池（静态配置），还是全局事件池按权重随机（动态）？当前倾向于每图预配置+全局补充 | 探索系统 | 探索系统设计时 |
| 3 | 斜月三星洞奖励品质随境界提升的映射表——炼气蓝→筑基紫→金丹金→元婴暗金，各品质的具体奖励内容 | 奖励设计 | 卡牌系统设计时 |
| 4 | 事件文本是否需要本地化？——如果需要支持英文/其他语言，事件文本的存储格式必须考虑i18n | 国际化 | 上线前决定 |
