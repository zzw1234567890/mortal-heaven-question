# 控制清单 (Control Manifest)

> **引擎**: Godot 4.6
> **最后更新**: 2026-07-26
> **清单版本**: 2026-07-26
> **覆盖的 ADR**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013, ADR-0014, ADR-0015, ADR-0016, ADR-0017, ADR-0018, ADR-0019, ADR-0020, ADR-0021, ADR-0022, ADR-0023, ADR-0024, ADR-0025, ADR-0026, ADR-0027, ADR-0028, ADR-0029, ADR-0030
> **状态**: 活跃 —— 当 ADR 变更时通过 `/create-control-manifest` 重新生成

`清单版本` 即生成本清单的日期。Story 文件在创建时嵌入此日期。`/story-readiness` 将 story 的嵌入版本与本字段对比，以检测基于过时规则编写的 story。始终与`最后更新`一致——同一日期，服务于不同的消费方。

本清单是从所有已接受（Accepted）ADR、技术偏好设定和引擎参考文档中提取的程序员速查手册。每条规则背后的原因参见对应的 ADR。

---

## Foundation 层规则

*适用范围：场景管理、事件架构、存档/读档、引擎初始化、输入处理、信号通信*

### 必需模式 (Required Patterns)

- **所有游戏状态写入必须通过 GSM 第二层原子方法** —— 来源: ADR-0001
- **GSM 必须占据 Autoload #1 位置** —— `_ready()` 必须先于任何消费者读取完成 —— 来源: ADR-0001
- **三层 GSM API**：第一层（直接属性读取——零拷贝 O(1)）、第二层（原子写入方法——批量信号发射）、第三层（信号订阅——UI 响应层） —— 来源: ADR-0001
- **`batch_updated` 信号携带展平的 `{path: {old, new}}` 字典** —— 消费者通过路径前缀过滤 —— 来源: ADR-0001
- **启动时校验跳过模式**：GSM 以 `validation_enabled = false` 初始化——CardSystem 在模板加载后调用 `GSM.enable_validation(db)` —— 来源: ADR-0001, ADR-0006
- **存档格式必须为 JSON，以 `schema_version`（递增整数）为唯一迁移驱动字段** —— 来源: ADR-0002
- **原子写入策略**：`.tmp` 文件 → `DirAccess.rename_absolute()` → `.bak` 备份 → 删除 `.bak` —— 来源: ADR-0002
- **Windows 重命名重试**：最多重试 3 次 × 50ms 延迟，应对防病毒/索引器锁定 —— 来源: ADR-0002
- **使用 `JSON.new().parse()` —— 绝不使用 `JSON.parse_string()`**（无法区分合法 null 和解析错误） —— 来源: ADR-0002
- **存档容器必须包含 `"complete": true` 标记** 作为纵深防御 —— 来源: ADR-0002
- **`story_flags` 的唯一运行时写入者是 EventSystem** —— 所有其他系统通过 `EventSystem.set_flag()` 委托写入 —— 来源: ADR-0003
- **ADD_CARD 结果使用信号委托** (`card_reward_requested`) —— EventSystem（Foundation）不直接调用 CardSystem（Core） —— 来源: ADR-0003
- **EventTemplate 存储为 Godot Resource (`.tres`)** —— 所有 `@export` 字段 Inspector 可编辑，禁止使用 `Variant` 类型 —— 来源: ADR-0003
- **EventInstance 持有 `template_id: StringName` + 选项索引——而非 Resource 引用** —— 来源: ADR-0003
- **连锁事件：MAX_CHAIN_DEPTH = 3 + `visited_ids` 循环检测** —— 来源: ADR-0003
- **四级锁栈** (dialogue=0 < animation=1 < modal=2 < transition=3) —— 来源: ADR-0004
- **设备类型独立判定** (MOUSE | KEYBOARD | GAMEPAD 位掩码) —— Godot 4.6 双焦点合规 —— 来源: ADR-0004
- **`push_lock()` / `pop_lock()` 必须配对 —— 以 `StringName` 追踪来源** —— 重复 push 记录警告 —— 来源: ADR-0004
- **锁状态通过 GSM `batch_updated` 传播 —— 无 InputManager 自有信号** —— 来源: ADR-0004
- **所有场景转换必须通过 `SceneManager.request_scene_change()`** —— 来源: ADR-0005
- **5 阶段转换管线**：验证 → 转场前（锁输入 + 自动存档） → 加载（加载画面 → 目标场景） → 加载后（GSM 更新 + 解锁） → 收尾 —— 来源: ADR-0005
- **`TransitionType` 枚举驱动音频过渡矩阵** —— 来源: ADR-0005
- **Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由** —— 信号链深度追踪 —— 来源: ADR-0007
- **信号命名：snake_case 过去式**（pre/post 配对除外） —— 来源: ADR-0007
- **信号载荷：≤3 参数优先；>3 → 具名字典；展平路径字典仅限 GSM `batch_updated`** —— 来源: ADR-0007
- **信号声明在语义归属系统——禁止 SignalBus Autoload** —— 来源: ADR-0007

