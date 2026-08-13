# Story 001: SchoolSystem Autoload #19 + SCHOOL_LIBRARY const + 纯查询接口

> **Epic**: school-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/school-system.md`
**Requirement**: `TR-school-001`（待 `/architecture-review` 注册——5 流派定义库 + 优先级检测 + 匹配度计算）

**ADR Governing Implementation**: ADR-0025（流派系统——Core 层轻量 Autoload + 静态流派库 + 纯计算检测引擎）
**ADR Decision Summary**: SchoolSystem 作为 Core 层 Autoload #19，持有 `const SCHOOL_LIBRARY`（5 流派编译时常量定义）+ 纯计算检测引擎（`detect()`/`calculate_match()`）+ 纯查询接口（`get_school_info`/`get_school_effects`/`get_all_schools`）+ Cat 2b 信号 `school_changed`。与 RealmSystem/FactionSystem 模式一致——无副作用、无可变运行时状态（仅 const 库 + 纯计算）。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 查询、Array 遍历、条件判定——4.x 成熟 API。最坏遍历 5 流派 × 4 条件 = 20 次检查）
**Engine Notes**: 不依赖 4.4+ 新特性。const 嵌套 Dictionary 在 GDScript 中编译时分配——零运行时加载开销。

**Control Manifest Rules (Core 层)**:
- **Required**: SchoolSystem 是 Autoload —— 绝不声明 `class_name`（同 RealmSystem/FactionSystem/CardSystem/CostSystem/StatusEffectSystem 模式）
- **Required**: `const SCHOOL_LIBRARY` 编译时常量——5 流派的完整定义（检测条件 + 增益效果 + 元数据）
- **Required**: `detect()`/`calculate_match()` 为纯计算——无副作用、不写入 GSM、不发射信号（除 `school_changed` 由调用方在状态变更时触发）
- **Forbidden**: 不持有可变运行时状态——流派激活状态存 GSM `battle.active_school`，SchoolSystem 仅查询
- **Forbidden**: 阵营判定不在此系统实现——委托 `FactionSystem.count_on_field()` / `belongs_to_alignment()`

---

## Acceptance Criteria

*From ADR-0025 §关键接口 §验证标准 + GDD school-system.md §验收标准:*

- [x] **AC-001**: SchoolSystem extends Node，不声明 `class_name`
- [x] **AC-002**: `const SCHOOL_LIBRARY: Dictionary` 含 5 流派 entry——`righteous_dev`/`demonic_aggro`/`mixed_alignment`/`spirit_realm_beast`/`alchemy_mastery`
- [x] **AC-003**: 每个流派 entry 含字段——`id`/`name`/`tagline`/`description`/`priority`/`detection`/`effects`/`weakness`/`visual_theme`
- [x] **AC-004**: 优先级数值——归墟真灵流=1、正道发育流=2、魔道快攻流=3、正邪混合流=4、百艺炼丹流=5
- [x] **AC-005**: `detect(state: Dictionary) -> StringName`——按 priority 升序遍历，返回首个全部条件满足的流派 ID（或 `&""`）
- [x] **AC-006**: `calculate_match(school_id, state) -> Dictionary`——返回 `{score: float, missing: Array[String]}`
- [x] **AC-007**: `get_school_info(school_id) -> Dictionary`——返回流派元数据（name/tagline/description/effects/weakness/visual_theme）
- [x] **AC-008**: `get_school_effects(school_id) -> Array[Dictionary]`——返回增益效果列表
- [x] **AC-009**: `get_all_schools() -> Array[StringName]`——返回 5 流派 ID 列表
- [x] **AC-010**: `signal school_changed(old_school_id, new_school_id)` Cat 2b 信号声明
- [x] **AC-011**: `detect()` 优先级——同时满足正道+正邪混合 → 返回正道（priority 2 < 4）
- [x] **AC-012**: `detect()` 优先级——同时满足归墟+正道 → 返回归墟（priority 1 最高）
- [x] **AC-013**: `detect()` 无流派满足 → 返回 `&""`（空 StringName）
- [x] **AC-014**: `calculate_match` 权重——阵营人数 40、必备角色 30、卡牌类型占比 20、境界 10
- [x] **AC-015**: `calculate_match` score 范围 [0, 100]——round 加权平均
- [x] **AC-016**: `calculate_match` missing 列表——未满足条件含人类可读描述（如"需 3 个正道角色（当前 2/3）"）
- [x] **AC-017**: `get_school_info`/`get_school_effects` 未知 school_id 返回空（`{}`/`[]`），不报错
- [x] **AC-018**: `const SCHOOL_LIBRARY` 运行时不可变性——GUT 冒烟测试验证流派模板内容未被运行时修改

---

## Implementation Notes

*Derived from ADR-0025 §采用方案 A §关键接口 §检测触发时机:*

1. **文件位置**: `src/core/school_system/school_system.gd`（Core 层，Autoload #19——在 AISystem #18 之后）
2. **SCHOOL_LIBRARY 结构**: `Dictionary[StringName, Dictionary]`，每个内层 Dictionary 含 id/name/tagline/description/priority/detection/effects/weakness/visual_theme 9 字段
3. **detection 子结构**: `{min_faction: {tag, count}, min_faction_ratio: {tag, pct}, required_characters: [String], card_type_ratio: {type, min_pct}, min_realm: int, min_alchemy_count: int, excluded_cards: [String]}`——按 GDD §2 各流派实际条件填充
4. **effects 子结构**: `Array[Dictionary]`，每个 `{type, target, value, trigger}`——type ∈ {regen, damage_reduce, attack_boost, draw_on_kill, cost_discount, pill_boost, aura_hp, immune_debuff}
5. **detect 实现**: 构建 candidates 列表 → `sort_custom` 按 priority 升序 → 逐一 `_check_all_conditions` → 返回首个满足的 ID
6. **_check_all_conditions 实现**: 检测各条件类型——阵营人数委托 `FactionSystem.count_on_field(tag)`、境界读 `GSM.player.realm_level`、炼丹次数读 `GSM.player.alchemy_count`（GSM 不可用时优雅降级返回 false）
7. **calculate_match 实现**: 遍历 detection 条件 → 按 GDD §公式#1 权重打分 → 加权平均 → round 至 [0, 100]
8. **school_changed 信号**: 声明在 SchoolSystem——由调用方（CombatSystem/DeckEdit）在状态变更时发射；`detect()` 本身不发射（纯计算无副作用）
9. **测试模式**: `SS_SCRIPT.new()` 构造实例，`var ss: Node` 持有 + 动态分派，state Dictionary 作为入参注入

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 5 流派增益公式数值 + 不可驱散约束 + 流派切换清空
- **CombatSystem 集成**: 战前调用 `detect()` + `get_school_effects()` 注册增益 ——战斗 Epic（ADR-0008）职责
- **DeckEdit UI 集成**: 卡组变更后 `calculate_match()` 更新匹配度展示 ——卡组编辑 Epic 职责
- **Battle HUD 集成**: 监听 `school_changed` 显示流派激活提示 ——战斗 UI Epic 职责
- **炼丹次数计数器维护**: `GSM.player.alchemy_count` 由炼丹系统维护 ——炼丹 Epic（ADR-0028）职责

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-7 + ADR-0025 §验证标准:*

- **AC-001**: extends Node + 不声明 class_name
  - Given: SchoolSystem 脚本已加载
  - When: `SS_SCRIPT.get_instance_base_type()` / `get_global_name()`
  - Then: base type == "Node" + global_name == &""
  - Edge cases: 动态分派 `var ss: Node = SS_SCRIPT.new()`

- **AC-002**: SCHOOL_LIBRARY 5 流派 entry
  - Given: SchoolSystem 脚本已加载
  - When: 检查 `SS_SCRIPT.SCHOOL_LIBRARY`（或实例 `ss.SCHOOL_LIBRARY`）keys
  - Then: 含 5 个 StringName key——righteous_dev/demonic_aggro/mixed_alignment/spirit_realm_beast/alchemy_mastery
  - Edge cases: const 在所有实例间共享

- **AC-003**: 流派 entry 字段完整
  - Given: SCHOOL_LIBRARY 已加载
  - When: 检查 `righteous_dev` entry
  - Then: 含 id/name/tagline/description/priority/detection/effects/weakness/visual_theme 9 字段
  - Edge cases: 5 流派均含全部 9 字段

- **AC-004**: 优先级数值
  - Given: SCHOOL_LIBRARY 已加载
  - When: 检查各流派 priority
  - Then: spirit_realm_beast=1、righteous_dev=2、demonic_aggro=3、mixed_alignment=4、alchemy_mastery=5
  - Edge cases: priority 1 最高、5 最低

- **AC-005**: detect 返回流派 ID
  - Given: state 含正道≥3 角色 + 正道占比≥60% + 无魔道限定卡
  - When: `ss.detect(state)`
  - Then: 返回 `&"righteous_dev"`
  - Edge cases: 空字段角色返回 `&""`

- **AC-006**: calculate_match 返回结构
  - Given: state 含部分满足正道条件
  - When: `ss.calculate_match(&"righteous_dev", state)`
  - Then: 返回 Dictionary 含 score(float) 和 missing(Array[String])
  - Edge cases: score ∈ [0, 100]

- **AC-007**: get_school_info 返回元数据
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_info(&"righteous_dev")`
  - Then: 返回含 name="正道发育流"、tagline、description、effects、weakness、visual_theme 的 Dictionary
  - Edge cases: 未知 school_id 返回 `{}`

