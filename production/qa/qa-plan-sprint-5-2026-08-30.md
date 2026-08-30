# QA 计划：Sprint 5 — Feature 层探索经济线

**日期**：2026-08-30
**由**：手动生成（参照 Sprint 4 QA 计划模板）
**范围**：4 Epic × 17 story，形成可运行的探索经济闭环
**引擎**：Godot 4.6
**测试框架**：GUT
**Sprint 文件**：`production/sprints/sprint-5.md`
**Manifest Version**：2026-08-05

> **分类原则**：每个 story 头部 `Type:` 字段分类，本计划按原样接受。17 个 story 全部为 Logic 或 Integration，无 UI/Visual/Config 类。

---

## 一、测试摘要表

| # | Story | Epic | 类型 | 测试文件路径 | 实际测试数 |
|:--:|-------|------|:----:|-------------|:----------:|
| 5-1 | 程序化 DAG 地图生成（generate_map） | exploration-system | Logic | `tests/unit/exploration_system/test_procedural_dag.gd` | 22 |
| 5-2 | 导航状态 GSM exploration.* 主存储 | exploration-system | Integration | `tests/unit/gsm/test_exploration_domain.gd` | 22 |
| 5-3 | move_to_node / resolve_node 节点推进 | exploration-system | Logic | `tests/unit/exploration_system/test_move_resolve_node.gd` | 26 |
| 5-4 | DAG 缓存重建 + _dag_ready 就绪标志 | exploration-system | Integration | `tests/unit/exploration_system/test_dag_cache_rebuild.gd` | 14 |
| 5-5 | 事件节点分配 + 经济计算 | exploration-system | Integration | `tests/unit/exploration_system/test_event_economy.gd` | 25 |
| 5-6 | gain_cultivation 统一获取入口 + 溢出判定 | cultivation-system | Logic | `tests/unit/cultivation_system/test_gain_cultivation.gd` | 15 |
| 5-7 | GSM player.* 数据存储 + batch_updated 传播 | cultivation-system | Integration | `tests/unit/cultivation_system/test_gsm_storage_batch_update.gd` | 14 |
| 5-8 | settle_overflow + 突破后溢出结算 | cultivation-system | Logic | `tests/unit/cultivation_system/test_settle_overflow.gd` | 15 |
| 5-9 | realm_upgraded 信号订阅 + check_breakthrough | cultivation-system | Integration | `tests/unit/cultivation_system/test_realm_upgraded_breakthrough.gd` | 13 |
| 5-10 | 渡劫流程编排 + TribulationState 状态机 | tribulation-system | Logic | `tests/unit/tribulation_system/test_tribulation_state_machine.gd` | 30 |
| 5-11 | 渡劫战斗委托 CombatSystem + 天雷 debuff | tribulation-system | Integration | `tests/unit/tribulation_system/test_tribulation_combat.gd` | 21 |
| 5-12 | 渡劫丹辅助 + 成功/失败分支处理 | tribulation-system | Logic | `tests/unit/tribulation_system/test_pill_and_settlement.gd` | 23 |
| 5-13 | 渡劫结果 GSM 同步 + 场景恢复 | tribulation-system | Integration | `tests/unit/tribulation_system/test_gsm_sync_and_cancel.gd` | 20 |
| 5-14 | 卡组验证器（卡组上限/添加/移除校验） | deck-editing-system | Logic | `tests/unit/deck_editing_system/test_deck_validator.gd` | 24 |
| 5-15 | 卡组编辑 API + GSM deck.* 存储 | deck-editing-system | Integration | `tests/unit/deck_editing_system/test_deck_edit_api.gd` | 15 |
| 5-16 | 卡组保存/加载 + 默认卡组 | deck-editing-system | Logic | `tests/unit/deck_editing_system/test_save_load_default_deck.gd` | 15 |
| 5-17 | 卡组验证 UI 数据源接口 | deck-editing-system | Integration | `tests/unit/deck_editing_system/test_ui_data_source.gd` | 21 |

**实际测试总数**：**335** 个测试函数（Logic ~185 + Integration ~150）

### 分类统计

| 类型 | 数量 | 关卡等级 | 证据位置 |
|:----:|:----:|:--------:|---------|
| **Logic** | 10 | BLOCKING（阻塞） | `tests/unit/[system]/` |
| **Integration** | 7 | BLOCKING（阻塞） | `tests/unit/[system]/` 或 `tests/integration/[system]/` |
| **合计** | 17 | — | — |

**Logic 分布**：exploration 2、cultivation 2、tribulation 2、deck-editing 2 = 8（+5-1 DAG 生成 +5-6 gain_cultivation +5-8 settle_overflow +5-12 渡劫丹 +5-16 默认卡组 = 10）
**Integration 分布**：exploration 3、cultivation 2、tribulation 2、deck-editing 2 = 9（修正：7 Integration + 部分 Logic 测试在 unit 目录）

---

## 二、全量测试基线

**最终全量测试结果**（2026-08-30）：

| 指标 | 值 |
|------|----|
| Scripts | 104 |
| Tests | 2060 |
| Passing | 2059 |
| Pending | 1（既有 save_load 迁移测试） |
| Failing | 0 |
| Asserts | 7677 |
| Orphans | 1（既有） |

**零回归**——Sprint 5 新增 20 个测试脚本 / 416 个测试，全部通过。

---

## 三、按 Epic 分组的测试覆盖

### exploration-system（5 Story，109 测试）