### 禁止方法 (Forbidden Approaches)

- **绝不直接写 GSM 属性** —— 始终通过第二层原子方法 —— 来源: ADR-0001
- **绝不使用通用 `set(path, value)`** —— 使用专用原子方法 —— 来源: ADR-0001
- **绝不在 Cat 1 信号处理器内写回 GSM** —— 来源: ADR-0001, ADR-0007
- **绝不在 `_process()` 热路径中写 GSM** —— 写入仅在事件响应中 —— 来源: ADR-0001
- **绝不使用 `JSON.parse_string()` 读取存档** —— 使用 `JSON.new().parse()` 并检查 Error 返回值 —— 来源: ADR-0002
- **绝不让 `schema_version > CURRENT` 的存档静默加载** —— 拒绝并返回 VERSION_MISMATCH —— 来源: ADR-0002
- **绝不让 DialogueSystem/StorySystem/CardEffectEngine 直接写 `story_flags`** —— 委托给 `EventSystem.set_flag()` —— 来源: ADR-0003
- **绝不在 `@export` 字段中使用 `Variant` 类型** —— 使用类型化字段（enum/String/int/float/bool）以确保 Inspector 可编辑 —— 来源: ADR-0003
- **绝不直接调用 `get_tree().change_scene_to_file()`** —— 使用 `SceneManager.request_scene_change()` —— 来源: ADR-0005
- **绝不在 SceneManager 之外写 `GSM.session.current_scene`** —— 来源: ADR-0005
- **绝不声明 SignalBus Autoload** —— 信号属于其语义所有者 —— 来源: ADR-0007
- **绝不超出信号链深度 4** —— 截断 + `push_error` —— 来源: ADR-0007
- **绝不发射携带指令（"该做什么"）的信号** —— 信号携带事实（"发生了什么"） —— 来源: ADR-0007
- **绝不让业务系统直接连接 Godot 内置信号 (Cat 3)** —— 仅基础设施系统连接 —— 来源: ADR-0007
- **绝不声明 `pre_` 信号而无配对的 `post_` 信号** —— 来源: ADR-0007
- **绝不使用 `Callable.bind()` 而不在 `_exit_tree()` 中手动 `disconnect()`** —— 捕获的对象引用造成内存泄漏 —— 来源: ADR-0007

### 性能护栏 (Performance Guardrails)

- **GSM 读取**: <0.1ms/帧（35 个消费者 × O(1) 字典查询） —— 来源: ADR-0001
- **战斗中 GSM 信号发射**: <0.5ms（每场战斗 1-3 次 batch_updated） —— 来源: ADR-0001
- **存档 I/O**: <50ms SSD / <100ms HDD 每次写入 —— 来源: ADR-0002
- **`is_input_allowed()`**: <0.005ms/调用（O(n)，n ≤ 4 个锁条目） —— 来源: ADR-0004
- **每帧输入检查总开销**: <0.25ms（约 50 次调用 × 0.005ms） —— 来源: ADR-0004

---

## Core 层规则

*适用范围：卡牌数据模型、境界系统、状态效果、费用系统、阵营系统、资源系统、流派系统*

### 必需模式 (Required Patterns)

