# ADR-0016：上场阵位系统 — Feature 层 Autoload + 内部状态机 + GSM 快照持久化

## 状态
Accepted（2026-07-26——Feature 层审查通过。修复：Foundation 计数 7→5。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Deployment |
| **知识风险** | LOW（Dictionary 操作、信号系统、Autoload 模式、内部状态机均为 4.x 成熟 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑不依赖 4.4+ 新增 API。`Dictionary` 键查找、`signal` 发射、`enum` 状态机均为 4.0+ 稳定 API |
| **需要验证** | 化神期 6 角色阵位 × 前后排 + `can_target()` 每帧 O(1) 查询性能（<0.01ms/查询）；`deploy()` 单次调用（含阵位分配 + 待命标记 + 信号发射）<0.3ms；跨战斗不可用角色序列化至 GSM 的正确性（`_unavailable_characters` Dictionary → GSM 快照 → 读档恢复）；前后排保护规则与 AI 目标选择的集成——AI 调用 `is_targetable()` 前应确保前排检查已缓存；`clear_standby_state()` 在回合结束时的调用时序——绑定系统/阵法系统的信号消费在待命清除之前还是之后；阵位调整仅在备战阶段的一次性操作——UI 锁定由 InputManager 配合实现 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.realm_level` 只读查询获取 `max_deploy`；战斗结束时接收不可用角色快照 `GSM.battle.deployment_snapshot`）；ADR-0006（CardSystem——角色卡模板查询 `get_template(id)`；`create_instance()` 创建角色卡实例）；ADR-0007（三分类信号体系——上场/阵亡/待命清除等生命周期事件归类为 Cat 2b 系统信号）；ADR-0008（CombatSystem——Phase 0 PREPARATION 备战阶段调用 `DeploymentSystem.setup_field()`；Phase 2 PLAY 出牌阶段调用 `DeploymentSystem.deploy()`；Phase 6 END 回合结束时调用 `DeploymentSystem.clear_standby_state()`；`character_died` 信号触发 `mark_unavailable()`）；ADR-0010（RealmSystem——`get_realm_property(level, &"max_deploy")` 查询上场人数上限）；ADR-0011（StatusEffectSystem——Template/Instance 分离模式先例；战斗热路径 O(1) 查询先例；GSM 例外模式先例——战斗期间数据在子系统内部管理）；ADR-0013（BindingManager——Feature 层 Autoload 先例；角色上场/阵亡事件触发 BindingManager 的挂起/恢复/移除） |
| **启用** | 前向引用：阵法系统（尚无独立 ADR——上场人数变更通知重查阵法激活条件）；前向引用：AI 系统（尚无独立 ADR——`is_targetable()` 查询目标合法性 + `get_field()` 获取阵位分布用于决策）；前向引用：CombatUI（尚无独立 ADR——订阅 Cat 2b 信号更新阵位状态显示、待命标记、不可用灰显） |
| **阻塞** | 战斗 Epic——备战阶段的上场选择 UI + 战中补位的阵位选择 UI + 阵亡后空位显示；角色管理 Epic——不可用角色的复活途径（涅槃丹/事件/天赋） + 角色位替换逻辑 |
| **排序说明** | Feature 层——在 Foundation 层全部 5 个 ADR + Core 层 ADR-0010（RealmSystem）+ Feature 层 ADR-0008（CombatSystem）、ADR-0013（BindingManager）被接受后编写。DeploymentSystem 依赖 BindingManager（#13）的绑定生命周期 + CombatSystem（#9）的阶段编排——初始化顺序需排在两者之后。完整 Autoload 链 18 个：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13 / ExplorationSystem #14 / FactionSystem #15 / ResourceSystem #16 / DeploymentSystem #17 / AISystem #18。DeploymentSystem._ready() 执行时 #1-#16 已完全初始化 |

## 上下文

### 问题陈述

`deployment-system.md` GDD 定义了完整的角色上场与阵位系统——固定 6 格阵位（前 3 后 3）、上场人数随境界成长（`max_deploy = L + 1`）、前后排保护规则（前排存活时敌方不可攻击后排）、战中补位（打出角色卡→选空位→待命）、待命规则（上场回合不可攻击）、跨战斗角色死亡与不可用状态、全部不可用→游戏失败。但 GDD 关注的是"上场阵位应该表现出什么行为"，本 ADR 需要解决的是"上场阵位系统如何在 Godot 4.6 中工程化实现"：

1. **系统定位**：DeploymentSystem 是 Autoload 还是 CombatSystem 内部模块？状态需要跨回合持久（角色不可用状态），但阵位数据仅在战斗上下文中有意义——与 ADR-0011 StatusEffectSystem 和 ADR-0013 BindingManager 面临相同的系统边界问题
2. **前后排保护规则的执行位置**：AI 目标选择时需要知道谁能被攻击——这个查询在哪里提供？DeploymentSystem 作为"阵位真理来源"提供 `is_targetable()` 是最小耦合方案
3. **战中补位的触发流程**：打出角色卡→检查空位→分配阵位→通知绑定系统→通知阵法系统——这个多系统协调链的责任边界在哪里？
4. **待命状态的管理**：回合转换时谁负责将"待命"角色转为"已就绪"？CombatSystem 是回合编排器，DeploymentSystem 是状态拥有者——调用方向？
5. **不可用角色的存储位置**：跨战斗持久数据——GSM 中还是 DeploymentSystem 内部？存档时需要序列化到哪里？

`architecture.md` 将上场阵位系统归入 Feature 层——依赖 CardSystem、RealmSystem、CombatSystem、BindingManager。

### 约束

- **Feature 层定位**：DeploymentSystem 是 Feature 层 Autoload——依赖 Foundation 层（GSM、CardSystem）和 Feature 层（CombatSystem、RealmSystem、BindingManager），被 Presentation 层（CombatUI）消费
- **6 格固定阵位**：前 3 后 3，阵位在同一边界内等价——仅区分前排/后排
- **上场人数由境界决定**：`max_deploy = L + 1`——炼气 2 人→化神 6 人。通过 `RealmSystem.get_realm_property(level, &"max_deploy")` 查询，不自行维护境界→人数映射
- **前后排保护**：前排有存活角色时敌方不可直接攻击后排——穿透效果除外
- **待命 1 回合**：上场角色本回合标记为「待命」（不可攻击），下回合自动转为「已就绪」
- **战中补位**：打出角色卡→选空位→角色上场→待命状态
- **阵位调整仅备战阶段**：战斗中角色一旦上场即固定前/后排位置——不可在回合间移动（GDD 设计决策 2026-07-23）
- **跨战斗死亡持久**：角色阵亡后标记为「不可用」——跨战斗持久状态，需复活丹药/事件恢复
- **GSM 边界——ADR-0011/ADR-0013 先例模式**：战斗期间阵位数据和角色在场状态由 DeploymentSystem 内部管理——战斗结束时导出快照至 GSM。不可用角色列表在战斗结束时同步至 GSM 用于存档持久化
- **帧预算**：`is_targetable()` O(1) Dictionary 查询 <0.01ms；`deploy()` 单次 <0.3ms；`get_field()` 返回 Array[Dictionary] <0.05ms
- **Autoload 计数**：DeploymentSystem 为 Autoload #17——项目 Autoload 总数 18 个（本 ADR 批次后）

### 需求

- 6 格阵位（前 3 后 3）的运行时管理：`_field: Dictionary`（slot_index → {character_id, is_front, deploy_turn, state}）
- 上场人数上限查询：`RealmSystem.get_current_property(&"max_deploy")`——战斗开始时缓存
- 公共 API：`setup_field()` / `deploy()` / `remove_character()` / `is_targetable()` / `can_deploy()` / `get_field()` / `get_empty_slots()` / `clear_standby_state()` / `mark_unavailable()` / `revive_character()` / `get_unavailable_characters()` / `is_game_over()` / `serialize_field()` / `deserialize_field()`
- 前后排保护查询：`is_targetable(character_id, attacker_has_penetration: bool = false) → bool`
- 战中补位流程：检查空位 → 自动分配前排优先 → 标记待命 → Cat 2b 信号通知
- 待命状态管理：DeploymentSystem 内部持有状态，CombatSystem 在 Phase 6 回合结束时调用 `clear_standby_state()`
- Cat 2b 信号：`character_deployed` / `character_removed` / `standby_cleared` / `character_unavailable` / `character_revived` / `front_line_breached`（由 DeploymentSystem Autoload 直接发射，通过 ADR-0007 `_emit_signal_safe` 包装器路由）
- 不可用角色存储：DeploymentSystem 内部 `_unavailable_characters: Dictionary[int, Dictionary]`（key=character_id，value={death_turn, death_battle_id, revival_methods}）——战斗结束时同步至 GSM

## 决策

**DeploymentSystem 实现为 Feature 层 Autoload（DeploymentSystem），采用内部状态机管理阵位数据——阵位分布、角色在场状态、待命/已就绪标记、不可用角色列表均在 DeploymentSystem 内部 Dictionary 中管理。战斗期间阵位数据不经过 GSM。战斗结束时 `serialize_field()` 导出阵位快照至 `GSM.battle.deployment_snapshot`，不可用角色列表同步至 GSM 用于存档持久化。前后排保护通过 `is_targetable(character_id)` 提供 O(1) 查询。战中补位由 CardEffectEngine（打出角色卡）→ DeploymentSystem.deploy() → Cat 2b 信号通知 BindingManager/阵法系统/CombatUI 的链式调用。待命状态由 DeploymentSystem 内部状态机管理，CombatSystem 在回合转换时调用 `clear_standby_state()`。**

### 对象模型

```
┌──────────────────────────────────────────────────────────────────┐
│                    DeploymentSystem 对象模型                       │
│                                                                   │
│  ┌─────────────────────┐          ┌──────────────────────────┐  │
│  │  RealmSystem        │  查询    │  阵位数据 (运行时)         │  │
│  │  (ADR-0010)         │────────→ │                          │  │
│  │                     │  max_    │  _field: Dictionary       │  │
│  │  max_deploy         │  deploy  │    slot_index → {         │  │
│  └─────────────────────┘          │      character_id: int,   │  │
│                                    │      is_front: bool,      │  │
│  ┌─────────────────────┐          │      deploy_turn: int,    │  │
│  │  CardSystem         │  查询    │      state: FieldState    │  │
│  │  (ADR-0006)         │────────→ │    }                      │  │
│  │                     │  角色    │                          │  │
│  │  CardTemplate       │  模板    │  内部状态机：              │  │
│  └─────────────────────┘          │    STANDBY → READY →      │  │
│                                    │    ACTED → (回合结束)     │  │
│  内部注册表（战斗期间——不通过 GSM）：│    → READY               │  │
│    _field: Dictionary[int, Dict]  │                          │  │
│    _unavailable_characters:       │  不可用角色（跨战斗持久）： │  │
│      Dictionary[int, Dict]        │    character_id → {       │  │
│                                    │      death_turn: int,     │  │
│  战斗结束时：                       │      death_battle_id: str,│  │
│    serialize_field() →             │      revival_methods: [] │  │
│      GSM.battle.deployment_snapshot│    }                      │  │
│    _unavailable_characters →       │                          │  │
│      GSM.player.unavailable_chars  │                          │  │
└──────────────────────────────────────────────────────────────────┘
```

### 阵位数据模型

```
战场布局（固定 6 格，前 3 后 3）：

    敌方侧
  ─────────────────
  [前1] [前2] [前3]   ← 前排（slot 0-2）
  [后1] [后2] [后3]   ← 后排（slot 3-5）
  ─────────────────
    己方侧

