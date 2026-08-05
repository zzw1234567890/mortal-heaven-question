# QA 计划：Sprint 2 — Core 层

**日期**：2026-08-05
**由**：/qa-plan 生成
**范围**：涉及 4 个系统（card-system / realm-system / resource-system / faction-system）的 12 个编码 Story + 1 个技术债拆分 + 1 个基础设施验证
**引擎**：Godot 4.6.3（GDScript）
**Sprint 文件**：`production/sprints/sprint-2.md`
**里程碑**：core-layer-complete（目标 2026-08-19）
**Manifest Version**：2026-08-05

---

## 测试摘要

| Story | 类型 | 需要自动化测试 | 需要手动验证 | AC 数 |
|-------|------|------------------------|------------------------------|-------|
| card/001 CardTemplate + enums | Logic | 单元测试 — `tests/unit/card_system/` | 无 | 10 |
| card/002 CardInstance RefCounted | Logic | 单元测试 — `tests/unit/card_system/` | 无 | 8 |
| card/003 CardSystem Autoload + 注册表 | Integration | 集成测试 — `tests/integration/card_system/` | 冒烟检查 | 12 |
| card/004 工厂 + GSM 集成 | Integration | 集成测试 — `tests/integration/card_system/` | 冒烟检查 | 11 |
| card/005 实例序列化/重组 | Integration | 集成测试 — `tests/integration/card_system/` | 冒烟检查 | 9 |
| realm/001 realm_table + 查询 | Logic | 单元测试 — `tests/unit/realm_system/` | 无 | 15 |
| realm/002 压制计算 + 权重 | Logic | 单元测试 — `tests/unit/realm_system/` | 无 | 13 |
| realm/003 realm_up 编排 + 信号 | Integration | 集成测试 — `tests/integration/realm_system/` | 冒烟检查 | 10 |
| resource/001 Autoload + 读写 API | Integration | 集成测试 — `tests/integration/resource_system/` | 冒烟检查 | 19 |
| resource/002 6 公式纯函数 | Logic | 单元测试 — `tests/unit/resource_system/` | 无 | 22 |
| faction/001 FACTION_LIBRARY + 查询 | Logic | 单元测试 — `tests/unit/faction_system/` | 无 | 20 |
| faction/002 场上统计 + 判定 | Integration | 集成测试 — `tests/integration/faction_system/` | 冒烟检查 | 20 |
| 拆分 event_system.gd | Refactor | 重跑全部 520 现有测试 | grep 行数验证 | — |
| Autoload 顺序验证 | Task | 无 | project.godot 手动检查 | — |

**总计**：6 Logic + 6 Integration + 1 Refactor + 1 Task = 14 项，预估 ~169 测试函数，179 AC 全覆盖

---

## 需要自动化测试

> **注**：每个 Story 的 `## QA Test Cases` 章节已含完整 Given/When/Then/Edge cases 规格（由 ADR §验证标准 + GDD §验收标准直接引用）。本节为冲刺级整合视图，详细测试用例见各 Story 文件。

### card/001 CardTemplate + enums — Logic
**测试文件路径**：`tests/unit/card_system/test_card_template.gd`
**测试内容**：
- CardTemplate extends Resource + class_name CardTemplate
- CardType 枚举（CHARACTER/TECHNIQUE/ARTIFACT/PILL/TALISMAN/FORMATION）
- Rarity 枚举（WHITE/BLUE/PURPLE/GOLD/DARK_GOLD）
- @export 类型化字段（id/name/card_type/rarity/faction_tags 等）
- 默认值表验证

**需要覆盖的边界情况**：
- 空 faction_tags 数组
- rarity 越界值
- id 为空字符串
- GDD card-system.md §边界情况中的卡牌数据约束

**预估测试数量**：~10 个单元测试（对应 AC-001~010）

---

### card/002 CardInstance RefCounted — Logic
**测试文件路径**：`tests/unit/card_system/test_card_instance.gd`
**测试内容**：
- CardInstance extends RefCounted（非 Node）
- AcquiredMethod 枚举（INITIAL/DRAW/PURCHASE/DISMANTLE/EVENT_REWARD）
- instance_id 唯一性
- template_id 引用完整性
- 实例级独立状态（level/acquired_method）

