# Story 001: FactionSystem Autoload + const FACTION_LIBRARY 标签库 + 标签查询 API

> **Epic**: faction-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic（需 GUT 单元测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-05

## Context

**GDD**: `design/gdd/faction-system.md`
**Requirement**: `TR-faction-001`（待 `/architecture-review` 注册——当前 tr-registry.yaml 无 faction 条目，不阻塞实现）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0018（阵营系统——Core 层轻量 Autoload 服务 + 标签库字典 + 实时遍历统计）
**ADR Decision Summary**: FactionSystem 作为 Core 层 Autoload #15，持有 `const FACTION_LIBRARY`（编译时常量标签库，含 2 大阵营 + 12 门派 + 4 跨阵营 = 18 标签）+ `FactionRelation` 枚举 + 标签查询 API。本 Story 聚焦标签库定义和纯查询接口（不依赖场上角色列表），实时统计/判定 API 在 Story 002 实现。

**Engine**: Godot 4.6.3 | **Risk**: LOW（const Dictionary + 字典查询 + StringName 键类型——均为 4.x 成熟 API）
**Engine Notes**: `Array[StringName]` 类型化集合（4.4+）用于 CardTemplate.faction_tags。FactionSystem 使用裸 `Array` 迭代（兼容 4.0+）。

**Control Manifest Rules (Core 层)**:
- **Required**: FactionSystem 是 Autoload —— 绝不声明 `class_name`（控制清单 2026-08-05 新增规则——同 RealmSystem/ResourceSystem 模式）
- **Required**: `FACTION_LIBRARY` 是阵营标签元数据的唯一真理来源 —— 所有消费者通过 FactionSystem 查询
- **Required**: Foundation Autoload 测试用动态分派模式（控制清单 2026-08-05 新增规则——适用 Core Autoload）
- **Forbidden**: 绝不直接写 `FACTION_LIBRARY` 内容 —— const Dictionary 并非真正冻结，团队约定只读
- **Forbidden**: FactionSystem 不发射任何自有信号（ADR-0018 §信号策略——纯查询接口，由 Deployment/Combat 信号驱动消费者重新查询）

---

## Acceptance Criteria

*From ADR-0018 §关键接口 + §验证标准 + GDD §1 阵营标签结构 + §2 角色阵营分配规则:*

- [ ] **AC-001**: FactionSystem extends Node（Autoload #15），不声明 `class_name`
- [ ] **AC-002**: `enum FactionRelation { SAME = 0, HOSTILE = 1, NEUTRAL = 2 }` 枚举定义
- [ ] **AC-003**: `const FACTION_LIBRARY: Dictionary` 含 18 个标签（2 大阵营 + 12 门派 + 4 跨阵营）
- [ ] **AC-004**: `get_tag_info(&"zhengdao")` 返回 `{name="正道", is_major=true, parent_alignment=&"", icon="...", color=Color(0.29,0.62,0.43)}`
- [ ] **AC-005**: `get_tag_info(&"modao")` 返回 `{name="魔道", is_major=true, parent_alignment=&"", icon="...", color=Color(0.75,0.22,0.17)}`
- [ ] **AC-006**: `get_tag_info(&"qixuanmen")` 返回门派定义，`parent_alignment=&"zhengdao"`, `is_major=false`
- [ ] **AC-007**: `get_tag_info(&"xuehai_temple")` 返回魔道门派定义，`parent_alignment=&"modao"`
- [ ] **AC-008**: `get_tag_info(&"suixing_islands")` 返回跨阵营标签，`parent_alignment=&"`（空，中立）
- [ ] **AC-009**: `get_tag_info(&"nonexistent")` 无效 tag_id → 返回空 Dictionary + `push_warning`
- [ ] **AC-010**: `get_major_alignments()` 返回 `[&"zhengdao", &"modao"]`（2 个大阵营）
- [ ] **AC-011**: `derive_major_alignment(&"qixuanmen")` → 返回 `&"zhengdao"`（门派推导大阵营）
- [ ] **AC-012**: `derive_major_alignment(&"xuehai_temple")` → 返回 `&"modao"`
- [ ] **AC-013**: `derive_major_alignment(&"zhengdao")` → 返回 `&"zhengdao"`（大阵营自身即大阵营）
- [ ] **AC-014**: `derive_major_alignment(&"suixing_islands")` → 返回 `&""`（跨阵营标签无大阵营归属）
- [ ] **AC-015**: `derive_major_alignment(&"nonexistent")` → 返回 `&""`（无效 tag_id 返回空）
- [ ] **AC-016**: `get_tags_of_character(character_id)` 通过 `CardSystem.get_template_by_instance_id` 获取角色的 `faction_tags`（跨 Epic 依赖——见下方 §跨 Epic 依赖声明）
- [ ] **AC-017**: `belongs_to_alignment(character_id, &"zhengdao")` 当角色含正道标签 → 返回 true
- [ ] **AC-018**: `belongs_to_alignment(character_id, &"modao")` 当角色含正道标签 → 返回 false
- [ ] **AC-019**: FactionSystem 不发射任何信号（`get_signal_list()` 返回空数组——ADR-0018 §信号策略）
- [ ] **AC-020**: FactionSystem `_ready()` 为空（const Dictionary 编译时分配，零运行时加载开销）