slot_index 编码：0=前1, 1=前2, 2=前3, 3=后1, 4=后2, 5=后3
is_front = slot_index ∈ [0, 2]
```

### 角色在场状态机

```
                    ┌──────────┐
                    │  未上场   │
                    └────┬─────┘
                         │ deploy()——备战阶段或战中补位
                         ▼
              ┌──────────────────┐
              │   STANDBY（待命） │ ◄── 上场回合不可攻击
              │   可被攻击 ✓     │
              │   可攻击 ✗       │
              └────────┬─────────┘
                       │ clear_standby_state()——下回合开始
                       ▼
              ┌──────────────────┐
              │   READY（已就绪） │ ◄── 可正常行动
              │   可被攻击 ✓     │
              │   可攻击 ✓       │
              └────────┬─────────┘
                       │ 攻击后（由 CombatSystem 标记）
                       ▼
              ┌──────────────────┐
              │   ACTED（已行动） │ ◄── 本回合已执行动作
              │   可被攻击 ✓     │
              │   可攻击 ✗       │
              └────────┬─────────┘
                       │ 回合结束（Phase 6 END）
                       ▼
              ┌──────────────────┐
              │   READY（已就绪） │ ◄── 循环
              └────────┬─────────┘
                       │ 角色阵亡（HP ≤ 0）
                       ▼
              ┌──────────────────┐
              │   DEAD（阵亡）    │ ◄── 阵位变为空位
              │   战斗结束        │
              │   → UNAVAILABLE  │
              └──────────────────┘
