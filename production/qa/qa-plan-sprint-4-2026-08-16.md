# QA 计划：Sprint 4 — Feature 层战斗子系统

**日期**：2026-08-16
**由**：/qa-plan 生成
**范围**：6 Epic × 25 story（+ 1 个 4-0 Autoload 注册 task），形成可运行的战斗闭环
**引擎**：Godot 4.6
**测试框架**：GUT
**Sprint 文件**：`production/sprints/sprint-4.md`
**Manifest Version**：2026-08-05

> **分类原则**：每个 story 头部 `Type:` 字段由 lead-programmer 权威分类，本计划**按原样接受，不重新分类**。25 个 story 全部为 Logic 或 Integration，无 UI/Visual/Config 类。

---

## 一、测试摘要表

| # | Story | Epic | 类型 | 测试文件路径（story 文件声明） | 预估测试数 |
|:--:|-------|------|:----:|--------------------------------|:----------:|
| 4-1 | EffectTemplate/EffectInstance 双层对象模型（4 种子类） | card-effect-engine | Logic | `tests/unit/card_effect_engine/test_template_instance_model.gd` | ~8 |
| 4-2 | ResolutionStack 栈式结算引擎（优先级队列 + LIFO + 中断插入） | card-effect-engine | Logic | `tests/unit/card_effect_engine/test_resolution_stack.gd` | ~6 |
| 4-3 | 触发链硬限制 10 层 + visited_card_ids 循环检测 | card-effect-engine | Logic | `tests/unit/card_effect_engine/test_trigger_chain_10_layer_cycle.gd` | ~8 |
| 4-4 | PRD 伪随机分布引擎（5% 步进 + 怜悯保护） | card-effect-engine | Logic | `tests/unit/card_effect_engine/test_prd_distribution.gd` | ~7 |
| 4-5 | AI 干跑评估接口（GameStateSnapshot 不可变纯计算） | card-effect-engine | Logic | `tests/unit/card_effect_engine/test_ai_dry_run_snapshot.gd` | ~9 |
| 4-6 | 内部状态机 + 阵位数据管理（STANDBY→READY→ACTED） | deployment-system | Logic | `tests/unit/deployment_system/test_internal_state_machine.gd` | ~20 |
| 4-7 | deploy / remove / is_targetable 前后排保护 O(1) | deployment-system | Logic | `tests/unit/deployment_system/test_deploy_targetable.gd` | ~18 |
| 4-8 | 战斗结束 serialize_field 快照导出 GSM.battle.deployment_snapshot | deployment-system | Integration | `tests/integration/deployment_system/test_serialize_snapshot.gd` | ~14 |
| 4-9 | clear_standby_state + mark_unavailable + revive_character | deployment-system | Logic | `tests/unit/deployment_system/test_standby_unavailable_revive.gd` | ~16 |
| 4-10 | BindingRecord RefCounted 实例模型 + 内部注册表 | binding-system | Logic | `tests/unit/binding_system/test_binding_record_model.gd` | ~10 |
| 4-11 | bind / unbind / get_bindings 查询 API | binding-system | Logic | `tests/unit/binding_system/test_bind_unbind_query_api.gd` | ~22 |
| 4-12 | 绑定生命周期信号总线（7 个 Cat 2b 信号） | binding-system | Integration | `tests/integration/binding_system/test_binding_signal_bus.gd` | ~12 |
| 4-13 | serialize_all 快照导出 + persistent effect 接口 | binding-system | Integration | `tests/integration/binding_system/test_serialize_snapshot_effect_integration.gd` | ~14 |
| 4-14 | 内部条件状态机 + 阵法位管理 | formation-system | Logic | `tests/unit/formation_system/test_internal_state_machine.gd` | ~10 |
| 4-15 | 激活条件实时重判（订阅 deployment 信号） | formation-system | Integration | `tests/integration/formation_system/test_activation_rejudge.gd` | ~7 |
| 4-16 | get_aura_bonus O(1) 查询 + 梯度光环计算 | formation-system | Logic | `tests/unit/formation_system/test_aura_bonus_query.gd` | ~9 |
| 4-17 | serialize_all 快照导出 GSM.battle.formation_snapshot | formation-system | Integration | `tests/integration/formation_system/test_serialize_snapshot.gd` | ~7 |
| 4-18 | EnemyTemplate Resource + EnemyFactory + EnemyBattleState | ai-system | Logic | `tests/unit/ai_system/test_enemy_template_factory.gd` | ~12 |
| 4-19 | execute_turn 决策主循环（普通/精英/Boss 分支） | ai-system | Logic | `tests/unit/ai_system/test_execute_turn_decision.gd` | ~17 |
| 4-20 | BossPhaseMgr 阶段转换内部状态机 | ai-system | Logic | `tests/unit/ai_system/test_boss_phase_manager.gd` | ~15 |
| 4-21 | 难度缩放 + register_preconfigured_bindings | ai-system | Logic | `tests/unit/ai_system/test_difficulty_scaling_bindings.gd` | ~13 |
| 4-22 | 7 阶段回合状态机（advance_phase 确定性推进 + 阶段转换校验） | combat-system | Logic | `tests/unit/combat_system/test_seven_phase_state_machine.gd` | ~15 |
| 4-23 | 战斗生命周期编排（battle_start / battle_end + GSM battle.* 域） | combat-system | Integration | `tests/integration/combat_system/test_battle_lifecycle_gsm.gd` | ~19 |
| 4-24 | play_card 出牌 + 目标解析 + 自动推进调度 | combat-system | Logic | `tests/unit/combat_system/test_play_card_target_resolution.gd` | ~14 |
| 4-25 | 阶段转换 Cat 2b 信号通知 CombatUI | combat-system | Integration | `tests/integration/combat_system/test_phase_transition_signals.gd` | ~12 |

**预估测试总数**：约 **314** 个测试函数（Logic ~194 + Integration ~120）。

> 测试文件名已统一为 `test_` 前缀（GUT 配置要求），与项目 `.gutconfig.json` 的 `prefix: "test_"` 一致。缺口 #1（`_test.gd` 后缀孤儿测试）已在 9 个 story 文件中修复完毕，详见 §七。

### 分类统计