- **CardTemplate (Resource, `.tres`) 运行时只读** —— 所有可变状态在 CardInstance (RefCounted) 上 —— 来源: ADR-0006
- **CardInstance 持有 `template_id: StringName` —— 而非 Resource 引用** —— 通过 `CardSystem.get_template(id)` 查询 —— 来源: ADR-0006
- **CardSystem 是模板注册表 + 实例工厂** —— `create_instance(template_id)` 分配 GSM ID —— 来源: ADR-0006
- **GSM 存储序列化的 Dictionary（模型 A）** —— 通过 `CardSystem.reconstitute_instances()` 重构 —— 来源: ADR-0006
- **模板加载**：`DirAccess` 枚举 `.tres` → `ResourceLoader.load_threaded_request()` —— 每帧 10 个批处理 —— 来源: ADR-0006
- **所有境界属性查询必须通过 `RealmSystem.get_realm_property(level, key)`** —— 来源: ADR-0010
- **RealmSystem 持有 `const realm_table` Dictionary —— 编译时常量，O(1) 查询** —— 来源: ADR-0010
- **`player.realm_level` 所有权保留在 GSM —— RealmSystem 是只读查询者 + 编排者** —— 来源: ADR-0010
- **`realm_up()` 原子编排器**：`GSM.change_realm()` → `realm_upgraded` 信号 → 子系统委托 —— 来源: ADR-0010
- **StatusTemplate (Resource, `.tres`) 只读 —— StatusInstance (RefCounted) 持有运行时状态** —— 来源: ADR-0011
- **状态实例存储在 StatusEffectSystem 内部 Dictionary 注册表 —— 而非 GSM** —— 来源: ADR-0011
- **3 种叠加规则**：独立（新建实例）、刷新（取最大持续 + 新值）、叠加上限（递增至 max_stacks） —— 来源: ADR-0011
- **免疫检查链**：类型免疫 → 模板免疫 → 属性免疫（短路求值） —— 来源: ADR-0011
- **溢出驱逐**：每角色最多 20 个活跃状态——驱逐最旧非永久非隐藏状态 —— 来源: ADR-0011
- **费用状态由 CostSystem 内部管理** —— `_current_cost`、`_max_cost`、`_temp_bonus`、`_temp_bonus_stack` —— 来源: ADR-0015
- **CostSystem 委托 GSM 写入** —— `GSM._set_battle_cost()` 用于战斗费用传播 —— 来源: ADR-0015
- **所有费用检查通过 `CostSystem.can_afford(n)` —— O(1) 整数比较** —— 来源: ADR-0015
- **FactionSystem 持有 `const FACTION_LIBRARY` —— 静态标签定义，纯查询 API** —— 来源: ADR-0018
- **场上阵营统计通过实时遍历（O(6×3) = O(18)）—— 不使用缓存计数器** —— 来源: ADR-0018
- **门派 → 大阵营推导通过 `parent_alignment` 映射** —— 来源: ADR-0018
- **所有资源公式在 ResourceSystem 中以 const 数据表 + 纯函数形式存在** —— 来源: ADR-0019
- **资源数据存储在 GSM `player.resources.*` —— ResourceSystem 是纯逻辑层** —— 来源: ADR-0019
- **所有资源写入必须通过 `ResourceSystem.add_resource()` / `spend_resource()`** —— 来源: ADR-0019
- **SchoolSystem 持有 `const SCHOOL_LIBRARY` —— 5 个流派模板，纯检测引擎** —— 来源: ADR-0025
- **流派检测在卡组变更/上场角色变更/炼制操作后触发** —— 来源: ADR-0025
- **流派增益在战斗开始时锁定 —— 战中不可变更** —— 来源: ADR-0025

### 禁止方法 (Forbidden Approaches)

- **绝不运行时写 CardTemplate 字段** —— Resource 共享引用语义导致静默数据损坏 —— 来源: ADR-0006
- **绝不在 CardTemplate 上使用 `duplicate()`** —— 模板必须保持共享且不可变 —— 来源: ADR-0006
- **绝不在消费者系统中硬编码境界数值** —— 始终查询 `RealmSystem.get_realm_property()` —— 来源: ADR-0010
- **绝不写 `realm_table` 或 `DROP_POOL_WEIGHTS` 内容** —— const Dictionary 并非真正冻结 —— 来源: ADR-0010
- **绝不将状态运行时实例存储在 GSM 中** —— 仅内部 Dictionary —— 来源: ADR-0011
- **绝不在 Foundation 层调用 `StatusEffectSystem` 方法** —— Core → Feature 依赖允许；Foundation → Core 写入不允许 —— 来源: ADR-0011
- **绝不绕过 `CostSystem.can_afford()` 进行消费** —— 来源: ADR-0015
- **绝不直接写 `GSM.player.resources.*`** —— 始终通过 `ResourceSystem` API —— 来源: ADR-0019
- **绝不在消费者系统中重新定义资源公式** —— 真理来源在 ResourceSystem —— 来源: ADR-0019
- **绝不缓存阵营计数** —— 始终从当前场上状态统计 —— 来源: ADR-0018
- **绝不允许同一角色携带互斥的阵营标签**（正道 + 魔道在同一角色上） —— 来源: ADR-0018

### 性能护栏 (Performance Guardrails)