```

### 关键接口

#### DeploymentSystem 公共 API

| 方法 | 签名 | 说明 |
|------|------|------|
| `setup_field` | `setup_field(character_ids: Array[int], layout: Dictionary = {}) → bool` | 备战阶段初始化阵位。layout 可指定手动前后排分配（{char_id: is_front}），未指定则自动前排优先填充。返回 false = 人数超上限或角色不可用 |
| `deploy` | `deploy(card_instance_id: int, character_id: int, slot_index: int = -1) → DeployResult` | 战中补位。slot_index=-1 时自动分配前排优先空位。DeployResult = {success: bool, slot_index: int, reason: String}。reason: 'deployed' / 'field_full' / 'character_unavailable' / 'invalid_slot' |
| `remove_character` | `remove_character(character_id: int) → void` | 角色阵亡时调用——清空阵位 + 标记不可用（战斗结束时持久化）。注意：绑定卡的洗回由 BindingManager 处理——DeploymentSystem 不负责绑定卡生命周期 |
| `is_targetable` | `is_targetable(character_id: int, attacker_has_penetration: bool = false) → bool` | O(1) 前后排保护查询。前排有存活角色 + 目标在后排 + 无穿透 → false。AI 系统每帧调用 |
| `can_deploy` | `can_deploy() → CanDeployResult` | 出战前检查。CanDeployResult = {can_deploy: bool, empty_slots: int, max_deploy: int, reason: String} |
| `get_field` | `get_field() → Array[Dictionary]` | 返回当前阵位分布（按 slot_index 排序）。每个 Dictionary = {slot_index, character_id, is_front, state, deploy_turn}。空位为 {slot_index, character_id=-1, is_front, state=EMPTY} |
| `get_empty_slots` | `get_empty_slots() → Array[int]` | 返回空阵位 slot_index 列表——前排优先排序 |
| `get_character_slot` | `get_character_slot(character_id: int) → int` | O(n) 遍历查询角色所在阵位——返回 slot_index，未上场返回 -1 |
| `get_front_count` | `get_front_count(alive_only: bool = true) → int` | 前排存活角色数——AI 判断前排是否已清空 |
| `clear_standby_state` | `clear_standby_state() → void` | 回合结束时由 CombatSystem 调用——所有 STANDBY→READY、所有 ACTED→READY。发射 `standby_cleared` 信号（Cat 2b） |
| `set_acted` | `set_acted(character_id: int) → void` | 角色攻击后由 CombatSystem 调用——READY → ACTED |
| `mark_unavailable` | `mark_unavailable(character_id: int, death_context: Dictionary) → void` | 战斗结算时标记角色不可用。death_context = {death_turn, death_battle_id}。发射 `character_unavailable` 信号 |
| `revive_character` | `revive_character(character_id: int) → bool` | 复活不可用角色——从 `_unavailable_characters` 移除。角色属性保留但空载（无绑定卡）。返回 false = 角色不在不可用列表中 |
| `get_unavailable_characters` | `get_unavailable_characters() → Array[int]` | 返回不可用角色 ID 列表——商店/事件系统查询复活道具可用性 |
| `is_game_over` | `is_game_over(roster: Array) → bool` | 全部角色位角色均为不可用——触发游戏失败。判定时机：战斗开始前。**签名偏离**：ADR 原声明无参，实现改为必传 roster——DeploymentSystem 不持有角色位总列表（角色位属 CardSystem/CombatSystem 管理），由调用方传入角色位角色 ID 列表（retrofit 2026-08-18，见 Story 004 Completion Notes） |
| `is_standby` | `is_standby(character_id: int) → bool` | O(1) 查询角色是否处于待命状态——CombatSystem 攻击声明阶段排除待命角色 |
| `serialize_field` | `serialize_field() → Dictionary` | 战斗结束时序列化阵位 → GSM.battle.deployment_snapshot |
| `deserialize_field` | `deserialize_field(data: Dictionary) → void` | 从快照恢复阵位（读档/战斗快照恢复） |
| `sync_unavailable_to_gsm` | `sync_unavailable_to_gsm() → void` | 战斗结束时同步不可用角色列表至 GSM——用于存档持久化 |
| `load_unavailable_from_gsm` | `load_unavailable_from_gsm(data: Dictionary) → void` | 从 GSM 恢复不可用角色列表（读档时） |

#### Cat 2b 信号（通过 `_emit_signal_safe` 路由）

| 信号 | 参数 | 触发时机 | 订阅者 |
|------|------|----------|--------|
| `character_deployed` | `(character_id, slot_index, is_front, deploy_turn)` | 角色上场（备战/战中补位） | CombatUI（阵位更新+动画）、BindingManager（绑定恢复）、阵法系统（重查激活条件）、AudioSystem（上场音效） |
| `character_removed` | `(character_id, slot_index, reason: String)` | 角色阵亡离场 | CombatUI（阵亡动画+空位显示）、BindingManager（阵亡洗回）、阵法系统（重查激活条件） |
| `standby_cleared` | `(character_ids: Array[int])` | 回合结束时待命清除 | CombatUI（待命标记移除+已就绪高亮） |
| `character_unavailable` | `(character_id: int)` | 角色标记为不可用 | CombatUI（角色位灰显+骷髅标记）、商店系统（复活道具可购买条件）、事件系统（分支条件判定） |
| `character_revived` | `(character_id: int)` | 角色复活 | CombatUI（角色位恢复彩色）、商店系统（复活道具不可购买） |
| `front_line_breached` | `()` | 前排全灭→后排暴露 | CombatUI（镜头震动+破防音效）、AudioSystem（低沉破碎音） |

信号链深度 ≤2 层——部署信号 → CombatUI/BindingManager/阵法系统更新 → 无进一步信号级联。

### 备战阶段流程（与 CombatSystem 协作）

```
CombatSystem.battle_start(config)
  ├─ 1. RealmSystem.get_current_property(&"max_deploy") → 缓存上场人数上限
  ├─ 2. DeploymentSystem.setup_field(character_ids, layout)
  │      ├─ 验证：上场人数 ≤ max_deploy
  │      ├─ 验证：所有角色均为「可用」状态
  │      ├─ 自动分配阵位：前排优先（前1→前2→前3→后1→后2→后3）
  │      ├─ 所有角色标记为 STANDBY（第1回合不可攻击——GDD §5 待命规则）
  │      └─ 发射 character_deployed × N 信号（Cat 2b）
  ├─ 3. CombatSystem.advance_phase(PREPARATION)
  └─ ...