| 类型 | 数量 | 关卡等级 | 证据位置 |
|:----:|:----:|:--------:|---------|
| **Logic** | 18 | BLOCKING（阻塞） | `tests/unit/[system]/` |
| **Integration** | 7 | BLOCKING（阻塞） | `tests/integration/[system]/` |
| **合计** | 25 | — | — |

**Logic 分布**：card-effect-engine 5、deployment 3、binding 2、formation 2、ai 4、combat 2 = 18
**Integration 分布**：deployment 1、binding 2、formation 2、combat 2 = 7

---

## 二、需自动化测试

> 测试命名规范：函数名 `test_[scenario]_[expected]`；无随机种子、无时间依赖断言（PRD/撤退/目标选择随机性场景除外——用固定 seed 保证可复现，参照 event_system 的 `seed(42)` 先例）。每个测试自我设置与清理，不依赖执行顺序。

### card-effect-engine（结算引擎，无下游依赖，最先实现）

#### Story 4-1 — EffectTemplate/EffectInstance 双层对象模型（Logic，~8 测试）

**测试文件**：`tests/unit/card_effect_engine/`（story 文件声明 `story-001-template-instance-model_test.gd`，命名需修正为 `test_` 前缀）

**测试内容（从 AC-001~004 推导）**：
- AC-001：伤害效果精确匹配 `effective_value`（base_value=3、无修正、无本命 → HP-3）
- AC-002：本命绑定 ×1.5 floor 取整（base_value=3 → `floor(3×1.5)=4`）
- AC-003：功法绑定 ATK+2 通过 `get_accumulated_value(target, "ATK")` 验证
- AC-004：`binding_multiplier` 绑定瞬间预计算锁定 1.5

**边界情况**：
- base_value=0 时 HP 不减少（严格非负）
- 无目标可选中时效果不结算
- 偶数 base_value=4 → `floor(4×1.5)=6`（整数）；奇数 base_value=3 → 4（损失 0.5）
- 绑定前查询返回基础值；解绑后加成移除
- 非本命绑定锁定 1.0；第二绑定尝试自动降级普通绑定（1.0）

**扫描自动化测试需防范的禁止模式**（control-manifest Feature 层）：
- EffectTemplate（Resource）运行时只读，EffectInstance（RefCounted）运行时层——断言模板字段不被实例修改
- CardEffectEngine 不直接写 GSM——通过 `StatusSystem.apply_status` 等子系统接口
- 不复制 `OutcomeType` 枚举——扩展 ADR-0003 权威枚举

#### Story 4-2 — ResolutionStack 栈式结算引擎（Logic，~6 测试）

**测试文件**：`tests/unit/card_effect_engine/`（命名需修正）

**测试内容**：
- AC-001：己方效果 A(t=3) vs B(t=5) 同时机触发 → B 先于 A（较新优先）
- AC-002：先发标记=开（t=1）vs 先发=关（t=10）→ 先发优先

**边界情况**：
- t 相同 → 按 `card_instance_id` 升序决胜
- 次级 `priority: int` 仅在同主排序层级内生效
- 两个先发效果之间仍按激活时间从新到旧
- 5 级主排序（主动出牌 > 先发己方 > 普通己方 > 敌方 > instance_id）

**禁止模式**：CardEffectEngine 不直接写 GSM（通过 `CombatSystem.damage_target` / `StatusSystem.apply_status` 等）；不全局 `randf()`（PRD 归 Story 4-4）。

#### Story 4-3 — 触发链硬限制 10 层 + visited_card_ids 循环检测（Logic，~8 测试）

**测试文件**：`tests/unit/card_effect_engine/`（命名需修正）

**测试内容**：
- AC-001：A→B→C 触发链（深度 3）→ C 先结算完，B 其次，A 最后（栈式 LIFO）
- AC-002：同一 card_instance_id 再次触发 → 跳过不重复触发（循环检测），DEBUG 日志
- AC-003：深度达 10 → 第 11 层终止，前 10 层正常结算，WARN 日志 `"[CardEffectEngine] Trigger chain depth exceeded: max=10, root_card_id=<ID>, chain=<A→B→...→K>"`

**边界情况**：
- 结算顺序按完成时间（非开始时间）判定
- 两卡 A↔B 无限循环 → visited 字典第二次遇到时终止
- 扇出分支（A→B1、A→B2）共享深度计数器——总节点数达 11 即截断
- 第 1-10 层必须完整结算完毕
- `stack_overflow_warning` 信号载荷 `{root_card_id, depth, chain}`（>3 参数用具名字典）

**禁止模式**：绝不超出深度 10——截断 + WARN。

#### Story 4-4 — PRD 伪随机分布引擎（Logic，~7 测试）

**测试文件**：`tests/unit/card_effect_engine/`（命名需修正）

**测试内容**：
- AC-001：30% 概率冰冻（P_base=0.3），连续失败 4 次 → 第 5 次必然触发（怜悯保护 `ceil(1/0.3)=4`）
- AC-002：同一 PRNG 种子执行 100 次 30% PRD → 触发次数在 24-36 次之间（99% CI 近似值）

**边界情况**：
- 不同 card_instance_id 各自独立累计失败次数（`P_current` 按实例追踪）
- 触发后 `P_current` 重置为 P_base
- 固定种子 → 100 次结果确定性可重现（同种子同操作序列 = 相同结果）
- 测试模式 `prng_override_seed`

**⚠ 缺口**：PRD 累加常数 C 的默认值「待游戏测试校准」（GDD §调优参数 + 待解决问题 #4）。`P_current += P_base × C` 的 C 值直接影响收敛速度，AC-002 的 24-36 次区间是 C 未定时的近似值——**区间断言需在 C 值确定后校准**，否则测试脆弱（详见 §七 缺口 #2）。

**禁止模式**：绝不使用全局 `randf()`——独立 `RandomNumberGenerator` 实例。

#### Story 4-5 — AI 干跑评估接口（Logic，~9 测试）

**测试文件**：`tests/unit/card_effect_engine/`（命名需修正）

**测试内容**：
- AC-001：`evaluate_effect(card_id, target_id, snapshot)` 对伤害卡 → `EffectEvaluation.damage` 与 `get_accumulated_value()` 一致
- AC-002：`simulate_chain(card_id, target_id, snapshot, max_depth=5)` 会连锁 → `ChainPreview.chain` 含每步触发来源 + 效果评估
- AC-003：AI 评估 288 次 effect 调用（6敌 ×8技 ×6目标）总耗时 < 30ms（不含快照创建一次性 1-2ms）

