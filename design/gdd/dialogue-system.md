# 对话系统 (Dialogue System)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-23
> **最后验证 (Last Verified)**：—
> **实现的支柱 (Implements Pillar)**：支柱4「始于凡人，忠于原著」

> **快速参考** — 层级：`叙事 (Narrative)` · 优先级：`Vertical Slice` · 关键依赖：`剧情系统`、`事件系统`、`游戏状态管理器`

## 概述

对话系统是游戏中所有角色对白和叙事文本的播放器——它不是内容创作工具（文本内容由剧情系统和事件系统提供），而是**对话的呈现引擎和条件分支解析器**。它管理对话树的数据结构、对话节点的条件可见性判定、对话播放的UI时序、以及对话选择的结果写入。

对玩家来说，对话系统是「与这个世界交谈」的界面——当你在坊市与NPC对话时、在事件节点做出选择时、在章节开头聆听引子时、在章末面对结局分支时，对话系统负责让文字有节奏地呈现、让选择有重量、让角色有声音。

对话系统的设计信条：**文字是修行路上的歇脚处，不是拖慢节奏的拦路石**。所有对话可跳过、所有选择可快速点选、没有无法跳过的长对白。

## 玩家幻想

| 情感 | 触发场景 |
|------|---------|
| **文字的节奏感** | 对话逐字浮现、关键句停顿半秒——「打字机效果让每句话都有分量」 |
| **角色活过来了** | 林渊说话时左侧是林渊的头像、苏剑鸣插话时头像切换——「能想象他们在说话」 |
| **选择有代价** | 三个选项，其中一个灰色不可选——「因为上一章我拒绝了墨渊，这个选项消失了」 |
| **不被打断的流畅** | 战斗后来一段2句话的NPC吐槽——「哈，这群废物连我一剑都接不住」——看完继续走 |
| **快速略过的自由** | 重玩时按住跳过键——所有对话3秒过完——「剧情我看过了，直接进入策略」 |
| **世界记得我** | 同一个NPC，上次见面说我「炼气小辈」，这次说「筑基道友」——条件文本让世界有反应 |

对话系统的核心情感不是长篇叙事的沉浸（那是视觉小说的目标），而是**角色存在的真实感**——每个人都对你说不同的话，同一句话因你的选择而不同。

## 详细设计

### 核心规则

#### 1. 对话数据结构

对话系统使用两层数据结构：`DialogueNode`（原子节点）和 `DialogueTree`（对话树）。

```
DialogueNode {
  id: String                          # 节点ID（如 "ch1_mo_yuan_01"）
  speaker: String                     # 说话者ID（如 "mo_yuan"、"narrator"）
  speaker_display: String             # 说话者显示名（如 "墨渊"、"旁白"）
  text: String                        # 对话文本（单条，建议≤80字）
  expression: String|null             # 说话者表情（如 "neutral", "angry", "smile", "hurt"）
  conditions: Condition[]|null        # 该节点是否可见的条件列表
  choices: DialogueChoice[]|null      # 该节点的选项（可选，null=纯叙事无选择）
  next_node: String|null              # 无选择时的下一个节点ID
  sfx: String|null                    # 播放音效（如 "voice_evil_laugh"）
  delay_ms: int                       # 该句播放后的停顿时间（默认400ms）
}

DialogueChoice {
  id: String                          # 选项ID
  text: String                        # 选项文本（≤30字）
  conditions: Condition[]|null        # 该选项是否可见的条件
  outcomes: DialogueOutcome[]|null    # 选择后的状态变更
  next_node: String|null              # 选择后跳转的节点ID
  tooltip: String|null                # 选项提示（悬停时显示影响预览）
}

DialogueOutcome {
  type: Enum [set_flag, add_resource, add_card, trigger_battle, 
              advance_chapter, change_relation, nothing]
  target: String                      # 目标（flag名/资源类型/卡牌ID等）
  value: Variant                      # 值
}

DialogueTree {
  id: String                          # 对话树ID
  title: String                       # 内部标题（如 "ch1_boss_pre_fight"）
  trigger_type: Enum [story, event, bark, shop, camp, chapter_intro, chapter_end]
  nodes: Dictionary<String, DialogueNode>  # {node_id: DialogueNode}
  start_node: String                  # 入口节点ID
  end_action: String|null             # 对话结束后执行的动作（如 "start_battle:mo_yuan_boss"）
  allow_skip: bool                    # 是否允许整段跳过（默认true）
  max_display_ms: int                 # 最长自动播放时间（0=不自动，由玩家点击推进）
}
```