**需要覆盖的边界情况**：
- 实例级 level 独立于模板（AC-007 实例级独立性）
- 多实例引用同一模板
- instance_id 重复检测

**预估测试数量**：~8 个单元测试（对应 AC-001~008）

---

### card/003 CardSystem Autoload + 注册表异步加载 — Integration
**测试文件路径**：`tests/integration/card_system/test_template_registry.gd`
**测试内容**：
- CardSystem extends Node（Autoload #6，不声明 class_name）
- templates Dictionary 管理
- DirAccess 遍历 .tres 文件
- load_threaded_request 异步加载流程
- templates_loaded(count: int) Cat 2b 信号
- 节流机制（私有计数器反射）

**需要覆盖的边界情况**：
- 空目录 → 仍发射 templates_loaded(0) + push_error
- DirAccess 失败 → 信号 + push_error
- 重复模板 ID → push_error + 跳过
- 异步加载未完成时查询 → 返回 null

**预估测试数量**：~12 个集成测试（对应 AC-001~012）

---

### card/004 工厂 + GSM 集成 — Integration
**测试文件路径**：`tests/integration/card_system/test_factory_gsm.gd`
**测试内容**：
- create_instance 工厂方法
- GSM.allocate_card_id 集成
- enable_validation 主动调用模式（Core→Foundation 方向）
- 统一 push_error + return null 错误处理

**需要覆盖的边界情况**：
- 无效 template_id → push_error + return null
- GSM 未就绪 → 防御性返回
- enable_validation 主动调用（AC-006——非 GSM 监听信号）
- Foundation 原则 #3 合规验证（grep CardSystem 调用 GSM 方向）

**预估测试数量**：~11 个集成测试（对应 AC-001~011）

---

### card/005 实例序列化/重组 — Integration
**测试文件路径**：`tests/integration/card_system/test_serialization.gd`
**测试内容**：
- serialize_instance 序列化为 Dictionary
- deserialize_instance 反序列化
- reconstitute_instances 批量重组
- StringName 显式转换
- .get(key, default) 容错

**需要覆盖的边界情况**：
- 未知字段忽略
- 类型不匹配 → push_error
- 空数组重组
- StringName ↔ String 转换边界

**预估测试数量**：~9 个集成测试（对应 AC-001~009）

---

### realm/001 realm_table + 查询接口 — Logic
**测试文件路径**：`tests/unit/realm_system/test_realm_table.gd`
**测试内容**：
- RealmSystem extends Node（Autoload #11，不声明 class_name）
- const realm_table（5 境界 × 10 属性）
- get_realm_property(realm, property) 查询
- get_current_property(player_level, property) 当前境界查询
- max_cultivation 公式验证（1000/1500/2250/3375/5063）

**需要覆盖的边界情况**：
- 无效 realm_level（0/6）
- 无效 property 名
- 境界 1~5 所有属性字段验证
- ADR-0010 §验证标准 8 条 GIVEN-WHEN-THEN 直接引用

**预估测试数量**：~15 个单元测试（对应 AC-001~015）

---

### realm/002 压制计算 + 稀有度权重 — Logic
**测试文件路径**：`tests/unit/realm_system/test_realm_calculation.gd`
**测试内容**：
- realm_penalty(attacker_lv, defender_lv) → float
- map_effective_realm(player_lv, map_max_lv) → Dictionary
- get_rarity_weights(pool_tier) → Dictionary
- const DROP_POOL_WEIGHTS（5 池等级）

**需要覆盖的边界情况**：
- delta=0（无压制）→ 1.0
- delta=1 → 0.8（-20%）
- delta=2 → 0.5（-50%）
- delta>=3 → 0.5（封顶）
- 无效 pool_tier（0/6）→ 空 Dictionary + push_warning
- GDD §验收标准直接引用：realm_penalty(1,2)=0.8, realm_penalty(1,3)=0.5

**预估测试数量**：~13 个单元测试（对应 AC-001~013）

---