**边界情况**：
- 有本命绑定（×1.5）时 floor 取整一致
- 评估后 snapshot 不被修改（不可变浅拷贝验证）
- 链长超 max_depth 时 `would_overflow=true`；无连锁时 chain 只含根效果
- 单次 `evaluate_effect()` < 100μs；`simulate_chain` 深度 5 < 500μs
- 确定性契约：`evaluate_effect()` 与 `resolve_card()` 同输入同结果

**⚠ 缺口**：AC-003 及单次性能护栏（<100μs/<500μs/<30ms）在 GUT 无头/CI 环境中因机器差异可能波动——性能断言应设宽松阈值或标记为非 CI 强断言（详见 §七 缺口 #3）。

**禁止模式**：评估路径只读——不修改游戏状态，不直接写 GSM。

---

### deployment-system（纯逻辑，可较早启动）

#### Story 4-6 — 内部状态机 + 阵位数据管理（Logic，~20 测试）

**测试文件**：`tests/unit/deployment_system/test_internal_state_machine.gd`

**测试内容（AC-001~018 全量）**：
- 自动分配：炼气(max_deploy=2) 前2后0；金丹(max_deploy=4) 前2后2；化神(max_deploy=6) 全6填满
- 人数可少于上限（金丹 3 人 → 前2后1）；空数组拒绝；人数超上限拒绝
- 手动 layout 覆盖自动分配
- `is_front` 边界判定（slot 0/1/2 前排，3/4/5 后排）
- setup_field 后全部 STANDBY；`is_standby` 查询（STANDBY/READY/未上场）
- `set_acted` READY→ACTED；`get_field` 结构 + 排序（6 项按 slot_index 升序）；`get_character_slot`（未上场 -1）
- `get_front_count`（存活 vs 占用）；`get_empty_slots`（前排优先 0,1,2,3,4,5）；`can_deploy` 结果结构
- `_front_line_breached_emitted` 重置
- AC-018：`extends Node` + 不声明 `class_name`（`get_instance_base_type()=="Node"` + `get_global_name()==&""`）

**边界情况**：空位 character_id=-1 + state=EMPTY + deploy_turn=-1；`get_character_slot` O(n)（n≤6）；前排全灭时 alive_only=true 返回 0。

**禁止模式**：`max_deploy = L + 1` 通过 `RealmSystem.get_realm_property(level, &"max_deploy")` 查询——不自行维护映射；绝不战中移动前后排（阵位调整仅备战阶段）。

#### Story 4-7 — deploy / remove / is_targetable 前后排保护 O(1)（Logic，~18 测试）

**测试文件**：`tests/unit/deployment_system/test_deploy_targetable.gd`

**测试内容（AC-001~015 全量）**：
- `deploy` 自动分配前排优先空位（返回 `{success, slot_index, reason}`）；满员 `field_full`；无效槽 `invalid_slot`；不可用角色 `character_unavailable`
- deploy 成功后 STANDBY；`character_deployed` 信号载荷
- `remove_character` 清空阵位 + `character_removed` 信号
- `is_targetable`：前排始终 true；后排受保护（前排有存活 → false）；前排全灭 → true + `front_line_breached`（仅一次）；穿透 → true；未上场 → false；阵亡 → false
- 前排全灭后再补位 → 后排重新受保护（`front_line_breached` 不重复发射）
- AC-015：6 个 Cat 2b 信号经 `_emit_signal_safe` 路由

**边界情况**：`front_line_breached` 标志守卫（第二次调用不再发射）；前排空位（0,1,2）优先于后排（3,4,5）；信号链深度 ≤2。

**禁止模式**：前排保护（穿透除外）；Cat 2 信号经 `_emit_signal_safe`；绝不战中移动前后排。

#### Story 4-8 — 战斗结束 serialize_field 快照导出 GSM（Integration，~14 测试）

**测试文件**：`tests/integration/deployment_system/test_serialize_snapshot.gd`

**测试内容（AC-001~011 全量）**：
- `serialize_field()` 返回 6 阵位完整 Dictionary（character_id/is_front/state/deploy_turn）
- 输出纯序列化结构（`JSON.stringify` 无报错，无 RefCounted/Node 引用）
- 战斗结束写 `GSM._set_battle_deployment_snapshot(snapshot)` → `battle.deployment_snapshot`
- GSM 不可用不崩溃（`is_instance_valid` + `has_method` 双守卫）
- `deserialize_field(data)` 恢复阵位；空/无效 data 安全处理
- `sync_unavailable_to_gsm()` / `load_unavailable_from_gsm(data)` 不可用角色同步
- snapshot round-trip 一致性（serialize → deserialize → get_field 一致）
- GSM 写走第二层原子方法（不直接属性赋值）；不可用角色 entry 含 `{death_turn, death_battle_id, revival_methods}`

**边界情况**：空位也序列化；state 枚举序列化 int 或 String；缺字段 entry 用默认值填充。

**禁止模式**：绝不直接写 GSM 属性（第二层原子方法）；绝不实时将 `_field` 写入 GSM（仅战斗结束导出）。

#### Story 4-9 — clear_standby_state + mark_unavailable + revive_character（Logic，~16 测试）

**测试文件**：`tests/unit/deployment_system/test_standby_unavailable_revive.gd`

**测试内容（AC-001~014 全量）**：
- `clear_standby_state`：STANDBY→READY；ACTED→READY；READY/DEAD 不变；空位跳过
- `standby_cleared` 信号仅含待命角色（不含 ACTED→READY）；无 STANDBY 不发射
- `mark_unavailable(character_id, death_context)` + `character_unavailable` 信号；death_context 存储 `{death_turn, death_battle_id}`
- `get_unavailable_characters()`；`revive_character` 成功/拒绝（非不可用 → false，不发射）
- `is_game_over`（全不可用 → true；有可用 → false）
- 不可用角色拒绝上场（setup_field/deploy）
- 待命清除调用点契约（Phase 6 END 之前）

**边界情况**：跨战斗死亡持久标记；角色属性保留但空载；`revival_methods` 可为空 Array。

**禁止模式**：Cat 2 信号经 `_emit_signal_safe`；绝不直接写 GSM 属性。

---

### binding-system

#### Story 4-10 — BindingRecord RefCounted 实例模型 + 内部注册表（Logic，~10 测试）

