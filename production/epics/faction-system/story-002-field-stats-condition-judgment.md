# Story 002: 场上阵营实时统计 + 阵法条件判定 + 阵营关系判定

> **Epic**: faction-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration（需集成测试——依赖 CardSystem 场上角色列表）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-05

## Context

**GDD**: `design/gdd/faction-system.md`
**Requirement**: `TR-faction-002`（待 `/architecture-review` 注册——当前 tr-registry.yaml 无 faction 条目，不阻塞实现）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0018（阵营系统——Core 层轻量 Autoload 服务 + 标签库字典 + 实时遍历统计）
**ADR Decision Summary**: FactionSystem 提供场上阵营实时统计 API（实时遍历上场角色，O(6×3) ≤ 18 次 StringName 判等，<0.001ms）+ 阵法条件判定（check_condition）+ 阵营关系判定（is_hostile_to / get_alignment_relation，基于 parent_alignment 三层关系：同阵营/敌对/中立）。所有统计基于当前场上存活角色——阵亡角色不在场上列表中，自动不计入。

**Engine**: Godot 4.6.3 | **Risk**: LOW（Array 遍历 + StringName 判等——O(1) 指针比较）
**Engine Notes**: 场上角色上限 6 人（ADR-0008），每人最多 3 标签——最坏 18 次比较 <0.001ms，在 16.6ms 帧预算中可忽略。

**Control Manifest Rules (Core 层)**:
- **Required**: `count_on_field` 实时遍历上场角色 —— 不维护缓存计数器（ADR-0018 §替代方案 C 拒绝原因：缓存一致性问题远超其消除的遍历开销）
- **Required**: Foundation Autoload 测试用动态分派模式（控制清单 2026-08-05 新增规则）
- **Forbidden**: FactionSystem 不监听 DeploymentSystem/CombatSystem 信号维护缓存 —— 纯查询接口，每次调用实时计算
- **Forbidden**: FactionSystem 不发射任何自有信号（ADR-0018 §信号策略）
- **Forbidden**: 绝不直接写 `FACTION_LIBRARY` 内容

---

## Acceptance Criteria

*From ADR-0018 §关键接口 §统计 API + §判定 API + §验证标准 + GDD §3 阵营判定接口 + §6 阵法联动 + §公式 1/2:*

- [ ] **AC-001**: `count_on_field(tag_or_alignment: StringName) -> int` 方法签名
- [ ] **AC-002**: 场上 3 正道角色 + 1 魔道角色 → `count_on_field(&"zhengdao")` 返回 3
- [ ] **AC-003**: 场上有青云剑宗角色 → `count_on_field(&"zhengdao")` 门派角色自动计入正道计数
- [ ] **AC-004**: 同一角色只计一次（即使有多个正道门派标签）
- [ ] **AC-005**: `get_field_faction_distribution() -> Dictionary` 返回场上所有标签的计数快照
- [ ] **AC-006**: `check_condition(requirement: Dictionary) -> bool` 方法签名
- [ ] **AC-007**: 场上正道=3，`check_condition({tag_id=&"zhengdao", min_count=3})` → true
- [ ] **AC-008**: 场上正道=2，`check_condition({tag_id=&"zhengdao", min_count=3})` → false
- [ ] **AC-009**: `check_condition({})` 空 requirement → false（tag_id 为空）
- [ ] **AC-010**: `is_hostile_to(card_a_id: int, card_b_id: int) -> bool` 方法签名
- [ ] **AC-011**: 正道角色 A + 魔道角色 B → `is_hostile_to(a, b)` 返回 true
- [ ] **AC-012**: 正道角色 A + 正道角色 B → `is_hostile_to(a, b)` 返回 false（同阵营）
- [ ] **AC-013**: 正道角色 A + 碎星群岛角色 B → `is_hostile_to(a, b)` 返回 false（中立）
- [ ] **AC-014**: `get_alignment_relation(a_id: int, b_id: int) -> int` 返回 FactionRelation 枚举值
- [ ] **AC-015**: 正道 vs 魔道 → `FactionRelation.HOSTILE`（1）
- [ ] **AC-016**: 正道 vs 正道 → `FactionRelation.SAME`（0）
- [ ] **AC-017**: 正道 vs 碎星群岛 → `FactionRelation.NEUTRAL`（2）
- [ ] **AC-018**: 角色阵亡后不在场上列表 → `count_on_field` 不计入（依赖 CardSystem.get_field_characters 排除阵亡角色）
- [ ] **AC-019**: `count_on_field` 当 CardSystem 不可用（is_instance_valid 为 false）→ 返回 0
- [ ] **AC-020**: FactionSystem 仍不发射信号（Story 002 未新增 signal 声明）

### 跨 Epic 依赖声明（全部 AC）

**依赖目标**: `src/core/card_system.gd`（CardSystem，ADR-0006）