#### 2. 对话类型

| 类型 | 触发场景 | 节点数 | 选择 | 可跳过 | 示例 |
|------|---------|:-----:|:----:|:-----:|------|
| **story（剧情对话）** | 章节必经事件、关键剧情节点 | 3~8 | 有 | 整段可跳 | 「墨渊夺舍前与林渊的对话」 |
| **event（事件对话）** | 探索事件触发 | 1~4 | 2~4选1 | 整段可跳 | 「坊市老板：『道友要买点什么？』」 |
| **chapter_intro（章节引子）** | 每章开始时 | 2~4 | 无 | 可跳过 | 「第一话：青云入世——引子文本」 |
| **chapter_end（章末结局）** | 章末BOSS战后 | 3~5 | 2~3选1 | 不可跳 | 「面对墨渊的残魂，你的选择…」 |
| **bark（短对话）** | 商店/NPC路过/战斗后/营寨 | 1 | 无 | 自动消失 | 「林渊：『这瓶丹药……品质不错』」 |
| **shop（商店对话）** | 进入商店 | 1~2 | 无 | 可跳过 | 「坊市掌柜：『道友请随意挑选』」 |

**各类对话播放模式：**

| 类型 | 播放方式 | 推进方式 | 跳过行为 |
|------|---------|---------|---------|
| story | 逐句播放（打字机+点击推进） | 点击/按键 | 跳过整段，不触发结果 |
| event | 逐句播放+选项面板 | 点击选项 | 跳过到选项面板 |
| chapter_intro | 滚动文本（自动/手动快进） | 点击继续 | 直接进入探索 |
| chapter_end | 分步展示（回顾→抉择→确认） | 点击选项 | 不可跳过（必须选） |
| bark | 浮动气泡（3秒后自动消失） | 自动 | 点击气泡立刻消失 |
| shop | 顶部横幅文字（非阻塞） | 自动消失 | — |

#### 3. 条件系统（Condition Resolver）

对话节点和对话选项的可见性由条件系统判定。条件系统复用事件系统的 Condition 结构，并扩展：

```
Condition {
  type: Enum [
    story_flag,          # 剧情标记（story_flags中的flag）
    identity,            # 本局身份
    realm,               # 当前境界
    faction,             # 阵营（正道/魔道）
    card_owned,          # 是否拥有某卡牌
    chapter_completed,   # 是否已完成某章节
    relation,            # NPC好感度（未来系统）
    has_item,            # 是否持有某物品
    combat_result,       # 上一场战斗结果（win/loss）
    always               # 始终满足（兜底选项）
  ]
  operator: Enum [==, !=, >=, <=, <, >, has, not_has]
  value: Variant
}
```

**条件判定流程：**

```
evaluate_conditions(conditions, gsm_state) → bool:
  if conditions == null or conditions == []:
    return true  # 无条件 = 始终可见
  
  for cond in conditions:
    result = evaluate_single(cond, gsm_state)
    if not result:
      return false  # 任一条件不满足则不可见
  
  return true  # 全部满足

evaluate_single(cond, gsm_state) → bool:
  match cond.type:
    story_flag:     return gsm_state.narrative.story_flags[cond.target] == cond.value
    identity:       return gsm_state.player.identity_id == cond.value
    realm:          return gsm_state.player.realm_level >= cond.value (operator == >= 时)
    faction:        return cond.value in gsm_state.player.factions
    card_owned:     return cond.value in gsm_state.collection.owned_cards
    chapter_completed: return cond.value in gsm_state.narrative.completed_chapters
    relation:       return gsm_state.narrative.relations[cond.target] >= cond.value
    has_item:       return gsm_state.player.resources[cond.target] >= cond.value
    combat_result:  return gsm_state.battle.last_result == cond.value
    always:         return true
```

