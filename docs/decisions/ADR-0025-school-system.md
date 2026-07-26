# ADR-0025：流派系统 — Core 层轻量 Autoload + 静态流派库 + 纯计算检测引擎

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core（流派系统持有只读静态流派定义库——5 个 SchoolTemplate，编译时常量。所有接口为纯查询/纯计算——无副作用、无可变运行时状态。此模式与 RealmSystem ADR-0010 的 `const realm_table` 和 FactionSystem ADR-0018 的 `const FACTION_LIBRARY` 完全一致） |
| **知识风险** | LOW（Dictionary 查询、Array 遍历、条件判定——均为 Godot 4.x 成熟 API。流派检测的最坏遍历——5 流派 × 4 条件 = 20 次检查——O(1) 级实际开销） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | None——本 ADR 使用的 Dictionary、const、signal、Array 遍历均为 4.0+ 稳定 API |
| **需要验证** | `const SCHOOL_LIBRARY` 嵌套 Dictionary 在 GDScript 中的实际不可变性——需 GUT 冒烟测试验证流派模板内容未被运行时修改 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——通过 `GSM.player.realm_level` 读取境界数据用于归墟流派检测；通过 GSM 读取卡组构成和场上角色列表）；ADR-0006（CardSystem——卡牌类型/费用/稀有度/标签元数据——流派检测和匹配度计算的核心数据源）；ADR-0018（FactionSystem——`get_tags_of_character()` / `belongs_to_alignment()` / `count_on_field()`——流派条件中的阵营判定全部委托给 FactionSystem）；ADR-0016（DeploymentSystem——`get_field()` 场上角色列表——阵营人数检测的来源） |
| **启用** | 战斗系统（CombatSystem——流派增益的落地执行：伤害修正、回合回复、击杀抽牌、费用折扣）；卡组编辑 UI（流派匹配度百分比展示 + 流派详情弹窗）；战斗 HUD（流派激活标识 + 增益触发闪烁） |
| **阻塞** | 流派 Epic（流派系统本身的实现）、战斗增益落地（CombatSystem 的流派增益钩子） |
| **排序说明** | Core 层 ADR——在 FactionSystem (ADR-0018) 和 DeploymentSystem (ADR-0016) 之后被接受。流派检测依赖阵营判定和场上角色列表，两者必须在流派系统就绪前可用。Autoload #19——排在 AISystem(#18) 之后，为 Core 层"静态数据表三剑客"最末位。本 ADR 属于 7 个并行创建的批次 ADR 之一（18→25 总 Autoload：ADR-0020 修炼 #20 / 0021 渡劫 #24 / 0022 身份 #21 / 0023 卡组 #22 / 0024 阵法 #23 / 0025 流派 #19 / 0026 剧情 #25）

## 上下文

### 问题陈述

流派系统是游戏的元玩法层——它通过分析玩家卡组中的卡牌构成模式（阵营分布、角色组合、卡牌类型比例），判定当前构筑偏向哪种流派风格，并在满足条件时给予战术增益奖励。系统支持 5 种预设流派：正道发育流、魔道快攻流、正邪混合流、归墟真灵流、百艺炼丹流。

核心架构问题：**流派定义数据和检测逻辑应如何组织？层归属是什么？是否需要独立 Autoload？**

架构现状：
- `architecture.md` §模块注册表将"流派系统"归入 **Feature** 层，列出接口 `get_school(card)` 和 `get_bonus(school, level)`
- GDD `school-system.md` 定义了完整的 5 流派模板（检测条件 + 增益效果 + 弱点）、检测优先级规则、匹配度计算公式、增益应用逻辑
- 流派的检测条件依赖：阵营标签（FactionSystem #15 Core）、卡牌元数据（CardSystem #6 Core）、场上角色列表（DeploymentSystem #17 Feature）、玩家境界（GSM #1 Foundation）
- FactionSystem (ADR-0018) 和 RealmSystem (ADR-0010) 均已论证从 Feature 层迁移至 Core 层——理由：静态数据表 + 纯查询接口 + 被多系统消费。流派系统是否符合此模式？

需要决策的问题：
1. **层归属**——流派系统定义 5 个编译时常量流派模板 + 纯计算检测引擎。应归入 Core 层还是 Feature 层？
2. **形态**——独立 Autoload，还是嵌入现有系统（CombatSystem 或 CardSystem），还是纯工具类？
3. **流派检测时机**——检测在何时触发？结果是否缓存？主动推送还是按需查询？
4. **流派增益的执行路径**——增益定义在流派库中，由谁落地到战斗结算？