**测试文件**：`tests/unit/binding_system/`（story 文件声明 `binding_record_model_test.gd`，命名需修正）

**测试内容（AC-001~008 全量）**：
- AC-001：BindingRecord 为 RefCounted（`is RefCounted==true` + `is Resource==false` + `is Dictionary==false`）
- AC-002：14 个字段完整（类型匹配：int/float/bool/Array[int]/BindingSlot）
- AC-003：三索引结构（`_bindings` + `_by_character` + `_card_to_character`）初始为空
- AC-004：`_register_binding`/`_unregister_binding` 原子同步三索引（任一遗漏即失败）
- AC-005：`assert(_bindings[id] is BindingRecord)` 运行时守卫
- AC-006：`get_binding_ids_by_character` 零分配（两次调用返回同一引用）
- AC-007：`get_bindings_by_character` 每次分配新数组（非热路径）
- AC-008：`get_character_by_card` O(1) 反向查询

**边界情况**：`stack_slots[0]` 为自身；`stack_count >= 1`；连续 register 3 条后 `_by_character[char_id].size()==3`；unregister 最后一条后删除 character_id 键。

**⚠ 缺口**：AC-005 的 `assert` 守卫在 release 构建下不生效——测试需确认 debug 构建（GUT 默认 debug，可测，但需显式说明）（详见 §七 缺口 #4）。

**禁止模式**：BindingRecord 非 Resource 非 Dictionary；绝不将绑定运行时实例存 GSM（仅内部 Dictionary）。

#### Story 4-11 — bind / unbind / get_bindings 查询 API（Logic，~22 测试）

**测试文件**：`tests/unit/binding_system/`（命名需修正为 `test_` 前缀）

**测试内容（AC-001~018 全量）**：
- `bind_card` 绑定空位；无空位 `slot_full`（不触发覆盖）
- `can_bind` 四种着色状态（灰遮罩/绿叠加/橙覆盖/蓝空位）
- 绑定位上限经 `RealmSystem.get_realm_property` 查询（炼气功法1法宝1；化神3+3）
- 本命判定（native_owner 前缀匹配 → ×1.5；不匹配/本命位满 → ×1.0）；本命不可逆（叠加沿用首次值）
- `stack_card` 叠加（stack_count+1、共享槽位）；达上限 `stack_limit_reached`；无绑定 `no_existing_binding`
- 叠加乘法公式：`effective = base × native × stack_multiplier^(stack_count-1)`（floor 取整）
- `overwrite_binding` 覆盖（remove_effects 先于 register）；覆盖叠加一层（stack_count-1）；覆盖至 0 删除 BindingRecord
- `remove_binding`/`remove_all_bindings`（返回序列化数据供洗回）
- 角色阵亡洗回（含所有叠层）；`suspend_bindings`/`restore_bindings`
- `get_accumulated_bonus`；不同角色独立 stack_count；`card_already_bound` 拒绝

**边界情况**：叠加公式数值表（base=4, stack_multiplier=1.5：非本命 4/6/9/13/20；本命 6/9/13/20/30）；stack_count=1 退化为 base×native；restore 时 card 已不存在 → 删除 BindingRecord 变空位（不报错）。

**禁止模式**：绝不硬编码绑定位数量（查询 RealmSystem）；`bind_card()` <0.5ms。

#### Story 4-12 — 绑定生命周期信号总线（Integration，~12 测试）

**测试文件**：`tests/integration/binding_system/`（命名需修正）

**测试内容（AC-001~010 全量）**：
- 7 个 Cat 2b 信号签名与 ADR-0013 一致（binding_applied/removed/overwritten/stacked/suspended/restored/native_activated）
- 全部经 `_emit_signal_safe` 路由（非直接 emit_signal）
- `binding_applied` 发射（本命时额外发射 native_activated）；`binding_removed`（reason 区分 death/overwritten）
- `binding_overwritten` 载荷（old/new_binding_id/character_id/slot_index）
- `binding_stacked`（new_stack_count）；`binding_suspended`/`binding_restored`
- 信号链深度 ≤2；信号携带事实而非指令（无 show_animation/play_sound 等指令性字段）

**边界情况**：达上限拒绝时不发射 `binding_stacked`；restore 验证失败时 binding_ids 不含被删除绑定；非本命不发射 native_activated。

**禁止模式**：Cat 2 信号经 `_emit_signal_safe`；信号声明在语义归属系统（禁止 SignalBus Autoload）；不超信号链深度 4。

#### Story 4-13 — serialize_all 快照导出 + persistent effect 接口（Integration，~14 测试）

**测试文件**：`tests/integration/binding_system/`（命名需修正）

**测试内容（AC-001~012 全量）**：
- `serialize_all()` 完整序列化（含 stack_slots/stack_count/is_native/native_multiplier/is_suspended）
- 导出 `GSM.battle.bindings`（战斗期间不写，仅战斗结束）
- `deserialize_all` 恢复三索引；部分恢复（失效 card_instance_id 跳过 + WARN）
- `register_persistent_effect` 绑定成功调用（context 含 native_multiplier + stack_count）
- 覆盖严格顺序（remove 先于 register）；suspend/restore 效果调用；阵亡 remove_effects_by_source（含叠层）
- `get_binding_context` 预计算乘积（native × stack^(count-1)）；覆盖积累数值保留；serialize_all 性能

**边界情况**：mock CardEffectEngine 记录调用序列；mock GSM 验证 battle.bindings 写入。

**禁止模式**：绝不将绑定运行时实例存 GSM；角色阵亡绑定卡洗回牌库（非永久丢失）。

---

### formation-system（纯光环层，可最干净存根）

#### Story 4-14 — 内部条件状态机 + 阵法位管理（Logic，~10 测试）

**测试文件**：`tests/unit/formation_system/test_internal_state_machine.gd`

**测试内容（AC-001~008 全量）**：
- `deploy_formation` 空位部署（slot_index=-1 自动分配第一个空位）
- 满 3 位 → `slots_full`；条件满足 → ACTIVE；条件不满足 → DEPLOYED_UNACTIVE
- `overwrite_formation`（旧 DISCARDED + 清除归属 + remove 先于 register）
- 未激活阵法占用阵位（计 1/3）；`set_character_affilation` 归属指定（已有归属/非 ACTIVE → false）
- 阵法失效清除归属

