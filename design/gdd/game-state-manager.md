# 游戏状态管理器 (Game State Manager)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-23
> **最后验证 (Last Verified)**：2026-07-23（设计审查 / design-review）
> **实现的支柱 (Implements Pillar)**：支柱2「苟道成长，步步为营」

## 概述

游戏状态管理器（GSM）是游戏运行时的单一数据源（Single Source of Truth），负责维护所有全局游戏状态——包括当前境界、修为值、灵石/灵材数量、已收集卡牌、装备绑定关系、探索进度、战斗临时状态等。GSM以 Godot Autoload 单例的形式常驻内存，为所有系统提供统一的 read/write 接口，并通过信号系统广播状态变更事件，确保各系统之间的数据一致性。

对玩家来说，GSM是不可见的后台系统，但它的质量直接影响游戏体验：修炼突破后修为即时更新、战斗结束后资源准确结算、探索进度不会因场景切换丢失、读档后回到完全一致的状态。GSM的好坏决定了玩家是否能够**信任这个游戏世界**——状态丢失或不一致是最破坏沉浸感的问题。

暂无相关ADR。

## 玩家幻想

玩家从不直接操作GSM，但它的质量决定了玩家对游戏的**信任感**。当玩家在坊市买了一张金色功法→回到战斗发现功法确实在手牌中；当玩家花了1小时探索地图→读档后一切分毫不差；当渡劫突破后修为、卡牌池、敌人强度都正确反映新的境界——玩家不会注意到GSM的存在，而正是这种"不被注意到"就是GSM最大的成功。

GSM的核心情感不是兴奋或满足，而是**可靠**——它是那个永远把账算对的幕后管家，让玩家可以放心地把注意力放在策略和叙事上。

## 详细设计

### 核心规则

#### 1. 数据层级结构

GSM 维护一个分层的游戏状态树，根节点为 `GameState`，按功能域划分为以下层级：

```
GameState（根）
├── meta                    # 运行元数据（局ID、种子、时间戳）
├── player                  # 玩家核心数据
│   ├── realm               # 当前境界
│   ├── cultivation         # 当前修为值
│   ├── max_cultivation     # 突破所需修为上限
│   ├── overflow_pool       # 溢出修为池（突破后按比例转化为属性丹，见 cultivation-system.md §溢出转化）
│   ├── resources           # {灵石, 灵材, 丹药碎片, ...}
│   ├── identity_id         # 本局选择的开局身份ID
│   └── talents             # 已激活的轮回天赋列表
├── collection              # 卡牌收藏
│   ├── owned_cards         # 拥有的全部卡牌（模板ID列表）
│   └── total_count         # 总收藏量（用于统计和成就）
├── deck                    # 当前卡组
│   ├── character_slots     # 角色位 [position_1~6]（每位置包含角色卡 ID，空位为 null）
│   ├── current_deck        # 当前卡组（30-40张卡牌模板ID列表）
│   └── presets             # 卡组预设列表（多套卡组）
├── battle                  # 战斗状态（运行时，不持久化）
│   ├── field               # 战场布局（阵位、阵法、绑定）
│   ├── turn                # 当前回合数
│   ├── hand                # 手牌列表
│   ├── snapshot_realm      # 【战斗快照】战斗开始时锁定的境界
│   └── temp_effects        # 战斗中临时效果列表
├── exploration             # 探索进度
│   ├── current_map_id      # 当前地图ID
│   ├── node_position       # 当前所在格位置
│   ├── action_points       # 当前行动力
│   ├── revealed_nodes      # 已探索的节点ID列表
│   └── map_state           # 地图的完整状态（各节点的事件、奖励等）
├── narrative               # 剧情状态
│   ├── current_chapter     # 当前章节
│   ├── completed_chapters  # 已完成章节列表
│   └── story_flags         # 剧情触发标记字典
├── progression             # 跨局元进度（轮回保留）
│   ├── highest_realm       # 历史最高境界
│   ├── total_playtime      # 累计游戏时间
│   ├── unlocked_cards      # 已解锁的卡牌永久收录
│   ├── unlocked_talents    # 已解锁的轮回天赋
│   └── achievements        # 成就进度
└── session                 # 会话临时状态（不持久化）
    ├── current_scene       # 当前场景路径
    ├── ui_state            # UI 暂存状态（打开的窗口等，由各 UI 系统维护）
    └── input_locks         # 输入锁定状态（由场景管理器/UI系统管理——阻止玩家在转场/动画期间操作）
```