### 约束

- **静态数据规模**：5 个流派模板，每个含 4~5 个检测条件 + 3~5 个增益效果 + 元数据——总计约 2KB
- **检测性能**：流派检测在卡组变更、上场角色变更、炼丹操作后触发——非热路径（非每帧）。最坏遍历 5 流派 × 4 条件 = 20 次条件检查。每次条件检查涉及 1~2 次 FactionSystem 查询（O(字段角色数) ≤ O(6)）
- **流派唯一性**：同一时刻仅一个流派激活（优先级规则）
- **增益系统级**：流派增益不可被敌方驱散——不占用常规 buff 位——这是系统级效果
- **战斗中增益锁定**：战斗开始时增益锁定，战中不变（GDD §边缘情况明确要求）——避免战中反复切换造成混乱
- **无持久化"流派等级"**：当前 GDD 不定义流派等级概念——流派只有"激活/未激活"二进制状态。`get_school_bonus(card, school_level)` 接口留待未来扩展

### 需求

- 5 种流派的模板定义（检测条件 + 增益效果 + 元数据）需单一真理来源——策划可在一个文件中查看所有流派定义
- 流派检测在卡组变更、上场角色变更、炼丹操作后触发——返回当前应激活的流派 ID（或 null）
- 流派匹配度（0~100%）可用于 UI 展示——即使未激活也显示"距离激活还有多远"
- 流派增益在战斗结算中落地——伤害修正、回复、抽牌、费用折扣等
- 流派切换事件需通知 UI（提示文字 + 光效）

## 决策

### 层分类决议：Core 层论证

`architecture.md` §模块注册表原先将"流派系统"归入 Feature 层。本 ADR 论证**迁移至 Core 层**，理由：

1. **静态数据 + 纯计算**：`SCHOOL_LIBRARY` 是 5 个流派的编译时常量定义。所有接口（`detect()`、`calculate_match()`、`get_bonus()`）均为无副作用查询/计算——不写入 GSM、不持有除流派库之外的可变运行时状态。与 RealmSystem 的 `const realm_table` 和 FactionSystem 的 `const FACTION_LIBRARY` 模式完全一致。

2. **被依赖广度**：流派系统被 CombatSystem（增益执行）、DeckEdit UI（匹配度展示）、Battle HUD（流派标识）消费——至少 3 个跨层消费者。Core 层的定位是"被多个 Feature 层系统消费的基础设施"——流派系统符合此定义。

3. **类比先例**：FactionSystem (ADR-0018) 持有 18+ 标签的 `const FACTION_LIBRARY` 字典，以 Core 层 Autoload 运行。流派系统以相同模式持有 5 个流派的 `const SCHOOL_LIBRARY` 字典，附加检测算法（纯计算，无副作用）。两者在模式上的唯一区别是检测算法的复杂度——但纯计算不影响层归属。

4. **"流派增益执行"不等于"流派系统拥有运行时状态"**：流派增益的落地执行由 CombatSystem 完成（与卡牌效果引擎相同模式）。SchoolSystem 仅负责"判定哪个流派激活 + 提供增益定义"——这是数据 + 判定的角色，而非运行时状态管理者。

**需同步更新**：`architecture.md` §系统层映射表格中"流派系统"应从 Feature 层迁移至 Core 层。本 ADR 接受后执行此更新。

### 采用方案 A：SchoolSystem Core 层 Autoload + const SCHOOL_LIBRARY + 纯计算检测引擎

**SchoolSystem** 作为一个 Godot Autoload（`res://src/core/school_system.gd`），负责：

