# ADR-0007：信号驱动通信 — 三分类信号体系 + 信号 vs 直接调用决策矩阵

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Foundation / Cross-cutting |
| **知识风险** | LOW（Godot 信号系统 4.x 稳定——`signal` 关键字、`emit()`、`connect()` 均为成熟 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | None——Godot 信号系统核心 API 自 4.0 起稳定 |
| **需要验证** | 4.6 中 `signal` 的 `emit()` 在大量连接（50+ 监听者）下的帧开销；`Callable.bind()` 在信号连接中的内存持有模式 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM 三层 API——信号分类中的 GSM 状态信号以此为基础）、ADR-0003（EventSystem 信号委托模式——本 ADR 将其推广为通用原则）、ADR-0004（InputManager——通过 GSM 传播锁状态而非自有信号——本 ADR 将其确立为标准模式） |
| **启用** | 所有 Foundation 层之后创建的 ADR（ADR-0008+ 战斗系统、ADR-0009 卡牌效果引擎等——信号设计决策矩阵指导其 API 设计） |
| **阻塞** | 战斗 Epic（战斗系统 7 阶段状态机需定义哪些转换发射信号 vs 直接调用）、卡牌效果 Epic（效果引擎的信号粒度决策）、UI Epic（HUD 订阅策略） |
| **排序说明** | Foundation 层最后一个 ADR（#7）。在 Foundation 层所有模块 ADR 之后、Core/Feature 层 ADR 开始之前被接受。本 ADR 不给现有 ADR 增加新需求——它编纂现有 ADR 中已使用的模式 |

## 上下文

### 问题陈述

项目已有 5 个 Foundation 层 ADR（GSM、SaveLoad、EventSystem、InputManager、SceneManager），各自定义了信号模式：

| ADR | 定义的信号 | 特点 |
|-----|-----------|------|
| ADR-0001 (GSM) | `batch_updated`、`player_changed`、`realm_changed`、`resource_changed`、`gsm_initialized` | 数据变更广播——多消费者、消费者未知 |
| ADR-0002 (SaveLoad) | `save_completed`、`load_started`、`load_completed`、`save_corrupted`、`progression_saved` | 操作结果通知——存档/读档生命周期 |
| ADR-0003 (EventSystem) | `event_triggered`、`event_resolved`、`chain_triggered`、`chain_ended`、`card_reward_requested`、`templates_loaded`、`flag_changed` | 事件动作通知 + 信号委托（`card_reward_requested`） |
| ADR-0004 (InputManager) | 无自有信号——通过 GSM `batch_updated` 传播锁状态 | 复用 GSM 信号体系 |
| ADR-0005 (SceneManager) | `pre_transition`、`post_transition` | 生命周期钩子——2 个确定消费者 |

在没有统一规范的情况下，以下问题将在实现阶段反复出现：

1. **信号 vs 直接调用选择不一致**：战斗系统某阶段推进后应该发射信号还是直接调用下一个系统？两个开发者可能做出不同选择，导致 API 风格混乱
2. **信号命名不统一**：现有信号使用 snake_case 过去式（`event_resolved`）、现在式（`pre_transition`）和描述性名称（`card_reward_requested`）三种风格——没有统一的时态规则
3. **信号链深度无上限**：A 的处理函数发射信号 B → B 的处理器发射信号 C → ... 无限递归无法检测
4. **载荷格式不统一**：GSM 的 `batch_updated` 使用 `{path: {old, new}}` 展平字典格式，EventSystem 的 `event_resolved` 传递 `(event_id, option_idx, outcomes)` 元组——没有何时用哪种格式的指导
5. **禁止模式分散在各 ADR**：递归写入（ADR-0001）、绕过 GSM（ADR-0001）、Fire-and-forget 无人监听（ADR-0003）——没有汇总的禁止模式清单

`architecture.md` §架构原则 #2 已声明"信号用于通知，不是用于逻辑"，但未细化到可执行层面。本 ADR 将其编纂为具体规则。

### 约束

- Godot 信号是同步的——`emit()` 立即调用所有连接的回调，而非异步排队。信号处理器中的阻塞逻辑直接影响调用者
- Godot 信号无内置返回值——`emit()` 不返回任何值。需要反馈的场景必须通过方法调用或回调
- GDScript 信号连接在对象销毁时自动断开——无需手动 `disconnect()`（Godot 4.x 改进）
- 信号必须在 `class_name` 脚本顶层声明——不能动态创建
- `Callable.bind()` 可用于携带额外参数，但创建新的 Callable 对象——高频连接场景需注意内存
- GSM 信号已确立为"写入优先，然后发射"（ADR-0001）——本 ADR 不改变此顺序

### 需求

- 统一的信号分类法——开发者根据场景快速判断"应该用什么类型的信号"
- 信号 vs 直接调用的决策矩阵——消除 API 设计中的歧义
- 信号命名规范——所有信号遵循统一的时态和格式
- 载荷格式标准——何时用简单参数 vs 字典 vs 展平路径
- 信号链深度硬限制——防止无限递归
- 禁止模式汇总——所有 ADR 中已确立的反模式集中记录

