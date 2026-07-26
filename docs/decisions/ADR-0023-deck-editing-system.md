# ADR-0023：卡组编辑系统 — Feature 层独立 Autoload + GSM deck 域存储 + 委托公式查询

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Deck Editing |
| **知识风险** | LOW（Dictionary 操作、信号系统、Autoload 模式均为 4.x 成熟 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑（卡组增删、上限验证、战利品生成）不依赖 4.4+ 新增 API |
| **需要验证** | `GSM.player.deck` 域中的 `Array[int]`（card_instance_id 列表）在 GSM batch_updated 中正确序列化/反序列化；超限弃牌流程中 `call_deferred()` 与 CombatSystem Phase 7 的交互——需 GUT 集成测试 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.deck` 域数据存储、`batch_updated` Cat 1 信号传播卡组变更）；ADR-0006（CardSystem——`create_instance()` 工厂方法用于战利品/购买生成实例；`get_template()` 模板查询；`owned_cards` 反序列化重构成）；ADR-0019（ResourceSystem——`dismantle_value()` 出售定价、`delete_card_cost()` 散功费用公式）；ADR-0010（RealmSystem——`get_deck_limit(realm_level)` 境界上限查询）；ADR-0008（CombatSystem——Phase 7 `BATTLE_END` 触发战利品三选一流程）；ADR-0003（EventSystem——事件 `OUTCOME` 触发卡组增删接口）；ADR-0007（信号分类——卡组变更通过 GSM Cat 1 `batch_updated` 传播，DeckEditingSystem 不发射自有数据信号） |
| **启用** | 坊市 Epic（购买/散功/出售 UI 消费本系统 API）、战利品 Epic（三选一混合奖励面板）、战斗 Epic（Phase 7 战利品触发）、事件 Epic（事件卡牌增删接口） |
| **阻塞** | **不阻塞上游系统**——CombatSystem、EventSystem、ResourceSystem 可独立实现，仅在与 DeckEditingSystem 集成点需使用本 ADR 定义的接口签名。**阻塞**坊市 UI 和战利品 UI——在上述 UI 系统实现消费逻辑前必须接受本 ADR |
| **排序说明** | Feature 层——在 Core 层 CardSystem（#6）、ResourceSystem（#16）、RealmSystem（#11）和 Feature 层 CombatSystem（#9）、EventSystem（#5）被接受后编写。Autoload 初始化顺序需排在 ResourceSystem（#16）之后——DeckEditingSystem 在运行时查询 `delete_card_cost()` 和 `dismantle_value()`。完整 Autoload 链 25 个（从 18 个增至 25 个，本批次 7 个 ADR 并行创建）：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoadSystem #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13 / ExplorationSystem #14 / FactionSystem #15 / ResourceSystem #16 / DeploymentSystem #17 / AISystem #18 / SchoolSystem #19 / CultivationSystem #20 / IdentitySelectionSystem #21 / DeckEditingSystem #22 / FormationSystem #23 / TribulationSystem #24 / StorySystem #25 |

## 上下文

### 问题陈述

`deck-editing-system.md` GDD 定义了卡组编辑系统的完整设计——四种卡牌变更渠道（战利品三选一、坊市买卖与散功、事件增删、开局初始卡组）、境界渐进制上限、最低 5 张保护、超限弃牌流程、角色位管理、卡组变更日志持久化等。但 GDD 关注的是"玩家体验到什么"，本 ADR 需要解决的是"系统如何工程化实现"：

1. **模块归属**：卡组编辑系统需要协调 7+ 个子系统（CardSystem、ResourceSystem、CombatSystem、EventSystem、RealmSystem、GSM、SaveLoadSystem）。是作为独立 Feature 层 Autoload，还是集成到 CardSystem 中？
2. **卡组数据存储位置**：GDD 指定 `deck.current_deck` 存储在 GSM 中——但具体数据结构是什么？存完整 CardInstance Dictionary 还是仅存 card_instance_id 索引？
3. **卡组修改的校验入口**：上限验证、最低张数保护——在 DeckEditingSystem 统一执行，还是分散在各渠道系统各自检查？
4. **战利品三选一流程归属**：战利品生成（调用 CardSystem 掉落规则）→ 混合选项编排（卡牌/灵石/消耗品）→ 玩家选择 → 卡组写入——这个流程由 DeckEditingSystem 编排还是 CombatSystem 直接处理？
5. **公式委托边界**：散功费用（`delete_card_cost`）和出售定价（`dismantle_value`）在 ResourceSystem 中定义——DeckEditingSystem 是公式的消费者，不重新定义公式

### 约束

- **Feature 层定位**：依赖 Core 层（CardSystem、ResourceSystem、RealmSystem）和 Feature 层（CombatSystem、EventSystem）
- **无自由编辑界面**：卡组变更全部通过具体游戏行为触发——不存在独立"卡组编辑器"面板。卡组查看为只读
- **GSM 数据所有权**：`player.deck` 域的数据存储在 GSM 中——DeckEditingSystem 不持有数据副本
- **公式委托**：所有经济公式（散功费用、拆解价值、出售定价、境界差额惩罚）的唯一真理来源是 ResourceSystem（ADR-0019）——DeckEditingSystem 仅消费这些公式，绝不重新定义
- **四种渠道统一入口**：所有卡组增删操作必须通过 DeckEditingSystem 的 API——防止直接绕过上限校验写入 GSM
- **角色位与卡组计数隔离**：角色位中的角色卡不在卡组张数计数内——DeckEditingSystem 管理角色位替换逻辑
- **卡组变更日志持久化**：日志序列化到存档——读档后完整恢复

### 需求

- 单一入口统一四种渠道的卡组增删——防止散落的上限/下限校验
- 卡组上限根据当前境界动态查询（炼气20→化神40）——而非硬编码常量
- 战利品混合三选一的完整编排流程——生成选项→展示→选择→写入
- 散功费用的递增追踪（`session_remove_count`）在 DeckEditingSystem 内部管理
- 超限弃牌流程——先展示获得物→弃牌选择→补偿结算
- 角色位满后的替换流程——含叙事确认步骤和初始角色不可替换保护

## 决策

**DeckEditingSystem 作为 Feature 层独立 Autoload（#22）实现——持有卡组校验逻辑（上限/下限/重复限制）和四种渠道的编排流程（战利品三选一、坊市买卖散功、事件增删、开局初始化），但不持有卡组数据本身。所有卡组数据存储在 GSM `player.deck` 域中，所有卡组变更通过 GSM 第二层原子写入方法触发 `batch_updated`（Cat 1）传播。经济公式（散功费用、拆解价值）全部委托 ResourceSystem 查询——DeckEditingSystem 是公式的消费者，不重新定义公式。**

### 层分类决议：Feature 层论证

DeckEditingSystem 不是 Foundation 层（依赖 GSM、CardSystem），不是 Core 层（不是被 8+ 个系统消费的基础设施——仅有坊市 UI、战利品 UI、战斗结算、事件结算 4 个主要消费者）。它是典型的 Feature 层"垂直功能"——编排多个底层系统完成卡组编辑这一特定玩家体验。与 AISystem（#18，编排敌方行为）、CombatSystem（#9，编排战斗流程）属于同一层级。

### GSM 数据模型：`player.deck` 域

```
GSM.player.deck = {
  "current_deck": Array[int],          # card_instance_id 列表（索引到 GSM.collection.owned_cards）
  "slots": Array[Dictionary],          # 角色位 [{slot_index: int, role_card_id: int, is_protected: bool}]
  "change_log": Array[Dictionary],     # [{turn: int, source: String, card_id: int, card_name: String, action: String, detail: String, timestamp: int}]
  "session_remove_count": int,         # 本局散功已执行次数（驱动递增收费用）
  "deck_limit_modifier": int,          # 天赋修正值（万法归宗=5，其他=0）
}
```

**设计理由**：`current_deck` 只存 `card_instance_id`（int 数组），不存完整卡牌数据。完整卡牌数据通过 `GSM.collection.owned_cards` + `CardSystem.reconstitute_instances()` 获取。这保持了 GSM 的"纯数据容器"角色（ADR-0001 原则），并使卡组数据序列化体积最小（40 个 int = 160 bytes）。`session_remove_count` 和 `deck_limit_modifier` 是运行时状态——存储在 `player.deck` 中以便存档恢复。

### GameStateManager 第二层扩展方法（DeckEditingSystem 专用）

DeckEditingSystem 通过 GSM 原子写入方法操作卡组数据——遵循 ADR-0001 的委托模式先例（与 ResourceSystem 的 `_set_resource_*`、CombatSystem 的 `_set_battle_*` 一致）：

```
# === GSM 第二层：卡组专用原子写入（纳入 ADR-0001 第二层 API）===