1. **静态流派库持有**：`SCHOOL_LIBRARY: Dictionary` —— 5 个流派的完整定义（检测条件 + 增益效果 + 元数据），编译时常量
2. **流派检测 API**：`detect(state: Dictionary) → StringName` —— 按优先级遍历 5 个流派，返回第一个全部条件满足的流派 ID（或空）
3. **匹配度计算 API**：`calculate_match(school_id: StringName, state: Dictionary) → Dictionary` —— 返回 `{score: float, missing: Array[String]}`
4. **增益查询 API**：`get_school_effects(school_id: StringName) → Array[Dictionary]` —— 返回该流派的增益效果列表
5. **元数据查询 API**：`get_school_info(school_id: StringName) → Dictionary` —— 返回流派名称、描述、视觉主题等
6. **便捷方法**：`get_active_school() → StringName` —— 从 GSM 读取当前流派状态（如缓存于 GSM 中）

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│              GSM (ADR-0001) — Autoload                       │
│  player.realm_level: int  ← 归墟流派检测条件                  │
│  battle.active_school: StringName  ← 当前激活流派（可选缓存） │
└──────────────┬──────────────────────────────────────────────┘
               │
    ┌──────────┼──────────┬────────────────┐
    ▼          ▼          ▼                ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────────┐
│CardSystem│ │FactionSys│ │DeploymentSys │ │CombatSystem  │
│ (ADR-0006)│ │(ADR-0018)│ │ (ADR-0016)   │ │ (ADR-0008)   │
│          │ │          │ │              │ │              │
│卡牌类型  │ │阵营标签  │ │场上角色列表  │ │流派增益执行  │
│费用/稀有度│ │阵营统计  │ │              │ │(伤害修正/    │
│卡组构成  │ │          │ │              │ │ 回复/抽牌)   │
└────┬─────┘ └────┬─────┘ └──────┬───────┘ └──────┬───────┘
     │            │              │                │
     └────────────┼──────────────┘                │
                  │ 查询数据源                      │
                  ▼                               │
┌─────────────────────────────────────────────────┼──────┐
│           SchoolSystem (ADR-0025) — Autoload #19（总 25 个）│      │
│                                                  │      │
│  SCHOOL_LIBRARY: Dictionary  ← const 编译时常量   │      │
│  ┌──────────────┬──────────────┬─────────────┐   │      │
│  │ 正道发育流    │ 魔道快攻流    │ 正邪混合流   │   │      │
│  │ righteous_dev│ demonic_aggro│ mixed_align  │   │      │
│  ├──────────────┼──────────────┼─────────────┤   │      │
│  │ 归墟真灵流    │ 百艺炼丹流    │             │   │      │
│  │ spirit_beast │ alchemy_mast │             │   │      │
│  └──────────────┴──────────────┴─────────────┘   │      │
│                                                  │      │
│  检测 API（纯计算——无副作用）：                   │      │
│    detect(state) → StringName    ← 优先级检测     │      │
│    calculate_match(school, state) → {score, miss} │      │
│                                                  │      │
│  查询 API（纯数据——O(1) 字典查询）：              │      │
│    get_school_info(id) → Dictionary               │      │
│    get_school_effects(id) → Array[Dictionary] ◄───┼── 战斗系统查询增益
│    get_all_schools() → Array[StringName]          │      │
│                                                  │      │
│  Cat 2b 信号：                                   │      │
│    school_changed(old_id, new_id)                │      │
└──────────────────────────────────────────────────┘      │
```

### 关键接口

```gdscript
# === SchoolSystem Autoload ===
# 路径: res://src/core/school_system.gd
# 初始化顺序: 在 FactionSystem (#15) 和 DeploymentSystem (#17) 之后注册

## 流派定义库 —— 编译时常量
## 策划在此定义所有流派的检测条件和增益效果
const SCHOOL_LIBRARY: Dictionary = {
    &"righteous_dev": {
        name = "正道发育流",
        tagline = "稳扎稳打，步步为营",
        priority = 2,  # 优先级（1 最高，5 最低）
        detection = {
            min_faction = {tag = &"zhengdao", count = 3},
            min_faction_ratio = {tag = &"zhengdao", pct = 0.6},
            excluded_cards = [],  # 不含魔道限定卡——由条件逻辑判定
        },
        effects = [
            {type = &"regen", target = &"zhengdao", value = 2, trigger = &"turn_end"},
            {type = &"damage_reduce", target = &"zhengdao", value = 1, floor = 1},
            {type = &"formation_ease", value = -1},  # 阵法所需正道人数 -1
        ],
        weakness = "被高爆发流派克制；清场类AOE对续航阵型打击大",
        visual_theme = {color = Color(0.29, 0.62, 0.43), glow = "golden"},
    },
    # ... 其余 4 个流派（魔道快攻流、正邪混合流、归墟真灵流、百艺炼丹流）
}