**边界情况**：满位含未激活阵法同样 slots_full；被覆盖旧阵法若已失效不影响任何角色；角色阵亡时保留归属记录（不影响其他归属角色）。

**禁止模式**：绝不缓存阵法激活状态——通过 `FactionSystem.check_condition()` 重判；角色归属锁定直到阵法失效。

#### Story 4-15 — 激活条件实时重判（Integration，~7 测试）

**测试文件**：`tests/integration/formation_system/test_activation_rejudge.gd`

**测试内容（AC-001~005 全量）**：
- 角色上场补足条件 → 阵法激活（订阅 `character_deployed` 信号触发重判）
- 阵眼角色阵亡 → 阵法失效（`character_removed` 触发）；阵眼复活重新上场 → 重新激活
- 阵营人数下降 → 阵法失效（归属清除）
- `recheck_all_conditions()` 不直接发射信号——返回变更列表，由调用方批量发射 `formation_condition_reevaluated`

**边界情况**：上场角色与条件无关时 changes 为空；从 3 降到 2 但门槛为 2 时不应失效；阵位保留（占用 1/3）。

**禁止模式**：绝不缓存激活状态（通过 `FactionSystem.check_condition()` 重判）；不超信号链深度 4。

#### Story 4-16 — get_aura_bonus O(1) 查询 + 梯度光环计算（Logic，~9 测试）

**测试文件**：`tests/unit/formation_system/test_aura_bonus_query.gd`

**测试内容（AC-001~007 全量）**：
- 归属角色获得光环加成（固定增益 HP+2/DEF+1）；未归属 → 0
- 梯度阵法效果等级 = `min(count_on_field(tag) - 1, max_level)`（2人→1级、4人→3级）
- 梯度封顶（max_level=4，6人 → 4 级不溢出）；梯度降级不失效（4→2 人，等级 3→1）
- 梯度从不足恢复（1→2 人，从 1 级开始，不保留记忆）；多阵营平局取先入场阵营

**边界情况**：`count_on_field < 2` 返回 0（门槛）；`breakdown` 数组记录来源；未归属角色/非 ACTIVE 阵法返回 0。

**禁止模式**：绝不缓存阵营计数（始终从当前场上状态统计——`FactionSystem.count_on_field`）；梯度实时计算。

#### Story 4-17 — serialize_all 快照导出 GSM（Integration，~7 测试）

**测试文件**：`tests/integration/formation_system/test_serialize_snapshot.gd`

**测试内容（AC-001~005 全量）**：
- `serialize_all()` 返回 `{slots, affiliations, next_formation_id}` 完整快照
- 导出 `GSM.battle.formation_snapshot`（第二层原子方法）；serialize/deserialize 往返完整性
- deserialize 归属悬空跳过（失效 character_id 跳过 + WARN，不阻塞阵法状态恢复）
- `clear_all_formations()` 清空阵位 + 归属，`_next_formation_id` 保留

**边界情况**：空阵法区 slots 为 3 个 EMPTY 阵位；template_id StringName→String 序列化。

**禁止模式**：绝不直接写 GSM 属性；绝不在 `_process()` 热路径写 GSM。

---

### ai-system

#### Story 4-18 — EnemyTemplate Resource + EnemyFactory + EnemyBattleState（Logic，~12 测试）

**测试文件**：`tests/unit/ai_system/test_enemy_template_factory.gd`

**测试内容（AC-001~010 全量）**：
- `EnemyTemplate extends Resource` 字段完整；内嵌 BehaviorProfile/SkillEntry/BossPhaseTransition 字段
- `EnemyBattleState extends RefCounted` 运行时字段完整
- EnemyFactory 从模板创建实例（max_hp/attack/defense/is_alive/current_phase_index=0）
- 模板只读（实例修改不影响模板）；`load_templates()` 扫描注册表
- `create_enemy_roster` 创建阵容；阵位自动分配（防御高→前排、攻击高→后排、front_slot 强制前排）
- ≤2 人全部前排；formation_limit 默认值（普通0/精英1/Boss2）

**边界情况**：`retreat_threshold=0` 表示不撤退；`skill_cooldowns` 为 Dictionary；`triggered_transitions` 为 Array[int]；重复 template_id 警告；未知 template_id 报错/跳过。

**禁止模式**：绝不运行时写 EnemyTemplate 字段（共享引用语义）；绝不在模板上用 `duplicate()`。

#### Story 4-19 — execute_turn 决策主循环（Logic，~17 测试）

**测试文件**：`tests/unit/ai_system/test_execute_turn_decision.gd`

**测试内容（AC-001~014 全量）**：
- `execute_turn` 返回 `Array[AIAction]`（每存活敌人至少一个行动）
- 三级分支（普通/精英/Boss 分派，is_boss 优先）
- 技能分数 `base_weight × modifier` 降序；修正系数（治疗+0.5/防御+0.3/攻击+0.4/阵法+20）
- 治疗技能权重高于攻击（残血时）；集火模式（HP% 最低）；分散模式（残血权重×2）
- 嘲讽强制目标；全技能冷却 → 普通攻击；费用不足回退；前排阵亡后排补位
- 撤退判定（50% 概率）；不写 GSM；走 CardEffectEngine 统一路径（不 resolve）

**边界情况**：确定性种子下可重复验证权重分布；法术 debuff 不受嘲讽限制；Boss 绝不撤退；普通攻击无冷却限制。

**⚠ 缺口**：撤退判定 AC-012 用 50% 概率 + 分散模式 AC-007 用加权随机——两者均需固定 `RandomNumberGenerator` 种子保证确定性（参照 event_system `seed(42)` 先例）。story 文件已声明种子来自 `GSM.meta.seed`。

**禁止模式**：绝不 AI 直接写 GSM（返回行动指令）；绝不全局 `randf()`（独立 RNG）；`execute_turn()` <5ms。

#### Story 4-20 — BossPhaseMgr 阶段转换内部状态机（Logic，~15 测试）

**测试文件**：`tests/unit/ai_system/test_boss_phase_manager.gd`