## 决策

**确立三分类信号体系 + 信号 vs 直接调用决策矩阵。GSM 状态信号（数据变更通知）→ 系统特定信号（生命周期/动作通知）→ Godot 内置信号（引擎生命周期）。信号命名遵循 snake_case 过去式（已发生事件），载荷优先使用具名参数（非展平字典——展平字典仅限 GSM 的 `batch_updated` 使用）。信号链深度硬限制为 4 层——超过则截断并记录错误。**

### 三分类信号体系

```
┌──────────────────────────────────────────────────────────────────┐
│                    信号分类体系                                   │
│                                                                   │
│  Category 1: GSM 状态信号 (Data-Change Notification)              │
│  ├─ 发射者：仅 GSM                                                │
│  ├─ 消费者：所有需要响应数据变更的系统（UI、SaveLoad、音频）       │
│  ├─ 特征：消费者未知、消费者数量不限、载荷含 old/new 对比          │
│  ├─ 示例：batch_updated、realm_changed、player_changed            │
│  ├─ 规则：绝不从信号处理器内写回 GSM（ADR-0001）                  │
│  └─ 规则：同帧去重——同一路径多次写入仅发射一次信号（ADR-0001）    │
│                                                                   │
│  Category 2: 系统特定信号 (Lifecycle / Action Notification)       │
│  ├─ 发射者：Foundation/Core/Feature 层各自系统                    │
│  ├─ 消费者：已知的 1-N 个系统（通常 ≤3）                          │
│  ├─ 特征：表示"某件事已发生"——消费者自行决定如何响应              │
│  ├─ 示例：event_resolved、save_completed、pre_transition           │
│  ├─ 子分类 2a：生命周期信号——pre/post 配对（如 SceneManager）     │
│  ├─ 子分类 2b：动作通知信号——单一事件通知（如 event_resolved）    │
│  └─ 子分类 2c：委托信号——fire-and-forget 解耦（如 card_reward_requested）│
│                                                                   │
│  Category 3: Godot 内置信号 (Engine Lifecycle)                    │
│  ├─ 发射者：Godot 引擎（SceneTree、Node、Control）                │
│  ├─ 消费者：需要响应引擎事件的基础设施系统                        │
│  ├─ 示例：tree_changed、ready、process、gui_input                 │
│  ├─ 规则：业务逻辑不得直接连接内置信号——应通过对应系统 API 间接使用│
│  └─ 示例：InputManager 连接 SceneTree.tree_changed 自动清理锁栈   │
│           而非每个使用锁的系统各自连接 tree_changed               │
└──────────────────────────────────────────────────────────────────┘
```

### 信号 vs 直接调用决策矩阵

核心原则（来自 architecture.md §架构原则 #2 的细化）：

> **信号用于通知"某事已发生"——消费者自行决定是否/如何响应。直接调用用于请求"执行某操作"——调用者需要结果或保证。**

决策矩阵：

| 场景 | 使用 | 示例 | 理由 |
|------|------|------|------|
| 数据已变更，未知哪些系统需要刷新 | **GSM 信号** | `batch_updated` → HUD、音频、成就系统各自刷新 | 消费者数量不确定；发射者不应知道谁能消费 |
| 操作已完成，已知消费者需要响应 | **系统信号** | `event_resolved` → SaveLoad 判定自动存档 + 探索系统恢复控制 | 消费者 ≤3 且稳定；信号名语义清晰 |
| 需要跨层解耦（Foundation → Core） | **委托信号**（Cat 2c） | `card_reward_requested` → EventSystem 不直接调用 CardSystem | Foundation 层原则 #3 合规——唯一解耦点 |
| 调用者需要返回值或保证 | **直接方法调用** | `GSM.add_resource()`、`InputManager.push_lock()` | 信号无返回值——需要确认操作结果时用方法 |
| 请求另一个系统执行操作（不关心结果） | **直接方法调用** | `SaveLoad.auto_save()` | fire-and-forget 调用——不需要信号间接层 |
| 已知单一消费者且该消费者稳定 | **直接方法调用** | SceneManager → InputManager.push_lock(TRANSITION) | 一对一、同步、需要立即生效——信号增加不必要的异步复杂度 |
| 预/后钩子——多个系统需在操作前后响应 | **系统信号**（Cat 2a） | `pre_transition` / `post_transition` | 音频、HUD、探索系统各自响应——发射者不列举他们 |
| 同层通知——Core→Core 或 Feature→Feature | **系统信号**（Cat 2b） | `battle_phase_changed`、`cultivation_threshold_reached` | 消费者 ≤3 且已知——如果消费者增长或变为未知，升级为 Cat 1（通过 GSM） |
| 引擎事件需要被基础设施系统处理 | **Godot 内置信号** | `tree_changed` → InputManager 自动清除锁 | 集中处理——不让每个业务系统各自连接引擎信号 |

**决策流程图**：

