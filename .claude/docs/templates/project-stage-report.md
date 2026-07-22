
# 项目阶段分析报告 (Project Stage Analysis Report)

**生成日期 (Generated)**: [日期]
**阶段 (Stage)**: [Concept | Systems Design | Technical Setup | Pre-Production | Production | Polish | Release]
**分析范围 (Analysis Scope)**: [全项目 | 特定角色：programmer/designer/producer]

---

## 执行摘要 (Executive Summary)

[1-2 段概述项目状态、主要差距和建议的优先级]

**当前重点 (Current Focus)**: [项目当前正在做的事情]
**阻塞问题 (Blocking Issues)**: [阻碍进展的关键差距]
**预计到达下一阶段的时间 (Estimated Time to Next Stage)**: [如适用]

---

## 完成度概览 (Completeness Overview)

### 设计文档 (Design Documentation)
- **状态 (Status)**: [X%] 已完成
- **找到的文件 (Files Found)**: `design/` 中有 [N] 个文档
  - GDD 章节：`design/gdd/` 中有 [N] 个文件
  - 叙事文档 (Narrative docs)：`design/narrative/` 中有 [N] 个文件
  - 关卡设计 (Level designs)：`design/levels/` 中有 [N] 个文件
- **关键差距 (Key Gaps)**:
  - [ ] [缺失文档 1 + 为什么重要]
  - [ ] [缺失文档 2 + 为什么重要]

### 源代码 (Source Code)
- **状态 (Status)**: [X%] 已完成
- **找到的文件 (Files Found)**: `src/` 中有 [N] 个源文件
- **已识别的主要系统 (Major Systems Identified)**:
  - ✅ [系统 1] (`src/path/`) — [简要状态]
  - ✅ [系统 2] (`src/path/`) — [简要状态]
  - ⚠️  [系统 3] (`src/path/`) — [问题或未完成]
- **关键差距 (Key Gaps)**:
  - [ ] [缺失系统 1 + 影响]
  - [ ] [缺失系统 2 + 影响]

### 架构文档 (Architecture Documentation)
- **状态 (Status)**: [X%] 已完成
- **已找到的 ADR (ADRs Found)**: `docs/architecture/` 中记录了 [N] 个决策
- **覆盖情况 (Coverage)**:
  - ✅ [决策领域 1] — 已记录
  - ⚠️  [决策领域 2] — 未记录但已实现
  - ❌ [决策领域 3] — 既未记录也未决定
- **关键差距 (Key Gaps)**:
  - [ ] [缺失 ADR 1 + 为什么需要]
  - [ ] [缺失 ADR 2 + 为什么需要]

### 生产管理 (Production Management)
- **状态 (Status)**: [X%] 已完成
- **已发现 (Found)**:
  - 冲刺计划 (Sprint plans)：`production/sprints/` 中有 [N] 个
  - 里程碑 (Milestones)：`production/milestones/` 中有 [N] 个
  - 路线图 (Roadmap)：[存在 | 缺失]
- **关键差距 (Key Gaps)**:
  - [ ] [缺失的生产制品 + 影响]

### 测试 (Testing)
- **状态 (Status)**: [X%] 覆盖率（估计）
- **测试文件 (Test Files)**: `tests/` 中有 [N] 个
- **按系统划分的覆盖情况 (Coverage by System)**:
  - [系统 1]：[X%]（估计）
  - [系统 2]：[X%]（估计）
- **关键差距 (Key Gaps)**:
  - [ ] [缺失测试领域 + 风险]

### 原型 (Prototypes)
- **活跃原型 (Active Prototypes)**: `prototypes/` 中有 [N] 个
  - ✅ [原型 1] — 已用 README 记录
  - ⚠️  [原型 2] — 无 README，状态不明
- **已归档 (Archived)**: [N] 个（实验已完成）
- **关键差距 (Key Gaps)**:
  - [ ] [未记录的原型 + 为什么重要]

---

## 阶段分类理由 (Stage Classification Rationale)

**为什么是 [阶段]？**

[解释为什么根据已发现的指标将项目分类到此阶段]

**此阶段的指标 (Indicators for this stage)**:
- [匹配此阶段的指标 1]
- [匹配此阶段的指标 2]

**下一阶段的要求 (Next stage requirements)**:
- [ ] [达到下一阶段的要求 1]
- [ ] [达到下一阶段的要求 2]
- [ ] [达到下一阶段的要求 3]

---

## 已识别的差距（含澄清问题）(Gaps Identified with Clarifying Questions)

### 关键差距（阻碍进展）(Critical Gaps)

1. **[差距名称]**
   - **影响 (Impact)**: [为什么阻碍进展]
   - **问题 (Question)**: [在假设解决方案之前的澄清问题]
   - **建议行动 (Suggested Action)**: [可以做的事情，待澄清]

### 重要差距（影响质量/效率）(Important Gaps)

2. **[差距名称]**
   - **影响 (Impact)**: [为什么重要]
   - **问题 (Question)**: [澄清问题]
   - **建议行动 (Suggested Action)**: [建议的解决方案]

### 可选差距（打磨/最佳实践）(Nice-to-Have Gaps)

3. **[差距名称]**
   - **影响 (Impact)**: [较小但有价值]
   - **问题 (Question)**: [澄清问题]
   - **建议行动 (Suggested Action)**: [可选的改进]

---

## 建议的下一步 (Recommended Next Steps)

### 立即优先 (Immediate Priority)
1. **[行动 1]** — [为什么是第一优先]
   - 建议技能：`/[skill-name]` 或手动操作
   - 预估工作量：[S/M/L]

2. **[行动 2]** — [为什么是第二优先]
   - 建议技能：`/[skill-name]`
   - 预估工作量：[S/M/L]

### 短期（本冲刺/本周）(Short-Term)
3. **[行动 3]** — [为什么很快重要]
4. **[行动 4]** — [为什么很快重要]

### 中期（下个里程碑）(Medium-Term)
5. **[行动 5]** — [未来需求]
6. **[行动 6]** — [未来需求]

---

## 角色特定建议 (Role-Specific Recommendations)

[如果使用了角色过滤器，提供角色特定的指导]

### 针对 [角色]：
- **重点领域 (Focus areas)**: [此角色应优先处理的内容]
- **阻塞项 (Blockers)**: [阻碍此角色工作的原因]
- **后续任务 (Next tasks)**:
  1. [任务 1]
  2. [任务 2]

---

## 建议后续运行的技能 (Follow-Up Skills to Run)

根据已识别的差距，考虑运行：

- `/reverse-document [type] [path]` — [针对哪个差距]
- `/architecture-decision` — [针对哪个差距]
- `/sprint-plan` — [如果缺少生产规划]
- `/milestone-review` — [如果接近截止日期]
- `/onboard [role]` — [如果有新贡献者加入]

---

## 附录：按目录划分的文件计数 (Appendix: File Counts by Directory)

```
design/
  gdd/           [N] files
  narrative/     [N] files
  levels/        [N] files

src/
  core/          [N] files
  gameplay/      [N] files
  ai/            [N] files
  networking/    [N] files
  ui/            [N] files

docs/
  architecture/  [N] ADRs

production/
  sprints/       [N] plans
  milestones/    [N] definitions

tests/           [N] test files
prototypes/      [N] directories
```

---

**报告结束 (End of Report)**

*由 `/project-stage-detect` 技能生成*