GSM._set_deck_cards(ids: Array) → void:
  # 写入 player.deck.current_deck = ids + 发射 batch_updated

GSM._set_deck_slots(slots: Array) → void:
  # 写入 player.deck.slots = slots + 发射 batch_updated

GSM._set_deck_change_log(log: Array) → void:
  # 写入 player.deck.change_log = log + 发射 batch_updated

GSM._set_deck_session_remove_count(count: int) → void:
  # 写入 player.deck.session_remove_count = count + 发射 batch_updated
```

### DeckEditingSystem 公共 API

```
# === 卡组校验 API（纯函数——不修改 GSM 状态）===

func can_add_to_deck(count: int = 1) → Dictionary:
  # 返回 {allowed: bool, reason: String}
  var limit: int = RealmSystem.get_deck_limit(GSM.player.realm) + GSM.player.deck.deck_limit_modifier
  if GSM.player.deck.current_deck.size() + count > limit:
    return {allowed: false, reason: "卡组已达上限（%d张）" % limit}
  return {allowed: true, reason: ""}

func can_remove_from_deck(count: int = 1) → Dictionary:
  # 最低保护——卡组至少 5 张（含角色卡计数隔离）
  if GSM.player.deck.current_deck.size() - count < 5:
    return {allowed: false, reason: "卡组至少保留5张"}
  return {allowed: true, reason: ""}