- **CardSystem 模板加载**: 222 文件 <2s 总计，分批轮询期间 <0.1ms/帧 —— 来源: ADR-0006
- **CardSystem `get_template()`**: O(1) 字典查询 <1μs —— 来源: ADR-0006
- **RealmSystem `get_realm_property()`**: O(1) 双重字典查询 <0.01ms —— 来源: ADR-0010
- **StatusEffectSystem `tick_all()`**: <1ms（全角色状态倒计时+过期移除） —— 来源: ADR-0011
- **`get_accumulated_value()`**: <0.01ms（遍历最多 20 个活跃状态） —— 来源: ADR-0011
- **CostSystem `can_afford()`**: O(1) 整数比较 <0.001ms —— 来源: ADR-0015
- **FactionSystem `count_on_field()`**: O(6×3) 标签遍历 <0.01ms —— 来源: ADR-0018

---

## Feature 层规则

*适用范围：战斗、卡牌效果、绑定、探索、上场阵位、AI、修为养成、渡劫突破、身份选择、卡组编辑、阵法、炼丹炼器、法宝铭刻*

### 必需模式 (Required Patterns)

- **7 阶段战斗状态机**：准备(0)→抽牌(1)→出牌(2)→攻击声明(3)→攻击结算(4)→敌方行动(5)→结束(6) —— 来源: ADR-0008
- **`advance_phase()` 在推进前验证前置条件** —— 不满足时返回 false —— 来源: ADR-0008
- **手动阶段（2, 3）需要玩家输入或超时** —— 自动阶段（0,1,4,5,6）使用 `call_deferred()` —— 来源: ADR-0008
- **CombatSystem 通过直接方法调用编排子系统** —— 非信号 —— 来源: ADR-0008
- **HP/费用变化通过 GSM Cat 1 `batch_updated` 传播** —— 来源: ADR-0008
- **EffectTemplate (Resource, `.tres`) 只读 —— EffectInstance (RefCounted) 运行时层** —— 来源: ADR-0009
- **ResolutionStack**：按优先级排序的队列 → LIFO 出栈 → 中分辨率插入新效果 —— 来源: ADR-0009
- **5 级优先级**：主动出牌 > 先发己方 > 普通己方 > 敌方 > instance_id —— 来源: ADR-0009
- **触发链硬限制：10 层 + `visited_card_ids: Dictionary[int, bool]` 循环检测** —— 来源: ADR-0009
- **PRD 引擎**：独立 `RandomNumberGenerator` 实例——5% 步进 + 怜悯保护 —— 来源: ADR-0009
- **AI 评估通过不可变 `GameStateSnapshot` 上的 `evaluate_effect()`** —— 不修改游戏状态 —— 来源: ADR-0009, ADR-0017
- **BindingRecord (RefCounted) —— 非 Resource，非 Dictionary** —— 来源: ADR-0013
- **BindingManager 持有三个同步索引**：`_bindings`、`_by_character`、`_card_to_character` —— 来源: ADR-0013
- **本命绑定通过 `native_owner` 前缀匹配自动判定——角色生命周期内不可逆** —— 来源: ADR-0013
- **同名叠加**：共享槽位、`stack_count` 递增、乘法叠加公式 —— 来源: ADR-0013
- **角色阵亡 → 所有绑定卡洗回牌库 —— 非永久丢失** —— 来源: ADR-0013
- **ExplorationSystem Autoload #14 —— GSM 主存储模型** —— 来源: ADR-0014
- **DAG 生成**：程序化、4-6 层 × 每层 2-4 节点、至少 2 条独立路径到 Boss —— 来源: ADR-0014
- **地图经济**：重入费用 = 10 × 进入次数、境界差额惩罚公式、永久免费地图安全阀 —— 来源: ADR-0014
- **DeploymentSystem**：6 固定阵位（前 3 + 后 3）、`max_deploy = L + 1` —— 来源: ADR-0016
- **前排保护**：前排有存活角色时敌方不可直接攻击后排（穿透效果除外） —— 来源: ADR-0016
- **待命规则**：上场角色在部署回合标记为「待命」——不可攻击 —— 来源: ADR-0016
- **跨战斗角色死亡**：`_unavailable_characters` 通过 GSM 持久化——需复活恢复 —— 来源: ADR-0016
- **AISystem**：3 级智能层级（普通/精英/Boss）、加权优先级决策树 —— 来源: ADR-0017
- **敌方技能通过 CardEffectEngine 统一路径结算** —— 无独立结算逻辑 —— 来源: ADR-0017
- **Boss 阶段转换**：AISystem 内部状态机——HP 阈值触发 —— 来源: ADR-0017
- **EnemyTemplate (Resource, `.tres`) —— EnemyBattleState (RefCounted) 运行时层** —— 来源: ADR-0017
- **难度缩放**：`scale = 1.0 + gap × 0.3` —— 在 `battle_start()` 时应用 —— 来源: ADR-0017
- **CultivationSystem**：统一入口 `gain_cultivation(amount, source)` —— 全部 6 条获取途径 —— 来源: ADR-0020
- **溢出池**：超额修为 → 溢出池；突破触发属性丹转换 —— 来源: ADR-0020
- **TribulationSystem**：复用 CombatSystem 配置 (`is_tribulation: true`) —— 非独立战斗模式 —— 来源: ADR-0021
- **雷伤机制作为 StatusEffect 实现 (`non_dispellable: true`)** —— 来源: ADR-0021
- **IdentitySelectionSystem**：6 个模板 `const Dictionary` —— `apply_identity()` 通过现有服务 API 编排 —— 来源: ADR-0022
- **初始资源通过 `ResourceSystem.add_resource()` 写入 —— 绝不直接写 GSM** —— 来源: ADR-0022
- **`player.talent_map` 作为键值注册表 —— 下游系统按键查询** —— 来源: ADR-0022
- **DeckEditingSystem**：四种渠道的统一入口 —— 来源: ADR-0023
- **卡组数据存储 `Array[int]` (card_instance_id) 在 GSM `player.deck` —— 非完整 CardInstance 字典** —— 来源: ADR-0023
- **所有经济公式委托给 ResourceSystem —— DeckEditingSystem 仅为消费者** —— 来源: ADR-0023
- **FormationSystem**：3 个阵法位、场上状态变更时实时重判条件 —— 来源: ADR-0024
- **阵法光环作用域模型**：GLOBAL / AFFILIATED_CHARACTERS / SAME_FACTION / FORMATION_TRIGGER —— 来源: ADR-0024
- **角色归属锁定直到阵法失效** —— 来源: ADR-0024
- **梯度阵法**：效果等级 = `min(count_on_field(tag) - 1, max_level)` —— 实时计算 —— 来源: ADR-0024
- **AlchemySystem (RefCounted 工具类)**：8 个配方 const Dictionary、独立 RNG 品质掷骰 —— 来源: ADR-0028
- **炼制流程**：校验余额 → 扣灵材 → 品质掷骰 → 创建卡牌实例 → 加入卡组 —— 来源: ADR-0028
- **InscriptionSystem (RefCounted 工具类)**：11 种副属性权重表、6 步加权抽取管线 —— 来源: ADR-0030
- **铭刻成本**：`min(N, 5)` 中级灵材，通过 ResourceSystem 扣减 —— 来源: ADR-0030
- **候选生成**：独立 `RandomNumberGenerator` 实例 —— 不调用全局 `randf()` —— 来源: ADR-0030

