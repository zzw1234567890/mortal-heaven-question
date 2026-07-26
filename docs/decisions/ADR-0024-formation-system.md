# ADR-0024：阵法系统 — Feature 层 Autoload + 内部条件状态机 + GSM 快照持久化

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Formation |
| **知识风险** | LOW（Dictionary 操作、信号系统、Autoload 模式均为 4.x 成熟 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑不依赖 4.4+ 新增 API。`Dictionary` 键查找、`signal` 发射、`enum` 状态机均为 4.0+ 稳定 API |
| **需要验证** | `recheck_all_conditions()` 在每次角色上场/阵亡/离场信号触发时的遍历成本——最多 3 个阵法 × O(2-3) 实时 `FactionSystem.count_on_field()` 调用 < 0.01ms；`get_aura_bonus()` 在伤害计算热路径上的查询延迟（O(1) Dictionary 查找）；多阵法归属选择面板的 UI 交互在敌方回合的时序安全 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——战斗结束时接收阵法快照 `GSM.battle.formation_snapshot` 用于存档持久化）；ADR-0007（三分类信号体系——阵法生命周期事件归类为 Cat 2b 系统信号）；ADR-0008（CombatSystem——Phase 2 PLAY 阶段阵法卡打出流程；Phase 6 END 回合结束不需触发阵法重判——阵法条件由场上状态变更驱动）；ADR-0009（CardEffectEngine——`register_persistent_effect()` / `remove_effects_by_source()` 管理阵法光环效果的注册与注销）；ADR-0016（DeploymentSystem——`character_deployed` / `character_removed` 信号触发阵法条件重判；`get_field()` 获取当前场上角色列表）；ADR-0018（FactionSystem——`count_on_field()` / `check_condition()` 实时判定阵法激活条件） |
| **启用** | 前向引用：CombatUI（尚无独立 ADR——订阅阵法 Cat 2b 信号更新阵法区 UI、归属图腾、激活/失效动画）；前向引用：AI 系统（尚无独立 ADR——`get_aura_bonus()` 查询阵法光环对伤害计算的影响） |
| **阻塞** | 阵法 Epic（阵法卡打出→部署→条件判定→激活/未激活→覆盖→失效的完整生命周期）；战斗 Epic（Phase 2 阵法部署流程 + 阵法光环对伤害计算的影响）；卡牌效果 Epic（效果引擎的 ACTIVATE_FORMATION 效果类型） |
| **排序说明** | Feature 层——在 FactionSystem（ADR-0018, Autoload #15）和 DeploymentSystem（ADR-0016, Autoload #17）被接受后编写。完整 Autoload 链 25 个（从 18 个增至 25 个，本批次 7 个 ADR 并行创建）：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13 / ExplorationSystem #14 / FactionSystem #15 / ResourceSystem #16 / DeploymentSystem #17 / AISystem #18 / SchoolSystem #19 / CultivationSystem #20 / IdentitySelectionSystem #21 / DeckEditingSystem #22 / FormationSystem #23 / TribulationSystem #24 / StorySystem #25。FormationSystem 排在 #23——依赖 FactionSystem(#15) 和 DeploymentSystem(#17)，在 TribulationSystem(#24) 和 StorySystem(#25) 之前注册。FormationSystem._ready() 执行时 #1-#22 已完全初始化 |

## 上下文

### 问题陈述

`formation-system.md` GDD 定义了完整的阵法系统——阵法区（最多 3 个阵法）、5 种条件类型（阵营人数≥N、同阵营梯度、特定角色在场、绑定条件、门派人数）、激活/失效自动判定、覆盖流程、多阵法角色归属规则、阵眼角色阵亡→阵法失效、梯度阵法效果随人数增长等完整生命周期。但 GDD 关注的是"阵法应该表现出什么行为"，本 ADR 需要解决的是"阵法系统如何在 Godot 4.6 中工程化实现"：

1. **系统定位**：FormationSystem 是独立 Autoload 还是嵌入 CombatSystem 内部？阵法状态在战斗期间管理——需遵循 ADR-0011/0013/0016 的例外模式。阵法数据量小（最多 3 个阵位 Dictionary），但被 5+ 系统消费（战斗、效果引擎、AI、阵营、UI）——独立 Autoload 是最小耦合方案
2. **阵法光环的作用域**：全局光环 vs 特定阵位 vs 特定阵营角色？GDD 定义了多种效果类型——属性增益（作用于归属角色）、每回合效果（作用于全队/归属角色）、全局 buff（影响战斗规则）。需要统一的"作用域模型"来表达光环的生效范围
3. **阵法激活条件的实时判定**：部署时判定 + 每次"场上状态变更"时重判。需要订阅 DeploymentSystem 的 `character_deployed` / `character_removed` 和 CombatSystem 的 `character_died` 信号——收到信号后对全部 3 个阵法位重新调用 `FactionSystem.check_condition()`
4. **角色归属的管理**：多阵法同时激活时，满足条件的角色需手动指定归属（锁定到阵法失效）。归属数据存储在 FormationSystem 内部——`_affiliations: Dictionary[int, int]`（character_id → formation_id）
5. **战斗结束时阵法状态的持久化**：阵法位状态 + 归属关系——战斗结束时 `serialize_all()` 导出快照至 `GSM.battle.formation_snapshot` 用于存档
6. **梯度阵法的动态效果计算**：效果等级随场上同阵营人数实时变化——`effect_level = min(count_on_field(tag_id) - 1, max_level)`。不是快照值，而是每次查询时实时计算

`architecture.md` 将阵法系统归入 Feature 层——依赖 FactionSystem、DeploymentSystem、CombatSystem、CardEffectEngine。

### 约束