- **AC-008**: get_school_effects 返回增益列表
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_effects(&"righteous_dev")`
  - Then: 返回含 {type="regen", target="zhengdao", value=2, trigger="turn_end"} 等增益的 Array[Dictionary]
  - Edge cases: 未知 school_id 返回 `[]`

- **AC-009**: get_all_schools 返回 5 流派 ID
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_all_schools()`
  - Then: 返回 Array[StringName] 含 5 个 ID
  - Edge cases: 顺序可与 SCHOOL_LIBRARY.keys() 一致

- **AC-010**: school_changed 信号声明
  - Given: SchoolSystem 脚本已加载
  - When: `SS_SCRIPT.get_script_signal_list()`
  - Then: 含 `school_changed` 信号，2 个 StringName 参数
  - Edge cases: 信号声明在 SchoolSystem（Cat 2b）

- **AC-011**: detect 优先级——正道 > 正邪混合
  - Given: state 同时满足正道（priority 2）和正邪混合（priority 4）条件
  - When: `ss.detect(state)`
  - Then: 返回 `&"righteous_dev"`（priority 2 < 4）
  - Edge cases: 优先级数值小者优先

- **AC-012**: detect 优先级——归墟 > 正道
  - Given: state 同时满足归墟（priority 1）和正道（priority 2）条件
  - When: `ss.detect(state)`
  - Then: 返回 `&"spirit_realm_beast"`（priority 1 最高）
  - Edge cases: 归墟条件最苛刻但优先级最高

