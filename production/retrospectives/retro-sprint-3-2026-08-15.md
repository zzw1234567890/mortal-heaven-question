# 回顾：Sprint 3 — Core 层剩余系统 + 技术债

周期：2026-08-10 -- 2026-08-23
生成日期：2026-08-15

---

## 指标

| 指标 | 计划 | 实际 | 偏差 |
|--------|---------|--------|-------|
| 任务数 | 12（9 must + 2 should + 1 nice） | 12 | 0 |
| 完成率 | -- | 100% | -- |
| 故事点/工作天数 | ~57h / 14 天（11 可用） | ~4 天（08-10→08-14） | -10 天 |
| 发现的 Bug | -- | 8（cost_system 既有失败，非本 Sprint 引入） | -- |
| 修复的 Bug | -- | 8 + 28 哑测试解锁 | -- |
| 新增计划外任务 | -- | 3（QA 收尾修复：cost_system 8 失败 + EventSystem 3 parse error + ADR 措辞矛盾） | +3 |
| 提交次数 | -- | 5（7fd0815 / d7b4b03 / fc01826 / 472288d / 7ebc8da） | -- |
| 自动化测试 | -- | 1145/1146 通过，0 失败，1 pending | -- |

---

## 速度趋势

| 冲刺 | 计划 | 完成 | 完成率 |
|--------|---------|-----------|------|
| Sprint 1 | 23 | 23 | 100% |
| Sprint 2 | 13 | 13 | 100% |
| Sprint 3（当前） | 12 | 12 | 100% |

**趋势**：稳定（连续三冲刺 100% 完成率），但时间盒利用率持续异常——连续两个冲刺都是 **4 天完成 14 天计划**。Sprint 3 计划曾明确"Sprint 2 的 11h/天是异常值，按 7-8h/天保守校准，计划 56h 需 7-8 天"，结果实际又是 4 天。速度校准连续两次低估，已不是"异常值"而是稳定模式。

---

## 做得好的方面

- **三项结转技术债全部清偿**：Sprint 1 回顾行动项 #2（拆分 game_state_manager.gd）经 Sprint 2 推迟后，在本 Sprint 的 3-9 完成——1016→282 行，拆为 4 文件（主类 + gsm_atomic_writes + gsm_signal_router + gsm_serializer），全量零回归。这验证了"委托包装器 + RefCounted 辅助类"的拆分模式对 933+ 行大文件同样有效。
- **Sprint 2 回顾行动项 #2（跨 Epic 接口契约盘点）落地**：3-1 在 `/create-stories` 阶段强制完成三系统 + 跨 Epic 接口契约盘点，消除了 Sprint 2 反复出现的"实现时才补 API 缺口"问题。
- **status-effect 高风险成功化解**：Sprint 3 计划将 8 阶段管线标记为"复杂度高，实际可能需 3-3.5 天 vs 预估 2.5 天"，实际 3-4/3-5/3-6 在预估范围内完成，20 条 AC + 3 叠加规则 + 免疫多级检查 + 20 上限全部通过测试。
- **QA 收尾发现了 36 个"幽灵"缺陷并修复**：8 个 cost_system 既有失败 + 28 个 EventSystem 从未运行的哑测试（3 文件 parse error）。这些是前两 Sprint 关闭时漏网的，本 Sprint 在 QA 关卡系统性暴露并修复，全量测试从 1117 提升到 1145 通过。
- **Feature 层铺路完成**：3-12 预创建 18 个 Feature Epic 标题级骨架（67 个 story 标题），Sprint 4 可直接从 combat-system 起 `/dev-story` 填充 AC，无需再走 create-epics。

---

## 做得不好的方面

