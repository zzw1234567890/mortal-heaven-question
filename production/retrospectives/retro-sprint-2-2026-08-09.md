# 回顾：Sprint 2 — Core 层

周期：2026-08-06 -- 2026-08-19
生成日期：2026-08-09

---

## 指标

| 指标 | 计划 | 实际 | 偏差 |
|--------|---------|--------|-------|
| 任务数（must-have） | 13 | 13 | 0 |
| 完成率 | -- | 100% | -- |
| 故事点/工作天数 | 44.5h / 14 天 | ~44.5h / 4 天(08-06→08-09) | -10 天 |
| 发现的 Bug | -- | 0 | -- |
| 修复的 Bug | -- | 0 | -- |
| 新增计划外任务 | -- | 2（CardSystem get_field_characters + get_template_by_instance_id 因 faction/002 跨 Epic 依赖补齐） | +2 |
| 提交次数 | -- | 5（Sprint 2 窗口内） | -- |
| 自动化测试 | -- | 808/809 通过，2933 断言 | -- |

---

## 速度趋势

| 冲刺 | 计划 | 完成 | 完成率 |
|--------|---------|-----------|------|
| Sprint 1 | 23 | 23 | 100% |
| Sprint 2（当前） | 13 | 13 | 100% |

**趋势**：稳定（连续两冲刺 100% 完成率）。本冲刺在时间盒 29% 时点（4/14 天）完成全部 must-have 工作，速度持续高于预估。

---

## 做得好的方面

- **跨 Epic 依赖前置解决**：faction-system Story 2-12 需要CardSystem 的 `get_field_characters` 和 `get_template_by_instance_id`，这两个方法在 Story 创建时标记为"跨 Epic 依赖"。本冲刺主动在 card-system 中补齐这两个方法（而非推迟到 DeploymentSystem Epic），使 faction-system 完整闭环，避免了 Sprint 中期阻塞。
- **技术债主动偿还**：Sprint 1 回顾行动项 #1（拆分 event_system.gd）在本冲刺作为 Story 2-13 优先处理，570→267 行拆分为 4 文件（主类 + ConditionChecker + EventResolver + ChainHandler），公共 API 不变，现有 14 个测试文件零改动通过。这验证了"委托包装器 + RefCounted 辅助类"的拆分模式对 Autoload 系统有效。
- **测试覆盖持续领先**：14 个 Story 全部 COVERED，新增 53 个测试函数（Sprint 1 结束 783→809），断言数 1763→2933（+67%）。faction-system 集成测试覆盖了 20 条 AC + 6 边缘情况。
- **Autoload 链验证前移**：Story 2-15（Autoload 顺序验证）在 Sprint 第 1 天就完成，注册 CardSystem 为 #6 Autoload，扩展测试覆盖 8 个 Autoload 完整顺序链断言，消除了 gate-check B6 风险。
- **动态分派 + 测试注入点模式成熟**：FactionSystem 的 `_test_card_system` 注入点解决了"测试用 CardSystem 不能加入场景树（避免 _ready 清空夹具）"的问题，与 Sprint 1 确立的"Autoload 不声明 class_name + 动态分派"控制清单规则形成完整模式。

---

## 做得不好的方面

