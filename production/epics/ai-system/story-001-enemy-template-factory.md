# Story 001: EnemyTemplate Resource + EnemyFactory + EnemyBattleState

> **Epic**: AI 系统（敌方 AI） (ai-system)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/ai-system.md`
**Requirement**: `TR-ai-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0017（AI 系统 — Feature 层独立 Autoload + 效果引擎统一路径 + Boss 内部阶段状态机）
**ADR Decision Summary**: EnemyTemplate 使用 Godot Resource（`.tres`）格式——策划在 Inspector 中编辑敌人模板数据（`@export` 字段 + 内嵌 BehaviorProfile/SkillEntry/BossPhaseTransition）；运行时由 EnemyFactory 创建轻量级 EnemyBattleState（RefCounted）实例。模板/实例分离：模板只读，运行时可变状态（HP/冷却/阶段索引）全部在实例上。

**Engine**: Godot 4.6 | **Risk**: LOW（Resource 加载、`@export` 内嵌 Resource、RefCounted——均为 4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新特性。`load_templates()` 需评估同步 `ResourceLoader.load()` vs `load_threaded_request()`——若敌人模板超过 50 个需重新评估（ADR-0017 §需要验证）。

**Control Manifest Rules (Feature 层)**:
- **Required**: EnemyTemplate（Resource, `.tres`）只读 —— EnemyBattleState（RefCounted）运行时层（来源：ADR-0017）
- **Required**: 与 ADR-0006 CardTemplate/CardInstance、ADR-0009 EffectTemplate/EffectInstance 模式一致——模板/实例分离（来源：ADR-0017）
- **Forbidden**: 绝不运行时写 EnemyTemplate 字段——Resource 共享引用语义导致静默数据损坏（同 ADR-0006 模式）
- **Forbidden**: 绝不在 EnemyTemplate 上使用 `duplicate()`——模板必须保持共享且不可变（同 ADR-0006 模式）
- **Guardrail**: EnemyTemplate Resource 注册表内存 ~50-80 模板 × 5KB ≈ 250-400KB（< 1MB）；加载 < 300ms（来源：ADR-0017 §性能影响）

---

## Acceptance Criteria

*From ADR-0017 §关键接口 + GDD ai-system.md §2（敌方卡组构成）+ §3（敌方上阵与阵位分配）+ §验收标准:*

- [ ] **AC-001**: `EnemyTemplate` 类定义 `class_name EnemyTemplate extends Resource`，`@export` 字段完整——template_id/display_name/realm/is_elite/is_boss/base_hp/base_attack/base_defense/faction_tags/formation_limit/front_slot/behavior_profile/skill_pool/preconfigured_bindings/preconfigured_formations/phase_transitions/reward_config
- [ ] **AC-002**: 内嵌 Resource 类型存在且 `@export` 字段完整——`BehaviorProfile`（aggression/focus_fire/front_priority/retreat_threshold）、`SkillEntry`（skill_id/display_name/skill_type/base_weight/cost/cooldown/target_type/effect_template_ids）、`BossPhaseTransition`（trigger{hp_below, turn_after}/effects{behavior_override, skill_unlock, skill_remove, reset_cooldowns, heal_percent, animation}）
- [ ] **AC-003**: `EnemyBattleState` 类定义 `class_name EnemyBattleState extends RefCounted`，运行时字段完整——template_id/current_hp/max_hp/attack/defense/skill_cooldowns/is_alive/field_position/is_front_row/current_phase_index/triggered_transitions
- [ ] **AC-004**: EnemyFactory 从模板创建实例——max_hp=base_hp、attack=base_attack、defense=base_defense、is_alive=true、skill_cooldowns 初始化为空（或全 0）、current_phase_index=0、triggered_transitions 为空
- [ ] **AC-005**: 模板只读——实例持有所有可变状态，绝不运行时写 EnemyTemplate 字段
- [ ] **AC-006**: `load_templates()` 扫描 `res://assets/enemies/` 加载所有 `.tres` EnemyTemplate 到 `_template_registry: Dictionary[StringName, EnemyTemplate]`（key=template_id）
- [ ] **AC-007**: `create_enemy_roster(template_ids, player_realm)` 返回 `Array[EnemyBattleState]`，数量与 template_ids 一致，且通过 EnemyFactory 创建实例
- [ ] **AC-008**: 阵位自动分配——防御较高的敌人分配前排、攻击较高的敌人分配后排；`front_slot=true` 时固定前排
- [ ] **AC-009**: 敌方仅 1~2 人时全部分配前排（无后排保护）
- [ ] **AC-010**: `formation_limit` 默认值——普通敌人 0、精英敌人 1、Boss 敌人 2（由模板字段承载，创建实例时原样携带）