**依赖方法**:
- `CardSystem.get_field_characters() -> Array` —— 返回当前场上存活角色列表（CardInstance 数组，每元素含 `card_instance_id`）
- `CardSystem.get_template_by_instance_id(id: int) -> CardTemplate` —— Story 001 已依赖

**理由**: ADR-0018 §关键接口明确 `count_on_field` 通过 `_get_field_characters()` 获取场上角色列表——场上角色状态由 DeploymentSystem/CombatSystem 维护，CardSystem 暴露查询接口。阵亡角色不在 `get_field_characters()` 返回值中（ADR-0008 战斗系统负责维护）。

**依赖状态**: card-system 5 个 Story 已创建，`get_field_characters` 将在 card-system 实现时提供。本 Story 全部 AC 依赖此方法——`/story-readiness` 会标记此依赖为 BLOCKED（依赖 card-system 未完成），Sprint 规划时本 Story 必须排在 card-system Story 003/004 之后。

**测试策略**: 集成测试需真实 CardSystem Autoload + 测试用 CardTemplate/CardInstance 工厂。测试用例在 `tests/integration/faction_system/` 下，mock 场上角色列表或使用 card-system 提供的测试夹具。

---

## Implementation Notes

*Derived from ADR-0018 §关键接口 §统计 API + §判定 API + §实时遍历 vs 缓存:*

1. **文件位置**: `src/core/faction_system.gd`（同 Story 001，扩展统计/判定方法）
2. **count_on_field 实现**（ADR-0018 §关键接口——实时遍历）:
   ```gdscript
   func count_on_field(tag_or_alignment: StringName) -> int:
       var field_chars: Array = _get_field_characters()
       var count: int = 0
       for char_instance in field_chars:
           var tags: Array[StringName] = get_tags_of_character(char_instance.card_instance_id)
           for tag in tags:
               # 判定逻辑：直接匹配 或 门派推导为大阵营匹配
               if tag == tag_or_alignment or derive_major_alignment(tag) == tag_or_alignment:
                   count += 1
                   break  # 同一角色只计一次
       return count
   ```
3. **get_field_faction_distribution 实现**（ADR-0018 §关键接口）:
   ```gdscript
   func get_field_faction_distribution() -> Dictionary:
       var dist: Dictionary = {}
       for tag_id in FACTION_LIBRARY:
           var c: int = count_on_field(tag_id)
           if c > 0:
               dist[tag_id] = c
       return dist
   ```
4. **check_condition 实现**（ADR-0018 §关键接口——阵法条件判定）:
   ```gdscript
   ## requirement 格式: { tag_id: StringName, min_count: int }
   func check_condition(requirement: Dictionary) -> bool:
       var tag_id: StringName = requirement.get("tag_id", &"")
       var min_count: int = requirement.get("min_count", 0)
       if tag_id.is_empty():
           return false
       return count_on_field(tag_id) >= min_count
   ```
5. **is_hostile_to 实现**（ADR-0018 §关键接口）:
   ```gdscript
   func is_hostile_to(card_a_instance_id: int, card_b_instance_id: int) -> bool:
       return get_alignment_relation(card_a_instance_id, card_b_instance_id) == FactionRelation.HOSTILE
   ```
6. **get_alignment_relation 实现**（ADR-0018 §关键接口——三层关系判定）:
   ```gdscript
   func get_alignment_relation(a_instance_id: int, b_instance_id: int) -> int:
       var a_tags: Array[StringName] = get_tags_of_character(a_instance_id)
       var b_tags: Array[StringName] = get_tags_of_character(b_instance_id)

       var a_major: StringName = &""
       var b_major: StringName = &""

       for tag in a_tags:
           var derived: StringName = derive_major_alignment(tag)
           if not derived.is_empty():
               a_major = derived
               break
       for tag in b_tags:
           var derived: StringName = derive_major_alignment(tag)
           if not derived.is_empty():
               b_major = derived
               break

       if a_major.is_empty() or b_major.is_empty():
           return FactionRelation.NEUTRAL  # 跨阵营角色 → 中立
       if a_major == b_major:
           return FactionRelation.SAME
       return FactionRelation.HOSTILE
   ```
7. **_get_field_characters 内部辅助**（ADR-0018 §关键接口——跨 Epic 依赖）:
   ```gdscript
   func _get_field_characters() -> Array:
       if not is_instance_valid(CardSystem):
           return []
       return CardSystem.get_field_characters()
   ```
8. **性能说明**（ADR-0018 §实时遍历 vs 缓存）:
   - 场上角色 ≤6 人，每人 ≤3 标签 → 最坏 18 次 StringName 判等
   - StringName 判等是 O(1) 指针比较（Godot 内部 intern 池）
   - 18 次比较 <0.001ms，在 16.6ms 帧预算中占 0.006%
   - 即使每帧调用 10 次 count_on_field，总计 <0.01ms——可忽略