### 禁止方法 (Forbidden Approaches)

- **绝不跳过 `advance_phase()` 验证** —— 玩家交互阶段必须先确认再推进 —— 来源: ADR-0008
- **绝不让 CombatSystem 在 Phase 6 清理完成前调用 `battle_end()`** —— 来源: ADR-0008
- **绝不使用全局 `randf()` 处理 PRD 效果** —— 每个引擎实例独立 `RandomNumberGenerator` —— 来源: ADR-0009
- **绝不让触发链超出深度 10** —— 截断并记录 WARN 日志 —— 来源: ADR-0009
- **绝不复制 `OutcomeType` 枚举** —— 扩展 ADR-0003 的权威枚举 —— 来源: ADR-0009
- **绝不让 CardEffectEngine 直接写 GSM** —— 所有效果通过子系统接口执行 —— 来源: ADR-0009
- **绝不硬编码绑定位数量** —— 查询 `RealmSystem.get_realm_property()` —— 来源: ADR-0013
- **绝不在 CombatUI 中每帧调用 `get_bindings_by_character()`** —— 使用零分配的 `get_binding_ids_by_character()` —— 来源: ADR-0013
- **绝不将 DAG 结构缓存进存档数据** —— 读档后从 `map_state` 重建 —— 来源: ADR-0014
- **绝不战中移动角色前后排位置** —— 阵位调整仅在备战阶段 —— 来源: ADR-0016
- **绝不让 AI 直接写 GSM** —— 返回行动指令给 CombatSystem —— 来源: ADR-0017
- **绝不重复实现资源消耗校验** —— 始终委托给 ResourceSystem —— 来源: ADR-0019, ADR-0028, ADR-0030
- **绝不让卡牌增删绕过 DeckEditingSystem 统一 API** —— 来源: ADR-0023
- **绝不缓存阵法激活状态** —— 场上变更时通过 `FactionSystem.check_condition()` 重判 —— 来源: ADR-0024
- **绝不使用全局 `randf()` 进行炼制品质掷骰** —— 独立 `RandomNumberGenerator` 实例 —— 来源: ADR-0028