- **Feature 层定位**：FormationSystem 是 Feature 层 Autoload——依赖 Core 层（FactionSystem）和 Feature 层（CombatSystem、DeploymentSystem、CardEffectEngine），被 Presentation 层（CombatUI）消费
- **阵法区上限**：最多 3 个阵法——固定值，不由境界或其他系统动态调整
- **角色归属上限**：每角色最多归属 1 个阵法——`max_affilations(character) = 1`
- **激活条件实时判定**：部署时立即判定；每次 DeploymentSystem 的 `character_deployed` / `character_removed` 信号发射后重判全部阵法
- **覆盖流程**：阵法区满 3 个→玩家选择覆盖目标→旧阵法进弃牌堆→新阵法部署并立即判定
- **阵眼阵亡→阵法失效**：条件涉及特定角色或阵营人数——阵亡导致条件不满足时阵法立即失效，但阵位保留（占用 1/3），可被覆盖或条件恢复后重新激活
- **归属锁定**：角色归属选择后锁定到阵法失效——不是每回合重新选择。简化操作量
- **GSM 边界——ADR-0011/0013/0016 先例模式**：战斗期间阵法数据和角色归属由 FormationSystem 内部管理——战斗结束时导出快照至 GSM
- **帧预算**：`deploy_formation()` 单次 <0.5ms（含条件判定+效果注册）；`recheck_all_conditions()` <0.02ms（3 阵法 × O(2-3) FactionSystem 调用）；`get_aura_bonus()` O(1) Dictionary 查找 <0.001ms
- **Autoload 计数**：FormationSystem 为 Autoload #23——项目 Autoload 总数 25 个

### 需求

- 3 格阵法位的运行时管理：`_slots: Dictionary[int, Dictionary]`（slot_index → {formation_id, card_instance_id, template_id, state, deployed_turn, affiliated_characters}）
- 阵法状态机：DEPLOYED_UNACTIVE → ACTIVE → （失效）→ UNACTIVE → （条件恢复）→ ACTIVE 或 （被覆盖）→ DISCARDED
- 公共 API：`deploy_formation()` / `overwrite_formation()` / `recheck_all_conditions()` / `set_character_affilation()` / `get_aura_bonus()` / `get_formation_state()` / `get_active_formations()` / `serialize_all()` / `deserialize_all()` / `clear_all_formations()`
- 条件判定管线：通过 `FactionSystem.check_condition(requirement)` 判定——requirement 格式 `{tag_id: StringName, min_count: int}` 或 `{character_id: int}`（特定角色在场）或 `{binding_threshold: int}`（绑定条件）
- 梯度阵法动态效果：`get_aura_bonus(character_id, stat_name)` → 实时计算当前场上同阵营人数 → 确定效果等级 → 返回梯度效果值
- 光环作用域模型：`AuraScope` 枚举——GLOBAL（影响战斗规则，如抽卡概率）、AFFILIATED_CHARACTERS（作用于归属角色，如属性增益）、SAME_FACTION（作用于同一阵营的所有角色，如每回合回复）、FORMATION_TRIGGER（条件触发，如击杀后攻击永久+2）
- Cat 2b 信号：`formation_deployed` / `formation_activated` / `formation_deactivated` / `formation_overwritten` / `character_affiliated` / `formation_condition_reevaluated`（由 FormationSystem Autoload 直接发射，通过 ADR-0007 `_emit_signal_safe` 包装器路由）
- 战斗结束时：`serialize_all()` 导出阵法快照至 `GSM.battle.formation_snapshot`——用于存档；`clear_all_formations()` 清理所有阵法和归属数据

## 决策

**FormationSystem 实现为 Feature 层 Autoload（FormationSystem），采用内部状态机管理阵法位数据——阵法位状态、激活/未激活判定、角色归属关系均在 FormationSystem 内部 Dictionary 中管理。战斗期间阵法数据不经过 GSM。战斗结束时 `serialize_all()` 导出阵位快照至 `GSM.battle.formation_snapshot` 用于存档持久化。阵法激活条件通过订阅 DeploymentSystem 的 `character_deployed` / `character_removed` 信号实时重判。阵法光环效果通过 `get_aura_bonus()` 提供 O(1) 查询——CombatSystem 在伤害计算时、CombatUI 在显示属性时调用。角色归属由玩家在阵法激活时手动指定，锁定到阵法失效。**

### 对象模型

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    FormatonSystem 对象模型                         │
│                                                                   │
│  ┌─────────────────────┐          ┌──────────────────────────┐     │
│  │  FactionSystem       │  查询   │  阵法位数据 (运行时)      │     │
│  │  (ADR-0018)          │───────→ │                          │     │
│  │                      │  count_ │  _slots: Dictionary       │     │
│  │  count_on_field()    │  on_    │    slot_index → {         │     │
│  │  check_condition()   │  field  │      formation_id: int,   │     │
│  └─────────────────────┘          │      card_instance_id: int,│     │
│                                    │      template_id: String,  │     │
│  ┌─────────────────────┐          │      state: SlotState,     │     │
│  │  DeploymentSystem    │  信号   │      deployed_turn: int,   │     │
│  │  (ADR-0016)          │───────→ │      requirement: Dict,    │     │
│  │                      │  char_  │      aura_scope: AuraScope,│     │
│  │  character_deployed  │  deployed│      effect_config: Dict,  │     │
│  │  character_removed   │  /      │      affiliated_chars:     │     │
│  └─────────────────────┘  removed │        Array[int]          │     │
│                                    │    }                      │     │
│  内部注册表（战斗期间——不通过 GSM）：│                          │     │
│    _slots: Dictionary[int, Dict]  │  角色归属（战斗期间）：     │     │
│    _affiliations: Dict[int, int]  │    character_id →          │     │
│    _next_formation_id: int        │      formation_id          │     │
│                                    │                          │     │
│  战斗结束时：                       │  每角色最多归属 1 个阵法   │     │
│    serialize_all() →               │                          │     │
│      GSM.battle.formation_snapshot │                          │     │
│    clear_all_formations() →        │                          │     │
│      清空 _slots + _affiliations   │                          │     │
└──────────────────────────────────────────────────────────────────────┘
```

### 阵法状态机

```
                    ┌──────────┐
                    │  手牌     │
                    └────┬─────┘
                         │ 阵法卡打出 (Phase 2 PLAY)
                         ▼
              ┌──────────────────────┐
              │  DEPLOYED_UNACTIVE    │ ◄── 部署完成，条件不满足
              │  占用阵位 ✓          │
              │  光环生效 ✗           │
              │  可被攻击(阵法本身) ✗│
              └────┬────────┬───────┘
                   │        │
       条件满足 ──┘        └────── 场上状态变更→条件满足
                   ▼
              ┌──────────────────────┐
              │  ACTIVE               │ ◄── 条件满足，光环生效
              │  占用阵位 ✓          │
              │  光环生效 ✓           │
              │  角色归属可指定       │
              └────┬────────┬──────┬┘
                   │        │      │
        条件不满足─┘   覆盖─┘      └── 战斗结束
                   ▼        ▼           ▼
              ┌────────┐ ┌──────────┐ ┌─────────────┐
              │ UNACTIVE│ │ DISCARDED │ │ clear_all_  │
              │ (同     │ │ 旧阵法进 │ │ formations()│
              │ DEPLOYED│ │ 弃牌堆    │ │ → 清空      │
              │ _UNACTIVE)│ │ 不可恢复 │ │             │
              └────┬───┘ └──────────┘ └─────────────┘
                   │
        条件恢复───┘
                   ▼
              ┌──────────────────────┐
              │  ACTIVE (重新激活)    │
              └──────────────────────┘