#### 2. 读写接口规范

GSM 对外提供统一的三层接口：

**读取接口（Read）——无副作用，任何系统随时可调用：**

```
get(path: String) → Variant                    # 按路径读取，如 "player.realm"
                                               # 路径以 "." 分隔逐级访问；键名不得包含 "."（含点的键请用下划线替代）
get_player_realm() → Enum                      # 强类型快捷读取
get_resource(type: Enum) → int                 # 资源数量查询
get_owned_cards() → Array[String]              # 已收藏卡牌列表
get_field_characters() → Array[CharacterData]  # 当前场上角色列表
```

**写入接口（Write）——通过GSM写入，触发信号广播：**

```
set(path: String, value: Variant)               # 通用写入，自动类型校验
add_cultivation(amount: int)                    # 修为增加（含上限校验+溢出处理，溢出逻辑见 cultivation-system.md §修为获取）
spend_resource(type: Enum, amount: int) → bool  # 资源消费（含余额校验，失败返回false）
add_card_to_collection(card_id: String)         # 添加卡牌收藏（含引用完整性校验）
allocate_card_instance_id() → int               # 分配全局唯一单调递增卡牌实例ID（供 card-system 调用）
battle_start()                                  # 初始化战斗状态快照
battle_end(result: Enum)                        # 清理战斗状态并结算
enable_validation(card_db: Dictionary) → void   # 注入卡牌模板库引用，开启校验（一次性调用，由 card-system 在 _ready() 中调用）
```

**订阅接口（Subscribe）——状态变更事件监听：**

```
subscribe(event: Enum, callback: Callable)      # 订阅状态变更事件
unsubscribe(event: Enum, callback: Callable)    # 取消订阅
```

#### 3. 信号广播机制

每次通过GSM写入接口修改状态后，自动广播对应的事件：

| 事件 | 触发时机 | 载荷 | 监听方示例 |
|------|---------|------|-----------|
| `realm_changed` | 境界突破完成 | `{old_realm, new_realm}` | 战斗系统（重算境界压制）、探索系统（解锁新地图） |
| `cultivation_changed` | 修为增减 | `{delta, current, max}` | UI修为条、境界突破系统 |
| `cultivation_full` | 修为达到当前上限 | `{current, max}` | 境界突破系统（触发"可以突破"提示） |
| `resource_changed` | 灵石/灵材变更 | `{type, delta, balance}` | UI资源显示、探索事件结果 |
| `action_points_changed` | 行动力变更 | `{delta, current, max}` | 探索UI行动力条 |
| `deck_modified` | 卡组增删卡牌 | `{card_id, action}` | 卡组编辑UI |
| `battle_started` | 进入战斗 | `{enemy_id, seed}` | 上场阵位系统、战斗系统 |
| `battle_ended` | 战斗结束 | `{result, rewards}` | 资源结算、探索系统 |
| `scene_changed` | 场景切换 | `{from_scene, to_scene}` | UI系统、音频系统 |
| `card_collection_changed` | 获得/删除卡牌 | `{card_id, action}` | 收藏库UI |
| `game_initialized` | 游戏启动完成 | `{}` | 主菜单系统、所有初始化监听方 |
| `progression_reset` | 跨局进度被重置 | `{reason}` | UI系统（警告提示） |
| `batch_updated` | 批量状态修改（战斗结算等） | `{changes: Dictionary[path, {old, new}]}`（展平的合并 Dict） | UI系统（集中刷新） |

**广播规则：**
- 同一帧内多次修改同一状态 → 仅广播最后一次变更（去重）
- 批量修改（如战斗结算时灵石+修为+卡牌同时变化）→ 广播一个 `batch_updated` 事件，带全部变更的载荷
- 监听方不应在回调中再次修改同一状态（防止循环）

#### 4. 运行时状态 vs 持久化状态

| 状态域 | 持久化方式 | 说明 |
|--------|-----------|------|
| `meta` | 存档/读档 | 运行元数据 |
| `player` | 存档/读档 | 玩家核心进度 |
| `collection` | 存档/读档 | 卡牌收藏为永久数据 |
| `deck` | 存档/读档 | 当前卡组和预设 |
| `exploration` | 存档/读档 | 探索进度（包括当前地图状态） |
| `narrative` | 存档/读档 | 剧情进度 |
| `progression` | 玩家本地文件 | 跨局元进度独立存储，不随存档重置 |
| `battle` | **不持久化** | 战斗中的临时状态；战斗中存档 → 保存非战斗状态，战斗中止视为未发生 |
| `session` | **不持久化** | 运行时临时状态，每次启动重置 |