**可见 vs 灰色（不可见）：**

| 元素 | 条件不满足时的行为 |
|------|------------------|
| 对话节点（node） | 跳过该节点，直接进入下一个满足条件的节点 |
| 对话选项（choice） | **灰色显示+简短提示**（如「需要：拒绝墨渊条件」），而非完全隐藏 |

> **设计理由**：事件系统的选择是完全隐藏不满足条件的选项（因为事件是「你能做什么」），但对话系统的选择是灰色显示+原因提示（因为对话是「世界在对你反应」——灰色的选项告诉玩家「如果你做了不同选择，这里会不一样」，增强选择的重玩动力）。

#### 4. 对话播放引擎

对话系统的核心是逐句播放引擎：

```
play_dialogue_tree(tree_id, gsm_state):
  tree = DIALOGUE_DATABASE[tree_id]
  current_node = tree.nodes[tree.start_node]
  
  while current_node != null:
    ① 评估 current_node.conditions：
       if not 满足 → 跳过到下一个满足条件的节点（不显示）
    ② 加载说话者头像/名称
    ③ 显示对话文本（打字机效果，可点击跳过打字）
    ④ 等待玩家点击推进
    ⑤ 如果当前节点有 choices：
       → 展示选择面板
       → 过滤：评估每个 choice.conditions
       → 满足条件的选项→正常显示
       → 不满足条件的选项→灰色+提示
       → 玩家选择一个选项
       → 执行 choice.outcomes（通过GSM）
       → current_node = choice.next_node
    ⑥ 如果无 choices：
       → current_node = current.next_node
    ⑦ 如果 current_node == null：
       → 执行 tree.end_action（如有）
       → 关闭对话
```

**打字机效果参数：**

| 参数 | 默认值 | 说明 |
|------|:-----:|------|
| 基础速度 | 40字/秒 | 每字符约25ms |
| 标点停顿 | +150ms | 句号/问号/感叹号后额外停顿 |
| 逗号停顿 | +80ms | 逗号/分号后额外停顿 |
| 点击快进 | 立即显示全文 | 点击或按空格跳过打字机动画 |
| 长按跳过 | 3×速度 | 按住Ctrl时加速播放 |
| 自动推进 | 关闭 | 默认需要点击推进，非自动 |

#### 5. 对话中的身份/条件文本变体

同一个对话节点可以有多个文本变体，根据条件选择显示哪个：

```
# 示例：坊市老板对不同境界玩家的招呼
DialogueNode "shop_greet_01":
  text_variants: [
    {text: "这位炼气小友，随便看看，别碰坏了东西。", condition: {type: realm, op: "==", value: 1}},
    {text: "道友筑基有成，老朽这里的货色可要好好看看了。", condition: {type: realm, op: "==", value: 2}},
    {text: "金丹前辈光临小店，真是蓬荜生辉！请随意挑选。", condition: {type: realm, op: ">=", value: 3}},
  ]
  default_text: "道友请随意挑选。"
```

文本变体解析优先选择**第一个满足条件的变体**；如果都不满足，使用 `default_text`。

#### 6. NPC 角色定义

对话系统维护一个 NPC 角色表，每个角色有固定的说话者ID、显示名和默认头像：

```
NPCProfile {
  speaker_id: String          # 内部ID（如 "lin_yuan"、"mo_yuan"）
  display_name: String        # 显示名（如 "林渊"、"墨渊"）
  default_portrait: String    # 默认头像资源路径
  expressions: {              # 表情变体
    "neutral": "res://assets/portraits/lin_yuan_neutral.png",
    "angry": "res://assets/portraits/lin_yuan_angry.png",
    "smile": "res://assets/portraits/lin_yuan_smile.png",
    "hurt": "res://assets/portraits/lin_yuan_hurt.png"
  }
  faction: String|null        # 所属阵营
  first_appearance_chapter: int  # 首次出场章节
}
```