```

### 阵法位数据模型

```
阵法区布局（战场顶部 UI 区域，独立于角色阵位）：

    ┌──────┐ ┌──────┐ ┌──────┐
    │ 阵法1 │ │ 阵法2 │ │ 阵法3 │   ← 阵法位 0-2
    │ (位0) │ │ (位1) │ │ (位2) │
    └──────┘ └──────┘ └──────┘

slot_index: 0=阵法位1, 1=阵法位2, 2=阵法位3
阵法位与角色阵位独立——阵法不占用角色位置，角色也不占用阵法位
```

### 关键接口

#### FormationSystem 公共 API

| 方法 | 签名 | 说明 |
|------|------|------|
| `deploy_formation` | `deploy_formation(card_instance_id: int, template_id: StringName, slot_index: int = -1) → DeployResult` | 部署阵法卡到阵法区。slot_index=-1 时自动分配第一个空位。DEPLOYED_UNACTIVE 状态→立即判定条件→条件满足则激活。DeployResult = {success: bool, formation_id: int, slot_index: int, activated: bool, reason: String}。reason: 'deployed_active' / 'deployed_inactive' / 'slots_full' / 'invalid_template' |
| `overwrite_formation` | `overwrite_formation(card_instance_id: int, template_id: StringName, target_slot: int) → DeployResult` | 阵法区已满→覆盖指定阵位。旧阵法 DISCARDED（释放全部归属关系）→新阵法部署→立即判定条件 |
| `recheck_all_conditions` | `recheck_all_conditions() → Array[Dictionary]` | DeploymentSystem 信号触发→遍历 3 个阵法位→对每个阵法调用 `FactionSystem.check_condition(requirement)`→条件变化时更新状态。返回变更列表 [{formation_id, old_state, new_state, reason}]。**不发射信号**（由调用方在信号处理器中发射——避免信号级联） |
| `set_character_affilation` | `set_character_affilation(character_id: int, formation_id: int) → bool` | 玩家手动指定角色归属阵法。角色当前无归属 + 阵法为 ACTIVE + 角色满足条件→返回 true。角色已有归属→返回 false（需先清除旧归属）。发射 `character_affiliated` 信号 |
| `clear_character_affilation` | `clear_character_affilation(character_id: int) → void` | 阵法失效/覆盖时自动调用——清除角色归属关系。若角色归归属的阵法变为 UNACTIVE/DISCARDED→自动清除 |
| `get_aura_bonus` | `get_aura_bonus(character_id: int, stat_name: String) → AuraBonusesult` | 战斗热路径 O(1) 查询——计算角色从归属阵法获得的总光环加成。AuraBonusesult = {total_bonus: float, breakdown: Array[Dict]}。对同阵营梯度阵法：实时计算当前场上同阵营人数→确定效果等级→返回梯度值 |
| `get_formation_state` | `get_formation_state(formation_id: int) → Dictionary` | O(1) 查询单阵法完整状态——{slot_index, template_id, state, deployed_turn, requirement, affiliated_count, is_active} |
| `get_active_formations` | `get_active_formations() → Array[Dictionary]` | 返回所有 ACTIVE 状态阵法的摘要列表——CombatUI 每帧更新阵法区显示 |
| `get_slot_states` | `get_slot_states() → Array[Dictionary]` | 返回 3 个阵法位的完整状态——CombatUI 渲染阵法区 UI |
| `get_character_affilation` | `get_character_affilation(character_id: int) → int` | O(1) 查询角色归属的阵法 ID——未归属返回 -1。CombatUI 显示角色头像旁归属图腾 |
| `is_formation_active` | `is_formation_active(formation_id: int) → bool` | O(1) 查询阵法是否处于 ACTIVE 状态 |
| `can_deploy` | `can_deploy() → CanDeployResult` | 阵法部署前检查。CanDeployResult = {can_deploy: bool, empty_slots: int, reason: String} |
| `serialize_all` | `serialize_all() → Dictionary` | 战斗结序时序列化全部阵法数据→GSM.battle.formation_snapshot。包含_slots 快照 + _affiliations + _next_formation_id |
| `deserialize_all` | `deserialize_all(data: Dictionary) → void` | 从快照恢复（读档/战斗快照恢复） |
| `clear_all_formations` | `clear_all_formations() → void` | 战斗结束时清空所有阵法位和归属关系——CombatSystem.battle_end() 调用 |

#### Cat 2b 信号（通过 `_emit_signal_safe` 路由）

| 信号 | 参数 | 触发时机 | 订阅者 |
|------|------|----------|--------|
| `formation_deployed` | `(formation_id, slot_index, template_id, deployed_turn)` | 阵法卡部署到阵法位（无论是否激活） | ComatUI（阵位更新+部署动画 0.5s）、AudioSystem（部署音效） |
| `formation_activated` | `(formation_id, slot_index, template_id, trigger_reason: String)` | 阵法条件满足→激活 | ComatUI（激活动画 0.3s+光环特效）、CardEffectEngine（注册持续效果）、AudioSystem（激活音效） |
| `formation_deactivated` | `(formation_id, slot_index, reason: String)` | 阵法条件不满足→失效 | ComatUI（失效动画 0.3s+灰显+锁标记）、CardEffectEngine（移除持续效果） |
| `formation_overwritten` | `(old_formation_id, new_formation_id, slot_index)` | 覆盖完成 | ComatUI（覆盖动画 0.6s——旧阵熔化+新阵展开） |
| `character_affiliated` | `(character_id, formation_id)` | 玩者手动指定角色归属 | ComatUI（角色头像旁显示归属图腾 0.2s） |
| `formation_condition_reevaluated` | `(changes: Array[Dictionary])` | `recheck_all_conditions()` 完成后批量通知 | ComatUI（阵法区状态刷新） |

信号链深度 ≤2 层——阵法信号→ComatUI 更新+CardEffectEngine 效果变更→无进一步信号级联。

### 阵法条件判定管线

```
deploy_formation() 或 recheck_all_conditions()
  │
  ▼