### realm/003 realm_up 编排 + 信号 — Integration
**测试文件路径**：`tests/integration/realm_system/test_realm_up.gd`
**测试内容**：
- realm_up(current_level) 原子编排器
- GSM.change_realm(new_level) 原子写入
- realm_upgraded(old, new) Cat 2b 信号
- 信号委托模式（不直接调用下游系统）

**需要覆盖的边界情况**：
- realm_up(5) 最高境界 → push_error + 不修改 GSM
- realm_up(2) → GSM.realm_level=3 + 信号(2,3)
- 信号仅发射 1 次（assert_signal_emit_count）
- grep 验证无直接调用 CultivationSystem/ExplorationSystem 等（AC-008）
- 突破后 cultivation 保留不变（AC-009）

**预估测试数量**：~10 个集成测试（对应 AC-001~010）

---

### resource/001 Autoload + 读写 API + GSM 第二层 — Integration
**测试文件路径**：`tests/integration/resource_system/test_resource_read_write_api.gd`
**测试内容**：
- ResourceSystem extends Node（Autoload #16，不声明 class_name）
- LingCaiQuality 枚举（LOW=1/MEDIUM=2/HIGH=3/TOP=4）
- add_resource / spend_resource / can_spend / get_resource API
- GSM 第二层 _set_resource_ling_shi / _set_resource_ling_cai（跨 Epic 修改）
- 非负守卫 max(0, value)
- batch_updated Cat 1 信号传播
- ResourceSystem 不发射自有信号（ADR-0007 禁止模式 #11）

**需要覆盖的边界情况**：
- 余额不足不扣减（spend ling_shi=20 消费 30 → false, 仍 20）
- 无效品质（quality=5）→ false
- 非负守卫（_set_resource_ling_shi(-50) → 0）
- 灵材总和查询（不传 quality）
- GDD AC-1~5 + ADR-0019 §验证标准直接引用

**预估测试数量**：~19 个集成测试（对应 AC-001~019）

---

### resource/002 6 资源公式纯函数 — Logic
**测试文件路径**：`tests/unit/resource_system/test_resource_formulas.gd`
**测试内容**：
- dismantle_value(rarity, level) → int
- dismantle_crafted_value(rarity, level, is_crafted) → int
- sell_ling_cai_value(quality, quantity) → int
- delete_card_cost(delete_count) → int
- realm_gap_penalty(player_level, map_max_level) → float
- apply_ling_shi_bonus(base_amount, has_ling_shi_boost) → int
- 原始类型参数（非领域对象）——纯函数无副作用

**需要覆盖的边界情况**：
- dismantle_value(1,1)=10, (4,1)=400, (5,20)=3900（暗金满级设计上限）
- dismantle_crafted_value 折价 50%
- sell_ling_cai_value 无效 quality → 0
- delete_card_cost(1)=50, (5)=150
- realm_gap_penalty 保底 0.1（gap>=3）
- apply_ling_shi_bonus floor(25×1.15)=28
- GDD §公式 1/1b/2/3/6/7 + §验收标准 AC-6~15 直接引用

**预估测试数量**：~22 个单元测试（对应 AC-001~022）

---

### faction/001 FACTION_LIBRARY + 标签查询 — Logic
**测试文件路径**：`tests/unit/faction_system/test_faction_library_query.gd`
**测试内容**：
- FactionSystem extends Node（Autoload #15，不声明 class_name）
- FactionRelation 枚举（SAME=0/HOSTILE=1/NEUTRAL=2）
- const FACTION_LIBRARY（18 标签：2 大阵营 + 12 门派 + 4 跨阵营）
- get_tag_info / get_major_alignments / derive_major_alignment
- get_tags_of_character / belongs_to_alignment
- _ready 为空（const 编译时分配）

**需要覆盖的边界情况**：
- 无效 tag_id → 空 Dictionary + push_warning
- 门派推导大阵营（qixuanmen → zhengdao）
- 跨阵营标签 parent_alignment=&""（碎星群岛）
- 大阵营自身推导返回自身
- AC-016~018 跨 Epic 依赖 card-system（集成测试在 Story 002）
- FactionSystem 不发射信号（AC-019）