---

## Implementation Notes

*Derived from ADR-0017 §关键接口 + §决策:*

1. **文件位置**：
   - `res://assets/enemies/enemy_template.gd`——`class_name EnemyTemplate extends Resource`（含内嵌 BehaviorProfile/SkillEntry/BossPhaseTransition/RewardConfig 定义，可在同文件或独立 Resource 文件）
   - `src/feature/ai_system.gd`——AISystem Autoload #18，含 EnemyFactory 方法 + EnemyBattleState 运行时类
2. **EnemyBattleState 为 RefCounted 运行时实例**——不在 GSM 中存储，由 AISystem 在 `create_enemy_roster()` 时创建并持有，战斗结束后释放
3. **EnemyFactory 职责**：模板 → 实例的纯映射（复制 base_hp/attack/defense 到 max_hp/attack/defense，初始化运行时字段）。不涉及难度缩放（难度缩放属 Story 004，在 `create_enemy_roster()` 内单独一步调用）
4. **模板注册表**：`load_templates()` 在 `AISystem._ready()` 中调用，扫描目录加载。同步加载 `< 300ms` 预算内（若敌人模板 > 50 个需评估异步加载）
5. **阵位分配逻辑**（`create_enemy_roster()` 内）：防御降序 → 前排（前排容量 3）；攻击降序 → 后排；`front_slot=true` 强制前排；总数 ≤2 全前排
6. **类型化字段**：所有 `@export` 字段使用类型化类型（StringName/int/bool/Array[Resource]/Array[StringName]），禁止 `Variant`（ADR-0003 模式）
7. **测试模式**：EnemyTemplate 用脚本内 `EnemyTemplate.new()` 构造（不依赖 `.tres` 文件），EnemyFactory/阵位分配用纯逻辑单测；`load_templates()` 目录扫描用集成测试

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `execute_turn()` 决策主循环 + 三级智能分支 + 技能分数/目标选择/撤退判定——决策逻辑
- **Story 003**: BossPhaseMgr 阶段转换内部状态机——Boss 阶段触发/行为替换/技能解锁
- **Story 004**: 难度缩放 `_apply_difficulty_scaling()` + `register_preconfigured_bindings()`——绑定注册与缩放公式（Story 001 的 `create_enemy_roster()` 只创建实例 + 分配阵位，不缩放、不注册绑定）
- **CombatSystem 集成**: Phase 6 调用 `execute_turn()`、执行返回的 AIAction——战斗 Epic（ADR-0008）职责
- **CardEffectEngine**: SkillEntry 的 `effect_template_ids` 关联解析——卡牌效果 Epic（ADR-0009）职责

---

## QA Test Cases

*From ADR-0017 §验证标准 + GDD ai-system.md §边缘情况 + §验收标准:*

- **AC-001**: EnemyTemplate Resource 类结构
  - Given: 脚本 `enemy_template.gd` 已加载
  - When: `EnemyTemplate.new()`
  - Then: 实例类型为 Resource，全部 `@export` 字段可通过属性访问（template_id/realm/is_boss/formation_limit 等）
  - Edge cases: 字段缺失时脚本解析失败——需全字段覆盖检查