## 流派检测 —— 按优先级遍历，返回第一个全部满足的流派 ID
## state 结构: {deck_cards, field_characters, realm_level, alchemy_count, ...}
func detect(state: Dictionary) -> StringName:
    var candidates: Array[Dictionary] = []
    for school_id in SCHOOL_LIBRARY:
        candidates.append({
            id = school_id,
            priority = SCHOOL_LIBRARY[school_id].priority,
        })
    candidates.sort_custom(func(a, b): return a.priority < b.priority)

    for candidate in candidates:
        if _check_all_conditions(candidate.id, state):
            return candidate.id
    return &""  # 无流派激活

## 流派匹配度计算 —— 返回 {score: 0~100, missing: [String]}
func calculate_match(school_id: StringName, state: Dictionary) -> Dictionary:
    var school: Dictionary = SCHOOL_LIBRARY.get(school_id, {})
    if school.is_empty():
        return {score = 0, missing = ["未知流派: %s" % school_id]}

    var score: float = 0.0
    var total_weight: int = 0
    var missing: Array[String] = []

    # 阵营人数条件（权重 40）
    var det: Dictionary = school.get("detection", {})
    if det.has("min_faction"):
        total_weight += 40
        var req = det.min_faction
        var count: int = FactionSystem.count_on_field(req.tag)
        if count >= req.count:
            score += 40.0
        else:
            var ratio: float = float(count) / float(req.count)
            score += 40.0 * ratio
            missing.append("需%d个%s角色（当前%d/%d）" % [req.count, FactionSystem.get_tag_info(req.tag).name, count, req.count])

    # ... 其余条件（卡牌类型占比权重 20、境界权重 10 等——遵循 GDD §公式#1）

    var total_score: float = round((score / float(total_weight)) * 100.0) if total_weight > 0 else 0.0
    return {score = total_score, missing = missing}

## 获取流派增益效果列表 —— CombatSystem 在战斗开始时调用
func get_school_effects(school_id: StringName) -> Array[Dictionary]:
    var school: Dictionary = SCHOOL_LIBRARY.get(school_id, {})
    if school.is_empty():
        return []
    return school.get("effects", [])

## 获取流派元数据 —— UI 展示用
func get_school_info(school_id: StringName) -> Dictionary:
    return SCHOOL_LIBRARY.get(school_id, {})

## 获取全部流派 ID 列表
func get_all_schools() -> Array[StringName]:
    return SCHOOL_LIBRARY.keys()

## Cat 2b 信号 —— 流派状态变更时发射
signal school_changed(old_school_id: StringName, new_school_id: StringName)
```

### 接口契约

| 接口 | 签名 | 调用方 | 分类 (ADR-0007) |
|------|------|--------|-----------------|
| 流派检测 | `detect(state: Dictionary) → StringName` | CombatSystem（战前检测）、DeckEdit（构筑检测） | 直接调用（纯计算） |
| 匹配度计算 | `calculate_match(school, state) → Dictionary` | DeckEdit UI | 直接调用（纯计算） |
| 增益查询 | `get_school_effects(school) → Array[Dictionary]` | CombatSystem | 直接调用（纯查询） |
| 元数据查询 | `get_school_info(school) → Dictionary` | UI/HUD | 直接调用（纯查询） |
| 流派变更信号 | `school_changed(old, new)` | UI/HUD、CombatSystem | Cat 2b（动作通知） |

### 检测触发时机与状态管理

流派检测在以下时机触发（**按需查询模式——不缓存中间状态**）：

| 触发时机 | 调用方 | 后续动作 |
|---------|--------|---------|
| 卡组变更（添加/删除卡牌） | DeckEdit System → `SchoolSystem.detect(state)` | 更新 UI 匹配度展示 |
| 上场角色确认（战斗开始前） | CombatSystem → `SchoolSystem.detect(state)` | 锁定流派增益 → 写入 `GSM.battle.active_school` → 发射 `school_changed` |
| 炼丹/炼器完成（百艺流派） | 炼丹系统 → `SchoolSystem.detect(state)` | 若百艺流派激活 → 发射 `school_changed` |

**关于"流派等级"**：当前 GDD 不定义流派等级系统——流派只有"激活/未激活"二进制状态。增益强度由流派模板中的 effect value 固定定义。`get_school_bonus(card, school_level)` 接口预留为未来扩展点（见 §未解决问题）。

### 流派增益的执行路径

流派增益的执行遵循 **"SchoolSystem 定义 → CombatSystem 执行"** 的委托模式：

```
战斗开始前:
  ① CombatSystem 调用 SchoolSystem.detect(state) → 获取 active_school_id
  ② CombatSystem 调用 SchoolSystem.get_school_effects(active_school_id) → 获取增益列表
  ③ CombatSystem 将增益注册到战斗上下文（不经过 StatusEffectSystem——流派增益是系统级效果）