### 跨 Epic 依赖声明（AC-016/017/018）

**依赖目标**: `src/core/card_system.gd`（CardSystem，ADR-0006，Sprint 2 同期实现）

**依赖方法**:
- `CardSystem.get_template_by_instance_id(character_id: int) -> CardTemplate` —— 通过实例 ID 查询模板，读取 `template.faction_tags: Array[StringName]`

**理由**: ADR-0018 §关键接口明确 `get_tags_of_character` 通过 CardSystem 查询模板——阵营标签数据的运行时来源是 CardTemplate.faction_tags（ADR-0006 已定义）。FactionSystem 不持有标签数据副本，避免双源真理。

**依赖状态**: card-system 5 个 Story 已创建（Story 001-005），`get_template_by_instance_id` 将在 card-system Story 003（模板注册表）或 Story 004（工厂）实现。本 Story 的 AC-016/017/018 在 card-system 实现完成后才能完整验证——`/story-readiness` 会标记此依赖，Sprint 规划时本 Story 排在 card-system Story 004 之后。

**测试策略**: AC-001~015（标签库 + 查询 + 推导）不依赖 CardSystem，可独立测试。AC-016~018（角色标签查询）依赖 CardSystem —— 测试中 mock CardSystem 或标记为集成测试（移至 Story 002 测试文件）。

---

## Implementation Notes

*Derived from ADR-0018 §关键接口 §FACTION_LIBRARY + §查询 API:*

1. **文件位置**: `src/core/faction_system.gd`（Core 层，Autoload #15）
2. **类声明**: `extends Node`（不声明 class_name——Autoload 固有权衡）
3. **FactionRelation 枚举**（ADR-0018 §关键接口）:
   ```gdscript
   enum FactionRelation { SAME = 0, HOSTILE = 1, NEUTRAL = 2 }
   ```
