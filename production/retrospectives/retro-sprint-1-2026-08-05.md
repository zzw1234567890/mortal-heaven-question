# 回顾：Sprint 1 — Foundation 层

周期：2026-07-27 -- 2026-08-10
生成日期：2026-08-05

---

## 指标

| 指标 | 计划 | 实际 | 偏差 |
|--------|---------|--------|-------|
| 任务数 | 23 | 23 | 0 |
| 完成率 | -- | 100% | -- |
| 故事点/工作天数 | 74h / 14 天 | 74h / 9 天(07-27→08-04) | -5 天 |
| 发现的 Bug | -- | 0 | -- |
| 修复的 Bug | -- | 0 | -- |
| 新增计划外任务 | -- | 1(Story 005 扩大范围补 GSM 4 方法) | +1 |
| 提交次数 | -- | 12(Sprint 1 窗口内) | -- |

---

## 速度趋势

| 冲刺 | 计划 | 完成 | 完成率 |
|--------|---------|-----------|------|
| Sprint 1（当前） | 23 | 23 | 100% |

**趋势**：首次冲刺，无历史对比基线。本冲刺在时间盒 64% 时点（9/14 天）完成全部计划工作，速度高于预估。

---

## 做得好的方面

- **自动化测试先行**：每个 Story 在实现同时编写 GUT 测试，最终 520/521 通过、1763 断言、零失败。Foundation 层 100% 故事拥有 BLOCKING 级测试证据，为后续 Sprint 提供了可靠回归基线。
- **ADR 驱动开发**：5 大系统均有 Accepted ADR 管辖（ADR-0001~0007），实现过程中发现的偏差（如 H-1 event_resolved 发射时机、Story 005 §4 add_cultivation 返回值文本错误）通过 code-review 透明记录而非静默偏离。
- **信号委托架构清晰**：Story 005 的 `card_reward_requested`（Cat 2c fire-and-forget）是 ADR-0007 的教科书级实现，Foundation 原则 #3（Foundation 不依赖 Core/Feature）通过信号解耦得到严格遵守，grep 验证零直接调用。
- **跨 Story 遗留项主动收尾**：Story 004 的 2 项 ADVISORY（选项不匹配残留、chain_triggered 连通性）在 Story 005 的 AC-020/021 主动覆盖，体现了对技术债务的负责任态度。
- **code-review 并行专家评审**：3 专家并行（godot-gdscript-specialist + godot-specialist + qa-tester）显著提升审查效率，交叉确认发现高度一致。

---

## 做得不好的方面

- **文件行数超标累积**：`event_system.gd` 558 行、`game_state_manager.gd` 933 行均超 300 行软限制。这是 Story 002/003/004/005 逐步累积的债务，每个 Story 关闭时都标记了 ADVISORY 但未触发拆分动作。系统级重构被持续推迟，后续 Sprint 若继续叠加将加剧可维护性风险。
- **Story 005 范围中途扩大**：/story-readiness 发现 AC-004/006/007/008 引用的 4 个 GSM 第二层方法不存在，经批准扩大范围在 GSM 中补齐。虽然处理透明，但反映出 /create-stories 阶段对 GSM 既有 API 的盘点不够充分，导致 Sprint 中期才发现跨 Epic 依赖缺口。
- **class_name 与 Autoload 冲突的试错成本**：Story 004 曾尝试为 EventSystem 添加 class_name，导致 402/486 测试失败后才回退。这个 Godot 4.6 固有权衡在 GSM/InputManager 已有先例，但未在 EventSystem Story 开局就规避，消耗了调试时间。
- **测试隔离性缺陷**：`test_card_reward_delegation.gd` 的 `_reset_gsm_state` 不完整、`test_apply_outcomes.gd` 的 `validation_enabled` 清理时机错误，均是 code-review 才发现的潜在 flaky 风险。测试标准要求"隔离性——每个测试自主设置和清理状态"，但实现时未严格遵守。

---

## 遇到的阻塞项

| 阻塞项 | 持续时间 | 解决方案 | 预防措施 |
|---------|----------|------------|------------|
| 目录合并后 global_script_class_cache.cfg 过时 | ~1h | 删除缓存 + headless 编辑器模式重扫 | git mv 后主动清理 .godot/ 缓存或运行一次编辑器重扫 |
| class_name EventSystem 与 Autoload 冲突 | ~1h | 回退为 extends Node + var es: Node 动态分派 | Foundation Autoload 统一不声明 class_name，写入控制清单 |
| 动态分派 `:=` 类型推断失败 | ~0.5h | 改为显式类型注解 | Autoload 测试模式文档化，在控制清单新增规则 |
| Story 005 GSM 4 方法缺失 | ~0.5h | 扩大 Story 005 范围补齐 | /create-stories 阶段强制盘点依赖 Epic 的既有 API |