```

### 战中补位流程（Phase 2 PLAY）

```
CombatSystem.play_card(card_instance_id, targets)  # 角色卡
  ├─ CardEffectEngine.resolve(card, targets)
  │    └─ 效果类型 = SUMMON_CHARACTER
  │         ├─ 1. DeploymentSystem.can_deploy() → {can_deploy: bool, empty_slots: int}
  │         │      └─ can_deploy=false → 效果结算失败，费用不退（GDD §边界情况"战场已满"）
  │         ├─ 2. DeploymentSystem.deploy(card_instance_id, character_id, slot_index)
  │         │      ├─ 分配阵位：槽位可用 + 前排优先（玩家可通过 UI 选择具体空位）
  │         │      ├─ 标记 STANDBY（本回合不可攻击）
  │         │      ├─ 发射 character_deployed 信号
  │         │      └─ 返回 DeployResult{success=true, slot_index}
  │         └─ 3. 信号级联（自动）：
  │                ├─ BindingManager（恢复绑定效果——如果角色曾有绑定且 card_instance_id 仍存在）
  │                ├─ 阵法系统（重查激活条件）
  │                └─ CombatUI（阵位更新+补位动画 0.3s）
```

### 前后排保护查询

```gdscript
## O(1) 前后排保护查询——AI 目标选择时每帧调用
## character_id: 被查询的目标角色
## attacker_has_penetration: 攻击者是否有穿透效果（符箓/特殊功法）
func is_targetable(character_id: int, attacker_has_penetration: bool = false) -> bool:
    # 1. 角色必须在场上
    var slot: int = get_character_slot(character_id)
    if slot == -1:
        return false  # 不在场上——不可被攻击

    # 2. 角色已阵亡——不可被攻击
    var entry: Dictionary = _field[slot]
    if entry.state == FieldState.DEAD:
        return false

    # 3. 前排角色——始终可被攻击
    if entry.is_front:
        return true

    # 4. 后排角色 + 穿透效果——可被攻击
    if attacker_has_penetration:
        return true

    # 5. 后排角色 + 前排无存活角色（前排已破）——可被攻击
    if get_front_count(true) == 0:
        if not _front_line_breached_emitted:
            _front_line_breached_emitted = true
            _emit_signal_safe(self, &"front_line_breached", [])
        return true

    # 6. 后排角色 + 前排有存活——受保护，不可被攻击
    return false
```

### 待命状态清除（回合结束时）

```gdscript
## 由 CombatSystem 在 Phase 6 END 时调用——回合结束阶段
func clear_standby_state() -> void:
    var cleared_ids: Array[int] = []
    for slot_index in _field:
        var entry: Dictionary = _field[slot_index]
        if entry.character_id == -1:
            continue
        match entry.state:
            FieldState.STANDBY:
                entry.state = FieldState.READY
                cleared_ids.append(entry.character_id)
            FieldState.ACTED:
                entry.state = FieldState.READY
                # ACTED→READY 不包含在 cleared_ids 中——非待命清除
            _:  # READY, DEAD —— 不变
                pass

    if cleared_ids.size() > 0:
        _emit_signal_safe(self, &"standby_cleared", [cleared_ids])