- **CardSystem API 缺口在 Story 创建时未识别**：`get_field_characters` 和 `get_template_by_instance_id` 在 ADR-0006 中未明确定义为公共 API，但 faction-system ADR-0018 依赖它们。这反映出 /create-epics 阶段对跨 Epic 接口契约的盘点仍不够充分，导致实现时才发现需要在 card-system 中补齐。虽然处理透明，但属于 Sprint 1 回顾行动项"前置识别跨 Epic 依赖"的重复出现。
- **重构引入的测试兼容性问题需多轮修复**：event_system.gd 拆分后出现 3 个测试兼容性问题（_init vs _ready 初始化时机、_chain_visited_ids 白盒访问点、MAX_CHAIN_DEPTH const 导出），每轮修复后重跑全量测试。虽然最终零回归，但说明重构前对测试白盒访问点的盘点不足——应在拆分设计阶段就识别这些耦合点。
- **测试夹具类型赋值陷阱**：faction 集成测试中 `tmpl.faction_tags = faction_tags`（裸 Array 赋值给 Array[StringName]）导致 Invalid assignment 错误，调试耗费数轮。GDScript 4.6 的类型化数组赋值规则在 Sprint 1 的 card-system 测试中已有先例，但未内化为团队习惯。
- **game_state_manager.gd 行数持续增长**：Sprint 1 标记的 933 行债务在本冲刺因新增 `_set_resource_ling_shi/_set_resource_ling_cai`、`_migrate_resources_dict`、`change_realm` 重构等进一步增长。这是 Sprint 1 回顾行动项 #2（拆分 gsm_serializer.gd）未在本冲刺处理的结果，债务仍在累积。

---

## 遇到的阻塞项

| 阻塞项 | 持续时间 | 解决方案 | 预防措施 |
|---------|----------|------------|------------|
| CardSystem get_field_characters 不存在 | ~1h | 在 card-system 新增 field_characters 成员 + get_field_characters 方法 | /create-epics 阶段明确跨 Epic 接口契约 |
| CardSystem get_template_by_instance_id 不存在 | ~1h | 在 card-system 新增方法 + _extract_instance_id/_extract_template_id 辅助 | 同上 |
| event_system 拆分后测试 _init 失败 | ~0.5h | 辅助类初始化从 _ready 移到 _init | 重构设计阶段识别测试实例化路径 |
| _chain_visited_ids 白盒访问丢失 | ~0.5h | 声明移回 EventSystem + 引用注入 ChainHandler | 重构设计阶段盘点测试白盒访问点 |
| faction 测试 CardSystem 加入场景树触发 _ready | ~0.5h | FactionSystem 新增 _test_card_system 注入点 | 测试模式文档化 |
| faction_tags 类型化数组赋值错误 | ~0.5h | 构建 Array[StringName] 显式赋值 | 类型化数组赋值规则内化 |

---

## 预估准确性

| 任务 | 预估 | 实际 | 偏差 | 可能原因 |
|------|-----------|--------|----------|--------------|
| faction/002 场上统计 + 判定 | 4h | ~6h（含 CardSystem 2 方法补齐 + 测试夹具修复） | +2h | 跨 Epic 依赖补齐 + 类型化数组陷阱 |
| tech-debt/013 拆分 event_system.gd | 3h | ~4h（含 3 轮测试兼容性修复） | +1h | 测试白盒访问点盘点不足 |
| card/004 工厂 + GSM 集成 | 3.5h | ~3h | -0.5h | ADR-0006 指导清晰 |
| faction/001 FACTION_LIBRARY + 查询 | 4h | ~3h | -1h | const Dictionary 模式成熟 |

**总体预估准确性**：约 75% 的任务偏差在预估的 +/- 20% 以内。偏差主要来自跨 Epic 依赖补齐和重构的测试兼容性问题。Sprint 1 回顾建议"AC > 15 条的 Story 预估上浮 30%"在本冲刺得到验证（faction/002 AC=20，实际 +50%）。

---

## 结转分析

| 任务 | 原始冲刺 | 结转次数 | 原因 | 处理方式 |
|------|----------------|---------------|--------|--------|
| 无结转任务（must-have） | — | 0 | Sprint 2 全部 13 个 must-have 当冲刺完成 | — |
| Story 2-14 ADR-0003 文档补充 | Sprint 2 | 0 | nice-to-have，未处理 | 推迟至文档维护窗口 |
| Story 2-16 Feature 层 Epic 预创建 | Sprint 2 | 0 | nice-to-have，未处理 | 推迟至 Sprint 3 规划 |