4. **FACTION_LIBRARY const 定义**（ADR-0018 §关键接口——18 标签完整定义）:
   ```gdscript
   const FACTION_LIBRARY: Dictionary = {
       # --- 大阵营 (is_major=true, parent_alignment=&"") ---
       &"zhengdao": {
           name = "正道", parent_alignment = &"", is_major = true,
           icon = "res://assets/icons/factions/zhengdao.png",
           color = Color(0.29, 0.62, 0.43),  # 青金色 #4A9E6E
       },
       &"modao": {
           name = "魔道", parent_alignment = &"", is_major = true,
           icon = "res://assets/icons/factions/modao.png",
           color = Color(0.75, 0.22, 0.17),  # 赤紫色 #C0392B
       },
       # --- 正道门派 (parent_alignment=&"zhengdao") ---
       &"qixuanmen": {name="青云剑宗", parent_alignment=&"zhengdao", is_major=false, icon="res://assets/icons/factions/qixuanmen.png"},
       &"dangxia_valley": {name="丹霞谷", parent_alignment=&"zhengdao", is_major=false, icon="res://assets/icons/factions/dangxia_valley.png"},
       &"xuanbing_palace": {name="玄冰宫", parent_alignment=&"zhengdao", is_major=false, icon="res://assets/icons/factions/xuanbing_palace.png"},
       &"dongyu": {name="东域", parent_alignment=&"zhengdao", is_major=false, icon="res://assets/icons/factions/dongyu.png"},
       &"xingdou_sect": {name="星斗宗", parent_alignment=&"zhengdao", is_major=false, icon="res://assets/icons/factions/xingdou_sect.png"},
       &"wei_family": {name="卫家", parent_alignment=&"zhengdao", is_major=false, icon="res://assets/icons/factions/wei_family.png"},
       # --- 魔道门派 (parent_alignment=&"modao") ---
       &"xuehai_temple": {name="血海殿", parent_alignment=&"modao", is_major=false, icon="res://assets/icons/factions/xuehai_temple.png"},
       &"meiying_pavilion": {name="魅影阁", parent_alignment=&"modao", is_major=false, icon="res://assets/icons/factions/meiying_pavilion.png"},
       &"samsara_hall": {name="轮回殿", parent_alignment=&"modao", is_major=false, icon="res://assets/icons/factions/samsara_hall.png"},
       &"xuesha_cult": {name="血煞教", parent_alignment=&"modao", is_major=false, icon="res://assets/icons/factions/xuesha_cult.png"},
       &"heisha_cult": {name="黑煞教", parent_alignment=&"modao", is_major=false, icon="res://assets/icons/factions/heisha_cult.png"},
       &"yunmeng": {name="云蒙", parent_alignment=&"modao", is_major=false, icon="res://assets/icons/factions/yunmeng.png"},
       # --- 跨阵营中立标签 (parent_alignment=&") ---
       &"suixing_islands": {name="碎星群岛", parent_alignment=&"", is_major=false, icon="res://assets/icons/factions/suixing_islands.png"},
       &"guixu_abyss": {name="归墟之境", parent_alignment=&"", is_major=false, icon="res://assets/icons/factions/guixu_abyss.png"},
       &"wanxiang_pavilion": {name="万象阁", parent_alignment=&"", is_major=false, icon="res://assets/icons/factions/wanxiang_pavilion.png"},
       &"jiyin_island": {name="极阴岛", parent_alignment=&"", is_major=false, icon="res://assets/icons/factions/jiyin_island.png"},
   }
   ```
5. **get_tag_info 实现**（ADR-0018 §关键接口）:
   ```gdscript
   func get_tag_info(tag_id: StringName) -> Dictionary:
       if not FACTION_LIBRARY.has(tag_id):
           push_warning("FactionSystem: unknown tag_id '%s'" % tag_id)
           return {}
       return FACTION_LIBRARY[tag_id]
   ```
6. **get_major_alignments 实现**（ADR-0018 §关键接口）:
   ```gdscript
   func get_major_alignments() -> Array[StringName]:
       var result: Array[StringName] = []
       for tag_id in FACTION_LIBRARY:
           if FACTION_LIBRARY[tag_id].is_major:
               result.append(tag_id)
       return result
   ```
7. **derive_major_alignment 实现**（ADR-0018 §关键接口）:
   ```gdscript
   func derive_major_alignment(tag_id: StringName) -> StringName:
       var info: Dictionary = get_tag_info(tag_id)
       if info.is_empty():
           return &""
       if info.is_major:
           return tag_id  # 自身就是大阵营
       return info.get("parent_alignment", &"") as StringName
   ```
8. **get_tags_of_character 实现**（ADR-0018 §关键接口——跨 Epic 依赖 CardSystem）:
   ```gdscript
   func get_tags_of_character(character_id: int) -> Array[StringName]:
       if not is_instance_valid(CardSystem):
           return []
       var template: CardTemplate = CardSystem.get_template_by_instance_id(character_id)
       if template == null:
           return []
       return template.faction_tags
   ```
9. **belongs_to_alignment 实现**（ADR-0018 §关键接口）:
   ```gdscript
   func belongs_to_alignment(character_id: int, alignment: StringName) -> bool:
       var tags: Array[StringName] = get_tags_of_character(character_id)
       for tag in tags:
           if derive_major_alignment(tag) == alignment:
               return true
       return false
   ```