**保存/加载职责边界：** GSM仅提供 `serialize() → Dictionary` 和 `deserialize(data: Dictionary) → bool` 接口。存档/读档系统（系统#2）负责实际的I/O操作（文件写入/读取、加密校验）。

#### 5. 初始化顺序

游戏启动时GSM的初始化顺序：

```
① GSM 预加载（Autoload）
② 设置默认值：初始化所有字段为默认状态
③ 加载 progression 数据（跨局元进度）
④ 发射 ready 信号 → 主菜单系统接收
⑤ 玩家选择「新游戏」或「读档」：
   新游戏 → 按开局身份生成初始状态
   读档   → 调用 deserialize() 恢复存档
⑥ 设定 current_scene 为初始场景
⑦ 广播 game_initialized 事件
```

#### 6. 状态校验规则

GSM在写入时执行以下校验（防止数据损坏）：

- **类型校验**：写入值的类型必须与字段定义一致（String→String, int→int）
- **范围校验**：资源不可为负数；修为不可超过上限；境界必须是枚举中的有效值
- **引用完整性**：卡牌ID必须在卡牌模板库中存在（新增卡牌时验证）
- **业务规则校验**：不可在两个系统中持有同一状态的副本（如修为存在 `player.cultivation` 就不应再存在 `battle.temp_cultivation`）

校验失败时GSM抛出一个可捕获的错误（使用 Godot 的 `@warning_ignore` 风格），并拒绝写入。此错误应当被调用方捕获和处理，不应导致崩溃。

#### 7. 多系统同时读写的冲突解决

卡牌游戏中，多个系统可能在同一帧内读写状态（如战斗结算时效果引擎+阵法系统+修为系统同时操作）：

- GSM使用**写时锁定（Write-Lock-Per-Frame）**：同一帧内对同一路径的多次写入，按调用顺序依次执行，只有最后一次的变更广播事件
- 不同路径的写入互不阻塞（如 `player.cultivation` 和 `player.resources.ling_shi` 可同时写入）
- 如果系统 A 写入状态 → 信号触发 → 系统 B 在回调中试图写入同一路径 → GSM 检测到递归写入，发出警告但不阻塞（允许，但记录日志以便调试）

### 状态与转换

GSM本身是状态容器，不维护运行时状态机。但以下状态域各自有其生命周期：

```
玩家修为状态（不触发状态机，仅数值变化）：
  cultivation ∈ [0, max_cultivation]
  max_cultivation 由境界决定

战斗状态生命周期（由战斗系统驱动）：
  null（非战斗）→ battle_start() → active（战斗中）→ battle_end() → null
  battle 状态域在非战斗状态时为 null，不占用内存

探索进度状态迁移（由探索系统驱动）：
  action_points ∈ [0, max_action_points]
  当 action_points = 0 时触发相关UI提示（非GSM职责）

元进度生命周期：
  首次启动 → 初始化默认值
  每次突破 → 更新 highest_realm（如果当前 > 历史最高）
  每次通关/结束 → 结算 unlocked_cards / unlocked_talents
```

### 与其他系统的交互

GSM 与所有系统都有交互，以下是主要数据流：