```

### 不可用角色生命周期

```
战斗中角色阵亡
  └─ CombatSystem 发射 character_died 信号（Cat 2b）
       ├─ DeploymentSystem.remove_character(character_id)
       │    └─ 清空阵位（空位立即可用——同回合可补位）
       ├─ BindingManager.remove_all_bindings(character_id)
       │    └─ 绑定卡洗回牌库
       └─ 阵法系统（重查激活条件）

战斗结束 → battle_end()
  └─ DeploymentSystem.sync_unavailable_to_gsm()
       ├─ 遍历本场战斗阵亡角色
       ├─ _unavailable_characters[character_id] = {death_turn, death_battle_id, ...}
       └─ 同步至 GSM.player.unavailable_characters 用于存档持久化

读档恢复：
  └─ DeploymentSystem.load_unavailable_from_gsm(GSM.player.unavailable_characters)
       └─ 恢复 _unavailable_characters 字典

复活：
  └─ DeploymentSystem.revive_character(character_id)
       ├─ 从 _unavailable_characters 移除
       ├─ 发射 character_revived 信号（Cat 2b）
       └─ 角色属性保留，空载状态（无绑定卡）

全部不可用判定：
  └─ DeploymentSystem.is_game_over()
       └─ 所有角色位角色均在 _unavailable_characters 中 → true
       └─ 判定时机：CombatSystem.battle_start() 调用前检查
```

### GSM 边界——ADR-0011/ADR-0013 先例模式

本 ADR 采用与 ADR-0011 StatusEffectSystem 和 ADR-0013 BindingManager 相同的 GSM 边界模式：

- **战斗期间**：所有阵位数据由 DeploymentSystem 内部 `_field` Dictionary 管理——不存储在 GSM 中。热路径查询（`is_targetable()`、`is_standby()`、`get_field()`）直接在 DeploymentSystem 内部完成，不经过 GSM 层
- **战斗结束**：`serialize_field()` 导出阵位快照至 `GSM.battle.deployment_snapshot`——用于战斗快照持久化
- **跨战斗持久**：`sync_unavailable_to_gsm()` 将不可用角色列表同步至 `GSM.player.unavailable_characters`——用于存档持久化
- **GSM 只读**：DeploymentSystem 通过 GSM 第一层只读访问 `player.realm_level`（通过 RealmSystem 间接获取 max_deploy）——不调用 GSM 第二层写入方法（战斗期间除外）
- **架构原则例外声明**：与 ADR-0011/ADR-0013 相同——`architecture.md` §架构原则 #1 需增加 ADR-0016 例外："战斗中阵位数据由 DeploymentSystem 独立管理，仅战斗结束时导出快照至 GSM；不可用角色列表同步至 GSM 用于存档持久化"

### 阵位自动分配算法

> **[b]修订 2026-08-17（Story 4-6 retrofit）[/b]**：原示例为「顺序填充 `[0,1,2,3,4,5]`」，
> 按此算法金丹期 4 人会填成前 3 后 1、筑基期 3 人填成前 3 后 0——均与 GDD §2 阵位分布表
> （筑基前 2 后 1、金丹前 2 后 2）矛盾。实现已修正为「按境界前排配额填满前排后转后排」，
> 前排配额由 `FRONT_CAPACITY_BY_MAX_DEPLOY = {2:2, 3:2, 4:2, 5:3, 6:3}` 决定（与 GDD §2 一致）。
> 本示例同步修正如下（Story 4-6 已实现并测试，全量 1244 passing）。

```gdscript
## 境界上场上限 → 前排配额映射（GDD §2 境界阵位分布表）。
const FRONT_CAPACITY_BY_MAX_DEPLOY: Dictionary = {2: 2, 3: 2, 4: 2, 5: 3, 6: 3}

## 自动阵位分配——按境界前排配额填满前排后转后排（前1→前2→前3→后1→后2→后3）
func _assign_slots(character_ids: Array[int], layout: Dictionary = {}) -> Dictionary:
    # 返回 {character_id: slot_index}
    var assignment: Dictionary = {}
    var used: Dictionary = {}
    var max_deploy: int = _query_max_deploy()
    var front_capacity: int = FRONT_CAPACITY_BY_MAX_DEPLOY.get(max_deploy, 3)
    var front_assigned: int = 0
    for char_id in character_ids:
        var slot: int
        if front_assigned < front_capacity:
            slot = _find_empty_in_row(true, used)   # 前排：0,1,2
        else:
            slot = _find_empty_in_row(false, used)  # 后排：3,4,5
        assignment[char_id] = slot
        used[slot] = true
    return assignment

## 空位查找——前排优先
func get_empty_slots() -> Array[int]:
    var empty: Array[int] = []
    for slot_index in [0, 1, 2, 3, 4, 5]:  # 前排优先排序
        if _field[slot_index].character_id == -1:
            empty.append(slot_index)
    return empty