```
需要通知其他系统某件事已发生？
  ├─ 否 → 直接方法调用
  └─ 是 →
      ├─ 数据变更 + 消费者未知？ → GSM 信号（Cat 1）
      ├─ 跨层（Foundation→Core）解耦？ → 委托信号（Cat 2c）
      ├─ 生命周期钩子（pre/post）？ → 系统信号（Cat 2a）
      ├─ 特定动作完成通知？ → 系统信号（Cat 2b）
      └─ 引擎事件？ → 连接 Godot 内置信号（Cat 3）
          └─ ⚠️ 仅基础设施系统连接——业务系统通过对应 API 间接使用
```

### 信号命名规范

所有项目自定义信号遵循 **snake_case 过去式**（已发生事件），与 `technical-preferences.md` 一致：

```
✓ event_resolved      # 事件已结算
✓ save_completed      # 存档已完成
✓ realm_changed       # 境界已变更
✓ card_reward_requested  # 卡牌奖励已请求（委托信号——"被请求"非"已完成"）
✓ batch_updated       # 批量数据已更新
✓ templates_loaded    # 模板已加载完毕

✗ resolve_event       # 祈使式——信号描述已发生事件，而非命令
✗ onSaveComplete      # 驼峰命名——使用 snake_case
✗ eventResolved       # 驼峰命名——使用 snake_case
```

**时态规则细化**：
- **过去式（默认）**：`event_resolved`、`save_completed`、`chain_ended`
- **过去式被动**（委托信号）：`card_reward_requested`（"被请求"——卡牌奖励的处理尚未完成）
- **状态变更式**：`realm_changed`、`player_changed`、`flag_changed`
- **预钩子例外**：`pre_transition`（"即将发生"语义——但配对 `post_transition` 使用）

**信号前缀规范**：
- 以触发信号的**主体**为前缀，而非动词：`event_triggered`（非 `triggered_event`）、`templates_loaded`（非 `loaded_templates`）

### 信号载荷格式标准

| 载荷类型 | 何时使用 | 格式 | 示例 |
|---------|---------|------|------|
| **简单参数**（优先，默认） | 3 个以下参数，类型明确 | `signal_name(param1: Type1, param2: Type2)` | `event_resolved(event_id: StringName, option_idx: int, outcomes: Array[Dictionary])` |
| **具名字典** | 4+ 个参数或参数含义不直观 | `signal_name(data: Dictionary)` 含具名键 | `{"event_id": ..., "option_idx": ..., "outcomes": ...}` |
| **展平路径字典**（仅 GSM） | GSM 数据变更——需区分 old/new 且路径可被消费者过滤 | `{ "path.to.field": {"old": ..., "new": ...} }` | `{"player.resources.ling_shi": {"old": 100, "new": 150}}` |
| **无参数** | 纯通知——消费者自行查询状态 | `signal_name()` | `gsm_initialized()` |

**载荷设计原则**：
1. 信号携带"发生了什么"，而非"应该做什么"——消费者解读语义
2. 载荷包含消费者做出响应所需的最小信息——不携带冗余字段
3. 不要为了"未来可能需要"而增加参数——信号只定义 API，未来需求加新信号
4. `batch_updated` 的展平字典格式是 GSM 的专用契约——其他系统不得复制此模式

### 信号链深度硬限制

```
信号链深度 = 从用户输入/引擎事件开始，通过信号→处理器→再发射信号→...的传播深度

硬限制：4 层
检测方法：全局整数 _signal_chain_depth 计数器
  - emit() 调用前递增
  - 处理器返回前递减
  - depth > MAX_SIGNAL_CHAIN_DEPTH (=4) → push_error + return（截断）

示例（合法——3 层）：
  用户点击 → 探索系统.move_to_node() [深度 0]
    → EventSystem.trigger_event() [深度 0]
    → event_triggered.emit()  [深度 1]
      → UI 系统处理器：展示面板 + 连接信号 [深度 1]
      → 玩家选择选项 → resolve_option() + apply_outcomes()
        → event_resolved.emit() [深度 2]
          → SaveLoad 处理器：auto_save() → save_completed.emit() [深度 3]
            → HUD 处理器：显示"已保存"提示 [深度 3]

示例（非法——将被截断）：
  save_completed 处理器内部调用 GSM.change_realm()
    → realm_changed.emit() [深度 4] ... → 继续嵌套
      → realm_changed 处理器内部调用 SceneManager.request_scene_change()
        → pre_transition.emit() [深度 5] → ❌ 截断！push_error
```

**为什么不使用 Godot 的 `call_deferred()` 打破链？**
`call_deferred()` 将调用推迟到下一帧——这确实打破了同步信号链，但引入了时序不确定性（下一帧的执行顺序不可预测）。本 ADR 选择显式深度限制 + 硬截断——开发者可以明确看到"我的信号链太深了"并重构，而非隐式依赖帧边界来避免无限递归。

如果需要更深的事件级联，应使用 **显式编排**（方法调用链）而非信号链——这使流程可读且可调试。

### 信号声明位置规范

| 信号归属 | 声明位置 | 示例 |
|---------|---------|------|
| GSM 数据信号 | ADR-0001（GSM）顶层 | `signal batch_updated(changes: Dictionary)` |
| 系统特定信号 | 对应系统 Autoload 顶层 | EventSystem: `signal event_resolved(...)` |
| 委托信号 | 发射者系统顶层 | EventSystem: `signal card_reward_requested(template_id)` |

