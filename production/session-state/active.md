# 活跃会话状态

> **会话 ID**：2026-07-25
> **上次更新**：2026-07-25（ADR-0014 — 进行中，等待 TD-ADR 审查完成）

## 本会话成果

### ADR-0014：探索系统 (`/architecture-decision 探索系统`)
- **产出**：`docs/decisions/ADR-0014-exploration-system-autoload-gsm-primary-procedural-dag.md`（~536 行）
- **引擎上下文**：Godot 4.6 — 知识风险 LOW，全部核心 API 4.0+ 稳定
- **godot-specialist 审查**：✅ 已处理 — 0 BLOCKING + 4 HIGH（H1 const Dictionary 可变性已在风险中记录、H2 GSM 写入契约已重写为第二层方法、H3 信号链深度已建模验证、H4 _ready() 竞态已添加 _dag_ready 守卫）+ 10 LOW（现代信号语法、@export 可调参数、Resource 子类建议等——实施阶段处理）
- **technical-director 审查**：⏳ 进行中 — 等待 TD-ADR 门禁审查返回
- **注册表**：⏳ 待审查完成后更新
- **GDD 同步**：⚠️ 发现 1 个不一致 — exploration-system.md 信号表中的 `ap_depleted`（由 ExplorationSystem 发射）在 ADR 中合并入 `exploration_ended`。action-point-system.md 信号名称差异（`action_points_changed/depleted/refilled` vs ADR 中的 `batch_updated` Cat 1 传播）——有意的架构重分配，等待 TD 确认
- **关卡模式**：full（godot-specialist ✅ + technical-director ⏳）
- **状态**：Draft——等待 TD-ADR 审查

## 本会话成果

### ADR-0013：绑定系统 (`/architecture-decision 绑定系统`)
- **产出**：`docs/decisions/ADR-0013-binding-system-autoload-refcounted-model.md`
- **引擎上下文**：Godot 4.6 — 知识风险 LOW，全部核心 API 4.0+ 稳定
- **godot-specialist 审查**：✅ 已处理 — 3 HIGH（H1 `get_bindings_by_character()` 每帧分配→新增 `get_binding_ids_by_character()` 零分配查询、H2 `_ready()` 信号时序→遵循 ADR-0012 直接调用模式、H3 Dictionary→类型化数组类型安全→assert 守卫）+ 4 LOW（RefCounted 释放路径、术语 GC→引用计数、部分恢复策略、缓存失效）
- **technical-director 审查**：✅ 已处理 — 4 CONCERNS（C#1 启用字段 ADR-0012→前向引用修正、C#2 相关决策链接修正 ADR-0002→ADR-0006、C#3 architecture.md 例外更新已声明、C#4 暂挂/恢复排序契约强化）
- **注册表**：✅ 已更新 — 3 state_ownership + 4 interfaces + 2 forbidden_patterns（9 entries）
- **GDD 同步**：无问题 — binding-system.md 已使用 ADR 定义的 API 名称（bind_card/stack_card/overwrite_binding/BindingRecord）
- **关卡模式**：full（godot-specialist + technical-director 均已通过）
- **状态**：Proposed（需 `/architecture-review` 后翻转为 Accepted）

<!-- STATUS -->
Epic: Architecture Foundation / Combat
Feature: Binding System
Task: ADR-0013 — complete ✅
<!-- /STATUS -->

## 关键架构决策

1. **BindingManager Autoload #13**：RefCounted BindingRecord 实例模型——对齐 ADR-0002/0009/0011 的 Template/Instance 四元组
2. **内部三索引注册表**：`_bindings` + `_by_character` + `_card_to_character`——战斗热路径 O(1) 查询，不通过 GSM
3. **GSM 例外模式**：战斗中绑定数据由 BindingManager 独立管理——战斗结束 `serialize_all()` → `GSM.battle.bindings` 快照（遵循 ADR-0011 先例）
4. **专用 Cat 2b 信号总线**：binding_applied/removed/overwritten/stacked/suspended/restored/native_activated——通过 _emit_signal_safe 路由
5. **同名叠加共享槽位**：stack_count 递增，乘法公式 `base × native × stack_multiplier^(count-1)`
6. **CardEffectEngine 集成**：BindingManager 调用 register_persistent_effect / remove / suspend / restore——绑定系统负责"何时"，效果引擎负责"如何"
7. **Autoload 完整链 13 个**：GSM→Input→Scene→SaveLoad→Event→Card→Cost→StatusEffect→Combat→CardEffect→Realm→Progression→BindingManager
- **产出**：`docs/decisions/ADR-0012-cross-run-meta-progression-system.md`（456 行）
- **引擎上下文**：Godot 4.6 — 知识风险 LOW，全部核心 API 自 4.0 起稳定
- **godot-specialist 审查**：✅ 已处理 — 3 HIGH（H-1 信号等待→直接调用模式、H-2 ADR-0003 信号源变更已记录、H-3 同步写盘+批量 API）+ 3 LOW（progression_initialized 信号声明、类型化 Dictionary、双焦点系统说明）
- **technical-director 审查**：✅ 已处理 — 5 CONCERNS（C#1 grant_talent() for EventSystem GAIN_TALENT、C#2 结构化返回值设计说明、C#3 unlock_ending 内置 total_completions 递增、C#4 Autoload 数量债务跟踪、C#5 统计边界文档化）
- **ADR-0001 取代**：✅ — `progression.*` 域所有权条目标记为 `superseded_by: ADR-0012`
- **ADR-0003 信号源变更**：✅ — `GSM.progression_updated` → `ProgressionSystem.progression_updated`
- **注册表**：✅ 已更新 — 6 state_ownership + 4 interfaces + 现有 progression_updated 条目更新（13 entries）
- **GDD 同步**：无问题 — 所有 5 个元系统 GDD（achievement/reincarnation/ending/card/save-load）均使用 ProgressionSystem API 名称
- **关卡模式**：full（godot-specialist + technical-director 均已通过）
- **状态**：Proposed（需 `/architecture-review` 后翻转为 Accepted）