**旁白（narrator）** 是一个特殊的说话者ID——无头像，文本以斜体居中显示，用于叙境描写（如「一个月后……」「苍玄古战场，血流成河……」「你感到一股不知名的力量在暗中注视着你……」）。

#### 7. 对话触发点

对话系统在以下游戏环节被触发：

| 触发点 | 对话类型 | 触发方式 | 对话树ID来源 |
|--------|:------:|---------|------------|
| **探索·事件节点** | event | 探索系统→事件系统→对话系统 | 事件模板的 `dialogue_tree_id` |
| **探索·商店节点** | shop + bark | 探索系统→商店系统→对话系统 | 商店模板的 `greeting_dialogue_id` |
| **探索·NPC节点** | story | 探索系统→剧情系统→对话系统 | 地图配置的NPC对话ID |
| **章节开始** | chapter_intro | 剧情系统→对话系统 | 章节模板的 `intro_dialogue_id` |
| **章节末BOSS战后** | chapter_end | 剧情系统→对话系统 | 章节模板的 `ending_dialogue_id` |
| **战斗胜利后** | bark | 战斗系统→对话系统 | 角色配置的 `victory_bark` |
| **营寨·炼丹/炼器** | bark | 炼丹炼器系统→对话系统 | 角色配置的 `craft_bark` |
| **营寨·卡组编辑** | bark | 卡组编辑系统→对话系统 | 角色配置的 `deck_edit_bark` |

**bark池机制**：每个角色有一个 bark 池（如 `lin_yuan_barks = ["这瓶丹药品质不错。", "还差点火候…", "再来一次。"]`），触发时从池中随机抽取（同一局中不重复，池耗尽后重置）。

#### 8. 对话状态管理

对话系统在 GSM 中不维护独立的数据域。对话的**副作用**（story_flags 变更、资源变更、章节推进）直接写入对应的GSM域。

```
# 对话结束后可能写入GSM的动作
execute_outcomes(outcomes):
  for outcome in outcomes:
    match outcome.type:
      set_flag:         GSM.narrative.story_flags[outcome.target] = outcome.value
      add_resource:     GSM.player.resources[outcome.target] += outcome.value
      add_card:         GSM.collection.owned_cards.append(outcome.value)
      trigger_battle:   战斗系统加载战斗
      advance_chapter:  剧情系统推进章节
      change_relation:  GSM.narrative.relations[outcome.target] += outcome.value
      nothing:          # 纯叙事，无状态变更
```

**对话进度不保存**——如果玩家在对话中途退出游戏，读档后对话不恢复（对话不是可中断的状态机）。对话结果（outcomes）在玩家做出选择时立即写入GSM，所以选择的影响会保存。

#### 9. 对话内容存储格式

对话数据以 Godot Resource 文件（`.tres`）或 JSON 文件存储，按章节组织：

```
assets/dialogue/
├── ch1_qingyun/
│   ├── ch1_intro.json                  # 第1章引子
│   ├── ch1_mo_yuan_confront.json       # 墨渊对峙
│   ├── ch1_ending.json                 # 第1章结局分支
│   └── ch1_events.json                 # 第1章事件对话集合
├── ch2_suixing/
│   ├── ch2_intro.json
│   ├── ch2_zhanchang.json              # 正魔大战
│   ├── ch2_ending.json
│   └── ch2_events.json
├── ...
├── shared/
│   ├── shop_greetings.json         # 通用商店问候
│   ├── npc_barks.json              # 全角色bark池
│   └── npc_profiles.json           # NPC角色定义
└── dialogue_index.json             # 对话树索引（ID→文件路径映射）
```

> **设计理由**：JSON格式便于策划直接编辑（无需Godot编辑器），且支持外部工具批量校验对话条件和文本一致性。

#### 10. 对话与音频的配合

对话系统通过音频系统播放角色语音和氛围音：

| 对话事件 | 音频 |
|---------|------|
| 打字机逐字输出 | 每个字符触发轻微的"书写声"（可选，设置中可关闭） |
| 新说话者出现 | 该角色的"发声"音效（短促音阶，区分角色） |
| 选项出现 | 轻微的"选择提示音" |
| 重要剧情节点 | 背景音乐短暂变调或淡入叙事BGM |
| bark气泡弹出 | 轻快的"气泡出现"音效 |