| 系统 | 数据流入（GSM→目标） | 数据流出（目标→GSM） |
|------|----------------------|---------------------|
| **存档/读档系统** | serialize() → 全量状态Dictionary；deserialize(data) → 恢复状态 | 存档文件路径；加载/保存请求 |
| **卡牌系统** | get_owned_cards()；add_card_to_collection()；deck相关数据 | 卡牌模板ID变更通知（升级/转化） |
| **战斗系统** | battle_start() / battle_end() 初始化/清理战斗状态；get_field_characters() | 回合阶段信号；战斗结果（胜利/失败/撤退） |
| **卡牌效果引擎** | 临时效果注册/查询（battle.temp_effects） | 效果解析完成回调 |
| **费用系统** | get_resource(type) 检查费用限额 | spend_resource() 扣除费用 |
| **角色上场与阵位系统** | get_field_characters()；battle.field 阵位分布 | 上场/阵亡/离场事件 |
| **绑定系统** | 绑定状态查询 | 绑定/解绑/覆盖事件 |
| **阵法系统** | 阵法条件查询所需角色数据 | 阵法激活/失效事件 |
| **阵营系统** | 角色阵营标签查询 | 无（阵营系统为纯查询层） |
| **AI系统** | 己方场上状态查询 | 敌方阵容定义 |
| **探索系统** | 地图状态读取/写入；action_points 读写 | 节点探索完成事件；行动力消耗 |
| **事件系统** | 事件结果影响资源、修为基础等 | 事件触发和结果回调 |
| **修为养成系统** | add_cultivation()；get_player_realm() | 使用丹药/灵材的修为增加请求 |
| **境界系统** | realm_changed 事件（突破后触发） | 突破成功/失败通知 |
| **渡劫突破系统** | 突破前后的修为、境界数据 | 渡劫结果（成功→更新realm，失败→扣除修为） |
| **资源系统** | get_resource() / spend_resource() | 资源获取/消耗请求 |
| **卡组编辑系统** | deck 读写接口 | 卡组编辑完成事件 |
| **开局身份选择系统** | 设置 identity_id | 身份选择完成 |
| **流派系统** | 查询当前卡组和阵容 | 流派判定条件变更 |
| **剧情系统** | 读取/写入 story_flags | 剧情进度推进事件 |
| **HUD/UI系统** | 订阅状态变更信号更新显示 | UI操作事件（不影响游戏状态的UI交互） |
| **音频系统** | 订阅 scene_changed、realm_changed 等事件 | 音频播放控制（无状态写入） |

## 公式

GSM是数据管理而非计算层，但以下逻辑以公式形式定义以确保无歧义。

### 1. 资源消费校验

```
spend_resource(type, amount) → bool:
  if resources[type] >= amount:
    resources[type] -= amount
    emit_signal("resource_changed", {type, delta: -amount, balance: resources[type]})
    return true
  else:
    return false
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| type | Enum | [灵石, 灵材, 丹药碎片] | 资源类型 |
| amount | int | [0, 999999] | 消费数量 |
| resources[type] | int | [0, 999999] | 当前余额 |

### 2. 修为上限

```
max_cultivation(realm) = ceil(BASE_MAX × 1.5^(realm_level - 1))
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| realm_level | int | [1,5] | 1=炼气, 2=筑基, 3=金丹, 4=元婴, 5=化神 |
| BASE_MAX | int | 固定值 | 炼气期修为上限（=1000，见 realm-system.md §公式） |
| max_cultivation | int | [BASE_MAX, BASE_MAX×5.063] | 当前境界修为上限 |

**验证：** 炼气(L1) → BASE_MAX；筑基(L2) → BASE_MAX×1.5；金丹(L3) → BASE_MAX×2.25；元婴(L4) → BASE_MAX×3.375；化神(L5) → BASE_MAX×5.063

### 3. 战斗状态快照规则

```
battle_start():
  if battle != null:
    push_warning("battle_start() called while battle already active — ignored")
    return                                    # 幂等保护：重复调用不产生副作用
  battle_snapshot = copy(related_states)       # 深度复制player/collection数据到battle域
  battle.snapshot_realm = player.realm         # 锁定额外战斗相关数据
  emit_signal("battle_started", {...})

battle_end(result: Enum):
  if battle == null:
    push_warning("battle_end() called with no active battle — ignored")
    return                                    # 幂等保护：非战斗状态调用无副作用
  if result == victory:
    apply_rewards(...)                         # 胜利结算
  else if result == defeat:
    # 战败：无奖励，角色阵亡状态由战斗系统处理
    pass
  else if result == retreat:
    # 撤退：无奖励，保留角色状态
    pass
  battle = null                                # 释放战斗状态（GC可回收）
  emit_signal("battle_ended", {result, ...})
```

这里没有数学公式，而是状态生命周期合约——battle域在战斗开始时创建，结束时释放。

### 4. 引用完整性校验

```
validate_card_id(card_id) → bool:
  return card_id in card_template_database
```

GSM在 `add_card_to_collection()` 时自动调用 `validate_card_id()`，拒绝写入无效ID。

### 5. 卡牌校验的初始化合约

GSM与卡牌系统之间存在循环依赖：GSM需要卡牌模板库进行 `add_card_to_collection()` 的引用完整性校验，但卡牌系统自身依赖GSM进行状态存储。按以下合约解决：