**不得声明"通用信号总线"Autoload**——信号应声明在语义归属明确的位置。GSM 不是信号总线——它只发射数据变更信号。

### 现有 ADR 信号汇总与合规性

对已有 6 个 ADR 的所有信号进行分类和合规检查：

| 信号 | ADR | 分类 | 命名合规 | 载荷合规 | 备注 |
|------|-----|------|---------|---------|------|
| `batch_updated` | ADR-0001 | Cat 1 | ✅ 过去式 | ✅ 展平字典（GSM 专用） | — |
| `player_changed` | ADR-0001 | Cat 1 | ✅ 状态变更式 | ✅ 简单参数 | — |
| `realm_changed` | ADR-0001 | Cat 1 | ✅ 状态变更式 | ✅ 简单参数 | — |
| `resource_changed` | ADR-0001 | Cat 1 | ✅ 状态变更式 | ✅ 简单参数 | — |
| `gsm_initialized` | ADR-0001 | Cat 1 | ✅ 过去式 | ✅ 无参数 | — |
| `save_completed` | ADR-0003 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `load_started` | ADR-0003 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `load_completed` | ADR-0003 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `save_corrupted` | ADR-0003 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `progression_saved` | ADR-0003 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `event_triggered` | ADR-0004 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `event_resolved` | ADR-0004 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `flag_changed` | ADR-0004 | Cat 1 | ✅ 状态变更式 | ⚠️ 通过 GSM batch_updated 承载 | 无独立信号——ADR-0004 正确设计 |
| `chain_triggered` | ADR-0004 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `chain_ended` | ADR-0004 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `card_reward_requested` | ADR-0004 | Cat 2c | ✅ 过去式被动 | ✅ 简单参数 | 委托信号——Fire-and-forget |
| `templates_loaded` | ADR-0004 | Cat 2b | ✅ 过去式 | ✅ 简单参数 | — |
| `pre_transition` | ADR-0006 | Cat 2a | ⚠️ 现在式 | ✅ 简单参数 | 合法例外——pre/post 配对 |
| `post_transition` | ADR-0006 | Cat 2a | ⚠️ 现在式 | ✅ 简单参数 | 合法例外——pre/post 配对 |

**命名合规结果**：19 个现有信号中，17 个符合过去式规范，2 个（`pre_transition`/`post_transition`）为合法的 pre/post 配对例外。无需重命名任何现有信号。

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                     信号通信分类决策树                            │
│                                                                   │
│  需要通知其他系统？                                               │
│    ├─ 否 → 直接方法调用                                           │
│    │       ├─ 需要返回值 → 同步调用（如 GSM.add_resource()）       │
│    │       └─ 不需要返回值 → fire-and-forget 调用（如 auto_save()）│
│    │                                                              │
│    └─ 是 → 分类判定：                                            │
│            ├─ 数据变更 + 消费者未知？                              │
│            │   └→ Category 1: GSM 信号                            │
│            │       ├─ 发射者：仅 GSM                              │
│            │       ├─ 载荷：展平 {path: {old, new}}               │
│            │       └─ 规则：写入优先→然后发射；处理器不可写回      │
│            │                                                      │
│            ├─ 跨层解耦 (Foundation → Core)？                      │
│            │   └→ Category 2c: 委托信号                           │
│            │       ├─ Fire-and-forget——不等待结果                 │
│            │       └─ Foundation 原则 #3 合规                     │
│            │                                                      │
│            ├─ 生命周期 pre/post 钩子？                            │
│            │   └→ Category 2a: 生命周期信号                       │
│            │       ├─ 必须 pre/post 配对                          │
│            │       └─ pre 不携带可变载荷（状态尚未变更）           │
│            │                                                      │
│            ├─ 特定动作完成通知？                                  │
│            │   └→ Category 2b: 动作通知信号                       │
│            │       ├─ 消费者 ≤3 且稳定                            │
│            │       └─ 载荷：最多 3 个简单参数                      │
│            │                                                      │
│            └─ 引擎事件？                                          │
│                └→ Category 3: Godot 内置信号                      │
│                    └─ ⚠️ 仅基础设施系统连接                       │
│                                                                   │
│  全局约束：                                                       │
│  ├─ 信号链深度 ≤ 4（超过则截断 + push_error）                     │
│  ├─ 信号命名：snake_case 过去式（pre/post 配对例外）              │
│  └─ 信号声明在语义归属系统——无 SignalBus Autoload                 │
└──────────────────────────────────────────────────────────────────┘
```

### 关键接口

#### 信号声明模板

```gdscript
## 系统特定信号的声明模式：
## 1. 顶层 signal 声明（非方法内）
## 2. snake_case 过去式命名
## 3. 类型化参数（Godot 4.x 支持）
## 4. 文档注释说明"何时发射"+"谁消费"

## 示例：EventSystem 的信号声明（参考 ADR-0004）
signal event_triggered(event_id: StringName)
  # 发射时机：trigger_event() 成功创建 EventInstance 后
  # 消费者：探索系统（隐藏地图 UI）、UI 系统（展示事件面板）
  # 载荷：event_id——消费者按需调用 get_template(event_id) 获取详情