- **Story 关闭门禁未卡住既有失败**：8 个 cost_system 测试失败在 Story 3-2/3-3 关闭时（08-10）就已存在，却一路"Complete"到 Sprint 3 收尾才被发现。session 记录显示"拆分前基线已存在"——即 Story 完成时已知有失败，但 `/story-done` 仍放行。这暴露了完成门禁只核对"该 story 测试通过"而未核对"全量零回归"的盲区。
- **EventSystem 28 个哑测试长期静默**：3 个测试文件的 parse error（`es` 动态分派 `:=` 无法推断返回类型）导致它们**从未被 GUT 加载**，但 EventSystem 在 Sprint 1/2 就被标记 Complete + QA APPROVED。`test_resolve_option.gd` 甚至是在 Sprint 1 就创建的。GUT 对 parse error 是"静默跳过并计入 orphan"，但没人看 orphan 计数。
- **孤儿测试问题二次出现**：3-10 才发现 `tests/unit/gsm/` 下 4 个 `*_test.gd`（非 `test_` 前缀）被 GUT 忽略。这与 EventSystem parse error 是同一系统性问题的两个表现——**测试文件被 GUT 静默跳过而 Story 仍标记完成**。
- **速度校准连续失效**：Sprint 3 明确吸取 Sprint 2 教训"按 7-8h/天保守校准"，结果又是 4 天完成。速度基准的持续低估会导致 Sprint 计划失去时间盒约束力——14 天计划 4 天做完，剩余的 10 天在计划上"空转"。

---

## 遇到的阻塞项

| 阻塞项 | 持续时间 | 解决方案 | 预防措施 |
|---------|----------|------------|------------|
| 无真正阻塞项 | — | Sprint 3 计划标记的 3 个高风险（status-effect 复杂度 / GSM 拆分回归 / create-stories 偏紧）全部在预估内化解 | 计划阶段的风险预判有效，无需新增预防 |

---

## 预估准确性

| 任务 | 预估 | 实际 | 偏差 | 可能原因 |
|------|-----------|--------|----------|--------------|
| status-effect 8 阶段管线（3-4/3-5/3-6） | 2.5d（含计划上浮后） | ~2.5d | 0 | 跨 Epic 契约盘点前置 + ADR 清晰，复杂度在预估内 |
| game_state_manager.gd 拆分（3-9） | 1d（计划已上调至 1.5d） | ~1d | -0.5d | event_system 拆分模式复用成熟 |
| cost-system（3-2/3-3） | 1d | ~0.5d 实现 + ~0.5d 收尾修复 | +0.5d | 既有 8 失败是 QA 阶段才修，未计入原预估 |
| school-system（3-7/3-8） | 1d | ~1d | 0 | const 库 + 纯查询模式成熟 |

**总体预估准确性**：约 75% 的任务偏差在预估的 +/- 20% 以内。但整体时间盒严重低估——**所有任务加起来 4 天完成 vs 计划 7-8 天**。问题不在单任务预估，而在"速度基准"整体偏保守。

---

## 结转分析

| 任务 | 原始冲刺 | 结转次数 | 原因 | 处理方式 |
|------|----------------|---------------|--------|--------|
| 无结转任务（must-have） | — | 0 | Sprint 3 全部 12 Story 当冲刺完成 | — |
| 拆分 game_state_manager.gd | Sprint 1 | 2（S1→S2→S3） | 技术债 nice-to-have 反复推迟 | 本 Sprint 完成（3-9）✅ |
| ADR-0003 文档补充 | Sprint 1 | 2（S1→S2→S3） | nice-to-have | 本 Sprint 完成（3-11）✅ |
| GSM 第二层方法独立单测 | Sprint 2 | 1（S2→S3） | 技术债 | 本 Sprint 完成（3-10）✅ |
| Feature 层 Epic 预创建 | Sprint 2 | 1（S2→S3） | nice-to-have | 本 Sprint 完成（3-12）✅ |

**分析**：Sprint 3 最显著的特征是**清偿了全部历史结转项**——4 个跨 Sprint 结转的技术债/nice-to-have 在本 Sprint 全部落地。此前 Sprint 1/2 反复推迟的 nice-to-have 项，在 Sprint 3 的"过渡准备"定位下被集中处理。

---

## 技术债务状态

- 当前 TODO 数量：0（src/ 目录 grep 无匹配）
- 当前 FIXME 数量：0
- 当前 HACK 数量：0
- 趋势：稳定（无新增 TODO/FIXME/HACK 标记）
- 关注领域：
  - `game_state_manager.gd` 已拆分至 282 行 ✅（Sprint 1 行动项 #2 完成）
  - `event_system.gd` 已拆分至 267 行 ✅（Sprint 1 行动项 #1 完成）
  - **新出现**：1 orphan 测试内存泄漏（input 系统）、RealmSystem/SchoolSystem 未注册 Autoload（预期架构决策）、CardSystem 模板目录缺失（预期现象）——均为 S3/S4 ADVISORY，不阻塞