func get_deck_limit() → int:
  return RealmSystem.get_deck_limit(GSM.player.realm) + GSM.player.deck.deck_limit_modifier

# === 卡组操作 API（通过 GSM 第二层写入——发射 batch_updated）===

func add_cards_to_deck(card_ids: Array[int], source: String, detail: String = "") → bool:
  # 统一添加入口——所有四种渠道必须通过此方法
  if not can_add_to_deck(card_ids.size()).allowed: return false
  var new_deck: Array = GSM.player.deck.current_deck.duplicate()
  new_deck.append_array(card_ids)
  GSM._set_deck_cards(new_deck)
  _append_change_log(card_ids, "add", source, detail)
  return true

func remove_cards_from_deck(card_ids: Array[int], source: String, detail: String = "") → bool:
  # 统一删除入口——用于散功、出售、事件销毁
  if not can_remove_from_deck(card_ids.size()).allowed: return false
  var new_deck: Array = []
  for id in GSM.player.deck.current_deck:
    if id not in card_ids: new_deck.append(id)
  GSM._set_deck_cards(new_deck)
  _append_change_log(card_ids, "remove", source, detail)
  return true

# === 坊市操作（委托 ResourceSystem 公式——自身不定义经济逻辑）===

func get_delete_cost() → int:
  return ResourceSystem.delete_card_cost(GSM.player.deck.session_remove_count)

func execute_delete(card_id: int) → bool:
  var cost: int = get_delete_cost()
  if not ResourceSystem.can_spend(&"ling_shi", cost): return false
  if not remove_cards_from_deck([card_id], "shop_delete", "散功"): return false
  ResourceSystem.spend_resource(&"ling_shi", cost)
  GSM._set_deck_session_remove_count(GSM.player.deck.session_remove_count + 1)
  return true

func get_sell_price(card_id: int) → int:
  var inst: Dictionary = _find_owned_card(card_id)
  var template: CardTemplate = CardSystem.get_template(inst.get("template_id", ""))
  if not template: return 0
  var base: int = ResourceSystem.dismantle_value(template.rarity, inst.get("level", 1))
  return floori(base * 0.8)  # 坊市抽成20%

func execute_sell(card_id: int) → bool:
  var price: int = get_sell_price(card_id)
  if not remove_cards_from_deck([card_id], "shop_sell", "出售"): return false
  ResourceSystem.add_resource(&"ling_shi", price)
  return true

# === 战利品操作 ===

func generate_loot_options(enemy_data: Dictionary) → Array[Dictionary]:
  # 返回 [LootOption, ...]
  # 根据敌人类型（普通/精英/Boss）决定选项构成模式
  # 卡牌选项：委托 CardSystem 掉落规则生成
  # 灵石选项：固定值（普通5/精英10/Boss20 跳过补偿基准）
  # 返回格式：[{type: "card"|"lingshi"|"consumable", data: Dictionary}]
  pass  # 实现细节见 GDD §核心规则 #2