signal event_resolved(event_id: StringName, option_idx: int, outcomes: Array[Dictionary])
  # 发射时机：apply_outcomes() 全部执行完毕后
  # 消费者：SaveLoad（判定自动存档）、探索系统（恢复地图控制）
  # 载荷：outcomes 为 Array[Dictionary]——每个元素含 {type, target, value, triggered}
```

#### 信号连接模式

```gdscript
## 信号连接的标准模式：

## 1. 在 _ready() 中连接（非 _init()——_init() 时其他 Autoload 可能未就绪）
func _ready() -> void:
    GSM.batch_updated.connect(_on_gsm_batch_updated)
    EventSystem.event_resolved.connect(_on_event_resolved)

## 2. 处理器命名：_on_[signal_name]——私有方法
func _on_gsm_batch_updated(changes: Dictionary) -> void:
    # ⚠️ 处理器内部禁止写回 GSM（ADR-0001 禁止模式 #1）
    if changes.has("player.resources.ling_shi"):
        _update_resource_display()

func _on_event_resolved(event_id: StringName, option_idx: int, outcomes: Array) -> void:
    # 判定是否需要自动存档——不在此函数内调用 save_game()
    # save_game() 由 SaveLoad 的独立逻辑决定
    _mark_dirty()

## 3. 委托信号的单向连接（fire-and-forget——发射者不等待）
##    EventSystem.card_reward_requested.connect(CardSystem._on_card_reward_requested)
##    CardSystem 的处理是独立的——EventSystem 不关心结果
```

#### 信号链深度追踪

```gdscript
## ⚠️ 全局单例追踪——在 ProjectSettings 中作为 Autoload 注册或作为 GSM 的静态变量
## 推荐：作为 GSM 的静态变量（避免增加 Autoload 数量）

# 在 GSM 中：
static var _signal_chain_depth: int = 0
const MAX_SIGNAL_CHAIN_DEPTH: int = 4

## 信号链深度包装 emit 函数（Cat 2 信号必须经过深度检查）
## ⚠️ 使用 Object.callv() 实现动态信号发射——StringName 路由路径在非热路径中可接受
## Cat 1（GSM 信号）跳过此包装——其禁止写回规则（ADR-0001）已防止信号链问题
func _emit_signal_safe(target: Object, signal_name: StringName, args: Array) -> void:
    GSM._signal_chain_depth += 1
    if GSM._signal_chain_depth > GSM.MAX_SIGNAL_CHAIN_DEPTH:
        push_error("Signal chain depth exceeded (%d > %d). "
                  % [GSM._signal_chain_depth, GSM.MAX_SIGNAL_CHAIN_DEPTH]
                  + "Last signal: %s. Chain truncated." % signal_name)
        GSM._signal_chain_depth -= 1
        return

    # 使用 Object.callv("emit_signal", ...) 动态展开 args 数组
    # Signal.emit() 返回 Error（非 Callable），无法链式调用 .callv()
    # Object.callv() 是 Godot 4.x 稳定 API——StringName 路由，非热路径中可接受
    var call_args: Array = [signal_name]
    call_args.append_array(args)
    target.callv("emit_signal", call_args)
    GSM._signal_chain_depth -= 1