```

## 考虑的替代方案

### 替代方案 1：DeploymentSystem 作为 CombatSystem 内部子系统

- **描述**：不创建独立 Autoload——上场阵位逻辑内嵌为 CombatSystem 的内部模块（`CombatSystem._deployment_manager`）。阵位数据直接挂在 CombatSystem 的 `_field` Dictionary 上
- **优点**：零 Autoload 开销（保持 17 个）；阵位数据与战斗生命周期自然绑定（战斗结束 → 阵位自动清理）；CombatSystem 直接编排部署操作——无需跨 Autoload 调用
- **缺点**：（1）CombatSystem 已经编排 9 个子系统（ADR-0008）——再内嵌阵位管理将使其成为上帝对象——总职责数增至 10+；（2）前后排保护查询 `is_targetable()` 被 AI 系统调用——如果阵位数据在 CombatSystem 内部，AI 需要通过 CombatSystem 间接查询，增加耦合；（3）不可用角色列表需要跨战斗持久——内嵌在 CombatSystem 中则需在战斗结束时由 CombatSystem 将所有不可用数据传递给 GSM——CombatSystem 承担了非战斗职责；（4）BM、阵法系统、商店系统、事件系统均需查询 DeploymentSystem 的接口——如果它内嵌在 CombatSystem 中，所有调用方都需持有 CombatSystem 引用
- **拒绝原因**：违反单一职责——CombatSystem 已承担 7 阶段编排 + 9 子系统调度，不应再内嵌阵位数据管理。独立 Autoload 使 AI、BindingManager、阵法系统、商店系统、事件系统能以解耦方式查询阵位状态和不可用角色信息。这与 ADR-0013 BindingManager 独立于 CombatSystem 的决策一致——上场阵位是战斗的"棋局布局"，而非战斗编排逻辑

### 替代方案 2：不可用角色存储在 GSM 中，DeploymentSystem 为无状态服务

- **描述**：DeploymentSystem 不持有 `_unavailable_characters`——不可用角色数据完全存储在 `GSM.player.unavailable_characters` Dictionary 中。DeploymentSystem 的所有方法通过 GSM 第二层 API 读写不可用角色列表
- **优点**：符合 ADR-0001 的 GSM 单一数据源原则——不可用角色数据与其他玩家持久数据在同一位置；无需战斗结束时同步——GSM 中的数据天然跨战斗持久；代码更简单——DeploymentSystem 仅管理阵位运行时数据
- **缺点**：（1）标记不可用角色的频率低（每场战斗 0-6 次）——通过 GSM 第二层 API 写操作的开销可接受，但引入了不必要的依赖；（2）`is_game_over()` 每场战斗调用一次——如果从 GSM 读取，需要额外的字典拷贝或引用；（3）不可用角色的复活途径（丹药/事件）需要修改 GSM 数据——调用方需同时引用 DeploymentSystem（阵位逻辑）和 GSM（不可用角色数据），增加 API 表面积
- **拒绝原因**：不可用角色数据量小（最多 6 个 Dictionary entry），频率低（每场战斗更新一次），复杂度低——不值得为此引入跨 Autoload 的写入依赖。DeploymentSystem 内部管理 + 战斗结束时同步至 GSM 的模式与 ADR-0011/ADR-0013 的"战斗结束时导出快照"先例一致——架构一致性的价值高于理论上的 GSM 纯度

### 替代方案 3：阵位数据存储在 GSM battle.* 域中

- **描述**：阵位数据和角色在场状态通过 `GSM.battle.field` Dictionary 存储——所有阵位读写通过 GSM 第二层 API
- **优点**：阵位数据与其他战斗数据（phase、turn、player_field、enemy_field）在同一位置——概念简单；战斗结束 GSM 清理 battle 域时自动清理阵位数据——无需额外清理逻辑
- **缺点**：（1）`is_targetable()` 被 AI 系统在敌方行动阶段每帧调用——通过 GSM 层查询增加方法调用开销；（2）阵位操作频繁（部署、待命清除、阵亡移除）——GSM `batch_updated` 信号为每次阵位变更发射，信号噪音高；（3）GSM battle.* 域已经持有 player_field 和 enemy_field——再增加 field 数据会造成职责重叠：谁才是角色位置的真理来源？
- **拒绝原因**：与"战斗期间子系统内部管理"的先例模式相悖——ADR-0011（StatusEffectSystem）和 ADR-0013（BindingManager）均已确立战斗热路径数据不经过 GSM 的例外模式。阵位数据与此同类——高频查询（AI 目标选择）+ RefCounted 不需要（Dictionary 即可）+ 战斗结束导出快照。GSM 已经持有 player_field/enemy_field——阵位数据是这些字段的"布置层"，应由 DeploymentSystem 独立管理以避免双重真理来源

### 替代方案 4：前后排保护规则在 AI 系统内部实现

- **描述**：DeploymentSystem 仅提供阵位数据（`get_field()`），前后排保护的判定逻辑在 AI 系统的目标选择算法中实现
- **优点**：DeploymentSystem API 更简洁——只提供数据，不提供规则判定
- **缺点**：（1）前后排保护规则需要在前排状态变更时重新评估——如果逻辑在 AI 内部，AI 需要订阅 `character_deployed`/`character_removed` 信号并维护自己的前排状态缓存；（2）前后排保护是通用战斗规则——不仅 AI 需要（玩家手动选择攻击目标时也需要），如果逻辑分散在多处，规则变更时（如新增"穿透"效果类型）需要修改多处代码；（3）AI 系统的职责是决策，而非规则判定——判定权应交由数据拥有者
- **拒绝原因**：`is_targetable()` 封装了前后排保护规则——它属于 DeploymentSystem 的数据权威范围，而非 AI 系统的决策权威范围。单一判定入口确保规则一致性——AI、玩家 UI、卡牌效果引擎的目标验证都通过同一个方法

## 后果

### 积极的

- **清晰的阵位真理来源**：`_field` Dictionary 是阵位状态和角色在场状态的唯一定义点——CombatSystem、AI、BindingManager、阵法系统、CombatUI 均通过 DeploymentSystem 查询，消除"谁在哪个位置"的歧义
- **前后排保护 O(1) 查询**：`is_targetable()` 封装保护规则，AI 和 UI 无需各自实现——规则一致性由单一入口保证
- **与已有先例一致**：战斗期间数据内部管理 + 战斗结束导出快照至 GSM 的模式与 ADR-0011（StatusEffectSystem）和 ADR-0013（BindingManager）一致——降低学习成本和代码审查复杂度
- **不可用角色生命周期完整**：从阵亡→标记不可用→复活丹药/事件恢复→重新上场的完整链条在 DeploymentSystem 内部闭环——GSM 仅用于存档持久化
- **CombatUI 解耦**：Cat 2b 信号总线使 CombatUI 仅订阅 DeploymentSystem 信号即可获取全部阵位状态变更——无需直接轮询 DeploymentSystem API
- **GSM 规模控制**：GSM 不持有阵位数据和角色状态机——仅战斗结束时接收序列化快照 + 不可用角色列表 Dictionary

### 消极的

- **Autoload 数量增加至 18**：DeploymentSystem 为 Autoload #17——项目 Autoload 总数 18 个。初始化顺序依赖链延长
- **GSM 例外模式第三处扩散**：ADR-0011（StatusEffectSystem）、ADR-0013（BindingManager）、ADR-0016（DeploymentSystem）均采用"战斗期间子系统内部管理"的例外模式——需在 `architecture.md` 中明确记录例外清单，防止 future 子系统滥用此模式
- **两个"角色在场"概念并存**：GSM `battle.player_field` 持有角色运行时属性（HP、ATK、statuses），DeploymentSystem `_field` 持有阵位和状态信息——同一角色在两个位置有数据。需要确保 `character_died` 信号处理时两者同步清理
- **不可用角色的跨战斗持久链路长**：DeploymentSystem._unavailable_characters → 战斗结束 sync → GSM.player.unavailable_characters → 存档序列化。读档时反向：存档 → GSM → load_unavailable_from_gsm → DeploymentSystem。链路中的每一步都可能出现数据不一致

### 风险

- **GSM player_field 与 DeploymentSystem _field 的数据不一致**：角色阵亡时，GSM `battle.player_field[i].hp = 0` 和 DeploymentSystem `_field[slot].state = DEAD` 是两次独立操作——如果其中一次失败（如信号处理器异常），两者将不同步
  - 缓解：`remove_character()` 是 DeploymentSystem 的唯一阵亡入口——CombatSystem 必须在此方法返回后才更新 GSM player_field 中的角色状态。GUT 集成测试覆盖阵亡流程的两个系统状态一致性
- **_front_line_breached_emitted 标志未在战斗开始时重置**：如果上一场战斗前排曾被清空，标志位残留可能导致新战斗中前排未破时 `is_targetable()` 仍返回 true
  - 缓解：在 `setup_field()` 中重置 `_front_line_breached_emitted = false`
- **待命状态清除时机与攻击声明阶段的顺序**：Phase 6 END 调用 `clear_standby_state()` 清除待命标记——但新回合的 Phase 3 ATTACK_DECLARATION 在 Phase 2 之后。时序上安全（Phase 6 → Phase 0 → Phase 1 → Phase 2 → Phase 3），但如果未来阶段顺序调整，需确保待命清除在攻击声明前执行
  - 缓解：在 ADR 中明确写入调用时机（Phase 6 END 的 `_exit_phase()`），若阶段顺序调整，ADR-0008 需同步更新此调用点
- **复活时角色位已被新角色替换**：GDD §边界情况——若阵亡角色的角色位已被新角色替换，复活角色进入等待队列。等待队列的管理复杂度（多角色排队、优先顺序、角色位空出时的自动填充）未在本 ADR 中详细设计
  - 缓解：MVP 阶段不实现等待队列——若角色位已被替换，复活丹药不可用（UI 灰显提示"角色位已满"）。等待队列推迟到角色管理系统 ADR 中设计
- **AI 目标选择每帧调用 `is_targetable()`**：化神期 6v6 = 12 角色 × 每角色评估 12 目标 = 144 次 `is_targetable()` / 决策帧——约 1.44ms。在 16.6ms 帧预算中占 ~8.7%。
  - 缓解：AI 系统可缓存前排存活状态（`get_front_count()`）——仅在后排角色查询时调用 `is_targetable()`。前排角色始终可攻击，无需查询

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| deployment-system.md | §1 战场阵位布局——固定 6 格阵位（前 3 后 3） | `_field: Dictionary[int, Dict]` —— slot_index 0-2 为前排，3-5 为后排。`is_front = slot_index ∈ [0, 2]` |
| deployment-system.md | §2 上场人数上限——max_deploy = L + 1 | 通过 `RealmSystem.get_current_property(&"max_deploy")` 查询——战斗开始时缓存。不自行维护境界→人数映射 |
| deployment-system.md | §3 备战阶段——选择角色上场+自动前排优先填充 | `setup_field(character_ids, layout)` —— 验证人数上限 + 可用性检查 + `_auto_assign_slots()` 自动分配 |
| deployment-system.md | §4 战中补位——打出角色卡→选空位→待命 | `deploy(card_instance_id, character_id, slot_index)` —— 前排优先自动分配 + STANDBY 标记 + `character_deployed` 信号 |
| deployment-system.md | §5 待命规则——上场回合不可攻击 | FieldState.STANDBY + `is_standby()` O(1) 查询。`clear_standby_state()` 在回合结束时由 CombatSystem 调用 |
| deployment-system.md | §6 前后排规则——前排存活保护后排 | `is_targetable(character_id, attacker_has_penetration)` —— 前排存活 + 后排目标 + 无穿透 → false。`front_line_breached` 信号 |
| deployment-system.md | §7 布阵阶段——仅备战阶段一次性操作 | `setup_field()` 仅接受 `layout` 参数指定前后排分配——战斗中不可变更。GDD 设计决策 2026-07-23 |
| deployment-system.md | §9 涅槃丹复活与重新上场 | `revive_character()` 从不可用列表移除——角色属性保留但空载。重新上场走标准 `deploy()` 流程 |
| deployment-system.md | §10 跨战斗死亡与不可用状态 | `_unavailable_characters` 字典——`mark_unavailable()` / `revive_character()` / `sync_unavailable_to_gsm()` / `load_unavailable_from_gsm()` 完整链路 |
| deployment-system.md | 全部阵亡→游戏失败 | `is_game_over()` —— 所有角色位角色均在 `_unavailable_characters` 中 → true。判定时机：战斗开始前 |
| deployment-system.md | 边界情况——前排全灭后排暴露 | `get_front_count(true) == 0` → `is_targetable()` 返回 true + `front_line_breached` 信号 |
| deployment-system.md | 边界情况——场上已满 6 人时打出角色卡 | `can_deploy()` 返回 `{can_deploy: false, empty_slots: 0}` → 卡牌灰色不可用 |

## 性能影响

- **CPU**：`is_targetable()` O(1) Dictionary 查询 <0.01ms；`deploy()` 单次 <0.3ms（含阵位分配+信号发射）；`clear_standby_state()` 遍历最多 6 个阵位 <0.02ms。对 60fps 帧预算无显著影响
- **内存**：`_field` Dictionary（6 slot × 5 字段）≈ 300 bytes；`_unavailable_characters`（最多 6 个角色 × 3 字段）≈ 200 bytes。Autoload 节点 ≈ 1KB。总计 <2KB 常驻内存
- **加载时间**：DeploymentSystem._ready() 不加载模板——无启动开销。战斗开始时缓存 RealmSystem max_deploy 数据——O(1)
- **网络**：不适用（单机游戏）

## 迁移计划

本 ADR 为新系统——无需迁移现有代码。实现顺序：

1. FieldState 枚举 + 阵位数据模型（Dictionary 结构）
2. DeploymentSystem Autoload 骨架（Autoload 注册 #14 + `_field` + `_unavailable_characters` 初始化）
3. `setup_field()` + 自动分配算法 + 备战阶段集成
4. `deploy()` + 战中补位 + 前排优先空位分配
5. `is_targetable()` + 前后排保护规则 + `front_line_breached` 信号
6. `clear_standby_state()` + CombatSystem Phase 6 END 集成点
7. `remove_character()` + CombatSystem character_died 信号集成
8. `mark_unavailable()` / `revive_character()` + 不可用角色生命周期
9. `serialize_field()` / `sync_unavailable_to_gsm()` + 战斗结束快照
10. `load_unavailable_from_gsm()` / `deserialize_field()` + 读档恢复
11. Cat 2b 信号总线（6 个信号）
12. CombatUI 订阅 + 阵位状态显示

## 验证标准

- GUT 单元测试：`setup_field()` 自动分配——炼气 2 人→前 2 后 0，化神 6 人→满阵，手动布局覆盖自动分配
- GUT 单元测试：`deploy()` 战中补位——前排优先空位 + 满员拒绝 + 无效槽位拒绝 + 不可用角色拒绝
- GUT 单元测试：`is_targetable()` —— 前排存活→后排受保护 false + 前排全灭→后排可攻击 true + 穿透→后排可攻击 true + 角色不在场上 false
- GUT 单元测试：`clear_standby_state()` —— STANDBY→READY + ACTED→READY + READY 不变 + DEAD 不变 + standby_cleared 信号仅含待命角色
- GUT 单元测试：不可用角色生命周期——mark_unavailable → is_game_over（仅有不可用角色时 true）→ revive_character → is_game_over（false）
- GUT 单元测试：`front_line_breached` 信号——前排从有到无时发射，仅发射一次（setup_field 时重置标志）
- 集成测试：CombatSystem.battle_start → DeploymentSystem.setup_field → Phase 2 战中补位 → Phase 4 阵亡 → Phase 6 clear_standby_state → battle_end sync 完整流程
- 集成测试：角色阵亡→BindingManager 解绑与 DeploymentSystem 清空阵位的顺序——两者在同一个 character_died 信号处理链中执行，结果一致
- 性能测试：`is_targetable()` × 1000 次调用 <10ms；`deploy()` × 100 次调用 <30ms

## 相关决策

- [ADR-0001：GameStateManager](ADR-0001-game-state-manager-autoload-singleton-three-tier-api.md) — GSM 只读 + battle.* 域快照 + player.* 域不可用角色持久化
- [ADR-0006：CardSystem](ADR-0006-card-data-model-template-instance-separation.md) — 角色卡模板查询 + CardInstance 管理
- [ADR-0007：信号驱动通信](ADR-0007-signal-driven-communication-taxonomy.md) — Cat 2b 信号（character_deployed 等 6 个信号）+ `_emit_signal_safe` 路由
- [ADR-0008：CombatSystem](ADR-0008-combat-system-seven-phase-state-machine.md) — Phase 0 备战 + Phase 2 出牌补位 + Phase 6 待命清除 + character_died 信号触发不可用
- [ADR-0010：RealmSystem](ADR-0010-realm-system-autoload-dedicated-service.md) — `max_deploy` 属性查询（L+1 公式）
- [ADR-0011：StatusEffectSystem](ADR-0011-status-effect-system-template-instance-model.md) — 战斗期间子系统内部管理 + GSM 例外先例
- [ADR-0013：BindingManager](ADR-0013-binding-system-autoload-refcounted-model.md) — Feature Autoload 先例 + 角色上场/阵亡触发绑定生命周期