**预估测试数量**：~20 个单元测试（AC-001~015 独立测试；AC-016~018 依赖 CardSystem 移至 Story 002 集成测试）

---

### faction/002 场上统计 + 判定 — Integration
**测试文件路径**：`tests/integration/faction_system/test_faction_field_stats_judgment.gd`
**测试内容**：
- count_on_field(tag_or_alignment) 实时遍历（O(6×3)）
- get_field_faction_distribution 场上分布快照
- check_condition(requirement) 阵法条件判定
- is_hostile_to / get_alignment_relation 三层关系
- 阵亡角色自动不计入（依赖 CardSystem.get_field_characters）

**需要覆盖的边界情况**：
- 门派角色自动计入大阵营（青云剑宗 → 正道）
- 同一角色只计一次（break 机制）
- 跨阵营角色 → NEUTRAL
- CardSystem 不可用 → count_on_field 返回 0
- 阵亡角色从场上列表移除 → 不计入
- ADR-0018 §验证标准 11 条直接引用

**预估测试数量**：~20 个集成测试（对应 AC-001~020）

---

### 拆分 event_system.gd — Refactor
**测试文件路径**：无新增测试——重跑全部 520 现有测试验证零回归
**测试内容**：
- 拆分后 event_system.gd ≤300 行
- 提取条件判定引擎到 event_condition_evaluator.gd
- 全部 520 测试通过（Sprint 1 基线）

**需要覆盖的边界情况**：
- 拆分前后测试结果完全一致
- 信号连接无丢失
- GSM 第二层方法调用无中断

**预估测试数量**：0 新增（重跑 520 现有）

---

## 手动 QA 检查清单

### project.godot Autoload 顺序验证 — Task
**验证方法**：手动检查 project.godot 文件
**必须签收人**：lead-programmer
**需要捕获的证据**：project.godot [autoload] 段截图或文本

检查清单：
- [ ] CardSystem（#6）在 FactionSystem（#15）之前注册
- [ ] CardSystem（#6）在 ResourceSystem（#16）之前注册
- [ ] GSM（#1）在所有 Core Autoload 之前
- [ ] 25 个 Autoload 全部存在且顺序正确

---

## 冒烟测试范围

在此 sprint 的任何 QA 交接前需要验证的关键路径：

1. 游戏启动到主菜单无崩溃（Foundation 层无回归）
2. 可以开始新游戏/新会话
3. **Core 层新增机制**：
   - CardSystem 模板加载 + 实例创建
   - RealmSystem 境界查询 + realm_up 编排
   - ResourceSystem 灵石/灵材读写
   - FactionSystem 阵营标签查询 + 场上统计
4. **回归风险系统**：
   - event_system.gd 拆分后全部 520 测试通过
   - GSM 第二层新方法（_set_resource_ling_shi/_set_resource_ling_cai）不破坏既有 batch_updated 流程
   - Autoload #15/#16 初始化不阻塞 Foundation 层
5. 存档/读档周期完成无数据丢失（SaveLoadSystem 不受 Core 层影响）
6. 性能在目标硬件上符合预算（Core 层为数据查询，预计无帧尖峰）

*冒烟测试由开发者通过 `/smoke-check sprint` 验证。运行该技能时参考此列表。*

---

## 试玩要求

| Story | 试玩目标 | 最少会期数 | 目标玩家类型 |
|-------|--------------|--------------|-------------------|
| 无 | Core 层为数据/逻辑层，无面向玩家 UI，无需试玩 | 0 | — |

*本次 sprint 无需试玩会期。Core 层系统在 Feature 层（战斗、探索）实现后才会有面向玩家的交互。*

---

## 完成定义 — 本次 Sprint

当以下所有条件都满足时，story 才算完成：