```

**异常安全性**：GDScript 4.x 无 `try/finally`。如果信号处理器抛出未捕获异常，`_signal_chain_depth` 计数器将泄漏（递减语句不会执行）。缓解措施：
- Cat 2 信号处理器必须捕获所有异常——在处理器入口处包裹逻辑，禁止异常逃逸
- 每帧开始时在 GSM 的 `_process()` 或 SceneTree 的 `process_frame` 信号中重置 `_signal_chain_depth = 0`——防止异常泄漏的计数器永久偏移
- GUT 测试验证异常路径下计数器通过帧级重置恢复（见 §验证标准）

**`Callable.bind()` 内存陷阱**：`signal_name.connect(_handler.bind(captured_object))` 创建持有 `captured_object` 强引用的新 Callable。如果连接从未断开，`captured_object` 永远不会被释放——即使其场景节点通过 `queue_free()` 移除。Godot 4.x 的自动断开仅在**订阅者对象**销毁时触发，不检查绑定参数的生命周期。使用 `bind()` 时必须在订阅者 `_exit_tree()` 或析构函数中手动 `disconnect()`。

**性能说明**：包装 `emit` 增加函数调用开销（深度计数器 ±1 + 分支判断）。在热路径（GSM 信号）中可选跳过——GSM 的 `batch_updated` 信号链深度风险低于系统特定信号（GSM 信号处理器的禁止写回规则已被 ADR-0001 强制约束）。系统特定信号（Cat 2）必须经过深度检查。

## 考虑的替代方案

### 替代方案 A：统一信号总线（SignalBus Autoload）

- **描述**：所有信号声明在一个中央 `SignalBus` Autoload 中。系统通过 `SignalBus.my_signal.emit()` 发射，消费者通过 `SignalBus.my_signal.connect()` 订阅。
- **优点**：单一订阅点——查找"谁在监听 X"只需看一个文件；避免信号声明分散在 10+ 个 Autoload 中
- **缺点**：SignalBus 成为上帝对象——所有系统的信号耦合在一个文件中，违反关注点分离。信号语义归属模糊——`card_reward_requested` 是 EventSystem 还是 CardSystem 的信号？重命名需要跨系统协调。GDScript 不支持命名空间——100+ 信号在一个文件中不可维护
- **拒绝原因**：Godot 的 `signal` 机制天然支持信号归属于语义所在的类——无需集中化。每个系统 Autoload 声明属于它的信号，消费者按系统名前缀连接（`EventSystem.event_resolved`）——这已经是自然的命名空间。SignalBus 引入了一个没有领域语义的中间层

### 替代方案 B：全部使用直接调用——最小化信号使用

- **描述**：信号仅在"消费者完全未知"时使用（如 GSM 数据变更）。所有已知消费者的通知通过直接方法调用的回调/委托模式实现（系统 A 持有系统 B 的回调列表
- **优点**：调用链显式、可调试——IDE "查找引用"即可看到所有调用者；同步语义——不需要理解信号发射时序；无信号链深度问题
- **缺点**：每个系统需要维护自己的回调注册表——重复实现信号系统的功能。跨层解耦（Foundation→Core）需要 Foundation 层持有 Core 层的回调——违反 Foundation 原则 #3。Godot 编辑器的信号连接面板无法使用——失去了可视化调试工具
- **拒绝原因**：Godot 的信号是引擎内置的观察者模式——再实现一套回调注册系统是反模式。信号提供了引擎级的连接追踪、自动断开和编辑器可视化——这些都是手工回调注册无法得到的。关键的是，Foundation→Core 的信号委托（`card_reward_requested`）是维持 Foundation 原则 #3 的唯一可行方案——回调注册会要求 EventSystem 持有 CardSystem 的引用，直接违反原则

### 替代方案 C：两分类体系——合并 Cat 2a/2b/2c

- **描述**：GSM 信号（Cat 1）+ 通用系统信号（Cat 2——不区分子分类）。生命周期钩子、动作通知和委托信号使用统一的命名和载荷规范。
- **优点**：分类更简单——开发者只需判断"这是 GSM 信号还是系统信号"；规则更少，记忆负担更轻
- **缺点**：pre/post 信号的配对约束（pre 不携带变更后数据）、委托信号的 fire-and-forget 语义（发射者不等待）、动作通知的 ≤3 消费者约束——这些是本质不同的设计约束，合并后会丢失这些语义区分。开发者需要一个完整的检查清单才能做出正确选择——而三分类体系内化了这些约束
- **拒绝原因**：子分类 2a/2b/2c 的约束差异足够大，值得明确区分。pre/post 配对错误（只发射 pre 忘记 post）是常见的信号设计 bug——单独分类使其可审计。委托信号的 fire-and-forget 语义需要在代码审查时一眼可辨——子分类 2c 提供了这一视觉锚点

## 后果

### 积极的

- **API 设计一致性**：所有开发者面对"信号还是直接调用"时使用同一决策矩阵——消除风格分歧
- **代码审查加速**：审查者对照分类表即可判定信号设计是否合理——不需要每次重新论证
- **信号链可审计**：深度硬限制 + 错误日志——递归信号循环在开发阶段而非生产阶段暴露
- **禁止模式集中化**：所有 ADR 中分散的禁止模式汇总为一处——新开发者入门只需读本 ADR
- **Foundation 原则 #3 有设计模式支持**：委托信号（Cat 2c）为跨层解耦提供了标准化的实现模式
- **OQ-06 解决**：术语"信号链深度"（signal chain depth）明确无多线程歧义——GDScript 单线程上下文中的同步调用链

### 消极的

- **额外认知负担**：三分类 + 决策矩阵 + 深度限制——新开发者需要学习本 ADR
- **深度追踪开销**：`_signal_chain_depth` 计数器在每个信号发射时递增/递减——热路径中增加函数调用开销
- **信号设计需要更谨慎的前期思考**：无法随意发射信号——需要对照决策矩阵判断分类

### 风险

- **信号深度追踪被绕过**：系统直接使用 Godot 原生的 `signal.emit()` 而不经过 `_emit_signal_safe()` 包装——深度追踪失效。缓解措施：GUT 测试中验证关键信号链路径（事件解析→自动存档→场景切换）的实际深度——在 CI 中捕获深度超标
- **开发者选择忽略决策矩阵**：在编码压力下直接选择最熟悉的模式（"全用信号"或"全用直接调用"）——不查询决策矩阵。缓解措施：代码审查清单包含"验证每个信号符合 ADR-0007 分类"——PR 审查时强制执行
- **分类边界模糊**：某些信号同时具有 Cat 1（通知多个系统）和 Cat 2b（通知特定系统）的特征。缓解措施：优先选择 Cat 2b——GSM 信号（Cat 1）有更严格的约束（处理器不可写回），应保守使用。如有疑问，在对应系统 ADR 中讨论分类
- **现有 ADR 中的信号命名不完全符合过去式规范**：`pre_transition` 和 `post_transition` 是现在式。缓解措施：pre/post 配对已在本 ADR 中认定为合法例外——不重命名。未来 pre/post 信号必须配对声明

## 禁止模式汇总

以下禁止模式来自所有 6 个 Foundation 层 ADR——集中记录以消除跨 ADR 分散：

| # | 禁止模式 | 来源 ADR | 违规示例 | 正确做法 |
|---|---------|---------|---------|---------|
| 1 | **从 Cat 1 (GSM) 信号处理器内写回 GSM** | ADR-0001, ADR-0007 | `_on_batch_updated()` 内部调用 `GSM.add_resource()` | 信号处理器只读消费者——如需写入，通过显式方法调用链而非信号回调 |
| 2 | **信号用于请求操作（而非通知事件）** | architecture.md §原则 #2 | `request_player_death_animation.emit()`——用信号请求执行动画 | 直接调用 `AnimationPlayer.play("death")`——信号描述已发生事件 |
| 3 | **声明 SignalBus Autoload** | ADR-0007 | `SignalBus.my_event.emit()` | 信号声明在语义归属系统——`EventSystem.event_resolved.emit()` |
| 4 | **绕过 GSM 直接写入游戏状态** | ADR-0001 | 任何系统直接操作 `GSM.player.realm = 5` | 通过 GSM 第二层原子方法——`GSM.change_realm(5)` |
| 5 | **通用 `set(path, value)` 绕过原子方法** | ADR-0001 | `GSM.set("player.realm", 5)` | 使用专用原子方法——`GSM.change_realm(5)` |
| 6 | **在 `_process()` 热路径中写入 GSM** | ADR-0001 | `_process()` 中调用 `GSM.add_resource()` | 写入仅在事件响应中进行——按键/结算/章节推进 |
| 7 | **Fire-and-forget 信号（Cat 2c）未标注预期消费者** | ADR-0004, ADR-0007 | `card_reward_requested.emit(id)` 无文档注释说明谁监听 | Cat 2c 信号声明包含 `# 消费者：CardSystem` 文档注释 |
| 8 | **Cat 2 信号处理器抛出未捕获异常** | ADR-0007 | 信号处理器内 `assert()` 失败逃逸 | 处理器入口包裹逻辑——`if not valid: push_error(...); return` |
| 9 | **`Callable.bind()` 捕获对象但不断开信号连接** | ADR-0007 | `signal.connect(_handler.bind(node))` 在 `node.queue_free()` 后泄漏 | 订阅者 `_exit_tree()` 中手动 `disconnect()`；避免 `bind()` 捕获生命周期短的对象 |
| 10 | **过度使用委托信号（Cat 2c）——每个 Foundation 系统 2+ 个 Cat 2c 信号** | ADR-0007 | 3 个 Foundation 系统各有 3 个 Cat 2c 信号 = 9 个隐式依赖 | 预期每 3 个 Foundation 系统 ≤1 个 Cat 2c 信号；多数跨层通信通过 GSM 状态（Cat 1）而非委托信号 |
| 11 | **业务系统直接连接 Godot 内置信号（Cat 3）** | ADR-0005, ADR-0007 | 10 个业务系统各自连接 `tree_changed` | 基础设施系统（InputManager）集中连接——业务系统通过 API 间接使用 |
| 12 | **信号载荷携带指令（"应该做什么"）而非事实（"发生了什么"）** | ADR-0007 | `event_resolved(event_id, "SHOW_REWARD_PANEL", prize_data)` | `event_resolved(event_id, option_idx, outcomes)`——消费者自行决定如何响应 |
| 13 | **反复对同帧内同一路径多次发射 GSM 信号（未启用去重）** | ADR-0001 | 同一帧内 3 次 `add_resource("gold", 10)` 发射 3 次 `batch_updated` | GSM 同帧去重——仅最后一次变更发射信号（ADR-0001 已强制） |
| 14 | **声明 pre_ 信号而无配对 post_ 信号** | ADR-0006, ADR-0007 | 仅 `pre_combat_started` 而无 `post_combat_started` | Cat 2a 信号必须 pre_/post_ 配对声明——不存在单向生命周期钩子 |

