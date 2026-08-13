# QA 计划：Sprint 3 — Core 层剩余系统 + 技术债

**日期**：2026-08-10  
**由**：/qa-plan 生成  
**范围**：9 个 must-have + 2 个 should-have + 1 个 nice-to-have，涉及 3 系统（cost/status-effect/school）+ GSM 技术债  
**引擎**：Godot 4.6.3  
**Sprint 文件**：`production/sprints/sprint-3.md`

> **注**：7 个 story 文件已全部创建，`## QA Test Cases` 章节已回填完毕（18+12+18+20+18+18+18 = 122 个测试用例）。3-1 `/create-stories` 步骤已完成，story 文件状态见 `production/sprint-status.yaml`。

---

## 测试摘要

| Story | 类型 | 需要自动化测试 | 需要手动验证 |
|-------|------|------------------------|------------------------------|
| 3-2 CostSystem 费用上限/恢复/临时加成 | Integration | 集成测试 — `tests/integration/cost_system/` | 冒烟检查 |
| 3-3 双重信号路径 | Logic | 单元测试 — `tests/unit/cost_system/` | 无 |
| 3-4 StatusEffect 8 阶段管线核心 | Integration | 集成测试 — `tests/integration/status_effect/` | 冒烟检查 |
| 3-5 3 叠加规则 + 免疫 + 20 上限 | Logic | 单元测试 — `tests/unit/status_effect/` | 无 |
| 3-6 snapshot 导出 + 暂挂/恢复排序 | Integration | 集成测试 — `tests/integration/status_effect/` | 冒烟检查 |
| 3-7 SchoolSystem 纯查询接口 | Logic | 单元测试 — `tests/unit/school_system/` | 无 |
| 3-8 5 流派增益公式 + 不可驱散 | Logic | 单元测试 — `tests/unit/school_system/` | 无 |
| 3-9 拆分 game_state_manager.gd | Refactor | 复用 GSM 现有测试（回归） | 无 |
| 3-10 GSM 第二层方法独立单测 | Task | 单元测试 — `tests/unit/gsm/` | 无 |
| 3-11 ADR-0003 文档补充 | Doc | — | 文档审查 |
| 3-1/3-12 create-stories/预创建 | Task/Planning | — | — |

---

## 需要自动化测试

### Story 3-2 — CostSystem 费用上限 + 全额恢复 + 临时加成（Integration）

**测试文件路径**：`tests/integration/cost_system/test_cost_system_basic.gd`

**测试内容**：
- `max_cost(realm) = 2 + (L-1)×3` 公式验证（炼气=2, 筑基=5, 金丹=8, 元婴=11, 化神=14）
- 每回合开始全额恢复至境界上限（不累积未使用费用）
- 后手第 1 回合额外 +1 费（仅第 1 回合）
- 临时费用叠加（低级+1/中级+2/高级+3，可突破上限）
- 临时费用回合结束清空，恢复标准上限
- `can_afford/spend/reset_for_turn/add_temp_bonus` 接口

**需要覆盖的边界情况**：
- 0 费卡不消耗费用（仍计入出牌操作）
- 临时费用叠加（2 张中级炼气丹 = +4 费）
- 临时费用突破上限（炼气期 + 高级炼气丹 = 2+3=5 费）
- 费用不足时 `can_afford` 返回 false

**预估测试数量**：~15 个集成测试

---

### Story 3-3 — 双重信号路径 cost_changed + batch_updated（Logic）

**测试文件路径**：`tests/unit/cost_system/test_cost_signals.gd`

**测试内容**：
- `cost_changed`（Cat 2b）即时发射——战斗热路径响应
- `batch_updated`（Cat 1）帧末批量发射——存档/HUD 刷新
- 两种信号发射时机区分（即时 vs 帧末）
- 信号载荷正确性（当前费用、上限、临时加成）

**需要覆盖的边界情况**：
- 连续多次 `spend` 只触发一次 `batch_updated`（帧末合并）
- `cost_changed` 每次即时触发（热路径不延迟）
- 临时加成变更触发 `cost_changed`

**预估测试数量**：~8 个单元测试

---

### Story 3-4 — StatusEffect 8 阶段管线核心（Integration）

**测试文件路径**：`tests/integration/status_effect/test_status_lifecycle.gd`

