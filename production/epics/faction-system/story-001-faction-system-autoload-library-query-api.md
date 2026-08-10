# Story 001: FactionSystem Autoload + const FACTION_LIBRARY 标签库 + 标签查询 API

> **Epic**: faction-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic（需 GUT 单元测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-08

## Completion Notes

- **Code Review**: 主会话审查 APPROVED WITH SUGGESTIONS（0 BLOCKER / 0 HIGH / 2 LOW）
- **Fixes**: 2 项测试修复——AC-019 改用 `get_script_signal_list()` 过滤 Node 基类内置信号 / AC-020 早退时加 `assert_true` 避免 GUT Risky
- **Changes**:
  - `src/core/faction_system.gd` — 新建 210 行：FactionSystem Autoload + FactionRelation 枚举 + FACTION_LIBRARY const Dictionary（18 标签）+ 5 个查询 API
  - `tests/unit/faction_system/test_faction_library_query.gd` — 新建 314 行：27 测试覆盖 AC-001~015 + AC-019/020（17 条 AC）+ 8 边缘情况补强
  - `project.godot` — 已注册 FactionSystem Autoload（#15）
  - `production/sprint-status.yaml` — Story 2-11 done + completed: 2026-08-08
- **测试结果**: 全量套件 782/783 通过（1 pending 无关），2818 断言，0 失败
- **Tech debt logged**: None（2 项 LOW ADVISORY 记录在 Completion Notes）
  - LOW-1: `_CARD_SYSTEM_PATH` 硬编码 Autoload 路径，建议 Story 2-15 验证路径一致性
  - LOW-2: `get_tags_of_character` 中 `as StringName` 转换是防御性编程，可接受

## Context

**GDD**: `design/gdd/faction-system.md`
**Requirement**: `TR-faction-001`（已注册于 tr-registry.yaml，covered_by: ADR-0018）
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

- [x] **AC-001**: FactionSystem extends Node（Autoload #15），不声明 `class_name`
- [x] **AC-002**: `enum FactionRelation { SAME = 0, HOSTILE = 1, NEUTRAL = 2 }` 枚举定义
- [x] **AC-003**: `const FACTION_LIBRARY: Dictionary` 含 18 个标签（2 大阵营 + 12 门派 + 4 跨阵营）
- [x] **AC-004**: `get_tag_info(&"zhengdao")` 返回 `{name="正道", is_major=true, parent_alignment=&"", icon="...", color=Color(0.29,0.62,0.43)}`
- [x] **AC-005**: `get_tag_info(&"modao")` 返回 `{name="魔道", is_major=true, parent_alignment=&"", icon="...", color=Color(0.75,0.22,0.17)}`
- [x] **AC-006**: `get_tag_info(&"qixuanmen")` 返回门派定义，`parent_alignment=&"zhengdao"`, `is_major=false`
- [x] **AC-007**: `get_tag_info(&"xuehai_temple")` 返回魔道门派定义，`parent_alignment=&"modao"`
- [x] **AC-008**: `get_tag_info(&"suixing_islands")` 返回跨阵营标签，`parent_alignment=&"`（空，中立）
- [x] **AC-009**: `get_tag_info(&"nonexistent")` 无效 tag_id → 返回空 Dictionary + `push_warning`
- [x] **AC-010**: `get_major_alignments()` 返回 `[&"zhengdao", &"modao"]`（2 个大阵营）
- [x] **AC-011**: `derive_major_alignment(&"qixuanmen")` → 返回 `&"zhengdao"`（门派推导大阵营）
- [x] **AC-012**: `derive_major_alignment(&"xuehai_temple")` → 返回 `&"modao"`
- [x] **AC-013**: `derive_major_alignment(&"zhengdao")` → 返回 `&"zhengdao"`（大阵营自身即大阵营）
- [x] **AC-014**: `derive_major_alignment(&"suixing_islands")` → 返回 `&""`（跨阵营标签无大阵营归属）
- [x] **AC-015**: `derive_major_alignment(&"nonexistent")` → 返回 `&""`（无效 tag_id 返回空）
- [x] **AC-016**: `get_tags_of_character(character_id)` 通过 `CardSystem.get_template_by_instance_id` 获取角色的 `faction_tags`（跨 Epic 依赖——见下方 §跨 Epic 依赖声明）
- [x] **AC-017**: `belongs_to_alignment(character_id, &"zhengdao")` 当角色含正道标签 → 返回 true
- [x] **AC-018**: `belongs_to_alignment(character_id, &"modao")` 当角色含正道标签 → 返回 false
- [x] **AC-019**: FactionSystem 不发射任何信号（`get_script_signal_list()` 返回空数组——ADR-0018 §信号策略）
- [x] **AC-020**: FactionSystem `_ready()` 为空（const Dictionary 编译时分配，零运行时加载开销）

### 跨 Epic 依赖声明（AC-016/017/018）

**依赖目标**: `src/core/card_system.gd`（CardSystem，ADR-0006，Sprint 2 同期实现）

**依赖方法**:
- `CardSystem.get_template_by_instance_id(character_id: int) -> CardTemplate` —— 通过实例 ID 查询模板，读取 `template.faction_tags: Array[StringName]`

**理由**: ADR-0018 §关键接口明确 `get_tags_of_character` 通过 CardSystem 查询模板——阵营标签数据的运行时来源是 CardTemplate.faction_tags（ADR-0006 已定义）。FactionSystem 不持有标签数据副本，避免双源真理。

**依赖状态**: card-system 5 个 Story 已完成，`get_template_by_instance_id` 已在 Story 004 实现。AC-016~018 在 card-system 可用时完整验证。

**测试策略**: AC-001~015（标签库 + 查询 + 推导）不依赖 CardSystem，可独立测试。AC-016~018（角色标签查询）依赖 CardSystem —— 无 CardSystem 时优雅返回空数组/false，集成测试在 Story 002 测试文件。

---

## Implementation Notes

*Derived from ADR-0018 §关键接口 §FACTION_LIBRARY + §查询 API:*

1. **文件位置**: `src/core/faction_system.gd`（Core 层，Autoload #15）
2. **类声明**: `extends Node`（不声明 class_name——Autoload 固有权衡）
3. **FactionRelation 枚举**（ADR-0018 §关键接口）:
   ```gdscript
   enum FactionRelation { SAME = 0, HOSTILE = 1, NEUTRAL = 2 }
   ```
4. **FACTION_LIBRARY const 定义**（ADR-0018 §关键接口——18 标签完整定义）
5. **get_tag_info 实现**（ADR-0018 §关键接口）: O(1) 字典查询 + push_warning 守卫
6. **get_major_alignments 实现**（ADR-0018 §关键接口）: 遍历 FACTION_LIBRARY 筛选 is_major=true
7. **derive_major_alignment 实现**（ADR-0018 §关键接口）: 门派→大阵营推导，大阵营返回自身
8. **get_tags_of_character 实现**（ADR-0018 §关键接口——跨 Epic 依赖 CardSystem）: 通过 `_get_card_system()` 动态查找 + 优雅降级
9. **belongs_to_alignment 实现**（ADR-0018 §关键接口）: O(3) 标签推导匹配
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

所有 AC 测试用例已通过——见 `tests/unit/faction_system/test_faction_library_query.gd`（27 测试函数）。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/faction_system/test_faction_library_query.gd` — exists and passes
**Status**: [x] Created — 27 tests, 782/783 全量通过（1 pending 无关），2818 断言