**测试内容（AC-001~013 全量）**：
- BossPhaseMgr `check()`/`transition()`/`get_phase()`
- HP 阈值触发 + 行为替换；技能解锁/锁定；冷却重置；转换回血（`round(max_hp × heal_percent)`）
- `boss_phase_transitioned` 信号（经 `_emit_signal_safe`）
- 击杀优先（is_alive 才检查）；防重复触发（triggered_transitions）；最多 3 阶段
- `should_transition` 公式（OR + 哨兵：`(hp_below > 0 AND hp_pct <= hp_below) OR (turn_after > 0 AND turn >= turn_after)`）；转换回合不行动；最终阶段保持

**✅ 已裁决**：AC-010/AC-011 语义冲突已由 game-designer 裁决（2026-08-16）——`should_transition()` 采用 **OR 语义 + 显式禁用哨兵（0 = 禁用）**。原 GDD §公式 4 的 `and` 为笔误（AND 下「即使血量未到阈值」数学上不可能），已修正 GDD。§边缘情况「最高难度回合兜底」降为**配置层分级**：极高难度 Boss 配置 `turn_after>0`，通用 Boss 配置 `turn_after=0`（禁用）。测试用例按 OR 语义编写（详见 §七 缺口 #5，已解决）。

**禁止模式**：绝不绕过内部状态机让 CombatSystem 掌握 Boss 转换细节；`boss_phase_transitioned` 经 `_emit_signal_safe`。

#### Story 4-21 — 难度缩放 + register_preconfigured_bindings（Logic，~13 测试）

**测试文件**：`tests/unit/ai_system/test_difficulty_scaling_bindings.gd`

**测试内容（AC-001~011 全量）**：
- 缩放公式 `scale = 1.0 + (player_realm - enemy_realm) × 0.3`（player_realm > enemy_realm 才应用）
- 缩放应用（base_hp=100 → round(×1.6)=160）；不缩放（player_realm ≤ enemy_realm 返回基础值）
- 境界来源经 `RealmSystem.get_realm_property`；缩放时机在 create_enemy_roster
- `register_preconfigured_bindings` 遍历调用 `BindingManager.register_binding(is_enemy=true)`
- 普通敌人无绑定；精英/Boss 预配置绑定注册；绑定不消耗费用/不占出牌；阵亡移除绑定

**边界情况**：gap=2 → ×1.6；gap=3 → ×1.9；round 四舍五入；空数组遍历零次。

**禁止模式**：绝不硬编码境界数值（查询 RealmSystem）；绝不绕过 `BindingManager.register_binding()`。

---

### combat-system（编排器，依赖全部，最后实现）

#### Story 4-22 — 7 阶段回合状态机（Logic，~15 测试）

**测试文件**：`tests/unit/combat_system/test_seven_phase_state_machine.gd`

**测试内容（AC-001~013 全量）**：
- `CombatPhase` 枚举 7 阶段取值（PREPARATION=0 ... END=6），END→PREPARATION 回绕
- `advance_phase` 确定性序列（validate → exit → enter → GSM._set_battle_phase → phase_changed）
- 验证失败返回 false + push_warning 不推进；非活跃战斗返回 false + push_error
- 无条件自动推进（0→1、1→2、4→5、5→6、6→0）
- PLAY→ATTACK_DECLARATION 条件（confirmed_end / timer_exceeded / hand_empty&&!can_afford_any）
- ATTACK_DECLARATION→RESOLUTION 条件（all_targeted / skip / queue empty）
- 自动阶段 call_deferred；手动阶段等输入；完整 1 回合流程；Phase 2 超时；Phase 3 空攻击队列空真
- 抽空牌库返还（弃牌堆随机返还 1 张）

**边界情况**：Phase 6→0 时 `_increment_battle_turn()`；验证失败时不发射 `phase_changed`；牌库+弃牌堆均空不返还不报错。

**⚠ 缺口**：AC-008 的 `call_deferred()` 自动推进在 GUT 无头环境需 `await` 或模拟帧推进——测试需特殊处理帧调度（详见 §七 缺口 #6）。

**禁止模式**：绝不跳过 `advance_phase` 验证（玩家交互阶段先确认）；手动阶段（2,3）需玩家输入或超时，自动阶段（0,1,4,5,6）用 `call_deferred()`。

#### Story 4-23 — 战斗生命周期编排（Integration，~19 测试）

**测试文件**：`tests/integration/combat_system/test_battle_lifecycle_gsm.gd`

**测试内容（AC-001~017 全量）**：
- `battle_start` 初始化 battle.* 域（phase=PREPARATION/turn=1/is_active=true）
- `GSM._set_battle_active(true)` 创建 battle 域；`battle_started` 信号；战斗快照创建；输入锁推入；advance_phase 调用
- 3 个 GSM 第二层方法（`_set_battle_phase`/`_increment_battle_turn`/`_set_battle_active`）
- `battle_end(VICTORY)` 调用 `apply_battle_rewards`；`battle_end(DEFEAT/RETREAT)` 保留 50% 资源
- 入口防御清理（`_attack_queue.clear` + `clear_locks` + `_is_active=false`）
- `GSM._set_battle_active(false)` 清理 battle 域；`battle_ended` 信号（清理前发射）；VICTORY 清快照
- 场景切换经 `SceneManager.request_scene_change`；`retreat()` 无活跃返回 / 有活跃发射确认

**边界情况**：重复 battle_start 拒绝或重置；快照创建失败不阻塞启动；DEFEAT/RETREAT 不清快照（保留失败分析）；从任意阶段调用 battle_end 均防御清理。

**禁止模式**：绝不直接写 GSM（第二层原子方法）；绝不 Phase 6 清理前调用 battle_end；场景转换经 SceneManager；Cat 2 信号经 `_emit_signal_safe`。

#### Story 4-24 — play_card 出牌 + 目标解析 + 自动推进调度（Logic，~14 测试）

**测试文件**：`tests/unit/combat_system/test_play_card_target_resolution.gd`

**测试内容（AC-001~012 全量）**：
- 非 PLAY 阶段拒绝；费用验证（can_afford 不过 → false 不扣费）；目标验证（validate_targets 不过 → false）
- 扣费（spend）；效果结算（resolve）；阵亡检查（_check_and_process_deaths）；空手牌自动推进
- 伤害公式 `max(1, ATK - DEF)`；境界压制 `floor(actual_damage × realm_penalty)`
- 高 1 级 → 0.8；高 2 级及以上 → 0.5；同境界 → 1.0