10. **_ready 为空**（ADR-0018 §性能影响）: const Dictionary 编译时分配，Autoload `_ready()` 无需初始化逻辑
11. **测试模式**: 测试用 `var fs: Node = FS_SCRIPT.new()` 动态分派——AC-001~015 不依赖 CardSystem，可独立测试；AC-016~018 依赖 CardSystem，集成测试在 Story 002 测试文件

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 场上阵营实时统计（count_on_field）+ 阵法条件判定（check_condition）+ 阵营关系判定（is_hostile_to / get_alignment_relation）
- **正魔同体校验**: CardSystem 数据加载阶段执行（ADR-0018 §解决的 GDD 需求 §2）——非 FactionSystem 运行时职责
- **角色标签上限校验（≤3）**: CardTemplate.faction_tags 字段校验，CardSystem 职责
- **图标资源实际加载**: 美术资产（assets/icons/factions/）由美术管线创建，本 Story 仅定义路径字符串
- **阵营动态变化（如"堕入魔道"剧情）**: GDD §待解决问题 #1，未来叙事系统开放项

---

## QA Test Cases

*Derived from ADR-0018 §验证标准 + GDD §验收标准:*

- **AC-001**: FactionSystem extends Node，不声明 class_name
  - Given: `src/core/faction_system.gd` 存在
  - When: `var script := load("res://src/core/faction_system.gd")`
  - Then: `assert_eq(script.get_instance_base_type(), "Node")`；源码无 `class_name` 关键字
  - Edge cases: 测试用 `var fs: Node = FS_SCRIPT.new()` 动态分派

- **AC-002**: FactionRelation 枚举定义
  - Given: FactionSystem 脚本已加载
  - When: 读取 FactionRelation 枚举常量
  - Then: 断言 3 个常量：SAME=0、HOSTILE=1、NEUTRAL=2
  - Edge cases: 枚举值总数 == 3

- **AC-003**: FACTION_LIBRARY 含 18 个标签
  - Given: FactionSystem 脚本已加载
  - When: 读取 `FS_SCRIPT.FACTION_LIBRARY`
  - Then: `assert_eq(FACTION_LIBRARY.size(), 18)`
  - Edge cases: 2 大阵营 + 12 门派 + 4 跨阵营 = 18

- **AC-004**: get_tag_info(&"zhengdao") 返回正道定义
  - Given: `var fs: Node = FS_SCRIPT.new()`
  - When: `fs.get_tag_info(&"zhengdao")`
  - Then: `assert_eq(result.name, "正道")`；`assert_true(result.is_major)`；`assert_eq(result.parent_alignment, &"")`；`assert_eq(result.color, Color(0.29, 0.62, 0.43))`
  - Edge cases: ADR-0018 §验证标准直接引用

- **AC-005**: get_tag_info(&"modao") 返回魔道定义
  - Given: fs 已创建
  - When: `fs.get_tag_info(&"modao")`
  - Then: `assert_eq(result.name, "魔道")`；`assert_true(result.is_major)`；`assert_eq(result.color, Color(0.75, 0.22, 0.17))`
  - Edge cases: 大阵营主题色校验

- **AC-006**: get_tag_info(&"qixuanmen") 返回正道门派定义
  - Given: fs 已创建
  - When: `fs.get_tag_info(&"qixuanmen")`
  - Then: `assert_eq(result.name, "青云剑宗")`；`assert_false(result.is_major)`；`assert_eq(result.parent_alignment, &"zhengdao")`
  - Edge cases: 正道门派 parent_alignment 校验

- **AC-007**: get_tag_info(&"xuehai_temple") 返回魔道门派定义
  - Given: fs 已创建
  - When: `fs.get_tag_info(&"xuehai_temple")`
  - Then: `assert_eq(result.name, "血海殿")`；`assert_false(result.is_major)`；`assert_eq(result.parent_alignment, &"modao")`
  - Edge cases: 魔道门派 parent_alignment 校验

- **AC-008**: get_tag_info(&"suixing_islands") 返回跨阵营标签
  - Given: fs 已创建
  - When: `fs.get_tag_info(&"suixing_islands")`
  - Then: `assert_eq(result.name, "碎星群岛")`；`assert_false(result.is_major)`；`assert_eq(result.parent_alignment, &"")`（空——中立）
  - Edge cases: 跨阵营标签 parent_alignment 为空字符串

- **AC-009**: get_tag_info(&"nonexistent") 无效 tag_id → 空 Dictionary + push_warning
  - Given: fs 已创建
  - When: `fs.get_tag_info(&"nonexistent")`
  - Then: `assert_eq(result, {})`；`assert_push_warning_count(1)`
  - Edge cases: ADR-0018 §验证标准直接引用