┌──────────────────────────────┐
│ 1. 加载阵法条件定义          │
│   requirement = template.    │
│     activation_requirement   │
│   格式: {type, tag_id/       │
│          character_id,       │
│          min_count}          │
└────────────┬───────────────┘
             ▼
┌──────────────────────────────┐
│ 2. 调用 FactionSystem       │
│   check_condition(req)      │
│   → 实时遍历场上角色         │
│   → O(6×3) <0.001ms         │
└────────────┬───────────────┘
             ▼
       ┌────┴────┐
       ▼         ▼
  条件满足    条件不满足
       │         │
       ▼         ▼
  ACTIVE    UNACTIVE
       │         │
       ▼         ▼
  注册光环    注销光环
  (CardEffect (CardEffect
   Engine)     Engine)
```

### 梯度阵法动态效果计算

```gdscript
## 梯度阵法光环加成——实时计算当前场上同阵营人数
func _calculate_gradient_aura(formation_id: int, target_character_id: int, stat_name: String) -> float:
    var slot = _slots[_get_slot_by_formation(formation_id)]
    var requirement = slot.requirement
    var tag_id: StringName = requirement.get("tag_id", &"")
    if tag_id.is_empty():
        return 0.0

    # 实时查询场上该阵营角色数
    var count_on_field: int = FactionSystem.count_on_field(tag_id)
    
    # 门槛检查：≥2 人
    if count_on_field < 2:
        return 0.0
    
    # 效果等级：人数-1（2人→1级、3人→2级...）
    var effect_level: int = mini(count_on_field - 1, slot.max_level)
    return slot.base_value * float(effect_level)
```

**公式**：`effect_value = base_value × min(count_on_field(tag_id) - 1, max_level)`

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| tag_id | StringName | 阵营标签 ID | 梯度的判定阵营 |
| count_on_field | int | [0,6] | 当前场上该阵营的角色数量 |
| max_level | int | [4,6] | 阵法稀有度决定（蓝 4/紫 5/金 6） |
| base_value | float | 按阵法定义 | 每级的基础效果增量 |
| effect_level | int | [1, max_level] | 当前效果等级（2 人→1 级，3 人→2 级，依此类推） |

### 光环作用域模型

| 作用域 | AuraScope 枚举 | 效果作用于 | 示例 |
|--------|-------------|-----------|------|
| 全局规则 | `GLOBAL` | 战斗规则本身 | 万象忘尘阵：抽卡概率+15% |
| 归属角色 | `AFFILIATED` | 仅归属到此阵法的角色 | 苍玄正道盟阵：归属角色 HP+2, DEF+1 |
| 同阵营 | `SAME_FACTION` | 场上所有满足阵营条件的角色 | 玄冰回春阵：全体同道每回合回复 1 HP |
| 条件触发 | `TRIGGERED` | 事件触发时执行 | 魔域血海阵：击杀后攻击永久+2 |

CardEffectEngine 在注册光环效果时根据 AuraScope 确定效果的目标集合——FormationSystem 仅提供作用域标记，不直接操作角色属性。

### 角色归属管理

```
角色归属生命周期：
  无归属 → 阵法激活 + 玩家指定 → 已归属(锁定)
                                          │
                              阵法失效/被覆盖 → 无归属

归属规则：
  - 每角色最多归属 1 个阵法（max_affilations = 1）
  - 仅 ACTIVE 状态的阵法可接受角色归属
  - 归属选择后锁定到阵法失效——不可中途更换
  - 阵法失效时自动清除所有归属关系
  - 阵法被覆盖时自动清除所有归属关系
  - 角色阵亡时保留归属关系（阵位角色阵亡不影响阵法其他归属角色）
```

### 覆盖流程

```
阵法区已满（3/3）+ 玩家打出新阵法卡
  │
  ▼
┌──────────────────────────────┐
│ 1. ComatSystem 发射          │
│    formation_overwrite_query │
│    → ComatUI 显示覆盖选择   │
│      面板                    │
└──────────┬─────────────────┘
           │ 玩家选择覆盖目标阵位
           ▼