<!-- STATUS -->
Epic: Architecture Foundation
Feature: Meta-Progression System
Task: ADR-0012 — complete ✅
<!-- /STATUS -->

## 关键架构决策

1. **ProgressionSystem Autoload #12**：拥有所有跨局元进度数据——6 个领域（achievements/talents/card_gallery/endings/statistics/meta）
2. **直写缓存模型**：特征系统 → API → 内部存储 → `progression_updated` 信号 → SaveLoadSystem 被动持久化
3. **GSM 解耦**：GSM 不再持有 `progression.*` 域——生命周期分离（ProgressionSystem=跨局，GSM=单局）
4. **结构化返回值**：`{success: bool, reason: String}` 用于用户可见失败（与 GSM `bool` 风格有意不同）
5. **初始化策略**：利用 Godot 顺序 `_ready()` 保证直接调用 SaveLoadSystem.load_progression()（非信号等待）
6. **批量更新 API**：`batch_update_begin/end` 防止高频统计增量的帧尖峰累积
7. **EventSystem GAIN_TALENT 迁移**：`grant_talent()` API — 不消耗轮回点的天赋授予
8. **Autoload 完整链 12 个**：GSM→Input→Scene→SaveLoad→Event→Card→Cost→StatusEffect→Combat→CardEffect→Realm→Progression

## 本会话成果

### ADR-0011：状态效果系统 (`/architecture-decision 状态效果生命周期`)
- **产出**：`docs/decisions/ADR-0011-status-effect-system-template-instance-model.md`
- **引擎上下文**：Godot 4.6 — 知识风险 LOW，所有 API 4.0+ 稳定
- **godot-specialist 审查**：✅ 已处理 — 2 HIGH（Autoload 数量更新为 11 个、信号发射策略明确）+ 4 LOW（对象池降级、const Dictionary 缓解、API 接口完整性、无引擎弃用 API）
- **technical-director 审查**：✅ 已处理 — 5 CONCERNS（C#1 与 ADR-0009 接口映射、C#2 ADR 编号 0013→0011、C#3 GSM 例外在 architecture.md 中记录、C#4 suspend 签名差异说明、C#5 长度超出预算已接受）
- **ADR-0009 同步**：✅ 已更新 — 4 处 `ADR-0013` → `ADR-0011` 替换 + 接口契约引用更新
- **architecture.md**：✅ 已更新 — §架构原则 #1 增加 ADR-0011 例外声明（战斗中 StatusEffectSystem 独立管理状态实例）
- **注册表**：✅ 已更新 — 3 state_ownership + 4 interfaces + 2 forbidden_patterns（9 entries）
- **GDD 同步**：无问题 —— status-system.md 已使用 ADR 定义名称（status_applied/removed/updated/immunity_blocked/get_accumulated_value/can_apply）
- **关卡模式**：full（godot-specialist + technical-director 均已通过）
- **状态**：Proposed（需 `/architecture-review` 后翻转为 Accepted）

<!-- STATUS -->
Epic: Architecture Foundation / Combat
Feature: Status Effect System
Task: ADR-0011 — complete ✅
<!-- /STATUS -->

## 关键架构决策

1. **双层对象模型**：StatusTemplate (Resource, .tres) + StatusInstance (RefCounted) — 与 CardSystem/EffectEngine 构成统一的 Template/Instance 三元组
2. **StatusSystem 内部存储**：`_instances` + `_by_target` 索引 — 非 GSM（战斗热路径 O(1) 查询需求）
3. **专用 Cat 2b 信号总线**：status_applied/removed/updated/immunity_blocked — 通过 _emit_signal_safe 路由
4. **tick_all() 递减不发射 status_updated** — 仅批量 remove_expired 发射 status_removed
5. **GSM 例外**：战斗中状态数据由 StatusEffectSystem 管理，仅战斗结束时导出快照至 GSM
6. **Autoload #8**（完整链 11 个：GSM→Input→Scene→SaveLoad→Event→Card→Cost→StatusEffect→Combat→CardEffect→Realm）

---

## 会话摘录 — /architecture-review 2026-07-25
- 裁决：CONCERNS
- 需求：35 TR-ID 注册（14 个 ADR 覆盖 14 个核心系统）
- 新注册的 TR-ID：35（TR-gsm-001~003, TR-save-001~003, TR-event-001~003, TR-input-001~002, TR-scene-001~002, TR-card-001~002, TR-signal-001~002, TR-realm-001~003, TR-status-001~002, TR-combat-001~003, TR-effect-001~003, TR-progression-001~002, TR-binding-001~002, TR-explore-001~003）
- GDD 修订标志：无
- 主要 ADR 缺口：22 个系统尚无 ADR（费用、上场阵位、阵法、阵营、AI 等 — top priority）
- 关键跨 ADR 冲突：ADR-0002~0006 内部编号与文件名不一致（需修正内部编号以匹配文件名——文件名为权威来源）
- 报告：docs/architecture/architecture-review-2026-07-25.md
