# 架构可追溯性索引 (Architecture Traceability Index)


<!-- 动态文档——由 /architecture-review 在每次审查运行后更新。
     除非修正错误，否则请勿手动编辑。 -->

## 文档状态 (Document Status)

- **最后更新 (Last Updated)**：[YYYY-MM-DD]
- **引擎 (Engine)**：[例如 Godot 4.6]
- **已索引 GDD 数 (GDDs Indexed)**：[N]
- **已索引 ADR 数 (ADRs Indexed)**：[M]
- **最后审查 (Last Review)**：[链接到 docs/architecture/architecture-review-[date].md]

## 覆盖摘要 (Coverage Summary)

| 状态 (Status) | 计数 (Count) | 百分比 (Percentage) |
|--------|-------|-----------|
| ✅ 已覆盖 (Covered) | [X] | [%] |
| ⚠️ 部分 (Partial) | [Y] | [%] |
| ❌ 缺口 (Gap) | [Z] | [%] |
| **总计 (Total)** | **[N]** | |

---

## 可追溯性矩阵 (Traceability Matrix)

<!-- 每行对应从 GDD 提取的一个技术需求。
     "技术需求"是 GDD 中暗示特定架构决策的任何陈述：
     数据结构、性能约束、所需引擎能力、跨系统通信、状态持久化。 -->

| 需求 ID (Req ID) | GDD | 系统 (System) | 需求摘要 (Requirement Summary) | ADR(s) | 状态 (Status) | 说明 (Notes) |
|--------|-----|--------|---------------------|--------|--------|-------|
| TR-[gdd]-001 | [filename] | [system name] | [一行摘要] | [ADR-NNNN] | ✅ | |
| TR-[gdd]-002 | [filename] | [system name] | [一行摘要] | — | ❌ GAP | 需要 `/architecture-decision [title]` |

---

## 已知缺口 (Known Gaps)

无 ADR 覆盖的需求，按层级优先级排序（基础层优先）：

### 基础层缺口 Foundation Layer Gaps——阻塞 (BLOCKING)，必须在编码前解决
- [ ] TR-[id]：[需求] —— GDD：[file] —— 建议 ADR："[title]"

### 核心层缺口 Core Layer Gaps——必须在相关系统构建前解决
- [ ] TR-[id]：[需求] —— GDD：[file] —— 建议 ADR："[title]"

### 功能层缺口 Feature Layer Gaps——应在功能冲刺前解决
- [ ] TR-[id]：[需求] —— GDD：[file] —— 建议 ADR："[title]"

### 表现层缺口 Presentation Layer Gaps——可推迟到实现阶段
- [ ] TR-[id]：[需求] —— GDD：[file] —— 建议 ADR："[title]"

---

## 跨 ADR 冲突 (Cross-ADR Conflicts)

<!-- 做出矛盾声明的 ADR 对。必须解决。 -->

| 冲突 ID (Conflict ID) | ADR A | ADR B | 类型 (Type) | 状态 (Status) |
|-------------|-------|-------|------|--------|
| CONFLICT-001 | ADR-NNNN | ADR-MMMM | 数据所有权 (Data ownership) | 🔴 未解决 (Unresolved) |

---

## ADR 到 GDD 覆盖（反向索引）(ADR → GDD Coverage, Reverse Index)

<!-- 对于每个 ADR，它涉及哪些 GDD 需求？ -->

| ADR | 标题 (Title) | 涉及的 GDD 需求 (GDD Requirements Addressed) | 引擎风险 (Engine Risk) |
|-----|-------|---------------------------|-------------|
| ADR-0001 | [title] | TR-combat-001, TR-combat-002 | HIGH |

---

## 被替代的需求 (Superseded Requirements)

<!-- 编写 ADR 时 GDD 中存在，但 GDD 后来已更改的需求。
     ADR 可能需要更新。 -->

| 需求 ID (Req ID) | GDD | 变更 (Change) | 受影响的 ADR (Affected ADR) | 状态 (Status) |
|--------|-----|--------|-------------|--------|
| TR-[id] | [file] | [变更内容] | ADR-NNNN | 🔴 ADR 需要更新 (ADR needs update) |

---

## 如何使用本文档 (How to Use This Document)

**编写新的 ADR 时**：将其添加到"ADR 到 GDD 覆盖"表中，并将矩阵中其满足的需求标记为 ✅。

**批准 GDD 变更时**：扫描矩阵中来自该 GDD 的需求，检查变更是否使任何现有 ADR 失效。如果是，添加到"被替代的需求"中。

**运行 `/architecture-review` 时**：该技能将自动用当前状态更新本文档。

**关卡检查 (Gate check)**：预生产关卡要求本文档存在，且基础层缺口为零。