**审查强制执行**：PR 审查清单必须验证所有信号使用符合本表——任何匹配的违规模式 = 拒绝 PR。

| 来源 | 需求 | 本 ADR 如何解决 |
|------|------|--------------------------|
| architecture.md §架构原则 #2 | 信号用于通知，不是用于逻辑——所有游戏策略在信号触发前已执行 | 确立信号 vs 直接调用决策矩阵——"需要返回值"→ 直接调用，"通知已发生事件"→ 信号 |
| architecture.md §架构原则 #2 | 信号订阅者接受状态但不允许更改——除非通过系统明确请求 | 编纂为禁止模式 #1（Cat 1 处理器不可写回 GSM）——由 ADR-0001 和本 ADR 双重强制执行 |
| architecture.md OQ-06 | 语义门控命名应避免误导——GDScript 单线程无真正竟态条件 | "信号链深度"（signal chain depth）取代"递归调用深度"——明确指信号→处理器→再发射信号的传播层级 |
| ADR-0001 §信号 | GSM 第三层信号——`batch_updated`、`player_changed`、`realm_changed` | 归类为 Cat 1（GSM 状态信号）——确立展平字典载荷为 GSM 专用格式 |
| ADR-0004 §信号委托 | `card_reward_requested`——Foundation 层不依赖 Core 层 | 确立 Cat 2c（委托信号）为跨层解耦的标准模式 |
| ADR-0005 §锁通知 | InputManager 通过 GSM batch_updated 传播锁状态——无自有信号 | 确立此模式为 Cat 1 复用的正确实践——避免专用信号与 GSM 信号重复 |
| ADR-0006 §生命周期信号 | `pre_transition` / `post_transition`——audio、HUD、探索系统各自响应 | 归类为 Cat 2a（生命周期信号）——pre/post 配对约束正式确立 |
| ADR-0003 §信号 | `save_completed`、`load_completed`、`save_corrupted`、`progression_saved` | 归类为 Cat 2b（动作通知信号）——消费者 ≤3（UI 提示、HUD 更新、错误弹窗） |