**测试内容**：
- StatusTemplate（Resource）+ StatusInstance（RefCounted）数据结构
- 8 阶段管线：施加检查 → 施加/合并 → 持续跟踪 → 倒计时 → 触发 → 暂挂 → 恢复 → 移除
- `apply_status` 返回 `ApplyResult`（applied/status_id/reason）
- `remove_status`/`clear_all_statuses` 接口
- `get_active_statuses`/`get_statuses_by_type`/`has_status` 读取接口

**需要覆盖的边界情况**：
- 同名状态不同来源（相同 `template_id`，按叠加规则处理）
- 永久状态（`duration=-1`）不参与倒计时
- 同回合施加的状态不立即倒计时（下一己方回合阶段 0 才减）
- `remove_status` 不存在 ID 返回 false（不报错）

**预估测试数量**：~20 个集成测试

---

### Story 3-5 — 3 叠加规则 + 免疫 + 20 上限（Logic）

**测试文件路径**：`tests/unit/status_effect/test_stacking_immunity.gd`

**测试内容**：
- `effective_value = base_value × current_stacks` 公式验证
- 3 叠加规则：独立（新建实例）/ 刷新（`duration=max(旧,新)`，`value=新`）/ 叠加上限（`stacks+1`，不超 `max_stacks`）
- 刷新规则：duration 取 `max(旧剩余, 新施加)` 防止反直觉
- 叠加上限溢出返回 `MAX_STACKS` 拒绝（不刷新，不消耗来源）
- 免疫多级检查顺序：类型免疫 → 模板免疫 → 属性免疫（短路求值）
- 20 活跃上限驱逐（最旧非永久状态先驱逐，永久/隐藏状态不受影响）
- `get_accumulated_value` 加法叠加（非乘法）

**需要覆盖的边界情况**：
- 叠加 vs 刷新优先级（先找同名，再判叠加规则）
- 免疫判定不消耗施加来源（卡牌仍进弃牌堆）
- 多层状态部分移除（3 层减 1 → 2 层，归 0 完全移除）
- 驱逐按 `applied_turn` 升序，同回合按 id 字典序决胜
- 隐藏状态不计入 `get_accumulated_value`（`is_hidden=true` 排除）

**预估测试数量**：~25 个单元测试

---

### Story 3-6 — snapshot 导出 GSM + 暂挂/恢复排序（Integration）

**测试文件路径**：`tests/integration/status_effect/test_snapshot_suspend.gd`

**测试内容**：
- 战斗结束 `serialize_all` → `Array[Dictionary]` 导出至 GSM
- snapshot 完整性（所有活跃状态字段）
- `suspend_statuses_by_source`（仅非绑定来源——绑定由 BindingManager 处理）
- `restore_statuses` 恢复暂挂状态（duration 保持暂挂前值）
- 暂挂/恢复与 BindingManager 排序契约（先 BindingManager、后 StatusEffectSystem）
- `remove_statuses_by_source` 批量移除

**需要覆盖的边界情况**：
- 暂挂期间来源卡牌移除 → 恢复时自动移除（日志 WARN）
- 角色永久死亡 → 暂挂状态销毁（不触发 `status_removed`）
- `remove_statuses_by_source` 零匹配返回 0（不报错）
- 暂挂状态来源引用 `source_card_instance_id` 保持

**预估测试数量**：~12 个集成测试

---

### Story 3-7 — SchoolSystem const + 纯查询接口（Logic）

**测试文件路径**：`tests/unit/school_system/test_school_library_query.gd`

**测试内容**：
- SCHOOL_LIBRARY 5 流派数据完整性（righteous_dev/demonic_aggro/mixed_alignment/spirit_realm_beast/alchemy_mastery）
- `get_school_info(id)` 返回流派元数据（name/tagline/description/effects/weakness）
- `detect(state)` 流派检测（优先级：归墟 > 正道 > 魔道 > 正邪 > 百艺）
- `calculate_match(school, state)` 匹配度计算（加权平均，0-100）
- 优先级选择（同时满足多条件 → 选最高优先级）

**需要覆盖的边界情况**：
- 无流派激活返回 null（匹配度仍可查询）
- 百艺炼丹流需运营进度（`alchemy_count ≥ 3`）
- 归墟真灵流需境界 ≥ 金丹（L≥3）
- 流派检测以场上角色为准（非卡组）

**预估测试数量**：~18 个单元测试

---

### Story 3-8 — 5 流派增益公式 + 不可驱散约束（Logic）