### 性能护栏 (Performance Guardrails)

- **`resolve_card()`**: <2ms（ResolutionStack + 触发链） —— 来源: ADR-0009
- **AI `execute_turn()`**: <5ms（6 敌人 × 5 技能 × evaluate_effect） —— 来源: ADR-0017
- **`evaluate_effect()` 单次**: <100μs —— 来源: ADR-0009
- **`bind_card()` 单次**: <0.5ms —— 来源: ADR-0013
- **`deploy()` 单次**: <0.3ms —— 来源: ADR-0016
- **`gain_cultivation()` 单次**: <0.1ms —— 来源: ADR-0020
- **DAG 生成**: <5ms（100-200 节点） —— 来源: ADR-0014

---

## Meta 层规则

*适用范围：跨局元进度（成就、天赋、卡牌图鉴、结局、统计数据）*

### 必需模式 (Required Patterns)

- **ProgressionSystem Autoload #12 拥有所有跨局元进度运行时数据** —— 来源: ADR-0012
- **直写缓存模型**：API → 内部存储 → `progression_updated` 信号 → SaveLoadSystem 被动持久化 —— 来源: ADR-0012
- **6 个领域化 API**：成就(achievements)、天赋(talents)、卡牌图鉴(card_gallery)、结局(endings)、统计(statistics)、元数据(meta) —— 来源: ADR-0012
- **ProgressionSystem 取代 GSM `progression.*` 域所有权** —— GSM 不再持有元进度数据 —— 来源: ADR-0012
- **特征系统通过 ProgressionSystem 读写元进度数据 —— 而非通过 GSM** —— 来源: ADR-0012
- **首局默认值**：空的 `progression.dat` → 所有领域从零初始化——不报错 —— 来源: ADR-0012

### 禁止方法 (Forbidden Approaches)

- **绝不通过 GSM 写元进度数据** —— 使用 ProgressionSystem API —— 来源: ADR-0012
- **绝不访问 `GSM.progression.*`** —— 域所有权已转移至 ProgressionSystem —— 来源: ADR-0012
- **绝不直接调用 SaveLoadSystem 写元进度** —— ProgressionSystem 的信号触发被动持久化 —— 来源: ADR-0012
- **绝不在特征系统间重复定义进度域结构** —— 来源: ADR-0012
- **绝不按进度域创建独立持久化文件** —— 全部通过 SaveLoadSystem 存储于 `progression.dat` —— 来源: ADR-0012

### 性能护栏 (Performance Guardrails)

- **`progression_updated` → SaveLoadSystem 写入**: <50ms 每次写入 —— 来源: ADR-0012
- **序列化的元进度数据**: <25KB 总计（全部 6 个域） —— 来源: ADR-0012

---

## Narrative 层规则

*适用范围：剧情系统、对话系统、结局分支系统*

### 必需模式 (Required Patterns)

- **StorySystem Autoload #25**：GSM 主存储模型管理 `narrative.*` 域 —— 来源: ADR-0026
- **5 个章节模板以 `const Dictionary` 编译时常量存储 —— 非 Resource `.tres`** —— 来源: ADR-0026
- **StorySystem 通过 5 个专用第二层原子方法写入 `GSM.narrative.*`** —— 来源: ADR-0026
- **`story_flags` 写入委托给 `EventSystem.set_flag()` —— 遵守唯一写入者契约** —— 来源: ADR-0026
- **对话系统**：RefCounted 服务类 —— 零 Autoload 扩容 —— 来源: ADR-0027
- **`DialoguePlayer` + `DialogueDatabase` 由触发系统按需实例化** —— 来源: ADR-0027
- **对话树以 JSON 文件存储 —— 按需加载（每树 3-15 节点，<5ms）** —— 来源: ADR-0027
- **Bark 池状态在 `GSM.session.bark_history` —— 瞬态数据，不持久化到存档** —— 来源: ADR-0027
- **EndingEvaluator**：纯函数 RefCounted 工具类 —— 嵌入 StorySystem —— 来源: ADR-0029
- **结局评分**：加权求和 + 第 5 章偏斜 + 优先级平局解决 —— 来源: ADR-0029
- **结局图鉴持久化通过 `ProgressionSystem.unlock_ending()`** —— 来源: ADR-0029
- **结局展示序列**：CG → 尾声叙事 → 统计面板 → 图鉴更新 → 轮回结算 → 主菜单 —— 来源: ADR-0029

### 禁止方法 (Forbidden Approaches)