func apply_loot_choice(option_index: int) → void:
  # 应用玩家选择的战利品选项
  pass  # 实现细节见 GDD §核心规则 #2

# === 超限弃牌 ===

func handle_overflow(new_cards: Array[int]) → void:
  # 先展示获得物弹窗→弃牌界面→每弃1张补偿5灵石
  pass  # 实现细节见 GDD §详细设计 #4 事件导致的超限处理

# === 角色位管理 ===

func replace_character_slot(new_role_card_id: int, old_slot_index: int) → bool:
  # 含初始角色不可替换保护 + 叙事确认步骤
  pass  # 实现细节见 GDD §详细设计 #6 角色位管理

# === 开局初始化 ===

func initialize_initial_deck(identity_preset: Array[int]) → void:
  # 开局身份绑定的初始卡组写入
  # 初始卡组不受境界上限约束（6-7张远低于炼气期20上限）
  GSM._set_deck_cards(identity_preset.duplicate())
  # 初始化角色位、清空 change_log、session_remove_count = 0
```

### 信号传播路径

DeckEditingSystem 自身不发射任何 Cat 2b 信号——卡组变更是数据变更，天然属于 GSM Cat 1 的职责范围（ADR-0007 §三分类信号体系）：

```
DeckEditingSystem.add_cards_to_deck()
  → GSM._set_deck_cards(new_deck)
  → GSM._set_deck_change_log(new_log)
  → GSM 发射 batch_updated({"player.deck.current_deck": {old, new}, "player.deck.change_log": ...})
  → HUD 刷新卡组计数 / 卡组查看界面更新 / 战利品面板状态更新
```

### 四种渠道的数据流

```
渠道1：战利品三选一
  CombatSystem Phase 7 (BATTLE_END) → DeckEditingSystem.generate_loot_options(enemy_data)
  → UI 展示 3 个混合选项 → 玩家点击 → DeckEditingSystem.apply_loot_choice(idx)
  → 若选卡牌：DeckEditingSystem.add_cards_to_deck([new_id], "loot", "战利品")
  → 若选灵石：DeckEditingSystem 委托 ResourceSystem.add_resource(&"ling_shi", N)
  → 若跳过：委托 ResourceSystem.add_resource(&"ling_shi", skip_value)

渠道2：坊市买卖与散功
  坊市 UI → DeckEditingSystem.get_delete_cost() / get_sell_price(card_id)
  → 玩家确认 → DeckEditingSystem.execute_delete(card_id) / execute_sell(card_id)
  → 内部：DeckEditingSystem.remove_cards_from_deck() + ResourceSystem 灵石操作

渠道3：事件增删
  EventSystem OUTCOME → DeckEditingSystem.add_cards_to_deck(card_ids, "event", event_name)
  → 若超限 → DeckEditingSystem.handle_overflow(new_cards)

渠道4：开局初始化
  身份选择确认 → DeckEditingSystem.initialize_initial_deck(identity_preset)
  → 不受境界上限约束