战斗中:
  ④ CombatSystem 在各结算点（伤害计算、回合结束、击杀事件、费用计算）查询注册的流派增益
  ⑤ 流派增益不占用 StatusEffect 槽位——不可被敌方驱散

战斗结束后:
  ⑥ 流派增益随战斗上下文一起清除
```

## 考虑的替代方案

### 替代方案 B：嵌入 CombatSystem —— 流派检测和增益作为 CombatSystem 内部模块

- **描述**：流派检测逻辑和增益定义嵌入 CombatSystem。CombatSystem 在战斗开始前运行检测，内部管理流派增益。卡组编辑 UI 通过 `CombatSystem.get_school_match(school_id, deck_state)` 查询匹配度。
- **优点**：不增加 Autoload 数量。增益执行和定义在同一系统中——无跨 Autoload 调用。CombatSystem 本身已是战斗的核心编排器——添加流派检测是其职责的自然延伸。
- **缺点**：
  - CombatSystem 职责膨胀——它已编排 9 个子系统（费用/卡牌/AI/效果引擎/状态/上场/绑定/阵法/境界）。添加流派检测将使子系统数达到 10——这接近单一编排器的管理上限
  - 卡组编辑 UI 查询流派匹配度时需通过 CombatSystem——概念上错误（卡组编辑不在战斗中）。违反"最小知识原则"——DeckEdit 不应依赖 CombatSystem
  - 流派定义（SCHOOL_LIBRARY）嵌入 CombatSystem 后——策划修改流派数据需触及战斗系统文件（最敏感的战斗代码），风险高。独立 SchoolSystem 的文件修改隔离更好
  - 流派增益虽在战斗中执行，但其定义是独立的游戏设计数据——与 RealmSystem 的境界属性表性质相同。RealmSystem 作为独立 Autoload 时每人都同意"战斗系统不应持有境界定义数据"——同理，战斗系统不应持有流派定义数据
- **拒绝原因**：流派定义是独立的游戏设计数据层，不是战斗系统的内部实现细节。将 5 个流派的完整定义（检测条件 + 增益 + 弱点 + 视觉主题）嵌入 CombatSystem 违反单一职责原则——CombatSystem 的任务是执行战斗流程，不是管理流派元数据。独立 Autoload 遵循与 RealmSystem/FactionSystem 一致的关注点分离模式。

### 替代方案 C：非 Autoload RefCounted 工具类 —— `class_name SchoolData` 由 GSM 持有共享实例

- **描述**：`SchoolData` 作为 `class_name SchoolData extends RefCounted` 工具类。GSM 在 `_ready()` 中创建共享实例，暴露为 `GSM.school_data`。消费者通过 `GSM.school_data.detect(state)` 访问。
- **优点**：
  - 不占用 Autoload 槽位（保持在 18 个——本批次扩张至 25）
  - 可测试性更好——测试中可创建独立 SchoolData 实例
  - 生命周期由 GSM 管理——GSM 持久化 → SchoolData 持久化
- **缺点**：
  - 消费者必须通过 GSM 间接访问——`GSM.school_data.detect(state)` 而非 `SchoolSystem.detect(state)`——增加间接层级
  - 如果 GSM 被重新加载（理论上不应发生），SchoolData 实例丢失
  - DeckEdit UI 需要查询流派匹配度——但 DeckEdit 不在战斗中，不应依赖 GSM（Foundation 层）来获取纯计算数据
  - `const SCHOOL_LIBRARY` 类变量在所有实例间共享——`SchoolData.new()` 不复制数据，但暴露方式不如 Autoload 直接
- **拒绝原因**：流派系统有 3+ 个跨层消费者（CombatSystem Feature 层 / DeckEdit UI Presentation 层 / Battle HUD Presentation 层），需要一个项目级别的单一访问点。在 GDScript 中，这天然对应 Autoload。且 GSM 不应成为"所有工具类的持有者"——这会退化为上帝对象。此替代方案在消费者数量较少时（≤2）更合适，但流派系统的消费已跨越 3 个架构层。

## 后果

### 积极的

- **单一真理来源**：`SCHOOL_LIBRARY` 是 5 个流派的唯一定义点。检测条件、增益效果、优先级规则、视觉主题——所有消费者通过 SchoolSystem 查询，杜绝跨 GDD 重复定义
- **纯计算无副作用**：`detect()` 和 `calculate_match()` 不写入任何状态——调用方自行决定如何使用检测结果。这消除了缓存一致性问题和信号时序 bug
- **增益执行解耦**：SchoolSystem 定义"流派 A 给予什么增益"，CombatSystem 负责"如何在战斗中落地这些增益"——定义与执行分离。修改增益数值只需触及 SchoolSystem 的 const Dictionary，无需修改战斗代码
- **与 FactionSystem/RealmSystem 模式一致**：三者均为 Core 层 Autoload + const Dictionary + 纯查询接口——降低团队认知负担。新增开发者理解了一种模式，就理解了三种系统
- **扩展成本低**：新增第 6 流派只需在 `SCHOOL_LIBRARY` 中添加一个 entry + 分配优先级。新增检测条件维度只需在 detect() 的条件检查循环中添加新的条件类型
- **流派检测的按需模式灵活**：不维护缓存——每次 detect() 从当前状态实时计算。无"缓存与事实不一致"的风险。调用方自行决定何时重新检测（卡组变更、上场变更、炼丹操作）

### 消极的

- **增加 1 个 Autoload**：项目 Autoload 从 18 个增至 25 个（本批次 7 个 ADR 并行创建：ADR-0020 修炼/0021 渡劫/0022 身份/0023 卡组/0024 阵法/0025 流派/0026 剧情）。SchoolSystem 在 AISystem #18 之后注册为 #19。Autoload 数量 25 已超出 20 的警戒线——本批次是 Autoload 数量的重大里程碑。后续 ADR 创建新 Autoload 需引用本风险并论证为何需要超过 25
- **初始化顺序依赖**：SchoolSystem 的 `_ready()` 必须在 FactionSystem (#15) 和 DeploymentSystem (#17) 之后——因为 `detect()` 调用 `FactionSystem.count_on_field()` 和通过 DeploymentSystem 获取场上角色列表。需在 `project.godot` 中确保 SchoolSystem 列在它们之后
- **detect() 每次调用重建 candidates 列表**：每次 `detect()` 调用都会创建临时 Array 并排序（5 个元素，O(5 log 5) = 可忽略）。但这不是热路径——流派检测在卡组变更/上场确认时触发（非每帧），开销可接受
- **"流派等级"概念缺失**：当前接口将增益值与流派模板固定绑定——不支持"流派 A 等级 2 时增益翻倍"。若未来引入流派等级系统，get_school_effects() 接口需要扩展参数。当前预留了接口扩展空间（见 §未解决问题）

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Autoload 数量超出 20 警戒线（25 个——本批次 7 个 ADR 并行） | 已发生 | 后续新 Autoload 需要更严格论证 | 本批次是 Autoload 数量的重大里程碑（18→25）。本 ADR 明确记录此计数，后续 ADR 创建 Autoload 时需引用本风险并论证为何需要超过 25 |
| `detect()` 的条件检查逻辑与 GDD 检测规则不同步 | 中 | 流派激活行为与设计意图不一致 | `detect()` 的每项条件检查直接从 `SCHOOL_LIBRARY[ school_id].detection` 读取——策划修改流派模板文件即修改检测逻辑。GUT 测试覆盖所有 5 种流派的激活/不激活场景 |
| 百艺炼丹流的"本局炼丹次数"计数器维护位置不明确 | 中 | 检测条件中"已进行 ≥3 次炼丹"的数据来源无系统负责 | 炼丹次数计数器由炼丹炼器系统维护，存储在 `GSM.player.alchemy_count` 中（跨战斗持久化）。SchoolSystem 仅读取此值——不负责维护。若炼丹系统尚未实现，百艺流派的此条件始终不满足——优雅降级 |
| 卡牌效果引擎与流派增益的执行优先级冲突 | 低 | 流派减伤和效果引擎的增伤同时作用时顺序不明确 | 流派增益是系统级修正（在 CombatSystem 的伤害结算层，不经过 CardEffectEngine 的 ResolutionStack）。在伤害公式中：流派修正 > 效果引擎修正。GDD §边界情况明确"流派增益不可被驱散"——作为系统级效果的优先级更高 |
| 流派检测在"战斗开始前"锁定但"战中动态条件变化" | 低 | 战中如果角色阵亡导致阵营条件不满足——流派增益是否失效？ | GDD §边缘情况明确：增益在战斗开始时锁定，战中不变。战后重新检测。此规则优先于实时一致性——避免战中流派反复切换造成玩家困惑 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| school-system.md | §1 流派定义结构——SchoolTemplate 含 id/name/detection/effects/weakness | `SCHOOL_LIBRARY` const Dictionary 定义 5 个流派的完整模板 |
| school-system.md | §2 五种流派详细定义——检测条件 + 增益效果 + 弱点 | 每个流派的 detection/effects/weakness 在 SCHOOL_LIBRARY 中各有一个完整 entry |
| school-system.md | §3 流派检测机制——优先级检测 + 触发时机 | `detect(state)` 按 priority 排序 candidates 后逐一检测。触发时机由调用方决定（按需模式） |
| school-system.md | §4 流派匹配度——百分比计算 + 缺失条件列表 | `calculate_match(school, state)` 返回加权分数和 missing 列表——与 GDD §公式#1 对齐 |
| school-system.md | §5 流派增益生效范围——静态增益 + 动态增益 | `get_school_effects(school)` 返回增益列表。CombatSystem 区分静态增益（战斗开始时一次性计算）和动态增益（战中实时响应） |
| school-system.md | §8 流派平衡原则——无绝对最强、混合不惩罚、流派可切换 | detect() 只在条件满足时返回流派——无流派时返回空（无惩罚）。优先级规则有文档说明，但每种流派都有明确的克制弱点 |

## 性能影响

- **CPU**：`detect()` 最坏情况——遍历 5 个流派，每个检查 4 个条件，每个条件 1~2 次 FactionSystem 查询（O(字段角色数) ≤ O(6)）。总计约 20 次条件检查 × 最多 12 次 StringName 比较 = < 0.05ms。此操作在卡组变更/上场确认时触发（非每帧）——开销可忽略不计
- **内存**：`SCHOOL_LIBRARY` const Dictionary——5 个流派 × 约 400B/流派 ≈ 2KB。Autoload 节点本身 ≈ 0.5KB。总计 < 3KB 常驻内存
- **加载时间**：const Dictionary 编译时分配——零运行时加载开销。Autoload `_ready()` 为空
- **网络**：不适用（单机游戏）

## 迁移计划

本 ADR 创建新系统，非修改现有代码。实施顺序：
1. 创建 `res://src/core/school_system.gd` —— SchoolSystem Autoload（const SCHOOL_LIBRARY + detect/calculate_match/get_effects API + school_changed 信号）
2. 在 `project.godot` 中注册 Autoload —— 排在 AISystem #18 之后（新增为 #19，完整 25 节点链：GSM #1 → InputManager #2 → SceneManager #3 → SaveLoadSystem #4 → EventSystem #5 → CardSystem #6 → CostSystem #7 → StatusEffectSystem #8 → CombatSystem #9 → CardEffectEngine #10 → RealmSystem #11 → ProgressionSystem #12 → BindingManager #13 → ExplorationSystem #14 → FactionSystem #15 → ResourceSystem #16 → DeploymentSystem #17 → AISystem #18 → SchoolSystem #19 → CultivationSystem #20 → IdentitySelectionSystem #21 → DeckEditingSystem #22 → FormationSystem #23 → TribulationSystem #24 → StorySystem #25）
3. CombatSystem 集成：战前调用 `detect()` → 读取 `get_school_effects()` → 注册流派增益到战斗上下文
4. DeckEdit UI 集成：卡组变更后调用 `calculate_match()` 更新流派匹配度展示
5. Battle HUD 集成：监听 `school_changed` 信号 → 显示流派激活提示
6. `architecture.md` 更新：流派系统从 Feature 层迁移至 Core 层；Autoload 列表增至 25 个（#19 SchoolSystem）