- **绝不让 StorySystem 或 DialogueSystem 直接写 `story_flags`** —— 委托给 `EventSystem.set_flag()` —— 来源: ADR-0026, ADR-0027
- **绝不将 DialogueSystem 注册为 Autoload** —— 25 个 Autoload 已超出 20 软上限 —— 来源: ADR-0027
- **绝不将 EndingSystem 注册为 Autoload** —— 嵌入 StorySystem —— 来源: ADR-0029
- **绝不让 EndingEvaluator 写 `story_flags`** —— 仅只读访问 —— 来源: ADR-0029
- **绝不创建独立的 `endings.dat`** —— 使用 ProgressionSystem API —— 来源: ADR-0029
- **绝不持久化对话中途进度** —— 对话是瞬态的；选项结果在选择时写入 —— 来源: ADR-0027

### 性能护栏 (Performance Guardrails)

- **对话树 JSON 解析**: <5ms 每次加载（单棵树，3-15 节点） —— 来源: ADR-0027
- **`evaluate_ending()`**: <0.1ms（纯字典计算） —— 来源: ADR-0029
- **章节模板**: <5KB 内存（5 章 × ~30 字段，编译时常量） —— 来源: ADR-0026

---

## 全局规则 (所有层)

### 命名规范

| 元素 | 规范 | 示例 |
|---------|-----------|---------|
| 类 (Classes) | PascalCase | `PlayerController` |
| 变量 (Variables) | snake_case | `move_speed` |
| 信号/事件 (Signals/Events) | snake_case 过去式 | `health_changed`、`event_resolved` |
| 文件 (Files) | snake_case 匹配类名 | `player_controller.gd` |
| 场景/预制体 (Scenes/Prefabs) | PascalCase 匹配根节点 | `PlayerController.tscn` |
| 常量 (Constants) | UPPER_SNAKE_CASE | `MAX_HEALTH` |
| Autoload source 标识符 | snake_case StringName | `&"dialogue_system"`、`&"scene_manager"` |

### 性能预算

| 指标 | 数值 |
|--------|-------|
| 帧率 | 60fps |
| 帧预算 | 16.6ms |
| 绘制调用 | <200（2D 卡牌游戏） |
| 内存上限 | 2GB |
| 存档文件大小 | <1MB JSON |
| 启动时间（模板加载） | <2s 总计 |

### 已批准的库/插件

*[尚未配置 — 随着依赖项的获批而添加]*

### 禁止 API (Godot 4.6)

以下 API 在 Godot 4.6 中已被弃用或未经验证。来源：`docs/engine-reference/godot/deprecated-apis.md`。

#### 节点与类

| 已弃用 | 改用 | 起始版本 |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |

#### 方法与属性