```

## 考虑的替代方案

### 替代方案 A：集成到 CardSystem——卡组操作作为 CardSystem 的子模块

- **描述**：卡组增删、上限校验、战利品编排全部作为 CardSystem 的方法。DeckEditingSystem 不作为独立 Autoload 存在。CardSystem 扩张为"卡牌全生命周期管理器"。
- **优点**：减少 1 个 Autoload（保持 18 个，本批次扩张至 25）；卡牌数据和卡组操作在同一个类中——概念上的"卡牌中心"
- **缺点**：CardSystem 已被定义为模板注册表 + 实例工厂（ADR-0006），职责是数据模型而非流程编排。添加上限校验、战利品生成、坊市经济逻辑、角色位管理、超限弃牌流程会使 CardSystem 从约 200 行膨胀到约 600+ 行——成为"上帝对象"。违反单一职责原则。ResourceSystem 的公式消费、RealmSystem 的境界查询让 CardSystem 的依赖链膨胀——CardSystem 不应依赖 ResourceSystem 和 RealmSystem（这些是更高级别的系统）
- **拒绝原因**：CardSystem 是 Core 层的基础设施——被 10+ 个系统消费。将 Feature 层编排逻辑（坊市经济、战利品混合选项、超限弃牌流程）推入 Core 层会使 Core 层变得不稳定。ADR-0006 的先例——模板/实例分离的理由同样适用于此：保持 Core 层精简、稳定、不编排复杂流程

### 替代方案 B：纯工具类（class_name DeckEditor + RefCounted）——非 Autoload

- **描述**：`class_name DeckEditor` 的 RefCounted 工具类。所有方法为 `static func` 或实例方法。消费者在需要时实例化 `DeckEditor.new()` 调用方法。不占用 Autoload 插槽。
- **优点**：极简——无 Autoload 注册、无生命周期管理。可测试性更好——无需模拟 Autoload 环境。卡组操作主要在事件/结算时调用（非每帧），不需要全局存在
- **缺点**：`session_remove_count`（散功递增收费用）是局内持久状态——RefCounted 工具类必须在每次操作时携带或查询此状态。如果没有集中状态管理，不同渠道（坊市删卡 vs 事件删卡）可能使用不同的 `session_remove_count` 实例——导致费用不一致。DeckEditingSystem 需要跨多个场景（探索地图、坊市、战斗）持久存在——RefCounted 的生命周期需要手动管理
- **评估**：此替代方案适合纯公式服务（如 ResourceSystem 替代方案 B 的分析），但不适合有运行时状态的编排系统。DeckEditingSystem 需要 `session_remove_count`、`change_log` 缓存等跨场景持久状态——Autoload 提供生命周期保证，比 RefCounted + 手动状态管理更简洁。若未来发现 DeckEditingSystem 的状态可全部推入 GSM `player.deck` 域（当前已大部分），可迁移为纯工具类——低成本重构

### 替代方案 C：分散式——各渠道自行管理卡组操作

- **描述**：战利品逻辑在 CombatSystem 中、坊市逻辑在商店系统中、事件增删在 EventSystem 中、初始化在身份选择系统中。各系统各自直接调用 GSM 写入 `player.deck.current_deck`。上限校验和下限保护在 GSM 第二层方法中集中执行。
- **优点**：无额外模块——每个渠道系统独立运作，无需中间协调层
- **缺点**：上限校验逻辑（境界查询 + 天赋修正）在 4 个系统中重复定义——境界系统调整上限时需修改 4 处代码。散功费用的 `session_remove_count` 递增逻辑需在坊市系统和事件系统中同时维护。战利品混合选项编排（卡牌/灵石/消耗品比例模式）在 CombatSystem 中定义——CombatSystem 不应知道灵石经济和消耗品系统。所有问题本质是 cross-cutting concern 无家可归
- **拒绝原因**：GDD 已在 §依赖关系中明确定义 DeckEditingSystem 为独立系统，负责统一"数据流入/流出的编排"。分散式实现违反 GDD 设计意图，且违反 DRY 原则——上限校验的 4 处重复定义将在第一次平衡性调整时产生漂移

## 后果

### 积极的

- **统一校验入口**：上限验证（境界查询 + 天赋修正）、下限保护（5 张最小）在 DeckEditingSystem 的 `can_add_to_deck()` / `can_remove_from_deck()` 中唯一定义——所有四种渠道强制执行，无法绕过
- **公式委托清晰**：散功费用、拆解价值、出售定价全部委托 ResourceSystem（ADR-0019）查询——DeckEditingSystem 是纯消费者，不定义任何经济公式。策划调参只需修改 ResourceSystem 的 const 公式表
- **信号合规**：卡组变更通过 GSM Cat 1 `batch_updated` 传播——与 ResourceSystem 的"不重复定义信号"模式一致（ADR-0007 禁止模式 #11）
- **与 ADR-0019 架构一致**：Feature 层 Autoload + GSM 状态所有权分离 + 公式委托——开发者学习 ResourceSystem 模式即可理解 DeckEditingSystem
- **渠道可扩展**：新增加一种卡牌变更渠道（如"渡劫奖励卡牌"）只需在 DeckEditingSystem 中添加一个方法——不触及任何现有渠道系统

### 消极的

- **增加第 22 个 Autoload（25 链中）**：初始化链增长。依赖顺序：必须排在 ResourceSystem（#16）之后——`_ready()` 时需确认 ResourceSystem 已初始化（公式表就绪）
- **间接性**：坊市 UI 需要同时了解 DeckEditingSystem（卡组操作 API）、ResourceSystem（灵石余额查询）和 CardSystem（卡牌模板显示）——三个入口。缓解：文档明确"卡组增删用 DeckEditingSystem、灵石操作用 ResourceSystem、卡牌数据用 CardSystem"
- **GSM 第二层方法膨胀**：新增 `_set_deck_*` 四个专用方法——GSM 接口表面积继续增长。这是架构委托的一致代价（ADR-0008、ADR-0014、ADR-0019 均定义各自的 GSM 二层方法）

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 调用方绕过 DeckEditingSystem 直接操作 `GSM.player.deck.current_deck` | 中 | 上限/下限校验跳过、日志遗漏 | 代码审查检查清单纳入"卡组写入通过 DeckEditingSystem"。GUT 测试注入直接写入场景——验证 `batch_updated` 信号与 `change_log` 不一致的可见症状 |
| `session_remove_count` 因读档/边界情况变得不一致 | 低 | 散功费用计算错误 | DeckEditingSystem 的 `initialize_initial_deck()` 和 `deserialize` 路径显式设置 `session_remove_count`；GUT 测试验证读档后散功费用正确 |
| 战利品三选一在战斗结算帧内超时——16.6ms 帧预算紧张 | 低 | 战斗结算帧掉帧 | 战利品 UI 展开展示（0.4s 动画）是异步的——DeckEditingSystem 的计算部分（选项生成）<0.1ms。UI 展示通过 `call_deferred()` 延迟到下一帧——不阻塞 CombatSystem Phase 7 |
| 境界上限在战利品流程中途改变（渡劫战斗胜利同时突破境界） | 低 | 上限判断使用旧值 | `generate_loot_options()` 在调用时快照当前上限——选项不变。若战利品选择时境界已改变（渡劫战利品），`apply_loot_choice()` 重新查询上限——取最新值 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| deck-editing-system.md | §核心规则 #1 初始卡组——身份绑定的固定卡组在开局时写入 `deck.current_deck` | `initialize_initial_deck(identity_preset)` API——直接写入 GSM `player.deck.current_deck`，不受上限约束 |
| deck-editing-system.md | §核心规则 #2 战斗战利品——混合三选一 + 跳过 + 满卡组保护 | `generate_loot_options()` + `apply_loot_choice()` API——编排完整的战利品流程 |
| deck-editing-system.md | §核心规则 #3 坊市买卖与散功——购买/散功/出售 + 递增收费用 + 最低5张保护 | `execute_delete(card_id)` + `execute_sell(card_id)` API——委托 ResourceSystem 公式，自身不定义经济逻辑 |
| deck-editing-system.md | §核心规则 #4 事件增删——超限弃牌流程（先展示获得物→弃牌→补偿） | `handle_overflow(new_cards)` API——编排超限弃牌的展示-选择-补偿流程 |
| deck-editing-system.md | §核心规则 #5 卡组查看界面——只读浏览 + 历史标签 | DeckEditingSystem 暴露 `get_deck_cards()`（按类型分组）、`get_change_log()`（持久化日志）——纯查询 API，不提供修改入口 |
| deck-editing-system.md | §核心规则 #6 角色位管理——满6个后替换 + 初始角色保护 | `replace_character_slot()` API——含叙事确认步骤和初始角色不可替换检查 |
| deck-editing-system.md | §核心规则 #7 卡组上限——境界渐进制 + 万法归宗天赋修正 | `get_deck_limit()` 动态查询——委托 RealmSystem + GSM `deck_limit_modifier` |
| deck-editing-system.md | §核心规则 #8 卡组变更日志——持久化到存档 | `_append_change_log()` 内部方法——写入 GSM `player.deck.change_log` 数组，随 GSM `serialize()` 持久化 |
| deck-editing-system.md | §公式 #1 卡组上限验证 `can_add_to_deck()` | `can_add_to_deck(count)` API——境界查询 + 天赋修正 + 当前张数比较 |
| deck-editing-system.md | §公式 #2 坊市散功费用 `removal_cost()` | 委托 ResourceSystem `delete_card_cost(session_remove_count)`——DeckEditingSystem 管理 `session_remove_count` 状态 |
| deck-editing-system.md | §公式 #3 坊市卡牌售价 `sell_price()` | 委托 ResourceSystem `dismantle_value(rarity, level)` × 0.8 |
| deck-editing-system.md | §公式 #4 卡组最低张数保护 `can_remove_from_deck()` | `can_remove_from_deck(count)` API——强制最低 5 张保护 |

## 性能影响
- **CPU**：所有校验是整数比较 + 字典查询——单次 <0.001ms。`add_cards_to_deck()` 含一次数组 duplication + 一次 GSM 第二层调用——总计 <0.01ms。非热路径（仅在事件/结算/坊市操作时调用，非每帧）
- **内存**：DeckEditingSystem Autoload 节点 <1KB。GSM `player.deck` 域运行时约 2KB（40 个 int + 变更日志 + 插槽 + 计数器）。总常驻内存 <5KB
- **加载时间**：DeckEditingSystem `_ready()` 为空——零加载成本
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 为新建架构——无现有代码需迁移。实现顺序：
1. 在 GSM `player` 域中添加 `deck` 子树——初始化 `current_deck`、`slots`、`change_log`、`session_remove_count`、`deck_limit_modifier` 的默认值
2. 在 GSM 中添加 `_set_deck_*` 四个第二层方法——纳入 ADR-0001 API
3. 创建 `res://src/feature/deck_editing_system.gd`——校验 API + 操作 API + 战利品编排 + 超限弃牌 + 角色位管理
4. 在 `project.godot` 中注册 Autoload #22（排在 ResourceSystem 之后）
5. 坊市 UI 实现时：从硬编码卡组操作→调用 DeckEditingSystem API
6. 战利品 UI 实现时：消费 `generate_loot_options()` → 展示 → `apply_loot_choice()`
7. GUT 测试覆盖：上限校验边界值（境界变更）、散功递增收费用、出售定价正确性、超限弃牌流程、角色替换保护