```
① GSM 以"校验跳过"模式启动（_ready() 中不执行带卡牌校验的写入）
② card-system Autoload 加载卡牌模板数据库
③ card-system 在 _ready() 中调用 GSM.enable_validation(card_template_database)
④ GSM 开启校验——此后所有 add_card_to_collection() 调用均强制执行 validate_card_id()
⑤ GSM 发射 card_validation_ready 信号（其他系统可监听此信号确认卡牌系统就绪）
```

`enable_validation()` 接口：
```
enable_validation(card_template_database: Dictionary) → void   # 一次性调用；重复调用触发警告但不重复初始化
```

## 边界情况

- **战斗中存档/读档**：战斗中存档时，`battle` 域不被序列化（不保存战斗中间状态）。读档后玩家回到战斗前的探索状态，战斗未发生
- **资源归零后继续消费**：`spend_resource()` 返回 false，但不阻塞游戏——调用方需检查返回值并自行处理（如费用不足时卡牌灰色不可用）
- **修为溢出（超过 max_cultivation）**：溢出部分不丢失——自动存储为「溢出修为」，突破后计入新境界的修为进度中（支持 P2「苟道成长」的修为溢出机制）
- **两个系统在同一帧修改同一状态**：GSM 按写入顺序依次执行，仅广播最后一次变更。系统 B 在系统 A 的回调中写入同一路径→检测到递归写入→允许但日志警告
- **读档数据损坏或格式不兼容**：`deserialize()` 返回 false，不修改当前内存状态。由调用方（存档/读档系统）处理——显示"存档损坏"提示，不崩溃
- **新版本增加了状态字段后读取旧存档**：`deserialize()` 对缺失字段采用默认值填充，不报错。旧存档中不存在的字段初始化为安全的默认值
- **跨局元进度文件损坏**：progression 文件损坏时→重置为初始值（损失天赋解锁进度但不影响当前存档），发射 `progression_reset` 警告事件给 UI
- **同一帧内批量修改大量状态（战斗结算）**：使用 `batch_updated` 信号一次性广播全部变更，UI系统集中刷新（避免逐条刷新导致闪烁）
- **GSM加载时卡牌模板库尚未就绪**：GSM 以"校验跳过"模式启动——在 `enable_validation()` 被调用前不执行任何带卡牌校验的写入。card-system Autoload 加载模板库后调用 `GSM.enable_validation(card_template_database)` 开启校验。详细合约见 §公式 5「卡牌校验的初始化合约」。
- **状态路径不存在时 get() 调用**：返回 null 并产生一句 debug 日志（非错误）。set() 调用不存在的路径→触发错误日志，拒绝写入
- **开局身份不选择直接进入游戏**：不可能发生——身份选择是进入探索前的必选步骤，选择结果通过 GSM 写入 `player.identity_id`，之后才允许进入探索场景
- **死亡后存档被清除**：玩家角色死亡（渡劫失败并无法复活）→GSM 清空 meta/player/exploration/deck/narrative 域，保留 progression/collection 域（轮回保留）

## 依赖关系

| 依赖系统 | 性质 | 说明 |
|----------|------|------|
| **卡牌模板库** | 硬依赖 | GSM初始化后卡牌模板库必须已加载，否则 `add_card_to_collection()` 的引用完整性校验无法通过 |
| **存档/读档系统** | 软依赖 | GSM提供 `serialize/deserialize` 接口，但存档I/O由存档系统负责。GSM本身不依赖文件系统 |

### 下游依赖者（依赖本系统的系统）

本系统是**所有系统的上游依赖**——游戏中每个系统都需要通过GSM读取或写入状态。以下是最关键的依赖者：

| 下游系统 | 依赖性质 | 说明 |
|----------|---------|------|
| **存档/读档系统** | 硬依赖 | 通过 serialize/deserialize 接口存取状态 |
| **战斗系统** | 硬依赖 | 需要 battle_start/end 生命周期和场上角色数据 |
| **探索系统** | 硬依赖 | 需要读写地图状态和行动力 |
| **修为养成系统** | 硬依赖 | 需要 add_cultivation 和 realm 数据 |
| **卡牌系统** | 硬依赖 | 需要读写卡牌收藏和卡组数据 |
| **卡牌效果引擎** | 硬依赖 | 需要查询场上角色状态和绑定数据 |
| **资源系统** | 硬依赖 | 需要 get_resource / spend_resource 接口 |
| **卡组编辑系统** | 硬依赖 | 需要 deck 域的读写接口 |
| **身份选择系统** | 硬依赖 | 需要设置 player.identity_id |
| **UI系统** | 软依赖 | 通过订阅信号更新显示，不直接写状态 |
| **音频系统** | 软依赖 | 通过订阅场景/境界变更信号触发音效 |
| **渡劫突破系统** | 硬依赖 | 需要突破后的境界/修为更新和校验 |