---

## 预估准确性

| 任务 | 预估 | 实际 | 偏差 | 可能原因 |
|------|-----------|--------|----------|--------------|
| event/002 EventInstance + 触发/判定/结算 | 4h | ~6h(含 22 AC + 6 测试文件) | +2h | AC 数量多(22 条)、H-1/H-2/H-3 偏差处理 |
| event/005 结果执行器 + ADD_CARD 委托 | 4h | ~5h(含 GSM 4 方法补齐) | +1h | 跨 Epic 范围扩大 |
| gsm/001 Autoload 基础 + Tier1 读取 | 2.5h | ~2h | -0.5h | ADR-0001 指导清晰 |
| save/005 迁移链 + VERSION_MISMATCH | 3h | ~2.5h | -0.5h | 单步迁移设计简洁(1 pending 为预期) |

**总体预估准确性**：约 75% 的任务偏差在预估的 +/- 20% 以内。偏差主要来自 AC 数量密集的 event 系统 Story，以及跨 Epic 依赖发现。建议后续对 AC > 15 条的 Story 预估上浮 30%。

---

## 结转分析

| 任务 | 原始冲刺 | 结转次数 | 原因 | 处理方式 |
|------|----------------|---------------|--------|--------|
| 无结转任务 | — | 0 | Sprint 1 全部 23 Story 当冲刺完成 | — |

---

## 技术债务状态

- 当前 TODO 数量：0（src/ 目录 grep 无匹配）
- 当前 FIXME 数量：0
- 当前 HACK 数量：0
- 趋势：稳定（基线状态，无历史对比）
- 关注领域：文件行数超标（event_system.gd 558 + game_state_manager.gd 933）为隐性债务，虽未标记 TODO 但已在各 Story Completion Notes 记录 ADVISORY

---

## 先前行动项跟进

| 行动项（来自冲刺 N-1） | 状态 | 备注 |
|-------------------------------|--------|-------|
| 无 | — | Sprint 1 为首个冲刺，无历史行动项 |

---

## 下个迭代的行动项

| # | 行动 | 负责人 | 优先级 | 截止日期 |
|---|--------|-------|----------|----------|
| 1 | 拆分 event_system.gd（558 行）——提取条件判定引擎到 event_condition_evaluator.gd | engine-programmer | 中 | Sprint 2 结束前 |
| 2 | 拆分 game_state_manager.gd（933 行）——提取序列化/反序列化到 gsm_serializer.gd | engine-programmer | 中 | Sprint 3 结束前 |
| 3 | 补齐 GSM 4 个新第二层方法的独立单元测试（remove_card_from_collection / restore_action_points / unlock_talent / advance_chapter） | engine-programmer | 中 | GSM Epic 后续 Sprint |
| 4 | ADR-0003 §循环检测算法补充 visited_ids 生命周期说明（场景 a/b/d 清空契约） | technical-director | 低 | 下次文档维护窗口 |
| 5 | 控制清单新增规则：Foundation Autoload 不声明 class_name + 动态分派测试用显式类型注解 | technical-director | 高 | Sprint 2 开始前 |

---

## 流程改进

- **/create-stories 阶段强制 API 盘点**：创建 Story 时若涉及跨 Epic 依赖（如 Story 005 引用 GSM 方法），强制要求作者核对目标 Epic 的既有 API 清单，避免 Sprint 中期才发现缺口。预期收益：减少 Sprint 中期范围扩大。
- **AC 数量阈值预警**：当 Story 的 AC > 15 条时，/story-readiness 标记为"可能过大"并建议拆分或预估上浮 30%。预期收益：提升预估准确性，减少单 Story 工作量超载。

---

## 总结

Sprint 1 是一个成功的首个冲刺——23 个 Story 全部 Complete，自动化测试 520/521 通过，零缺陷，QA APPROVED，在时间盒 64% 时点提前完成。Foundation 层五大 Autoload 系统的架构基石稳固，ADR 驱动 + 测试先行的工作流验证有效。未来最需要改变的一件事是：**在 Story 创建阶段前置识别跨 Epic 依赖和 AC 过载**，避免 Sprint 中期范围扩大和预估偏差。