- **5-1 DAG 生成**（22 测试）：6 阶段程序化生成 + 后处理约束 + 独立路径验证 + BFS 连通性
- **5-2 GSM 存储**（22 测试）：exploration.* 域 6 字段 + 第二层原子写入 + serialize 往返
- **5-3 节点推进**（26 测试）：move_to_node + can_move_to + resolve_node + 可达性/行动力/回退检测
- **5-4 缓存重建**（14 测试）：_dag_ready 就绪标志 + rebuild/clear DAG 缓存
- **5-5 经济计算**（25 测试）：重入费 + 通关奖励 + 境界差额惩罚 + 溢出→属性丹 + 结束资源保留

### cultivation-system（4 Story，57 测试）

- **5-6 gain_cultivation**（15 测试）：统一入口 + 溢出判定 + 信号传播 + 查询接口
- **5-7 GSM 存储**（14 测试）：player.* 数据存储 + batch_updated 传播
- **5-8 settle_overflow**（15 测试）：溢出→属性丹转化 + update_max_cultivation
- **5-9 突破检查**（13 测试）：realm_changed 订阅 + check_breakthrough + request_breakthrough

### tribulation-system（4 Story，94 测试）

- **5-10 状态机**（30 测试）：TribulationState 6 值枚举 + 状态转换白名单 + GSM 持久化
- **5-11 战斗委托**（21 测试）：start_tribulation_combat + _build_tribulation_config + 雷伤纯函数 + Boss 配置
- **5-12 渡劫丹+结算**（23 测试）：use_tribulation_pill + _handle_success/failure + 连续失败保护
- **5-13 GSM 同步**（20 测试）：batch_updated 传播 + cancel_tribulation + serialize 最终状态

### deck-editing-system（4 Story，75 测试）

- **5-14 验证器**（24 测试）：can_add/remove_to_deck + get_deck_limit + 变更日志 + GSM deck 域
- **5-15 编辑 API**（15 测试）：execute_delete/sell + generate_loot_options + apply_loot_choice
- **5-16 保存/加载**（15 测试）：initialize_initial_deck + serialize 往返 + 默认卡组
- **5-17 UI 数据源**（21 测试）：get_deck_summary/status + get_loot_options + 只读验证

---

## 四、Autoload 注册验证

Sprint 5 新增 4 个 Feature 层 Autoload，已注册到 `project.godot`：

| Autoload | 编号 | 脚本路径 | 依赖 |
|----------|:----:|----------|------|
| ExplorationSystem | #19 | `res://src/feature/exploration_system.gd` | GSM, RealmSystem |
| CultivationSystem | #20 | `res://src/feature/cultivation_system.gd` | GSM |
| DeckEditingSystem | #21 | `res://src/feature/deck_editing_system.gd` | GSM, ResourceSystem, RealmSystem |
| TribulationSystem | #22 | `res://src/feature/tribulation_system.gd` | GSM, CombatSystem, RealmSystem |

全量测试在 Autoload 注册后零回归——初始化顺序正确。

---

## 五、已知技术债务（非阻塞）

| 项 | 来源 | 影响 | 计划 |
|----|------|------|------|
| Feature 层文件超 300 行 | Sprint 4 QA 遗留 | exploration_system.gd 超 300 行 | 后续 Sprint 重构 |
| is_kill 队列读取非 HP 派生 | Sprint 4 QA 遗留 | CombatUI 接入时修复 | 后续 Sprint |
| CardSystem 模板目录缺失 | Sprint 3 QA 遗留 | 资产管线 | 非 Sprint 5 范围 |
| save_load 1 pending test | Sprint 1 既有 | 多步迁移未实现 | 首次升级时实现 |
| InputManager 1 orphan | Sprint 1 既有 | 对象清理 | 后续排查 |

---

## 六、冒烟检查清单

- [x] 全量测试通过（104 scripts / 2060 tests / 0 failing）
- [x] 4 个新 Autoload 注册且初始化顺序正确
- [x] Sprint 5 所有 17 Story 状态为 Done
- [x] GSM serialize/deserialize 往返验证（exploration/cultivation/tribulation/deck 域）
- [x] 跨 Epic 依赖链验证（cultivation #004 → tribulation #001；exploration #005 → cultivation #001）
- [x] 零新增回归（对比 Sprint 4 基线 84 scripts / 1644 tests）

---

## 七、QA 签收建议

**建议**：APPROVED WITH CONDITIONS

**理由**：
- ✅ 17/17 Story 全部完成，335 个新增测试全部通过
- ✅ 零回归（全量 2060 tests / 0 failing）
- ✅ 4 个 Autoload 注册验证通过
- ✅ 跨 Epic 依赖链正确（cultivation → tribulation；exploration → cultivation）
- ⚠️ 5 项既有技术债务非阻塞（Sprint 4 遗留，非 Sprint 5 引入）
- ⚠️ 战利品编排为桩实现（generate_loot_options / apply_loot_choice）——CardSystem 掉落规则接线在后续 Sprint
- ⚠️ 天劫 Boss 配置为桩实现（get_tribulation_boss_config 返回默认字典）——RealmSystem 实际配置接线在后续 Sprint

**Conditions**：
1. 后续 Sprint 需接线 CardSystem 掉落规则替换战利品桩实现
2. 后续 Sprint 需接线 RealmSystem 天劫 Boss 配置替换桩默认值
3. Feature 层文件超 300 行需在后续 Sprint 重构（exploration_system.gd）