**测试文件路径**：`tests/unit/school_system/test_school_effects.gd`

**测试内容**：
- 正道发育流：减伤 -1（最低 1）、回合回复 2HP、阵法激活条件 -1
- 魔道快攻流：前 3 回合 ATK+2、击杀抽 1 牌、首回合费用 +1
- 正邪混合流：双方 +1 ATK/+1 DEF、共鸣 30% 减费
- 归墟真灵流：HP+3/ATK+1、免疫恐惧混乱、光环 +1HP/人
- 百艺炼丹流：丹药 +20%、灵材消耗 -1、每 3 丹药回 1AP
- 不可驱散约束（StatusEffectSystem 驱散免疫——系统级效果）

**需要覆盖的边界情况**：
- 魔道快攻第 4 回合 ATK 加成失效
- 归墟光环叠加（3 归墟角色 → 全体 +3HP）
- 百艺丹药加成（回复 100HP → 实际 120HP）
- 流派切换时旧增益立即清空（不叠加）
- 流派增益不可被 `StatusEffectSystem.remove_status` 移除

**预估测试数量**：~20 个单元测试

---

### Story 3-9 — 拆分 game_state_manager.gd（Refactor 回归）

**测试文件路径**：复用 GSM 现有测试（`tests/unit/gsm/` + `tests/integration/gsm/`）

**测试内容**：
- 1016 行 → ≤300 行（提取 `gsm_serializer.gd`）
- 公共 API 签名不变
- 全量 809 测试零回归

**需要覆盖的边界情况**：
- 测试白盒访问点（`_pending_changes`、`_next_card_instance_id` 等）保留
- Autoload 初始化路径（`_init` vs `_ready`，同 event_system 拆分模式）
- const/成员访问盘点（`SCRIPT.CONST` 等）

**预估测试数量**：复用现有 809 测试（0 新增，验证零回归）

---

### Story 3-10 — GSM 第二层方法独立单测（Task）

**测试文件路径**：`tests/unit/gsm/test_tier2_methods.gd`

**测试内容**：
- `allocate_card_id` 单调递增
- `_set_resource_ling_shi`/`_set_resource_ling_cai`（含 `max(0,value)` 守卫）
- `change_realm`（帧末批量发射 `realm_changed`）
- `remove_card_from_collection`/`restore_action_points`/`unlock_talent`/`advance_chapter`

**预估测试数量**：~10 个单元测试

---

## 手动 QA 检查清单

### Story 3-11 — ADR-0003 文档补充（Doc）

**验证方法**：文档审查  
**必须签收人**：technical-director  
**需要捕获的证据**：更新后的 ADR-0003 §visited_ids 生命周期章节

检查清单：
- [ ] 场景 a/b/d 清空契约已文档化
- [ ] 循环检测算法说明完整
- [ ] 与 `chain_handler.gd` 实现一致

---

## 冒烟测试范围

在此 sprint 的任何 QA 交接前需要验证的关键路径：

1. 项目启动无崩溃（Autoload 链 #1-#19 初始化）
2. 可以开始新游戏/新会话
3. CostSystem 费用上限/恢复/临时加成正常
4. StatusEffect 8 阶段管线无崩溃（施加/叠加/倒计时/移除）
5. SchoolSystem 5 流派检测正常
6. game_state_manager.gd 拆分后全量测试零回归
7. 存档/读档周期完成无数据丢失
8. 性能在目标硬件上符合预算

---

## 试玩要求

| Story | 试玩目标 | 最少会期数 | 目标玩家类型 |
|-------|--------------|--------------|-------------------|
| 无 | Core 层无玩家可见 UI，试玩在 Feature 层（战斗系统）接入后进行 | — | — |

**签收要求**：本次 sprint 无需试玩会期。Core 层系统通过自动化测试 + 冒烟检查验证。

---

## 完成定义 — 本次 Sprint

- [ ] 所有验收标准已验证 — 通过自动化测试结果或记录的手动证据
- [ ] 所有逻辑和集成类 story 的测试文件存在于指定路径
- [ ] 冒烟检查通过（在 QA 交接前运行 `/smoke-check sprint`）
- [ ] 未引入回归问题（game_state_manager.gd 拆分后全量 809 测试通过）
- [ ] 代码已审查（通过 `/code-review`）
- [ ] Story 文件已更新为 `Status: Complete`（通过 `/story-done`）