## 验证标准
- **GIVEN** 卡组 20 张（炼气上限 20），**WHEN** `can_add_to_deck(1)`，**THEN** 返回 `{allowed: false, reason: "卡组已达上限（20张）"}`
- **GIVEN** 卡组 20 张 + 万法归宗天赋（+5），**WHEN** `can_add_to_deck(1)`，**THEN** 返回 `{allowed: true}`
- **GIVEN** 卡组 5 张，**WHEN** `can_remove_from_deck(1)`，**THEN** 返回 `{allowed: false, reason: "卡组至少保留5张"}`
- **GIVEN** 卡组 35 张（上限 20），**WHEN** 调用 `handle_overflow(5 张新卡)`，**THEN** 触发弃牌流程提示弃 20 张（含补偿 100 灵石），弃足后卡组 = 20 张 + 补偿 100 灵石
- **GIVEN** `session_remove_count = 0`，**WHEN** `get_delete_cost()`，**THEN** 返回 50（委托 ResourceSystem `delete_card_cost(0)`）
- **GIVEN** `session_remove_count = 2`，**WHEN** `get_delete_cost()`，**THEN** 返回 100（委托 ResourceSystem `delete_card_cost(2)` = 50 + 25 × 2）
- **GIVEN** 角色位满 6 个，目标为初始角色（受保护），**WHEN** `replace_character_slot()`，**THEN** 返回 false，角色位不变
- **GIVEN** 读档后，**WHEN** 查看卡组变更日志，**THEN** 日志完整恢复——所有条目与存档前一致

## 相关决策
- ADR-0001（游戏状态管理器——`player.deck` 域数据所有权、GSM 第二层 `_set_deck_*` 原子写入方法、`batch_updated` Cat 1 信号）
- ADR-0006（卡牌数据模型——`create_instance()` 工厂用于战利品/购买生成实例、`get_template()` 模板查询）
- ADR-0019（资源系统——`delete_card_cost()` 散功费用公式、`dismantle_value()` 拆解价值公式、`add/spend_resource()` 灵石操作）
- ADR-0010（境界系统——`get_deck_limit(realm_level)` 卡组上限查询）
- ADR-0008（战斗系统——Phase 7 `BATTLE_END` 触发战利品三选一流程）
- ADR-0003（事件系统——事件 OUTCOME 触发卡组增删接口）
- ADR-0007（信号分类——卡组变更通过 GSM Cat 1 `batch_updated` 传播，不重复定义信号）
- ADR-0017（AI 系统——Feature 层独立 Autoload 的先例，DeckEditingSystem 在初始化顺序中排在其后）