┌──────────────────────────────┐
│ 2. overrite_formation(       │
│    card_instance_id,         │
│    template_id,              │
│    target_slot)              │
│    ├─ 旧阵法 state→DISCARDED │
│    ├─ 清除旧阵法所有归属     │
│    ├─ CardEffectEngine       │
│    │  .remove_effects_by_    │
│    │   source(old_card_id)    │
│    ├─ 新阵法部署到该阵位     │
│    ├─ 立即判定条件           │
│    └─ 发射 formation_        │
│       overwritten +          │
│       formation_deployed     │
└───────────────────────────────┘
```

### GSM 边界——ADR-0011/0013/0016 先例模式

本 ADR 采用与 ADR-0011 StatusEffectSystem、ADR-0013 BindingManager、ADR-0016 DeploymentSystem 相同的 GSM 边界模式：

- **战斗期间**：所有阵法位数据和角色归属由 FormationSystem 内部管理——不存储在 GSM 中。热路径查询（`get_aura_bonus()`、`get_character_affilation()`）直接在 FormationSystem 内部 Dictionary 完成，不经过 GSM 层
- **战斗结束**：`serialize_all()` 导出阵位快照至 `GSM.battle.formation_snapshot`——用于战斗快照持久化
- **GSM 只读**：FormationSystem 不调用 GSM 写入方法——所有阵法数据内部管理
- **架构原则例外声明**：与 ADR-0011/0013/0016 相同——`architecture.md` §架构原则 #1 需增加 ADR-0024 例外："战斗中阵法数据和角色归属由 FormationSystem 独立管理，仅战斗结束时导出快照至 GSM"

### 与 CardEffectEngine 的集成

FormationSystem 在阵法状态变更时调用 CardEffectEngine 的 persistent effect 接口：

| 时机 | 调用 | 说明 |
|------|------|------|
| 阵法激活 | `CardEffectEngine.register_persistent_effect(formation_card_instance_id, template_id, scope_context)` | 注册阵法光环的持续效果。scope_context 包含 AuraScope 和归属角色列表 |
| 阵法失效 | `CardEffectEngine.remove_effects_by_source(formation_card_instance_id)` | 注销阵法光环效果 |
| 阵法覆盖（旧） | `CardEffectEngine.remove_effects_by_source(old_card_instance_id)` | 先移除旧阵法效果 |
| 阵法覆盖（新） | `CardEffectEngine.register_persistent_effect(new_card_instance_id, ...)` | 再注册新阵法效果——严格顺序 |
| 归属变更 | `CardEffectEngine.update_effect_scope(card_instance_id, new_scope_context)` | 角色归属变更时更新光环作用域 |

### Autoload 初始化

```
FormationSystem 初始化顺序（Autoload #23——完整链 25 个）：

  #1  GSM              (Foundation, ADR-0001)
  #2  InputManager      (Foundation, ADR-0005)
  #3  SceneManager      (Foundation)
  #4  SaveLoad           (Foundation, ADR-0002)
  #5  EventSystem        (Foundation, ADR-0003)
  #6  CardSystem         (Core, ADR-0006)
  #7  CostSystem         (Core, ADR-0015)
  #8  StatusEffectSystem (Core, ADR-0011)
  #9  CombatSystem       (Feature, ADR-0008)
  #10 CardEffectEngine   (Feature, ADR-0009)
  #11 RealmSystem        (Core, ADR-0010)
  #12 ProgressionSystem  (Meta, ADR-0012)
  #13 BindingManager     (Feature, ADR-0013)
  #14 ExplorationSystem  (Feature, ADR-0014)
  #15 FactionSystem      (Core, ADR-0018)
  #16 ResourceSystem     (Core, ADR-0019)
  #17 DeploymentSystem   (Feature, ADR-0016)
  #18 AISystem           (Feature, ADR-0017)
  #19 SchoolSystem       (Feature)
  #20 CultivationSystem  (Feature)
  #21 IdentitySelectionSystem (Feature, ADR-0022)
  #22 DeckEditingSystem  (Feature, ADR-0023)
  #23 FormatonSystem     (Feature, ADR-0024)  ← 本 ADR
  #24 TribulationSystem  (Feature)
  #25 StorySystem        (Feature, ADR-0026)

_ready():
  1. 等待 gsm_initialized 信号（ADR-0001）——确保 GSM 可读
  2. 初始化 _slots: 3 个空阵位（slot_index 0-2，state=EMPTY）
  3. 初始化 _affiliations 为空 Dictionary
  4. 初始化 _next_formation_id = 1
  5. 连接 DeploymentSystem 信号：
     - character_deployed → _on_field_changed
     - character_removed → _on_field_changed
  6. 连接 CombatSystem 信号（可选——character_died 与 character_removed 重叠，取其一连接）：
     - 若 DeploymentSystem character_removed 已覆盖阵亡场景→无需额外连接
  7. 注册 CardEffectEngine 的 ACTIVATE_FORMATION 效果类型处理器（通过 ADR-0009 的效果类型注册表）