| 已弃用 | 改用 | 起始版本 |
|------------|-------------|-------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` 用于嵌套资源 | `duplicate_deep()` | 4.5 |
| `Skeleton3D` 信号 `bone_pose_updated` | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

#### 禁止模式（不仅是 API）

| 已弃用模式 | 改用 | 原因 |
|--------------------|-------------|-----|
| 基于字符串的 `connect()` | 类型化信号连接 | 类型安全，便于重构 |
| 在 `_process()` 中使用 `$NodePath` | `@onready var` 缓存引用 | 性能：每帧路径查找 |
| 无类型的 `Array` / `Dictionary` | `Array[Type]`、类型化变量 | GDScript 编译器优化 |
| shader 参数中的 `Texture2D` | `Texture` 基类型 | 4.4 中变更 |
| 手动后处理视口链 | `Compositor` + `CompositorEffect` | 结构化后处理（4.3+） |
| 新项目使用 GodotPhysics3D | Jolt Physics 3D | 4.6 起为默认，稳定性更好 |

### 引擎特定约束 (Godot 4.6)

- **Jolt Physics 为默认 3D 引擎** —— 2D 物理不变（Godot Physics 2D） —— 来源: `current-best-practices.md`
- **D3D12 为 Windows 上默认渲染器** —— 来源: `breaking-changes.md`
- **双焦点系统**：鼠标/触摸焦点与键盘/手柄焦点分离 —— 来源: `breaking-changes.md`、ADR-0004
- **Glow 在 tonemapping 之前处理**（4.6 变更）—— 现有 glow 配置可能呈现不同效果 —— 来源: `breaking-changes.md`
- **`FileAccess.store_*` 方法返回 `bool`**（4.4+）—— 必须检查返回值 —— 来源: ADR-0002
- **`@abstract` 类可用**（4.5+）—— 用于效果基类、状态基类 —— 来源: `current-best-practices.md`
- **可变参数**（4.5+）：`func log(prefix: String, values: Variant...)` —— 来源: `current-best-practices.md`
- **`duplicate_deep()` 用于嵌套 Resource 深拷贝**（4.5+） —— 来源: `deprecated-apis.md`
- **SMAA 1x 抗锯齿可用**（4.5+） —— 来源: `current-best-practices.md`
- **IK 系统完全恢复**（4.6）—— CCDIK、FABRIK、Jacobian IK、Spline IK、TwoBoneIK —— 来源: `current-best-practices.md`
- **ripgrep 没有 `gdscript` 类型** —— 使用 `--glob "*.gd"` 而非 `--type gdscript` —— 来源: `current-best-practices.md`

### 跨层约束

- **Foundation 层原则 #3**：Foundation 层系统不得依赖 Core/Feature 层系统 —— 来源: ADR-0003、ADR-0007
- **信号驱动通信分类法**：Cat 1（GSM 状态信号）/ Cat 2a（生命周期钩子 pre/post）/ Cat 2b（动作通知）/ Cat 2c（委托信号 fire-and-forget）/ Cat 3（Godot 内置信号） —— 来源: ADR-0007
- **Autoload 初始化顺序**：严格按 `project.godot` 的 `[autoload]` 部分顺序执行。见下方 §Autoload 全链 —— 来源: ADR-0001、ADR-0004、ADR-0005、ADR-0002、ADR-0003
- **所有公共方法必须可单元测试** —— 依赖注入优于单例 —— 来源: `coding-standards.md`
- **游戏数值必须数据驱动**（外部配置）—— 绝不硬编码 —— 来源: `coding-standards.md`
- **提交信息**：Conventional Commits 格式 —— `feat:`、`fix:`、`chore:`、`docs:`、`test:`、`refactor:` —— 来源: `coding-standards.md`
- **示例中的提交标题**：≤60 字符 —— 来源: `hub_structure.instructions.md`
- **按故事类型划分的测试证据**：逻辑（单元测试——阻塞级）、集成（集成测试——阻塞级）、视觉/感受（截图——建议级）、UI（手动演练——建议级）、配置/数据（冒烟检查——建议级） —— 来源: `coding-standards.md`
- **Autoload 25 个超出 Godot 20 软上限** —— 所有 ADR 已明确记录此风险。新系统默认采用 RefCounted 工具类模式，除非运行时持久状态确需 Autoload —— 来源: ADR-0027、ADR-0028、ADR-0029、ADR-0030

### Autoload 全链 (25 个)

```
#1  GSM                     (FOUNDATION — ADR-0001)
#2  InputManager             (FOUNDATION — ADR-0004)
#3  SceneManager             (FOUNDATION — ADR-0005)
#4  SaveLoadSystem           (FOUNDATION — ADR-0002)
#5  EventSystem              (FOUNDATION — ADR-0003)
#6  CardSystem               (CORE — ADR-0006)
#7  CostSystem               (CORE — ADR-0015)
#8  StatusEffectSystem       (CORE — ADR-0011)
#9  CombatSystem             (FEATURE — ADR-0008)
#10 CardEffectEngine         (FEATURE — ADR-0009)
#11 RealmSystem              (CORE — ADR-0010)
#12 ProgressionSystem        (META — ADR-0012)
#13 BindingManager           (FEATURE — ADR-0013)
#14 ExplorationSystem        (FEATURE — ADR-0014)
#15 FactionSystem            (CORE — ADR-0018)
#16 ResourceSystem           (CORE — ADR-0019)
#17 DeploymentSystem         (FEATURE — ADR-0016)
#18 AISystem                 (FEATURE — ADR-0017)
#19 SchoolSystem             (CORE — ADR-0025)
#20 CultivationSystem        (FEATURE — ADR-0020)
#21 IdentitySelectionSystem  (FEATURE — ADR-0022)
#22 DeckEditingSystem        (FEATURE — ADR-0023)
#23 FormationSystem          (FEATURE — ADR-0024)
#24 TribulationSystem        (FEATURE — ADR-0021)
#25 StorySystem              (FEATURE — ADR-0026)
```

### 非 Autoload 系统 (RefCounted 工具类)

| 系统 | 模式 | ADR |
|--------|---------|-----|
| 对话系统 (DialogueSystem) | `DialoguePlayer` + `DialogueDatabase` RefCounted + JSON 按需加载 | ADR-0027 |
| 炼丹炼器系统 (AlchemySystem) | RefCounted + `class_name` 工具类 + const 配方表 | ADR-0028 |
| 结局评估器 (EndingEvaluator) | 纯函数 RefCounted——嵌入 StorySystem | ADR-0029 |
| 法宝铭刻系统 (InscriptionSystem) | RefCounted + `class_name` 工具类 + const 权重表 | ADR-0030 |