**边界情况**：伤害最低保底 1（ATK-DEF<1 → 1）；0 防御 → 伤害=ATK；GDD 公式示例（4×0.5=2）。

**禁止模式**：费用检查经 `CostSystem.can_afford`（绝不绕过）；CardEffectEngine 不直接写 GSM；HP/费用变化经 GSM Cat 1 `batch_updated`。

#### Story 4-25 — 阶段转换 Cat 2b 信号通知 CombatUI（Integration，~12 测试）

**测试文件**：`tests/integration/combat_system/test_phase_transition_signals.gd`

**测试内容（AC-001~010 全量）**：
- 5 个 Cat 2b 信号声明在 CombatSystem（phase_changed/battle_started/battle_ended/attack_resolved/character_died）
- `phase_changed(old_phase, new_phase, turn)` 经 `_emit_signal_safe`
- `battle_started(config)` / `battle_ended(result, rewards)`（清理 battle 域前发射）
- `attack_resolved`（4 参数用具名字典 `{attacker_id, target_id, damage, is_kill}`）
- `character_died(character_id, side, binding_card_ids)`（binding_card_ids 正确）
- 信号链深度 ≤4（character_died → 解绑 → batch_updated → HUD = 3 层）
- 信号处理器捕获异常；HP/费用变更不通过自有信号（经 Cat 1 batch_updated）

**边界情况**：验证失败时不发射 phase_changed；`attack_resolved` 具名字典格式；信号声明在 CombatSystem 非 SignalBus。

**禁止模式**：Cat 2 信号经 `_emit_signal_safe`；信号 snake_case 过去式；≤3 参数优先（>3 具名字典）；不超深度 4；不发携带指令的信号。

---

## 三、手动 QA 检查清单

**本冲刺 25 个 story 全部为 Logic 或 Integration 类型，无 UI / Visual / Config 类 story。**

按故事类型 → 测试证据要求：
- Logic/Integration 类 → 自动化单元/集成测试（BLOCKING 阻塞级）
- 无 UI/Visual/Config 类 story → 无需截图签批、手动走查文档、交互测试

因此本冲刺**无手动 QA 检查清单条目**（手动验证仅冒烟级，见 §四）。所有 Logic/Integration story 的证据由自动化测试承担，标记为「完成」的前提是测试文件存在且通过（阻塞级关卡）。

---

## 四、冒烟测试范围

在任何 QA 交接前，必须先运行 `/smoke-check sprint` 验证以下关键路径：