- **AC-002**: 内嵌 Resource 类型
  - Given: `enemy_template.gd` 已加载
  - When: 构造 `BehaviorProfile.new()` / `SkillEntry.new()` / `BossPhaseTransition.new()`
  - Then: 各内嵌 Resource 字段完整且类型正确（aggression: float、base_weight: int、hp_below: float 等）
  - Edge cases: `retreat_threshold=0` 表示不撤退（默认值语义）

- **AC-003**: EnemyBattleState 运行时类结构
  - Given: `EnemyBattleState.new()`
  - When: 检查字段
  - Then: 含 template_id/current_hp/max_hp/attack/defense/skill_cooldowns/is_alive/field_position/is_front_row/current_phase_index/triggered_transitions
  - Edge cases: `skill_cooldowns` 为 `Dictionary`（{skill_id: int}），`triggered_transitions` 为 `Array[int]`

- **AC-004**: EnemyFactory 创建实例
  - Given: 模板 base_hp=100、base_attack=20、base_defense=10
  - When: `EnemyFactory.create_state(template)`
  - Then: 实例 max_hp==100 + attack==20 + defense==10 + is_alive==true + current_phase_index==0 + triggered_transitions 为空
  - Edge cases: skill_cooldowns 初始为 `{}` 或全部技能冷却 0

- **AC-005**: 模板/实例分离（只读模板）
  - Given: 模板实例 A + 由 A 创建的战斗状态 B
  - When: 修改 B.current_hp、B.skill_cooldowns
  - Then: A 的 base_hp/skill_pool 不受影响（模板字段无变化）
  - Edge cases: 两个实例共享同一模板，互不污染

- **AC-006**: load_templates 加载注册表
  - Given: `res://assets/enemies/` 目录含若干 `.tres` EnemyTemplate
  - When: `ai.load_templates()`
  - Then: `_template_registry` 含每个 template_id 到 EnemyTemplate 的映射
  - Edge cases: 空目录不崩溃；重复 template_id 记录警告

- **AC-007**: create_enemy_roster 创建阵容
  - Given: 3 个 template_ids
  - When: `ai.create_enemy_roster([t1, t2, t3], player_realm)`
  - Then: 返回 3 个 EnemyBattleState，各自 template_id 正确
  - Edge cases: 未知 template_id → 报错或跳过（push_error）

- **AC-008**: 阵位自动分配（防御高→前排）
  - Given: 3 敌人（防御 15/10/5，攻击 8/12/20）
  - When: `create_enemy_roster()` 分配阵位
  - Then: 防御 15 在前排；攻击 20 在后排；`is_front_row` 标记正确
  - Edge cases: `front_slot=true` 的敌人强制前排（即使攻击高）

- **AC-009**: ≤2 人全部前排
  - Given: 2 个敌人（防御 10/5）
  - When: `create_enemy_roster()` 分配阵位
  - Then: 两个都 is_front_row==true，无后排
  - Edge cases: 1 人也全前排

- **AC-010**: formation_limit 默认值
  - Given: 普通模板（is_elite=false, is_boss=false）、精英模板、Boss 模板
  - When: 检查 `formation_limit`
  - Then: 普通==0、精英==1、Boss==2
  - Edge cases: formation_limit 由模板数据承载，实例原样携带

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai_system/test_enemy_template_factory.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 无（需 CardEffectEngine 已实现——SkillEntry.effect_template_ids 的类型引用由 ADR-0009 定义，但本 Story 不调用其结算路径）
- Unlocks: Story 002（execute_turn 决策主循环——依赖 EnemyBattleState 模型 + create_enemy_roster）；Story 003（BossPhaseMgr——依赖 EnemyBattleState.current_phase_index/triggered_transitions）；Story 004（难度缩放 + 绑定注册——依赖 create_enemy_roster + EnemyBattleState）