9. **阵亡角色自动排除**（ADR-0018 §解决的 GDD 需求 §边缘情况）:
   - 阵亡角色不在 `CardSystem.get_field_characters()` 返回值中（ADR-0008 战斗系统维护）
   - FactionSystem 无需额外逻辑——依赖 CardSystem 的场上列表正确性
10. **信号策略**（ADR-0018 §信号策略）:
    - FactionSystem 不监听 DeploymentSystem/CombatSystem 信号
    - 不维护缓存计数器
    - 需要响应阵营变化的消费者（阵法系统）监听 Deployment/Combat 信号后主动调用 FactionSystem 重新查询
11. **测试模式**: 集成测试需真实 CardSystem + 测试夹具（mock CardTemplate.faction_tags + mock 场上角色列表）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: FACTION_LIBRARY 标签库 + 标签查询 API（get_tag_info / derive_major_alignment / belongs_to_alignment）
- **阵法激活后的 buff 应用**: 阵法系统 Epic 职责（调用 check_condition 判定激活，应用 buff 由阵法系统实现）
- **卡牌效果针对性伤害结算**: 卡牌效果引擎 Epic 职责（调用 is_hostile_to 判定，伤害计算由效果引擎实现）
- **场上角色列表维护**: DeploymentSystem/CombatSystem Epic 职责（CardSystem.get_field_characters 返回值由它们维护）
- **阵营分布变化通知**: FactionSystem 不发射信号——消费者监听 Deployment/Combat 信号后主动查询
- **阵营动态变化**: 未来叙事系统开放项（GDD §待解决问题 #1）

---

## QA Test Cases

*Derived from ADR-0018 §验证标准 + GDD §验收标准:*

- **AC-001**: count_on_field 方法签名
  - Given: `var fs: Node = FS_SCRIPT.new()`；CardSystem Autoload 可用（含测试夹具）
  - When: `var c: int = fs.count_on_field(&"zhengdao")`
  - Then: `assert_eq(typeof(c), TYPE_INT)`
  - Edge cases: 空场上返回 0

- **AC-002**: 场上 3 正道 + 1 魔道 → count_on_field(&"zhengdao")=3
  - Given: fs 已创建；场上 4 角色（3 正道 + 1 魔道，通过测试夹具设置）
  - When: `fs.count_on_field(&"zhengdao")`
  - Then: `assert_eq(result, 3)`
  - Edge cases: ADR-0018 §验证标准直接引用

- **AC-003**: 青云剑宗角色自动计入正道
  - Given: fs 已创建；场上 1 角色（faction_tags=[zhengdao, qixuanmen]）
  - When: `fs.count_on_field(&"zhengdao")`
  - Then: `assert_eq(result, 1)`（门派角色推导为大阵营正道，计入）
  - Edge cases: ADR-0018 §验证标准直接引用——门派自动推导

- **AC-004**: 同一角色只计一次
  - Given: fs 已创建；场上 1 角色（faction_tags=[zhengdao, qixuanmen, dangxia_valley]——2 个正道门派）
  - When: `fs.count_on_field(&"zhengdao")`
  - Then: `assert_eq(result, 1)`（break 机制——同一角色只计一次）
  - Edge cases: 多门派标签不重复计数

- **AC-005**: get_field_faction_distribution 返回场上分布快照
  - Given: fs 已创建；场上 3 正道 + 1 魔道（含门派标签）
  - When: `fs.get_field_faction_distribution()`
  - Then: 返回 Dictionary 含 `zhengdao: 3, modao: 1` 及各门派计数；无 0 计数标签
  - Edge cases: 仅返回 count > 0 的标签

- **AC-006**: check_condition 方法签名
  - Given: fs 已创建
  - When: `var ok: bool = fs.check_condition({tag_id=&"zhengdao", min_count=3})`
  - Then: `assert_eq(typeof(ok), TYPE_BOOL)`
  - Edge cases: requirement 格式 {tag_id, min_count}

- **AC-007**: 场上正道=3，check_condition(≥3) → true
  - Given: fs 已创建；场上 3 正道角色
  - When: `fs.check_condition({tag_id=&"zhengdao", min_count=3})`
  - Then: `assert_true(result)`
  - Edge cases: ADR-0018 §验证标准直接引用——阵法激活条件满足

- **AC-008**: 场上正道=2，check_condition(≥3) → false
  - Given: fs 已创建；场上 2 正道角色
  - When: `fs.check_condition({tag_id=&"zhengdao", min_count=3})`
  - Then: `assert_false(result)`
  - Edge cases: ADR-0018 §验证标准直接引用——阵法不激活