- **AC-013**: detect 无流派满足返回空
  - Given: state 不满足任何流派条件
  - When: `ss.detect(state)`
  - Then: 返回 `&""`（空 StringName）
  - Edge cases: 匹配度仍可单独查询

- **AC-014**: calculate_match 权重
  - Given: state 含阵营人数 = 2/3（其他条件全满足）
  - When: `ss.calculate_match(&"righteous_dev", state)`
  - Then: score = round((40×2/3 + 30 + 20 + 10)/100 × 100) ≈ 86
  - Edge cases: 权重 40+30+20+10=100

- **AC-015**: calculate_match score 范围
  - Given: state 各条件比例不同
  - When: `ss.calculate_match(&"righteous_dev", state)` 多次
  - Then: 所有 score ∈ [0, 100]，round 至整数
  - Edge cases: 全满足=100、全不满足=0

- **AC-016**: calculate_match missing 人类可读
  - Given: state 阵营人数 = 2/3
  - When: `ss.calculate_match(&"righteous_dev", state)`
  - Then: missing 含"需 3 个正道角色（当前 2/3）"类描述
  - Edge cases: 全满足时 missing 为空数组

- **AC-017**: 未知 school_id 返回空
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_info(&"unknown_school")` / `ss.get_school_effects(&"unknown_school")`
  - Then: 返回 `{}` / `[]`，不报错
  - Edge cases: calculate_match 未知 ID 返回 {score:0, missing:["未知流派"]}

- **AC-018**: const SCHOOL_LIBRARY 不可变性
  - Given: SCHOOL_LIBRARY 已加载
  - When: GUT 冒烟测试运行后检查
  - Then: `SCHOOL_LIBRARY["righteous_dev"].name == "正道发育流"` 验证通过——内容未被运行时修改
  - Edge cases: const 嵌套 Dictionary 编译时分配

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/school_system/test_school_library_query.gd` — must exist and pass
**Status**: [x] Created and passing（33 个测试函数，33 passed / 0 failed / 124 assertions，覆盖 AC-001 到 AC-018 + 边缘情况补强）

---

## Dependencies

- Depends on: FactionSystem（`count_on_field`/`belongs_to_alignment`——已就绪）+ GSM（`player.realm_level`/`player.alchemy_count` 只读——已就绪）
- Unlocks: Story 002（增益公式依赖 001 的 SCHOOL_LIBRARY 结构）；战斗 Epic（CombatSystem 战前 detect 集成）；卡组编辑 Epic（DeckEdit UI 匹配度展示）