```

**Godot Autoload 初始化顺序保证**：Godot 按 `project.godot` 的 `[autoload]` 列表顺序逐个同步调用每个 Autoload 的 `_ready()`——下层 `_ready()` 在上层完整返回后才执行。Godot 4.0 至 4.6 行为一致。FormationSystem（#23）执行时 #1-#22 已完全初始化。

## 考虑的替代方案

### 替代方案 1：FormationSystem 作为 CombatSystem 内部子系统

- **描述**：不创建独立 Autoload——阵法逻辑内嵌为 CombatSystem 的内部模块（`CombatSystem._formation_manager`）。阵位数据和归属关系直接挂在 CombatSystem 上
- **优点**：零 Autoload 开销（保持 18 个）；阵位数据与战斗生命周期自然绑定（战斗结束→阵法自动清理）；CombatSystem 直接编排阵法部署——无需跨 Autoload 调用
- **缺点**：（1）CombatSystem 已编排 9+ 子系统（ADR-0008）——再内嵌阵法管理将进一步膨胀其职责；（2）`get_aura_bonus()` 被 AI 系统、CombatUI 在伤害计算和属性显示时每帧调用——如果阵位数据在 CombatSystem 内部，这些消费者都需要通过 CombatSystem 间接查询，增加耦合；（3）角色归属查询 `get_character_affilation()` 被 ComatUI 每帧调用——间接查询链过长；（4）CardEffectEngine 的效果注册/注销需要明确的责任边界——阵法系统作为效果来源之一，应有独立身份
- **拒绝原因**：违反单一职责——CombatSystem 已承担 7 阶段编排 + 9+ 子系统调度，不应再内嵌阵法数据管理。独立 Autoload 使 AI、CombatUI、CardEffectEngine 能以解耦方式查询阵法状态和光环加成。这与 ADR-0016 DeploymentSystem 独立于 CombatSystem 的决策一致——阵法是战斗的"策略层"，而非战斗编排逻辑

### 替代方案 2：阵法数据存储在 GSM battle.* 域中

- **描述**：阵法位数据和角色归属通过 `GSM.battle.formations` Dictionary 存储——所有阵位读写通过 GSM 第二层 API
- **优点**：阵位数据与其他战斗数据（phase、turn、player_field）在同一位置——概念简单；战斗结束 GSM 清理 battle 域时自动清理阵法数据
- **缺点**：（1）`get_aura_bonus()` 被 CombatSystem 在伤害计算时每帧调用——通过 GSM 层查询增加方法调用开销+序列化/反序列化往返；（2）阵法部署/激活/失效/覆盖操作频繁——GSM `batch_updated` 信号为每次阵位变更发射，信号噪音高；（3）GSM 字典存储序列化 Dictionary（非 RefCounted 对象引用）→每次条件重判需序列化/反序列化；（4）角色归属变更同样需要通过 GSM——高频查询路径退化
- **拒绝原因**：与"战斗期间子系统内部管理"的先例模式相悖——ADR-0011（StatusEffectSystem）、ADR-0013（BindingManager）、ADR-0016（DeploymentSystem）均已确立战斗热路径数据不经过 GSM 的例外模式。阵法数据与此同类——高频查询（CombatSystem 伤害计算 + ComatUI 属性显示每帧数次）+ 轻量 Dictionary 存储 + 战斗结束导出快照。GSM 已持有 playr_field/enemy_field/bindings/deployment_snapshot——阵法快照是这些数据的"策略修饰层"，应由 FormationSystem 独立管理以避免 GSM 职责持续膨胀

### 替代方案 3：角色归属自动分配（非玩家手动指定）

- **描述**：多阵法同时激活时，角色自动分配到效果最强的阵法——无玩家手动选择。归属规则由系统根据光环效果值自动排序分配
- **优点**：零玩家操作——阵法激活无额外 UI 流程；减少战斗决策点——加快战斗节奏
- **缺点**：（1）违背 GDD 的玩家幻想——"多阵的困惑"和"覆盖的取舍"是中频决策点，自动分配移除了策略深度；（2）效果强弱比较逻辑复杂——不同阵法对不同角色的加成不可直接比较（HP+2 vs ATK+1 vs 25% 概率魅惑）——自动排序需要"效果价值"量化系统，引入不必要的复杂度；（3）GDD 明确要求"玩家手动指定该角色归属哪个阵法"——自动分配与设计意图矛盾
- **拒绝原因**：GDD 明确要求玩家手动指定归属——这是"策略为王"支柱的核心体现。自动分配移除策略深度，且效果价值量化系统是不必要的复杂度。归属选择面板的 UI 成本低（弹出式单次选择），不影响战斗节奏

### 替代方案 4：归属每回合可调整

- **描述**：角色归属不是锁定到阵法失效，而是每回合布阵阶段可调整一次
- **优点**：更灵活——玩家可以根据战局变化调整策略；多阵法环境下角色归属可动态优化
- **缺点**：（1）增加操作频率——每回合需要重新审视归属选择，拖慢战斗节奏；（2）GDD 的推荐方案是"锁定到失效"——"选择后就要承担后果"增加了阵法的沉没成本；（3）归属调整增加了 CombatSystem Phase 2 PLAY 阶段的复杂度——布阵阶段已经包含卡牌操作，再增加归属调整会挤压时间窗口
- **拒绝原因**：GDD 推荐"锁定到阵法失效"方案——本章采纳此推荐。归属锁定增加了策略的分量——玩家在阵法激活时做出的选择有持久后果。GDD 将此标记为开放问题 #1，并给出推荐方向——本 ADR 将此开放问题决议为锁定方案。若 UX 测试发现操作量过大，可在 MVP 后通过调优参数调整

## 后果

### 积极的

- **清晰的阵位真理来源**：`_slots` Dictionary 是阵法位状态和角色归属的唯一定义点——CombatSystem、AI、CardEffectEngine、CombatUI 均通过 FormationSystem 查询，消除"哪个阵法在生效、谁归属哪个阵法"的歧义
- **与已有先例一致**：战斗期间数据内部管理 + 战斗结束导出快照至 GSM 的模式与 ADR-0011（StatusEffectSystem）、ADR-0013（BindingManager）、ADR-0016（DeploymentSystem）一致——降低学习成本和代码审查复杂度
- **O(1) 光环查询**：`get_aura_bonus()` 和 `get_character_affilation()` 均为 Dictionary 查找——战斗热路径性能可忽略不计
- **CombatUI 解耦**：Cat 2b 信号总线使 ComatUI 仅订阅 FormationSystem 信号即可获取全部阵法状态变更——无需直接轮询 FormationSystem API
- **GSM 规模控制**：GSM 不持有阵法位数据和归属关系——仅战斗结束时接收序列化快照 Dictionary（最多 3 阵位 × 10 字段 ≈ 300 bytes）
- **梯度阵法与固定阵法的统一查询接口**：`get_aura_bonus()` 内部处理梯度计算和固定值两种情况——消费者无需知道阵法类型差异
- **GDD 开放问题决议**：#1（归属锁定 vs 每回合可调）→锁定到失效；与 GDD 推荐方案一致

### 消极的

- **Autoload 数量增加至 23**：FormationSystem 为 Autoload #23——项目 Autoload 总数 25 个。初始化顺序依赖链延长
- **GSM 例外模式第四处扩散**：ADR-0011（StatusEffectSystem）、ADR-0013（BindingManager）、ADR-0016（DeploymentSystem）、ADR-0024（FormationSystem）均采用"战斗期间子系统内部管理"的例外模式——需在 `architecture.md` 中明确记录例外清单，防止未来子系统滥用此模式
- **角色归属的 UI 交互在敌方回合的时序安全**：阵法激活条件在场上状态变更时自动重判——可能在敌方回合触发。如果重判导致新阵法激活→需要弹出归属选择面板——但敌方回合不应中断玩家 UI 交互。（缓解：敌方回合触发的条件重判中，若新阵法激活需要归属选择→延迟到己方回合开始再弹出——类似于"待处理归属队列"）
- **梯度阵法的效果计算略重**：每次 `get_aura_bonus()` 调用都需要实时计算 `count_on_field()`——虽然 O(6×3) <0.001ms，但若一帧内被多次调用（CombatSystem 伤害计算 + ComatUI 显示 × 6 角色），总计约 20-30 次遍历。在当前规模下仍可忽略，但需记录为已知开销
- **GGD 三个开放问题仍待下游系统决议**：#2（敌方 AI 归属判定）→ AI 系统 ADR；#3（万象忘尘阵抽卡概率）→ CombatSystem；#4（乾坤颠倒阵混乱效果）→ 效果引擎

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Autoload 数量持续增长（25→25+） | 中 | 启动时间增加、初始化顺序复杂度 | 当前 25 个已达此批次上限。后续 ADR 创建新 Autoload 时需引用此风险。阵法系统之后的余下系统中部分可合并——单一职责的边界需逐案评估 |
| 敌方回合触发归属选择面板的时序问题 | 中 | 玩家 UI 交互被敌方回合打断——糟糕的 UX | 延迟归属队列机制：敌方回合条件重判中需归属选择的→压入 `_pending_affiliations` 队列→己方回合 Phase 1 DR AW 开始时弹出。GUT 集成测试覆盖敌方回合条件重判 + 归属延迟场景 |
| `recheck_all_conditions()` 信号处理中的重入 | 低 | DeploymentSystem 信号处理器中调用→若 `recheck_all_conditions()` 内部发射信号→信号处理器递归深度增加 | `recheck_all_conditions()` 不直接发射信号——返回变更列表，由调用方的信号处理器在遍历完所有阵位后批量发射 `formation_condition_reevaluated`。信号发射延迟到条件重判全部完成后 |
| 梯度阵法的 `max_level` 与稀有度的绑定在数据层面的正确性 | 低 | 策划配置错误导致蓝色阵法 max_level=6（应封顶 4）→效果超预期 | 启动时校验：遍历全部阵法模板的 max_level 与 rarity 的一致性（蓝≤4、紫≤5、金≤6）→不一致时 push_error + 拒绝加载。GUT 冒烟测试覆盖 |
| `serialize_all()` / `deserialize_all()` 的归属关系完整性 | 低 | 读档恢复时 character_id 对应的角色可能已不可用（全部阵亡）→归属关系悬空 | `deserialize_all()` 中逐条验证 character_id——验证失败则跳过该归属 + WARN 日志。归属关系悬空不影响阵法自身状态恢复 |
| 阵法效果与 StatusEffectSystem 的交互重叠 | 低 | 阵法光环的"属性增益"（HP+2）与 StatusEffectSystem 的 `get_accumulated_value()` 可能重复计算 | CardEffectEngine 是属性修正的唯一仲裁者——阵法光环通过 `register_persistent_effect()` 注册，与状态效果的 `apply_status()` 走同一效果结算通道。不存在双轨计算 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| formation-system.md | §1 阵法区——最多 3 个阵法，独立于角色阵位 | `_slots: Dictionary[int, Dict]` —— slot_index 0-2。阵法位与角色阵位完全独立 |
| formation-system.md | §2 阵法部署流程——打出阵法卡→检查空位→覆盖流程→立即判定条件 | `deploy_formation()` + `overrite_formation()` —— 空位直接部署，满位进覆盖流程，部署后立即调用 `FactionSystem.check_condition()` |
| formation-system.md | §3 阵法激活与失效——条件满足激活/条件失去失效/自动判定 | 状态机（DEPLOYED_UNACTIVE↔ACTIVE）+ `recheck_all_conditions()` 订阅 DeploymentSystem 信号自动重判 |
| formation-system.md | §4 覆盖规则——选择覆盖目标/旧阵法进弃牌堆/新阵法立即判定 | `overrite_formation()` —— 严格顺序：旧阵→DISCARDED+清除归属→CardEffectEngine.remove→新阵→部署+判定 |
| formation-system.md | §5 多阵法角色归属——每角色最多 1 个阵法/玩家手动指定/锁定到阵法失效 | `_affiliations: Dict[int, int]` + `set_character_affilation()` + `clear_character_affilation()` —— max_affilations=1，锁定到阵法失效 |
| formation-system.md | §6 阵眼角色阵亡→阵法失效/阵位保留/可重新激活 | 条件重判中检测阵亡导致的条件不满足→阵法变为 UNACTIVE（阵位保留）；后续角色上场补足条件→重新 ACTIVE |
| formation-system.md | §7 阵法效果类型——属性增益/每回合效果/条件触发/概率效果/全局 buff | `AuraScope` 枚举 + CardEffectEngine persistent effect 接口——5 种效果类型映射为 GLOBAL/AFFILIATED/SAME_FACTION/TRIGGERED 四种作用域 |
| formation-system.md | §9 同阵营梯度阵法——门槛 2 人/效果随人数递增/封顶机制/多阵营取最多 | `_calculate_gradient_aura()` —— `effect_level = min(count_on_field(tag_id)-1, max_level)`；多阵营平局取先入场阵营 |
| formation-system.md | §边界情况——3 格全满覆盖/全未激活满位/同角色满足 3 阵法/阵眼复活重激/梯度降级/多阵营平局 | 每个边界情况对应本 ADR 的决策——覆盖流程、位占用、归属上限 1、条件重判自动处理、梯度实时计算 |
| formation-system.md | §依赖关系——6 个系统的数据流出入 | 入：FactionSystem（条件判定）、DeploymentSystem（场上变更信号）、CardEffectEngine（效果注册）、CombatSystem（阶段信号）。出：光环加成查询、阵法状态信号→ComatUI |
| formation-system.md | §调优参数——阵法区上限=3/归属上限=1/阵营人数≥3/归属锁定到失效 | 所有调优参数在本 ADR 中硬编为常量——提供集中修改点 |

## 性能影响

- **CPU**：`deploy_formation()` 单次 <0.5ms（含条件判定+FactionSystem 调用+效果注册）；`recheck_all_conditions()` <0.02ms（3 阵法 × FactionSystem O(6×3)）；`get_aura_bonus()` <0.001ms（Dictionary 查找+梯度实时计算）。对 60fps 帧预算无显著影响
- **内存**：`_slots` Dictionary（3 阵位 × 10 字段）≈ 300 bytes；`_affiliations`（最多 6 角色 × 8 bytes）≈ 48 bytes。Autoload 节点 ≈ 1KB。总计 <2KB 常驻内存
- **加载时间**：FormationSystem._ready() 不加载模板——无启动开销。阵法模板在 CardSystem 中作为卡牌数据的一部分已加载
- **网络**：不适用（单机游戏）

## 迁移计划

本 ADR 为新系统——无需迁移现有代码。实现顺序：

1. `SlotState` 枚举 + `AuraScope` 枚举 + 阵位数据模型（Dictionary 结构）
2. FormationSystem Autoload 骨架（Autoload 注册 #23 + `_slots` + `_affiliations` 初始化）
3. `deploy_formation()` + 条件判定 + 状态机
4. `recheck_all_conditions()` + DeploymentSystem 信号连接
5. `overrite_formation()` + 覆盖流程
6. `set_character_affilation()` / `clear_character_affilation()` + 归属管理
7. `get_aura_bonus()` + 梯度阵法 `_calculate_gradient_aura()`
8. `serialize_all()` / `deserialize_all()` + 战斗结束快照
9. `clear_all_formations()` + CombatSystem battle_end 集成点
10. CardEffectEngine 集成（persistent effect 注册/注销/作用域更新）
11. Cat 2b 信号总线（6 个信号）
12. ComatUI 订阅 + 阵法区 UI + 归属图腾 + 覆盖选择面板 + 归属选择面板

## 验证标准

- GUT 单元测试：`deploy_formation()` 空位部署——条件满足→立即 ACTIVE；条件不满足→DEPLOYED_UNACTIVE；满位→返回 slos_full
- GUT 单元测试：`recheck_all_conditions()` —— 场上阵营人数从 2 变为 3→UNACTIVE 阵法变为 ACTIVE；人数从 3 降为 2→ACTIVE 变为 UNACTIVE
- GUT 单元测试：`overrite_formation()` —— 旧阵法 DISCARDED + 归属清除 + 新阵法部署 + 条件判定
- GUT 单元测试：归属管理——指定归属→角色已有归属→拒绝；阵法失效→自动清除归属；角色阵亡→归属记录保留
- GUT 单元测试：梯度阵法 `get_aura_bonus()` —— 场上 2 人→1 级效果；4 人→3 级效果；封顶值正働
- GUT 单元测试：`serialize_all()` → `deserialize_all()` 往返——阵位状态 + 归属关系完整恢复
- GUT 单元测试：`clear_all_formations()` —— 所有阵位→EMPTY；所有归属→清除；_nex_formation_id 保留
- 集成测试：CombatSystem.battle_start → Phase 2 阵法部署 → 条件自动判定 → 角色阵亡触发重判 → 覆盖流程 → battle_end clear_all_formations 完整流程
- 集成测试：CardEffectEngine 集成——阵法激活→persistent effect 注册成功；阵法失效→effect 注销成功
- 集成测试：DeploymentSystem 信号→阵法条件重判→ComatUI 信号接收的端到端链
- 性能测试：`get_aura_bonus()` × 1000 次调用 <1ms；`recheck_all_conditions()` × 1000 次调用 <20ms

## 相关决策

- [ADR-0001：GameStateManager](ADR-0001-game-state-manager-autoload-singleton-three-tier-api.md) — GSM 只读 + battle.* 域快照持久化
- [ADR-0007：信号驱动通信](ADR-0007-signal-driven-communication-taxonomy.md) — Cat 2b 信号（6 个阵法信号）+ `_emit_signal_safe` 路由
- [ADR-0008：CombatSystem](ADR-0008-combat-system-seven-phase-state-machine.md) — Phase 2 PLAY 阵法卡打出 + Phase 6 END 不需阵法重判
- [ADR-0009：CardEffectEngine](ADR-0009-card-effect-engine-resource-refcounted-model.md) — persisent effect 注册/注销/暂挂/恢复接口 + ACTIVATE_FORMATION 效果类型
- [ADR-0011：StatusEffectSystem](ADR-0011-status-effect-system-template-instance-model.md) — 战斗期间子系统内部管理 + GSM 例外先例
- [ADR-0013：BindingManager](ADR-0013-binding-system-autoload-refcounted-model.md) — Feature Autoload 先例 + GSM 例外第二处
- [ADR-0016：DeploymentSystem](ADR-0016-deployment-system.md) — 角色上场/阵亡/离场信号触发阵法条件重判 + GSM 例外第三处
- [ADR-0018：FactionSystem](ADR-0018-faction-system.md) — `count_on_field()` / `check_condition()` 实时条件判定