## 性能影响

- **CPU**：信号发射（`emit()`）为 Godot 4.x 的 C++ 实现——每次发射约 0.001-0.005ms（取决于连接数）。`_signal_chain_depth` 计数器操作（递增+比较+递减）约 0.0001ms。Cat 2 信号每局发射约 50-100 次（事件解析、存档、场景转换）——总开销 <0.5ms/局。Cat 1（GSM）信号每场战斗发射 1-3 次，每局约 20-30 次——总开销 <0.15ms/局
- **内存**：信号连接（`connect()`）存储为每个连接的 `SignalConnection` 对象——每个约 64B。预计总信号连接数 <200（35 个系统 × 平均 5-6 个连接）= <13KB。`_signal_chain_depth` 为静态 int（4B）——无额外内存开销
- **加载时间**：无——信号连接在 `_ready()` 中建立，不阻塞启动
- **网络**：不适用（纯单机游戏）

## 迁移计划

无现有代码需迁移——这是 Foundation 层初始决策。以下为合规要求：

1. **已有 ADR 信号**：19 个现有信号全部合规——无需重命名（见 §现有 ADR 信号汇总）
2. **未来 ADR（ADR-0008+）**：在 ADR 草案阶段应用决策矩阵——每个新信号必须标注分类（Cat 1/2a/2b/2c/3）
3. **代码审查**：PR 审查清单纳入本 ADR 的决策矩阵——每个信号的使用必须有明确的分类归属
4. **ADR-0001 补充**：GSM 的信号声明部分添加对 Cat 1 分类的引用（"参见 ADR-0007 §三分类信号体系"）——在接受本 ADR 后补充

## 需同步更新的 ADR

- **ADR-0001**：GSM 信号声明部分添加分类标注（Cat 1）——在信号注释中添加 `# Category 1: GSM 数据变更信号`。非阻塞——纯文档标注
- **ADR-0004**：在 `card_reward_requested` 信号文档中添加 `# Category 2c: 委托信号` 标注。非阻塞
- **ADR-0006**：在 `pre_transition`/`post_transition` 信号文档中添加 `# Category 2a: 生命周期信号` 标注。非阻塞
- **ADR-0003**：在 SaveLoad 信号文档中添加 `# Category 2b: 动作通知信号` 标注。非阻塞

## 验证标准

- 通过 GUT：`SignalCompliance` 测试套件覆盖：
  - 所有自定义信号命名符合 `snake_case` + 过去式（允许 pre/post 例外）
  - 信号载荷参数不超过 5 个（超过 5 个必然违反"最小信息"原则——应使用具名字典）
  - 信号链模拟：4 层深度 → 通过；5 层深度 → `push_error` 被触发且第 5 层信号未发射
  - `_signal_chain_depth` 在异常路径中正确递减或通过帧级重置恢复——信号处理器抛出异常后，下一帧 `_process()` 中计数器重置为 0
  - Cat 2 信号处理器入口处有异常捕获包装——未捕获异常逃逸时 `push_error` + `return`
  - 无系统声明 `SignalBus` Autoload——信号必须在语义归属系统中声明
- 通过代码审查：新信号声明必须包含文档注释说明分类（Cat 1/2a/2b/2c/3）
- 通过架构审查：`/architecture-review` 检测新增 ADR 的信号是否符合本 ADR 分类

## 相关决策

- ADR-0001（游戏状态管理器——Cat 1 GSM 信号的定义和发射规则）
- ADR-0003（存档/读档——Cat 2b 动作通知信号）
- ADR-0004（事件系统——Cat 2b 动作通知 + Cat 2c 委托信号）
- ADR-0005（输入管理器——Cat 1 复用模式——通过 GSM 信号传播而非自有信号）
- ADR-0006（场景管理器——Cat 2a 生命周期信号 pre/post 配对）
- architecture.md §架构原则 #2（信是通知，不是逻辑——本 ADR 的父原则）
- architecture.md OQ-06（术语统一——本 ADR 解决）