---

## 先前行动项跟进

| 行动项（来自 Sprint 2） | 状态 | 备注 |
|-------------------------------|--------|-------|
| #1 拆分 game_state_manager.gd | ✅ 已完成 | Story 3-9，1016→282 行，4 文件 |
| #2 /create-epics 强制跨 Epic 接口契约盘点 | ✅ 已完成 | Story 3-1 强制执行 |
| #3 重构设计阶段盘点测试白盒访问点 | ⚠️ 部分完成 | GSM 拆分做了回归验证，但孤儿测试（`*_test.gd` 前缀）在 3-10 才发现，白盒盘点仍不彻底 |
| #4 补齐 GSM 第二层方法独立单测 | ✅ 已完成 | Story 3-10，15 测试 + 5 孤儿重命名 |
| #5 类型化数组赋值规则写入测试标准 | ⚠️ 未验证 | 未见明确写入测试标准的记录 |

---

## 下个迭代的行动项

| # | 行动 | 负责人 | 优先级 | 截止日期 |
|---|--------|-------|----------|----------|
| 1 | **强化 /story-done 门禁**：关闭 Story 前必须跑全量测试套件确认零新增失败（而非仅该 Story 套件），并检查 GUT orphan 计数 + parse error 输出 | producer / qa-lead | 高 | Sprint 4 开始前 |
| 2 | **建立测试清单完整性检查**：/smoke-check 或 /story-done 阶段核对"每个测试文件的 test 前缀 + 可加载性"，杜绝 parse error / 孤儿测试静默跳过 | qa-lead | 高 | Sprint 4 开始前 |
| 3 | **上调速度基准**：连续两 Sprint 4 天完成 14 天计划，Sprint 4 规划应采用 2-3 天/Sprint 或显著压缩时间盒，避免计划空转 | producer | 高 | Sprint 4 规划时 |
| 4 | **落实重构白盒盘点**（Sprint 2 行动项 #3 重提）：拆分前 grep 测试中的 `_` 私有访问 + 测试文件名前缀，形成检查清单 | engine-programmer | 中 | 下次重构前 |
| 5 | **RealmSystem/SchoolSystem Autoload 注册**：Feature 层 CombatSystem 接入时在 project.godot 补注册 #11/#19，避免 Feature 层引用时才发现全局名缺失 | engine-programmer | 中 | Sprint 4 CombatSystem 接入时 |

---

## 流程改进

- **测试门禁从"该 Story 套件通过"升级为"全量零回归 + 无 orphan + 无 parse error"**：本次 36 个幽灵缺陷（8 失败 + 28 哑测试）的根因是门禁只看局部、不看全量，且不看 GUT 的静默跳过信号。预期收益：杜绝"测试文件被跳过而 Story 仍 Complete"。
- **速度基准从"人日"转向"冲刺日历日"**：当前 7-8h/天 的人日估算已连续两次低估 AI 工作流实际速度，建议 Sprint 4 起按"日历日"规划（参考前两 Sprint 的 4 天实际），或在计划中显式标注"速度基准为 AI 辅助工作流，非人日"。

---

## 总结

Sprint 3 是一个"收尾 + 过渡"的双重成功冲刺——12 个 Story 全部 Complete，清偿了全部 4 项跨 Sprint 结转的技术债，Core 层 8 系统全部就绪，Feature 层 18 个 Epic 骨架铺路完成，QA APPROVED 零 S1/S2 缺陷。最值得肯定的是把前两 Sprint 反复推迟的债务集中消化掉了。未来最需要改变的一件事是：**修复 Story 关闭门禁的盲区**——本次暴露的 36 个"幽灵缺陷"（8 个 cost_system 失败 + 28 个从未运行的 EventSystem 测试）说明"测试文件被 GUT 静默跳过而 Story 仍标记 Complete"是贯穿三个 Sprint 的系统性漏洞，必须在 Sprint 4 开始前从流程层面堵住。