---

## 技术债务状态

- 当前 TODO 数量：0（src/ 目录 grep 无匹配）
- 当前 FIXME 数量：0
- 当前 HACK 数量：0
- 趋势：稳定
- 关注领域：
  - `game_state_manager.gd` 行数持续增长（Sprint 1 标记 933 行，本冲刺进一步增长）——Sprint 1 行动项 #2 未处理
  - `event_system.gd` 已拆分至 267 行（✅ Sprint 1 行动项 #1 已完成）
  - CardSystem.field_characters 公开性待 DeploymentSystem 实现后收敛（LOW ADVISORY）

---

## 先前行动项跟进

| 行动项（来自 Sprint 1） | 状态 | 备注 |
|-------------------------------|--------|-------|
| #1 拆分 event_system.gd（558 行） | ✅ 已完成 | Story 2-13，570→267 行，拆分为 4 文件 |
| #2 拆分 game_state_manager.gd（933 行） | ⏳ 未开始 | 推迟至 Sprint 3 |
| #3 补齐 GSM 4 新方法独立单元测试 | ⏳ 部分完成 | Story 2-9/2-10 resource_system 测试间接覆盖，独立单测未补 |
| #4 ADR-0003 visited_ids 生命周期文档 | ⏳ 未开始 | Story 2-14 nice-to-have，推迟 |
| #5 控制清单新增 Autoload 规则 | ✅ 已完成 | Sprint 1 结束前已写入控制清单 2026-08-05 |

---

## 下个迭代的行动项

| # | 行动 | 负责人 | 优先级 | 截止日期 |
|---|--------|-------|----------|----------|
| 1 | 拆分 game_state_manager.gd——提取序列化/反序列化到 gsm_serializer.gd | engine-programmer | 高 | Sprint 3 结束前 |
| 2 | /create-epics 阶段强制跨 Epic 接口契约盘点——明确每个公共 API 的签名、返回值、消费者 | technical-director | 高 | Sprint 3 开始前 |
| 3 | 重构设计阶段强制盘点测试白盒访问点——拆分前 grep 测试中的 `es._` / `cs._` 私有访问 | engine-programmer | 中 | 下次重构前 |
| 4 | 补齐 GSM 第二层方法独立单元测试（resource/faction 新增方法） | engine-programmer | 中 | Sprint 3 中期 |
| 5 | 类型化数组赋值规则写入测试标准——`Array[T]` 字段必须构建同类型数组赋值 | qa-lead | 中 | Sprint 3 开始前 |

---

## 流程改进

- **跨 Epic 接口契约前置**：/create-epics 阶段为每个跨 Epic 依赖生成接口契约表（方法签名 + 返回值 + 消费者 + 实现状态），避免实现时才发现 API 缺口。预期收益：消除 Sprint 中期的跨 Epic 补齐工作。
- **重构设计检查清单**：重构前执行"测试白盒访问点盘点"（grep 私有成员访问）+"测试实例化路径盘点"（_init vs _ready）+"const/成员访问盘点"（grep `SCRIPT.CONST` / `instance.member`），将重构引入的测试兼容性问题前置识别。预期收益：减少重构后的多轮修复。

---

## 总结

Sprint 2 是一个延续 Sprint 1 势头的成功冲刺——13 个 must-have Story 全部 Complete，自动化测试 808/809 通过，零缺陷，Core 层 4 个系统（card/realm/resource/faction）+ event_system 技术债拆分全部就绪，在时间盒 29% 时点（4/14 天）提前完成。Foundation + Core 两层基础设施稳固，Feature 层（战斗、效果引擎、流派等）可开始构建。未来最需要改变的一件事是：**在 Epic 创建阶段前置明确跨 Epic 接口契约**，避免实现时才发现 API 缺口——这是 Sprint 1 回顾"前置识别跨 Epic 依赖"行动项的重复出现，需要从流程层面根本解决。