- [ ] 所有验收标准已验证 — 通过自动化测试结果（179 AC 全覆盖）
- [ ] 所有逻辑和集成类 story 的测试文件存在于指定路径（12 个测试文件）
- [ ] 拆分 event_system.gd 后全部 520 现有测试通过（零回归）
- [ ] project.godot Autoload 顺序手动验证通过
- [ ] 冒烟检查通过（在 QA 交接前运行 `/smoke-check sprint`）
- [ ] 未引入回归问题
- [ ] 代码已审查（通过 `/code-review` 或记录的同行评审）
- [ ] Story 文件已更新为 `Status: Complete`（通过 `/story-done`）

---

## 控制清单规则（Core 层 + Foundation 层）— 自动化测试防范

*From `docs/architecture/control-manifest.md` v2026-08-05:*

**Required 模式（测试须验证）**：
- Foundation/Core Autoload 绝不声明 `class_name`（AC-001 各系统）
- Foundation Autoload 测试用 `ES_SCRIPT.new()` + `var es: Node` 动态分派模式
- 动态分派返回值必须显式类型注解 `var x: Type = es.method()`
- 所有资源写入通过 ResourceSystem API（不直接写 GSM.player.resources）
- const Dictionary 作为编译时常量数据表

**Forbidden 模式（测试须防范）**：
- Autoload 声明 class_name → 测试用动态分派验证实例非 Nil
- 直接写 `GSM.player.resources.*` → grep 验证
- 消费者系统重定义资源公式 → grep 验证
- ResourceSystem 发射 resource_changed 信号 → get_signal_list 验证为空
- FactionSystem 发射任何信号 → get_signal_list 验证为空
- FactionSystem 监听 Deployment/Combat 信号维护缓存 → grep 验证无 connect 调用

---

## GDD 公式引用汇总

*测试用例直接引用以下 GDD 公式章节：*

### card-system.md
- §公式 拆解卡牌价值 dismantle_value（Story 005 序列化 + resource/002 公式）
- §边界情况 卡牌数据约束（Story 001 模板字段）

### realm-system.md
- §公式 3 realm_penalty 境界压制（Story 002）
- §公式 5 map_effective_realm 地图压制（Story 002）
- §5 DROP_POOL_WEIGHTS 5 池等级（Story 002）
- §4 max_cultivation 突破上限公式 1000/1500/2250/3375/5063（Story 001）
- §验收标准 delta=1→0.8, delta=2→0.5（Story 002）

### resource-system.md
- §公式 1 dismantle_value（Story 002）
- §公式 1b dismantle_crafted_value 折价 50%（Story 002）
- §公式 2 sell_ling_cai_value（Story 002）
- §公式 3 delete_card_cost（Story 002）
- §公式 6 apply_ling_shi_bonus（Story 002）
- §公式 7 realm_gap_penalty 保底 0.1（Story 002）
- §验收标准 AC-1~5 核心 API（Story 001）
- §边界情况 灵石不足不扣减、灵材品质校验（Story 001）

### faction-system.md
- §1 阵营标签结构 18 标签（Story 001）
- §公式 2 alignment_relation 三层判定（Story 002）
- §边界情况 阵亡不计入、跨阵营中立（Story 002）

---

## 测试文件路径汇总

| 系统 | 类型 | 路径 |
|------|------|------|
| card_system | unit | `tests/unit/card_system/test_card_template.gd` |
| card_system | unit | `tests/unit/card_system/test_card_instance.gd` |
| card_system | integration | `tests/integration/card_system/test_template_registry.gd` |
| card_system | integration | `tests/integration/card_system/test_factory_gsm.gd` |
| card_system | integration | `tests/integration/card_system/test_serialization.gd` |
| realm_system | unit | `tests/unit/realm_system/test_realm_table.gd` |
| realm_system | unit | `tests/unit/realm_system/test_realm_calculation.gd` |
| realm_system | integration | `tests/integration/realm_system/test_realm_up.gd` |
| resource_system | integration | `tests/integration/resource_system/test_resource_read_write_api.gd` |
| resource_system | unit | `tests/unit/resource_system/test_resource_formulas.gd` |
| faction_system | unit | `tests/unit/faction_system/test_faction_library_query.gd` |
| faction_system | integration | `tests/integration/faction_system/test_faction_field_stats_judgment.gd` |

**总计**：12 个测试文件，预估 ~169 测试函数，179 AC 全覆盖