**角色语音设计**：本作不包含完整的语音演出（独立游戏预算约束），每个角色仅有：
- 1个「发声」短音效（说话者出现时播放，0.3s）
- 1个「情绪反应」短音效（惊恐/愤怒/喜悦，0.5s）
- 无完整配音台词

### 状态与转换

```
对话系统状态机（播放器侧）：

[空闲] ──play_dialogue_tree(id)──→ [播放中·打字]
                                         ↓ 点击/打字完成
                                    [播放中·等待]
                                         ↓ 点击推进
                                    [下一句] ──→ 循环或
                                         ↓
                                    [显示选项] ──→ 玩家选择 → [结算outcomes]
                                         ↓
                                    [对话结束] ──→ 执行end_action → [空闲]

特殊状态：
[播放中·打字] ──点击跳过──→ [立即显示全文] → [播放中·等待]
[播放中·打字] ──按住Ctrl──→ [加速播放 3×速度]
[任意播放状态] ──跳过整段──→ [对话关闭] → [空闲]（chapter_end不可跳过）
```

### 与其他系统的交互

| 系统 | 数据流入（本系统→目标） | 数据流出（目标→本系统） |
|------|----------------------|---------------------|
| **游戏状态管理器** | 对话 outcomes 写入 story_flags、resources、collection、relations | 读取所有条件判定所需的状态（identity、realm、story_flags、faction、card_owned 等） |
| **剧情系统** | 章节引子/结局对话的结果写入 story_flags | 对话树ID（来自章节模板）；对话触发指令 |
| **事件系统** | 事件对话的结果写入资源/卡牌/story_flags | 对话树ID（来自事件模板）；事件对话触发指令 |
| **音频系统** | 播放角色发声、打字机音效、叙事BGM切换 | — |
| **战斗系统** | trigger_battle outcome | 战斗结果（用于 combat_result 条件判定） |
| **商店系统** | — | 商店问候对话ID |
| **开局身份选择系统** | — | 身份ID（用于 identity 条件判定） |
| **UI系统** | 对话面板渲染数据（说话者、文本、选项） | 玩家交互（点击推进、选择选项、跳过） |

## 公式

### 1. 条件可见性判定

```
evaluate_node(node, state) → {visible: bool, skip_reason: String}:
  if node.conditions == null or node.conditions == []:
    return {true, ""}
  
  for cond in node.conditions:
    if not evaluate_single(cond, state):
      return {false, format_skip_reason(cond)}
  
  return {true, ""}

evaluate_choice(choice, state) → {visible: bool, grey: bool, tooltip: String}:
  if choice.conditions == null or choice.conditions == []:
    return {true, false, ""}
  
  for cond in choice.conditions:
    if not evaluate_single(cond, state):
      return {true, true, format_condition_hint(cond)}  # 可见但灰色
      # 注意：不同于节点的完全跳过——选项始终可见但可能灰色
  
  return {true, false, ""}

format_condition_hint(cond) → String:
  match cond.type:
    story_flag:   "需要前置剧情条件"
    identity:     "需要身份：{cond.value}"
    realm:        "需要境界≥{cond.value}"
    faction:      "需要阵营：{cond.value}"
    card_owned:   "需要拥有卡牌：{cond.value}"
    relation:     "需要与{cond.target}好感度≥{cond.value}"
    ...
```

### 2. 文本变体选择

```
select_text_variant(node, state) → String:
  if node.text_variants == null:
    return node.text  # 固定文本
  
  for variant in node.text_variants:
    if evaluate_single(variant.condition, state):
      return variant.text
  
  return node.default_text
```

### 3. 打字机播放时间估算