### 上游依赖设计顺序

无上游依赖（GSM是设计顺序中的第一个系统）。但实际实现中，卡牌模板库必须在GSM之前或同时初始化。

所有下游系统依赖GSM就绪后才可以启动。

## 调优参数

GSM作为数据层，调优参数较少——大多数配置属于各系统的领域。以下是与GSM相关的全局参数：

| 参数 | 默认值 | 安全范围 | 过低影响 | 过高影响 |
|------|:-----:|:--------:|---------|---------|
| 修为上限基准值 BASE_MAX | 1000（已确认，见 realm-system.md §公式） | 500-3000 | 炼气期太快突破，体验不到积累 | 炼气期太久卡住，节奏拖沓 |
| 资源最大上限 | 999999 | 99999-9999999 | 限制成长型资源积累 | 无意义的大数，无负面影响 |
| 战斗中存档限制 | 禁止 | 禁止/允许 | — | 战斗中存档可导致SL（S/L）滥用 |
| ~~卡组最小张数~~ | ~~30~~ 已移除 → 卡组上限由境界动态决定，见 realm-system.md §2（deck_limit 按境界 20→40，最低保护 5 见 deck-editing-system.md §4） | — | — | — |
| ~~卡组最大张数~~ | ~~40~~ 已移除 → 同上，卡组上限由境界动态决定 | — | — | — |
| 场上最高角色数 | 6 | 2-8 | 阵法策略空间小 | 战场拥挤，UI难以展示 |
| 修为溢出保留 | 100%（是） | 0-100% | 突破后清零导致溢出无意义 | 不影响平衡（高也是好） |
| 单帧最大信号广播数 | 50 | 10-200 | 批量结算时丢失事件 | 极端情况下卡死主循环 |
| GSM日志级别 | 警告(WARN) | DEBUG/INFO/WARN/ERROR | 性能开销大 | 难以定位状态问题 |

### 修为上限随境界变化

| 境界 | 当前值 | 默认值 | 说明 |
|:----:|:-----:|:------:|------|
| 炼气 | BASE_MAX | 1000 | 初始阶段，成长曲线起点 |
| 筑基 | BASE_MAX×1.5 | 1500 | 线性增长 |
| 金丹 | BASE_MAX×2.25 | 2250 | 中期加速 |
| 元婴 | BASE_MAX×3.375 | 3375 | 后期峰值 |
| 化神 | BASE_MAX×5.063 | 5063 | 终局上限 |

## 视觉/音频需求

GSM是纯数据层，无视觉或音频输出。所有状态变更的视觉反馈由各系统各自的UI组件处理（如修为变化由HUD显示，资源变化由资源栏显示）。

## 用户界面需求

GSM自身不提供UI。但以下UI元素**依赖GSM数据**：

| UI元素 | 数据来源（GSM路径） | 更新方式 |
|--------|-------------------|---------|
| HUD修为条 | `player.cultivation / max_cultivation` | 订阅 `cultivation_changed` 信号 |
| HUD灵石数 | `player.resources.ling_shi` | 订阅 `resource_changed` 信号 |
| 境界显示 | `player.realm` | 订阅 `realm_changed` 信号 |
| 行动力条 | `exploration.action_points` | 订阅 `action_points_changed` 信号 |
| 当前地图名 | `exploration.current_map_id` | 订阅 `scene_changed` 信号 |
| 卡组张数 | `deck.current_deck.size()` | 订阅 `deck_modified` 信号 |

> **📌 用户体验标记—游戏状态管理器**：此系统不直接提供UI，但HUD系统（#33）依赖GSM数据更新显示。在阶段4中设计HUD时，直接引用GSM的上述数据路径。