1. **项目启动无崩溃** —— Autoload 全链（25 个）初始化无报错
2. **4-0 Autoload 注册验证（本次硬前置）**：
   - RealmSystem(#11) 已注册进 `project.godot`
   - SchoolSystem(#19) 已注册进 `project.godot`
   - 6 个 Feature Autoload 已注册：CombatSystem(#9)、CardEffectEngine(#10)、BindingManager(#13)、DeploymentSystem(#17)、AISystem(#18)、FormationSystem(#23)
3. **Autoload 初始化顺序正确（关键矛盾点）**：
   - ⚠ 控制清单 Autoload 全链将 CombatSystem 列为 #9，但它的 `_ready()` 依赖 9 个子系统（CardEffectEngine #10 / RealmSystem #11 / BindingManager #13 / DeploymentSystem #17 / AISystem #18 / FormationSystem #23 均在 #9 之后）
   - sprint-4.md 风险登记第 3 条已声明「CombatSystem 最后注册」——4-0b 需终验：要么调整 `project.godot` 顺序让 CombatSystem 移到最后，要么用 `_ready()` 检查 `_initialized` 标志 + 延迟初始化（ADR-0008 已定模式）
   - **冒烟必须确认**：CombatSystem 在 9 子系统之后完成初始化，或 `_ready()` 延迟初始化机制生效，无「依赖子系统未就绪即调用」崩溃
4. **CombatSystem 能初始化** —— `battle_start()` → `advance_phase()` 无崩溃，Phase 4 伤害计算能调用 `RealmSystem.get_suppression()`（RealmSystem 已注册）
5. **游戏启动到主菜单无崩溃** —— 主菜单 → 战斗场景启动路径畅通
6. **战斗闭环可运行** —— 7 阶段状态机 + 卡牌效果结算 + 阵位 + 绑定 + 阵法 + AI 编排贯通，能完成至少一个完整回合（含敌方行动 Phase 5）
7. **存档/读档周期** —— 含新增 `battle.deployment_snapshot` / `battle.bindings` / `battle.formation_snapshot` 快照域，无数据丢失
8. **性能在目标硬件符合预算** —— 60fps、帧预算 16.6ms、`resolve_card()`<2ms、AI `execute_turn()`<5ms

---

## 五、试玩要求

| Story | 试玩目标 | 最少会期数 | 目标玩家类型 |
|-------|----------|:----------:|-------------|
| 无 | Feature 层战斗子系统为**系统层**（无 Presentation UI），玩家可见 UI 在 CombatUI 战斗 UI Epic（后续冲刺）接入后进行 | — | — |

**签收要求**：**本次冲刺无需试玩会期。** 战斗子系统通过自动化单元/集成测试 + 冒烟检查验证。战斗「手感」（输入响应性、动画节奏、UI 呈现）在 CombatUI Epic 接入后再安排试玩。

---

## 六、完成定义 — 本次 Sprint

- [ ] 所有 25 story + 1 task（4-0）验收标准已验证 —— 通过自动化测试结果或记录的手动证据
- [ ] 所有 Logic/Integration 类 story 的测试文件存在于指定路径（`tests/unit/[system]/` 或 `tests/integration/[system]/`），且 **GUT 能发现并运行**（阻塞级关卡）
- [ ] **9 个测试文件名修正完成**（card-effect-engine 5 + binding 4，`_test.gd` 后缀 → `test_` 前缀，详见 §七 缺口 #1 —— **已完成**，实现时按修正后路径创建测试文件）
- [ ] 冒烟检查通过（`/smoke-check sprint`）
- [ ] 4-0 Autoload 注册 + 初始化顺序验证通过（RealmSystem #11 / SchoolSystem #19 / 6 Feature Autoload，CombatSystem 依赖 9 子系统初始化正确）
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 未引入回归问题（全量测试零新增失败）
- [ ] 代码已审查并合并（`/code-review`）
- [ ] Story 文件已更新为 `Status: Complete`（`/story-done`，含 /story-done 门禁强化：全量零回归 + orphan + parse error 检查——Sprint 3 回顾行动项 #1/#2）
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 任何偏差已更新设计文档

---

## 七、标记的缺口（GDD 公式缺失 / AC 不可测试 / 命名冲突）

### 缺口 #1（已解决）：9 个测试文件命名与项目 GUT 配置冲突

**问题**：项目 GUT 配置为 `test_` 前缀（Sprint 3 active.md 明确记录「`tests/unit/gsm/` 下 4 个 `*_test.gd` 后缀文件不以 `test_` 开头，GUT 未发现——孤儿测试」）。但 lead-programmer 预创建的 story 文件 Test Evidence 路径中，有 9 个用了 `_test.gd` 后缀（非 `test_` 前缀）。

**解决**：已在 9 个 story 文件的 `## Test Evidence` 章节将路径修正为 `test_` 前缀（目录名 `card_effect_engine` / `binding_system` 保持不变，仅文件名从 `*_test.gd` 后缀改为 `test_*` 前缀）：

| Story | 修正后的路径 |
|-------|-------------|
| 4-1 | `tests/unit/card_effect_engine/test_template_instance_model.gd` |
| 4-2 | `tests/unit/card_effect_engine/test_resolution_stack.gd` |
| 4-3 | `tests/unit/card_effect_engine/test_trigger_chain_10_layer_cycle.gd` |
| 4-4 | `tests/unit/card_effect_engine/test_prd_distribution.gd` |
| 4-5 | `tests/unit/card_effect_engine/test_ai_dry_run_snapshot.gd` |
| 4-10 | `tests/unit/binding_system/test_binding_record_model.gd` |
| 4-11 | `tests/unit/binding_system/test_bind_unbind_query_api.gd` |
| 4-12 | `tests/integration/binding_system/test_binding_signal_bus.gd` |
| 4-13 | `tests/integration/binding_system/test_serialize_snapshot_effect_integration.gd` |

**实现时注意**：开发者在 `/dev-story` 创建测试文件时必须使用 `test_` 前缀命名（上述路径），杜绝孤儿测试再次出现。

### 缺口 #2：PRD 累加常数 C 未校准（card-effect-engine Story 4-4）

GDD §调优参数 + 待解决问题 #4：「PRD 累加常数 C 待游戏测试校准，安全范围 0.3-1.0」。`P_current += P_base × C` 的 C 值影响收敛速度，Story 4-4 AC-002 的「100 次触发 24-36 次」区间是 C 未定时的近似值。**C 值确定后需重新校准该区间断言**，否则测试脆弱。

### 缺口 #3：性能断言在 CI/无头环境不稳定（card-effect-engine 4-5 / ai 4-19 / binding 4-13）

多个 AC 是性能预算（`evaluate_effect`<100μs、`simulate_chain`<500μs、288 次<30ms、`execute_turn`<5ms、`get_accumulated_bonus`×1000<10ms）。GUT 无头/CI 环境机器差异会导致波动。建议性能断言设宽松阈值（如 ×3 容差）或标记为非 CI 强断言（手动/专用硬件验证）。

### 缺口 #4：assert 守卫仅 debug 构建生效（binding Story 4-10 AC-005）

`assert(_bindings[id] is BindingRecord)` 在 release 构建下不生效。测试需显式确认 GUT 在 debug 构建下运行（GUT 默认 debug，可测），且该守卫仅作为运行时防护、非 release 防护。

### 缺口 #5（已解决，game-designer 裁决 2026-08-16）：AI Boss 阶段转换 AC-011 语义冲突（ai Story 4-20）

story 文件原第 184-186 行标注：GDD §公式 4（`hp_pct <= hp_below AND turn >= turn_after`，AND 语义）与 GDD §边缘情况「回合数到达时自动进入下一阶段，即使血量未到阈值」（OR 语义）冲突。game-designer 裁决：**采用 OR 语义 + 显式禁用哨兵（0 = 禁用）**，修正后的签名与伪代码：

```
should_transition(boss, turn, hp_pct) → int:
  for each phase in boss.phase_transitions:
    hp_triggered   = phase.hp_below > 0.0 and hp_pct <= phase.hp_below
    turn_triggered = phase.turn_after > 0 and turn >= phase.turn_after
    if (hp_triggered or turn_triggered) and not phase.triggered:
      return phase.index
  return -1
```

裁决依据：§公式 4 的 `and` 为笔误——AND 语义下「即使血量未到阈值」在数学上不可能发生；§边缘情况的「最高难度回合兜底」降为**配置层分级**（极高难度 Boss 配置 `turn_after>0`，通用 Boss 配置 `turn_after=0` 禁用），符合「游戏数值数据驱动，绝不硬编码」技术偏好。已同步：GDD §公式 4/§边缘情况/§字段定义/§验收标准 + story 文件 AC-010/AC-011 + 本 QA 计划 §二 Story 4-20。

### 缺口 #6：call_deferred 帧调度测试技术难点（combat Story 4-22 AC-008）

自动阶段用 `call_deferred()` 下一帧推进。GUT 无头环境需 `await` 或显式帧推进来验证「每阶段至少 1 帧渲染间隔」。需在测试中特殊处理帧调度（可能需 GUT 的 `await` 支持或手动 `_process` 驱动）。

### 缺口 #7（非阻塞，文档质量）：GDD formation-system §公式编号错乱

formation-system.md §公式 章节编号为 1 → 4 → 2 → 3（顺序错乱）。公式内容完整（§1 激活判定、§2 覆盖选择、§3 归属限制、§4 梯度阵法），不影响测试推导，但需在设计文档维护时修正编号。

---

## 附注：4-0 Autoload 注册 task

4-0 是 **task 而非 story**，不纳入测试分类（不计入 25 story 的 Logic/Integration 统计），但**必须体现在冒烟测试范围**（见 §四 第 2、3 条）。4-0 的验收标准为：RealmSystem(#11) + SchoolSystem(#19) + 6 Feature Autoload 注册进 `project.godot`，且初始化顺序验证通过（CombatSystem 依赖 9 子系统的顺序矛盾在 4-0b 终验）。4-0 无独立测试文件，其正确性由冒烟检查 + combat 集成测试（`battle_lifecycle_gsm` / `phase_transition_signals` 等依赖真实 Autoload 的测试）间接验证。