```
estimate_typing_duration(text, speed=40) → float:
  base_ms = len(text) / speed × 1000
  punctuation_pauses = count_punctuation(text, ['.','!','?']) × 150ms
  comma_pauses = count_punctuation(text, [',',';']) × 80ms
  return base_ms + punctuation_pauses + comma_pauses

# 示例：80字中等文本，约2~3秒打字时间
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|:----:|------|
| speed | int | 20~60 | 每秒显示字数 |
| text_length | int | 1~200 | 单条对话文本长度 |
| delay_ms | int | 200~800 | 该句播放后停顿 |

## 边界情况

- **对话中途退出游戏**：对话不保存进度——下次读档时对话从头开始或从触发点重新触发。但 options 选择后的 outcomes 已写入 GSM（即时写入），因此选择的影响已保存
- **同一对话树被多次触发**：每次触发从头播放——对话树是可重入的
- **对话条件导致所有选项都灰色不可选**：保留至少1个无条件的兜底选项（如「……（沉默）」），确保对话不会卡死
- **对话条件导致整段对话无可见节点**：play_dialogue_tree 检测到所有节点都不满足条件时，直接返回（不显示任何对话面板），记录日志警告
- **文本变体全部不满足条件**：使用 `default_text`——每个有 `text_variants` 的节点必须提供 `default_text`
- **说话者ID在NPC角色表中不存在**：使用通用占位头像+黄色警告日志（策划配置错误）
- **玩家快速连点跳过时outcomes重复执行**：outcomes在第一次选择时写入GSM并标记"已执行"，连点不会重复触发
- **对话树引用的下一个节点ID不存在**：视为对话结束（截断），记录红色错误日志
- **bark池耗尽**：同一局游戏中，一个角色的bark池全部触发后重置全部（从头开始随机）——而非静默。重置时选择与上一句不同的bark
- **对话中触发战斗（trigger_battle outcome）**：对话关闭→短暂黑屏→加载战斗场景。战斗结束后不返回对话（对话已完成）
- **多个对话触发请求同时到达**：按优先级排队——bark > story = event > shop。后到达的请求覆盖前一个（不排队），当前对话被打断后不恢复
- **chapter_end对话不可跳过**：章末结局分支是叙事决策——跳过了等于随机选。保护玩家的叙事主体性
- **所有对话树ID引用验证**：游戏启动时校验 `dialogue_index.json` 中所有引用的文件是否存在——缺失文件记录错误但游戏不崩溃（缺文件时显示fallback文本「[对话缺失：{id}]」）
- **超长文本（>200字）**：系统不强制截断——但如果文本过长，UI应支持滚动（对话面板最多显示4行，超出部分滚动查看）。但建议策划将>200字的对白拆分为多个节点
- **同一角色连续说话**：头像不变、只更新文本——这是自然的小说式叙事节奏。不同角色交替说话时头像切换

## 依赖关系

| 依赖系统 | 性质 | 说明 |
|----------|:----:|------|
| **游戏状态管理器** | 硬依赖 | 条件判定读取GSM数据；outcomes写入GSM |
| **剧情系统** | 硬依赖 | 章节引子/结局/剧情事件的对话树ID来源 |
| **事件系统** | 硬依赖 | 事件对话的触发来源 |
| **开局身份选择系统** | 软依赖 | identity条件判定需要身份ID |
| **音频系统** | 软依赖 | 角色发声、打字机音效、BGM切换 |
| **战斗系统** | 软依赖 | trigger_battle outcome; bark触发（战斗胜利后） |
| **UI系统** | 硬依赖 | 对话面板、选择面板、bark气泡的渲染 |

### 上游依赖设计顺序

剧情系统 + 事件系统 + 游戏状态管理器（均已设计）→ **对话系统** → 结局分支系统

对话系统处于叙事层的中间——它接收剧情系统和事件系统的对话触发请求，解析条件后通过UI呈现，并将玩家选择的结果写回GSM。

## 调优参数

| 参数 | 默认值 | 安全范围 | 过低影响 | 过高影响 |
|------|:-----:|:--------:|---------|---------|
| 打字机速度 | 40字/秒 | 20~60 | 对话太慢拖节奏 | 文字太快来不及读 |
| 句末停顿 | 150ms | 80~300ms | 句子衔接太紧 | 节奏太拖 |
| 逗号停顿 | 80ms | 40~150ms | 句子太赶 | 停顿太多 |
| 单条对话文本上限 | 200字 | 100~300 | 限制太紧难写 | 文本过长玩家跳过 |
| 对话选项数上限 | 4 | 2~5 | 选择太少 | 选择太多决策疲劳 |
| 选项文本长度上限 | 30字 | 20~40 | 选项含义不清 | 选项太长读不动 |
| bark显示时长 | 3秒 | 2~5秒 | 还没读完就消失 | 占屏幕太久 |
| bark池大小（每角色） | 5~8条 | 3~15 | 重复太快 | 文本工作量大 |
| 角色表情数 | 4 | 3~6 | 表情变化太少 | 美术工作量大 |
| NPC角色总数 | ~20 | 15~30 | 角色太少世界空 | 每个角色内容太薄 |
| 对话树最大节点数 | 15 | 8~25 | 对话太短 | 对话太长失去节奏 |
| 长按加速倍率 | 3× | 2×~5× | 加速太慢没感觉 | 加速太快看不清 |

## 视觉/音频需求

| 事件 | 动画 | 时长 |
|------|------|:----:|
| 对话面板入场 | 从屏幕底部滑入（或从侧边展开） | 0.25s |
| 说话者切换 | 头像短暂缩放（1.05×→1.0）+ 名称淡入淡出 | 0.2s |
| 打字机文本 | 逐字显现（无动画曲线，直接出现）+ 光标闪烁 | 持续 |
| 选项面板展开 | 选项按钮从下方依次弹入（每个延迟0.05s） | 0.3s |
| 选项选中 | 选中按钮短暂高亮+其他选项淡出 | 0.2s |
| bark气泡 | 从说话角色头顶弹出+3秒后淡出 | 0.15s入场 |
| 对话面板退场 | 向下滑出 | 0.2s |
| 章节引子展示 | 古籍卷轴展开效果+文字从右至左逐列显示 | 0.6s入场 |

### 音频需求
- 打字机逐字：轻柔的"笔画声"或"键盘敲击声"（可关闭）
- 说话者出现：角色专属短音效（林渊=沉稳低音、苏剑鸣=轻快中音、月清霜=清脆高音等）
- 对话选项出现：「叮」的轻微提示音
- 选项确认：沉稳的确认音
- bark弹出：轻快的"气泡声"
- 章节引子：叙事氛围BGM（每章不同主题）

## 用户界面需求

| 界面 | 触发场景 | 核心功能 |
|------|----------|----------|
| **对话面板** | 触发 story/event/chapter_intro 对话时 | 屏幕底部 70%宽×25%高面板；左侧为说话者头像（圆形，80×80px）+表情切换动画；头像右侧：说话者名称+文本区（最多4行，打字机效果）；底部细进度条（当前节点/总节点） |
| **选项面板** | 对话节点有choices时 | 从对话面板上方扩展：选项以按钮形式垂直排列，每个选项含文本+条件提示（灰色时）；最多4个选项；键盘快捷键（1/2/3/4）快速选择 |
| **bark气泡** | 触发bark对话时 | 从触发角色/场景位置弹出的无边框气泡，2~3行文本，3秒后自动淡出；点击立刻消失；不影响玩家操作（非阻塞） |
| **章节引子屏** | 每章开始时 | 全屏叙事面板（替代对话面板）：居中古籍卷轴背景+章节标题+引子文本（逐行淡入）；底部"[点击继续]"提示 |
| **章末结局屏** | 章末BOSS战后 | 全屏叙事面板：章节回顾（1~2句）+ 分支选项列表（2~3选1）+ 不可撤销提示；选择后展开确认按钮 |
| **对话历史** | 按H键（任意对话中） | 透明浮层展示本次对话迄今所有已显示的文本（只读滚动），松手关闭——帮助错过某句的玩家回顾 |

> **📌 用户体验标记—对话系统**：此系统有UI需求。在预生产中运行 `/ux-design` 为对话面板、选项面板和bark气泡创建用户体验规格。

## 验收标准

- **GIVEN** 对话树有3个节点，**WHEN** 播放对话，**THEN** 逐句展示，每句需要点击推进
- **GIVEN** 对话节点有条件（realm≥筑基），**WHEN** 当前境界=炼气，**THEN** 该节点被跳过，显示下一个满足条件的节点
- **GIVEN** 对话选项有条件（story_flag: ch1_accepted_mo_condition=true），**WHEN** 该flag=false，**THEN** 选项灰色显示+提示"需要前置剧情条件"
- **GIVEN** 对话选项无条件，**WHEN** 显示选项面板，**THEN** 选项正常可点击
- **GIVEN** 玩家点击选项，**WHEN** 选项有outcome（set_flag），**THEN** GSM中该flag立即更新
- **GIVEN** 对话节点有text_variants（基于realm），**WHEN** 当前境界=金丹，**THEN** 显示金丹对应的文本变体
- **GIVEN** 旁白节点（speaker=narrator），**WHEN** 播放，**THEN** 文本居中斜体显示，无头像
- **GIVEN** story类型对话播放中，**WHEN** 玩家点击跳过按钮，**THEN** 整段对话关闭，不触发outcomes
- **GIVEN** chapter_end类型对话播放中，**WHEN** 玩家尝试跳过，**THEN** 跳过按钮不可用/隐藏
- **GIVEN** bark触发，**WHEN** 显示，**THEN** 3秒后自动消失；点击立刻消失
- **GIVEN** 同一角色bark池有5条，**WHEN** 连续触发6次bark，**THEN** 前5次各不相同，第6次重置池并重新随机
- **GIVEN** 对话中玩家退出游戏，**WHEN** 读档，**THEN** 对话不恢复，但已选择的outcomes已保存
- **GIVEN** 对话节点引用不存在的next_node，**WHEN** 播放到该节点，**THEN** 对话安全结束，记录错误日志
- **GIVEN** 对话树所有节点的conditions都不满足，**WHEN** 尝试播放，**THEN** 对话面板不显示，记录日志警告
- **GIVEN** 所有对话选项（含无条件选项）都grey且玩家必须选择，**WHEN** 存在无条件兜底选项，**THEN** 兜底选项无grey显示
- **GIVEN** 打字机播放中，**WHEN** 玩家点击，**THEN** 立即显示该句全文
- **GIVEN** 打字机播放中，**WHEN** 玩家按住Ctrl，**THEN** 播放速度×3
- **GIVEN** 对话树有end_action（start_battle），**WHEN** 对话结束，**THEN** 触发战斗加载
- **GIVEN** 第1章引子对话，**WHEN** 播放完毕，**THEN** 进入探索地图
- **GIVEN** bark触发时正在播放story对话，**WHEN** bark到达，**THEN** bark打断当前对话，对话不恢复

## 待解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | 对话文本的总量预估——每章多少条对话？当前估算：5章×(1段引子+1段结局+4~6段剧情对话+8~12段事件对话)≈16~22段对话树×5章=80~110段对话树。需要确认写作资源 | 内容预算 | 预生产阶段确认写作资源 |
| 2 | NPC角色表的设计——哪些角色有专属肖像和表情？当前建议核心角色（林渊、苏剑鸣、墨渊、月清霜等~12人）有4表情头像，次要角色用通用头像 | 美术预算 | 美术圣经阶段确定 |
| 3 | 对话文本是否需要本地化？当前文本量~100段对话树×平均5句=500条文本，加上bark池~100条，共~600条。英文本地化工作量中等 | 国际化 | 如有海外发行计划则需在预生产中规划 |
| 4 | 是否需要「对话日志」功能（查看历史对话）？当前设计在"对话历史"UI中包含此功能 | 用户体验 | 已包含在UI需求中 |
| 5 | 打字机音效是否需要为不同角色使用不同音色？当前设计使用统一的打字机音效。差异化音色会增加音频资产但增强角色个性 | 音频预算 | 音频设计时确定 |
| 6 | bark打断story对话的行为是否合适？当前设计为打断不恢复——更适合短bark（如「小心！」），但可能打断长剧情对话。考虑改为bark排队等待当前句结束 | 用户体验 | 原型阶段测试两种方案 |