## 待解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | ~~`BASE_MAX`（修为上限基准值）的精确数值——需要结合境界系统和渡劫突破系统的设计确定。当前暂设为1000~~ **✅ 已解决 (2026-07-23)**：BASE_MAX=1000 已被 realm-system.md、cultivation-system.md 确认，所有消费端数值一致。 | 修为成长曲线 | — |
| 2 | ~~卡牌模板库的加载时机——GSM初始化时卡牌模板库是否需要已就绪？还是GSM先以校验跳过模式运行，待模板库加载后再开启校验？~~ **✅ 已解决 (2026-07-23)**：GSM 以"校验跳过"模式启动（`_ready()` 中不执行带卡牌校验的写入）。card-system Autoload 加载模板库后调用 `GSM.enable_validation(card_template_database)` 开启校验。此合约须在架构阶段的 ADR 中正式记录。 | 启动流程顺序 | — |
| 3 | ~~批量变更信号 `batch_updated` 的载荷格式——是展平所有变更的合并Dictionary还是嵌套的变更列表？~~ **✅ 已解决 (2026-07-23)**：采用展平合并 Dictionary — `{changes: {"player.cultivation": {old, new}, "player.resources.ling_shi": {old, new}, ...}}`。已记录在信号表中。 | UI系统实现 | — |
| 4 | 跨局元进度（progression）的存储格式——使用Godot Resource文件、JSON、还是加密的二进制文件？ | 存档系统实现 | 存档/读档系统设计时 |

## 验收标准

- **GIVEN** GSM初始化完成，**WHEN** 读取 `player.realm`，**THEN** 返回默认境界（炼气）
- **GIVEN** GSM初始化完成，**WHEN** 读取 `player.resources.ling_shi`，**THEN** 返回初始灵石数量（≥0）
- **GIVEN** 系统A调用 `add_cultivation(100)`，**WHEN** 系统B读取 `player.cultivation`，**THEN** 值增加了100
- **GIVEN** 修为值500，**WHEN** 调用 `spend_resource("ling_shi", 30)` 且灵石余额≥30，**THEN** 灵石扣除30，返回true
- **GIVEN** 灵石余额20，**WHEN** 调用 `spend_resource("ling_shi", 30)`，**THEN** 灵石不扣除，返回false
- **GIVEN** 系统修改 `player.realm`，**WHEN** 监听 `realm_changed` 信号，**THEN** 收到包含新旧境界的载荷
- **GIVEN** 场上角色属性变更，**WHEN** 监听 `resource_changed` 以外的信号，**THEN** 不触发（信号不混淆）
- **GIVEN** 战斗开始，**WHEN** 调用 `battle_start()`，**THEN** `battle` 域初始化，发射 `battle_started` 事件
- **GIVEN** 战斗结束，**WHEN** 调用 `battle_end(victory)`，**THEN** `battle` 域清空为null
- **GIVEN** 战斗中存档，**WHEN** 序列化状态，**THEN** `battle` 域和 `session` 域不包含在输出中
- **GIVEN** 读档文件损坏，**WHEN** 调用 `deserialize(corrupted_data)`，**THEN** 返回false，内存状态不变
- **GIVEN** 旧版本存档缺少新字段，**WHEN** 调用 `deserialize(old_data)`，**THEN** 缺失字段采用默认值，返回true
- **GIVEN** 写入 `set("nonexistent.path", value)`，**WHEN** 调用，**THEN** 拒绝写入，日志记录错误
- **GIVEN** 无效卡牌ID，**WHEN** 调用 `add_card_to_collection(invalid_id)`，**THEN** 拒绝写入，返回false
- **GIVEN** 修为溢出，**WHEN** 修为达到max_cultivation后继续增加，**THEN** 溢出部分存储在溢出字段
- **GIVEN** 突破后，**WHEN** 读取修为值，**THEN** 溢出修为计入新境界进度
- **GIVEN** 同帧内多次修改 `player.cultivation`，**WHEN** 检查信号广播，**THEN** 仅最后一次变更广播事件
- **GIVEN** 批量修改（战斗结算），**WHEN** 监听信号，**THEN** 收到一个 `batch_updated` 事件而非多个逐条事件
- **GIVEN** 角色死亡，**WHEN** 执行轮回结算，**THEN** `player.cultivation` 清零，`collection.owned_cards` 保留，`progression` 更新
- **GIVEN** 新游戏开始，**WHEN** 身份选择完成，**THEN** `player.identity_id` 正确设置