## 验证标准

- **GIVEN** 场上正道角色 ≥3 且正道占比 ≥60%，**WHEN** 调用 `detect(state)`，**THEN** 返回 `&"righteous_dev"`
- **GIVEN** 场上正道 ≥3 且魔道 ≥2（同时满足正邪混合条件），**WHEN** 调用 `detect(state)`，**THEN** 返回 `&"righteous_dev"`（正道优先级 2 > 正邪混合优先级 4）
- **GIVEN** 同时满足归墟真灵流（优先级 1）和正道发育流（优先级 2）条件，**WHEN** 调用 `detect(state)`，**THEN** 返回 `&"spirit_realm_beast"`（归墟优先级最高）
- **GIVEN** 不满足任何流派条件，**WHEN** 调用 `detect(state)`，**THEN** 返回 `&""`（空 StringName）
- **GIVEN** 场上正道角色 = 2、需 3，**WHEN** 调用 `calculate_match(&"righteous_dev", state)`，**THEN** score < 100 且 missing 包含"还需 1 个正道角色"
- **GIVEN** `&"righteous_dev"` 流派，**WHEN** 调用 `get_school_effects(&"righteous_dev")`，**THEN** 返回包含 `{type="regen", target="zhengdao", value=2, trigger="turn_end"}` 等增益的数组
- **GIVEN** 流派从 A 切换到 B，**WHEN** detect() 返回 B，**THEN** `school_changed(A_id, B_id)` 信号已发射
- **GIVEN** `const SCHOOL_LIBRARY` 已定义，**WHEN** GUT 冒烟测试运行，**THEN** `SCHOOL_LIBRARY["righteous_dev"].name == "正道发育流"` 验证通过