- **AC-010**: get_major_alignments 返回 2 个大阵营
  - Given: fs 已创建
  - When: `fs.get_major_alignments()`
  - Then: `assert_eq(result.size(), 2)`；`assert_true(result.has(&"zhengdao"))`；`assert_true(result.has(&"modao"))`
  - Edge cases: 仅返回 is_major=true 的标签

- **AC-011**: derive_major_alignment(&"qixuanmen") → &"zhengdao"
  - Given: fs 已创建
  - When: `fs.derive_major_alignment(&"qixuanmen")`
  - Then: `assert_eq(result, &"zhengdao")`
  - Edge cases: ADR-0018 §验证标准直接引用——门派推导大阵营

- **AC-012**: derive_major_alignment(&"xuehai_temple") → &"modao"
  - Given: fs 已创建
  - When: `fs.derive_major_alignment(&"xuehai_temple")`
  - Then: `assert_eq(result, &"modao")`
  - Edge cases: 魔道门派推导

- **AC-013**: derive_major_alignment(&"zhengdao") → &"zhengdao"
  - Given: fs 已创建
  - When: `fs.derive_major_alignment(&"zhengdao")`
  - Then: `assert_eq(result, &"zhengdao")`（大阵营自身即大阵营）
  - Edge cases: is_major=true 时返回自身

- **AC-014**: derive_major_alignment(&"suixing_islands") → &""
  - Given: fs 已创建
  - When: `fs.derive_major_alignment(&"suixing_islands")`
  - Then: `assert_eq(result, &"")`（跨阵营标签无大阵营归属）
  - Edge cases: parent_alignment 为空 → 返回空

- **AC-015**: derive_major_alignment(&"nonexistent") → &""
  - Given: fs 已创建
  - When: `fs.derive_major_alignment(&"nonexistent")`
  - Then: `assert_eq(result, &"")`（无效 tag_id 返回空）
  - Edge cases: get_tag_info 返回空时 derive 返回空

- **AC-016**: get_tags_of_character 通过 CardSystem 查询
  - Given: fs 已创建；CardSystem Autoload 可用（含测试模板）
  - When: `fs.get_tags_of_character(lin_yuan_id)`（林渊角色实例 ID）
  - Then: 返回 `[&"zhengdao", &"qixuanmen"]`（CardTemplate.faction_tags）
  - Edge cases: 跨 Epic 依赖——card-system 实现后集成测试

- **AC-017**: belongs_to_alignment 正道角色 → true
  - Given: fs 已创建；林渊角色（faction_tags=[zhengdao, qixuanmen]）
  - When: `fs.belongs_to_alignment(lin_yuan_id, &"zhengdao")`
  - Then: `assert_true(result)`
  - Edge cases: ADR-0018 §验证标准直接引用

- **AC-018**: belongs_to_alignment 正道角色查询魔道 → false
  - Given: fs 已创建；林渊角色（正道）
  - When: `fs.belongs_to_alignment(lin_yuan_id, &"modao")`
  - Then: `assert_false(result)`
  - Edge cases: 正道角色不属于魔道

- **AC-019**: FactionSystem 不发射任何信号
  - Given: FactionSystem 脚本已加载
  - When: 读取 `fs.get_signal_list()`
  - Then: 返回空数组（FactionSystem 无 `signal` 声明）
  - Edge cases: ADR-0018 §信号策略——纯查询接口无信号

- **AC-020**: FactionSystem _ready 为空
  - Given: FactionSystem 脚本已加载
  - When: 检查 `_ready()` 方法实现
  - Then: `_ready()` 方法体为空或不存在（const Dictionary 编译时分配）
  - Edge cases: 零运行时加载开销

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/faction_system/test_faction_library_query.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 无（AC-001~015 标签库查询不依赖外部系统）；AC-016~018 跨 Epic 依赖 card-system（`get_template_by_instance_id` —— Sprint 2 同期实现，集成测试在 Story 002）
- Unlocks: Story 002（同文件扩展统计/判定 API）、阵法 Epic（check_condition）、卡牌效果 Epic（is_hostile_to/belongs_to_alignment）、流派 Epic（get_tags_of_character）、探索 Epic（get_tags_of_character）、AI Epic