- **AC-009**: check_condition({}) 空 requirement → false
  - Given: fs 已创建
  - When: `fs.check_condition({})`
  - Then: `assert_false(result)`（tag_id 为空字符串）
  - Edge cases: 缺失 tag_id 字段时返回 false

- **AC-010**: is_hostile_to 方法签名
  - Given: fs 已创建；两个角色实例 ID
  - When: `var ok: bool = fs.is_hostile_to(a_id, b_id)`
  - Then: `assert_eq(typeof(ok), TYPE_BOOL)`
  - Edge cases: 基于 get_alignment_relation 判定

- **AC-011**: 正道 A + 魔道 B → is_hostile_to=true
  - Given: fs 已创建；A=正道角色，B=魔道角色
  - When: `fs.is_hostile_to(a_id, b_id)`
  - Then: `assert_true(result)`
  - Edge cases: ADR-0018 §验证标准直接引用

- **AC-012**: 正道 A + 正道 B → is_hostile_to=false
  - Given: fs 已创建；A=正道，B=正道
  - When: `fs.is_hostile_to(a_id, b_id)`
  - Then: `assert_false(result)`（同阵营）
  - Edge cases: 同阵营非敌对

- **AC-013**: 正道 A + 碎星群岛 B → is_hostile_to=false
  - Given: fs 已创建；A=正道，B=碎星群岛（跨阵营）
  - When: `fs.is_hostile_to(a_id, b_id)`
  - Then: `assert_false(result)`（中立）
  - Edge cases: ADR-0018 §验证标准直接引用——跨阵营角色 NEUTRAL

- **AC-014**: get_alignment_relation 返回枚举值
  - Given: fs 已创建；两个角色实例 ID
  - When: `var r: int = fs.get_alignment_relation(a_id, b_id)`
  - Then: `assert_eq(typeof(r), TYPE_INT)`；值 ∈ {0, 1, 2}
  - Edge cases: 返回 FactionRelation 枚举值

- **AC-015**: 正道 vs 魔道 → HOSTILE(1)
  - Given: fs 已创建；A=正道，B=魔道
  - When: `fs.get_alignment_relation(a_id, b_id)`
  - Then: `assert_eq(result, fs.FactionRelation.HOSTILE)`（1）
  - Edge cases: GDD §公式 2 直接引用

- **AC-016**: 正道 vs 正道 → SAME(0)
  - Given: fs 已创建；A=正道，B=正道
  - When: `fs.get_alignment_relation(a_id, b_id)`
  - Then: `assert_eq(result, fs.FactionRelation.SAME)`（0）
  - Edge cases: parent_alignment 相同

- **AC-017**: 正道 vs 碎星群岛 → NEUTRAL(2)
  - Given: fs 已创建；A=正道，B=碎星群岛（parent_alignment=&""）
  - When: `fs.get_alignment_relation(a_id, b_id)`
  - Then: `assert_eq(result, fs.FactionRelation.NEUTRAL)`（2）
  - Edge cases: 任一方 parent_alignment 为空 → 中立

- **AC-018**: 阵亡角色不计入
  - Given: fs 已创建；场上原 3 正道，1 角色阵亡（从 get_field_characters 移除）→ 剩 2 正道
  - When: `fs.count_on_field(&"zhengdao")`
  - Then: `assert_eq(result, 2)`（阵亡角色不在场上列表，自动不计入）
  - Edge cases: GDD §验收标准直接引用——依赖 CardSystem.get_field_characters 排除阵亡角色

- **AC-019**: CardSystem 不可用时 count_on_field 返回 0
  - Given: fs 已创建；CardSystem 未注册或 is_instance_valid=false（测试中模拟）
  - When: `fs.count_on_field(&"zhengdao")`
  - Then: `assert_eq(result, 0)`（_get_field_characters 返回空数组）
  - Edge cases: 防御性编程——Autoload 未就绪时不崩溃

- **AC-020**: FactionSystem 仍不发射信号
  - Given: FactionSystem 脚本已加载（Story 001 + Story 002 完整实现）
  - When: 读取 `fs.get_signal_list()`
  - Then: 返回空数组（Story 002 未新增 signal 声明）
  - Edge cases: 纯查询接口无信号——ADR-0018 §信号策略

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/faction_system/test_faction_field_stats_judgment.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（同文件 faction_system.gd 的 FACTION_LIBRARY + 标签查询 API + FactionRelation 枚举）；跨 Epic 依赖 card-system（`get_field_characters` + `get_template_by_instance_id` —— Sprint 2 同期实现，本 Story 全部 AC 依赖此）
- Unlocks: 阵法 Epic（check_condition + count_on_field 阵法激活判定）、卡牌效果 Epic（is_hostile_to + get_alignment_relation 阵营针对性效果）、流派 Epic（阵营方向路由）、探索 Epic（阵营事件选项）、AI Epic（敌方阵营查询）