## 相关决策

- ADR-0001：游戏状态管理器 Autoload —— `GSM.player.realm_level` 为归墟流派检测提供境界数据；`GSM.battle.active_school` 可选缓存当前激活流派
- ADR-0006：卡牌数据模型 Template/Instance 分离 —— CardTemplate 的 type/rarity/cost/faction_tags 字段为流派检测提供卡牌元数据
- ADR-0007：三分类信号体系 —— `school_changed` 分类为 Cat 2b 动作通知信号（单一事件通知，无 pre/post 配对）
- ADR-0008：战斗系统 7 阶段状态机 —— CombatSystem 在 PREPARATION 阶段调用 `detect()` 锁定流派增益
- ADR-0010：境界系统 Core 层 Autoload —— 本 ADR 采用相同模式（const Dictionary + 纯查询 + Core 层），流派的"静态数据 + 纯计算"与境界的"静态数据 + 纯查询"一脉相承
- ADR-0018：阵营系统 Core 层 Autoload —— 流派检测中的阵营条件判定全部委托给 FactionSystem（`count_on_field()` / `belongs_to_alignment()`）。本 ADR 是 FactionSystem 的核心消费者之一

## 未解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | **流派等级系统**：当前 GDD 不定义流派等级——流派只有"激活/未激活"二进制状态。`get_school_bonus(card, school_level)` 接口是预留的扩展点。未来若引入流派等级（如"使用流派 X 获胜 N 次后等级 +1"），需要定义：等级提升触发条件、等级增益缩放公式、等级存储位置（GSM 还是独立存档文件） | 流派系统的深度——目前够用，但限制了长期养成的设计空间 | 在轮回天赋系统 ADR 中协同设计（流派等级可能与轮回天赋联动） |
| 2 | **流派视觉主题的资源加载**：`SCHOOL_LIBRARY` 中定义了 color 值，但未定义光效/动画资源的引用路径。流派激活提示和增益触发的视觉反馈需要加载资源——是由 SchoolSystem 持有资源路径，还是由 UI 系统自行映射？ | UI 实现时的资源引用路径——不影响核心逻辑 | UI 系统实现时在 contracts.md 中定义 |
| 3 | **detect() 的 state 参数结构标准化**：当前 `state` 是一个自由格式的 Dictionary，由调用方自行组装。调用方（CombatSystem、DeckEdit）需要知道 detect() 内部需要哪些字段——这构成了隐式契约。是否需要定义 `SchoolDetectionState` 内部类作为显式契约？ | 调用方与 SchoolSystem 之间的接口清晰度——当前 Dictionary 灵活但缺少编译时验证 | 实现阶段评估——如果调用方数量超过 1 个且字段不一致，定义 Resource 或内部类 |