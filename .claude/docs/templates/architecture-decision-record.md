# ADR-[NNNN]：[标题]


## 状态 (Status)

[Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## 日期 (Date)

[YYYY-MM-DD —— 此 ADR 的编写日期]

## 最后验证 (Last Verified)

[YYYY-MM-DD —— 此 ADR 上次确认为准确并与当前引擎版本和设计一致的日期。当你重新阅读并确认其仍然正确时更新此日期，即使没有任何变化。]

## 决策人 (Decision Makers)

[参与此决策的人员]

## 摘要 (Summary)

[2 句话：此 ADR 解决什么问题，以及做出了什么决定。为分层次上下文加载编写——扫描 20 个 ADR 的技能使用此部分来决定是否阅读完整决策。要具体：指明系统、问题和所选方案。]

## 引擎兼容性 (Engine Compatibility)

| 字段 (Field) | 值 (Value) |
|-------|-------|
| **引擎 (Engine)** | [例如 Godot 4.6 / Unity 6 / Unreal Engine 5.4] |
| **领域 (Domain)** | [Physics / Rendering / UI / Audio / Navigation / Animation / Networking / Core / Input / Scripting] |
| **知识风险 (Knowledge Risk)** | [LOW —— 在训练数据中 / MEDIUM —— 接近知识截止，需验证 / HIGH —— 超出知识截止，必须验证] |
| **参考文档 (References Consulted)** | [例如 `docs/engine-reference/godot/modules/physics.md`、`breaking-changes.md`] |
| **超截止日期使用的 API (Post-Cutoff APIs Used)** | [此决策依赖的超截止日期引擎版本的特定 API，或"无"] |
| **需要验证 (Verification Required)** | [在发布前需针对目标引擎版本测试的具体行为，或"无"] |

> **注**：如果知识风险为 MEDIUM 或 HIGH，当项目升级引擎版本时必须重新验证此 ADR。将其标记为"Superseded"并编写新的 ADR。

## ADR 依赖关系 (ADR Dependencies)

| 字段 (Field) | 值 (Value) |
|-------|-------|
| **依赖 (Depends On)** | [ADR-NNNN（必须被 Accepted 后才能实现此 ADR），或"无"] |
| **启用 (Enables)** | [ADR-NNNN（此 ADR 解锁该决策），或"无"] |
| **阻塞 (Blocks)** | [Epic/Story 名称 —— 在此 ADR 被 Accepted 前无法开始，或"无"] |
| **排序说明 (Ordering Note)** | [任何未在上面捕获的顺序约束] |

## 背景 (Context)

### 问题陈述 (Problem Statement)

[我们正在解决什么问题？为什么必须现在做出此决策？不做决策的代价是什么？]

### 当前状态 (Current State)

[系统今天是如何工作的？当前方法有什么问题？]

### 约束 (Constraints)

- [技术约束 —— 引擎限制、平台要求]
- [时间约束 —— 截止日期压力、依赖项]
- [资源约束 —— 团队规模、可用专业知识]
- [兼容性要求 —— 必须与现有系统协同工作]

### 需求 (Requirements)

- [功能需求 1]
- [功能需求 2]
- [性能需求 —— 具体、可衡量]
- [可扩展性需求]

## 决策 (Decision)

[具体的技术决策，描述足够详细以便他人无需进一步澄清即可实现。]

### 架构 (Architecture)

```
[ASCII 图展示此决策创建的系统架构。
显示组件、数据流方向和关键接口。]
```

### 关键接口 (Key Interfaces)

```
[伪代码或语言特定的接口定义，此决策创建的内容。
这些成为实现者必须遵循的契约。]
```

### 实现指南 (Implementation Guidelines)

[对实现此决策的程序员的具体指导。]

## 考虑的替代方案 (Alternatives Considered)

### 方案 1：[名称]

- **描述 (Description)**：[此方法将如何工作]
- **优点 (Pros)**：[此方法的优点]
- **缺点 (Cons)**：[此方法的缺点]
- **预估工作量 (Estimated Effort)**：[与所选方案相比的相对工作量]
- **排除原因 (Rejection Reason)**：[为什么未选择此方案]

### 方案 2：[名称]

[与上述结构相同]

## 后果 (Consequences)

### 正面 (Positive)

- [此决策的良好结果]

### 负面 (Negative)

- [我们接受的权衡和代价]

### 中性 (Neutral)

- [既不好也不坏的变化，只是不同]

## 风险 (Risks)

| 风险 (Risk) | 概率 (Probability) | 影响 (Impact) | 缓解措施 (Mitigation) |
|------|------------|--------|-----------|

## 性能影响 (Performance Implications)

| 指标 (Metric) | 之前 (Before) | 预期之后 (Expected After) | 预算 (Budget) |
|--------|--------|---------------|--------|
| CPU（帧时间） | [X]ms | [Y]ms | [Z]ms |
| 内存 (Memory) | [X]MB | [Y]MB | [Z]MB |
| 加载时间 (Load Time) | [X]s | [Y]s | [Z]s |
| 网络（如适用） | [X]KB/s | [Y]KB/s | [Z]KB/s |

## 迁移计划 (Migration Plan)

[如果这会更改现有系统，分步迁移计划。]

1. [步骤 1 —— 什么变化、什么中断、如何验证]
2. [步骤 2]
3. [步骤 3]

**回滚计划 (Rollback plan)**：[如果此决策被证明有误，如何回退]

## 验证标准 (Validation Criteria)

[我们如何在实现后知道此决策是正确的。]

- [ ] [可衡量的标准 1]
- [ ] [可衡量的标准 2]
- [ ] [性能标准]

## 涉及的 GDD 需求 (GDD Requirements Addressed)

<!-- 此部分为必填。每个 ADR 必须追溯到至少一个 GDD 需求，
     或明确声明其为无 GDD 依赖的基础性决策。可追溯性由 /architecture-review 审计。 -->

| GDD 文档 (GDD Document) | 系统 (System) | 需求 (Requirement) | 此 ADR 如何满足它 (How This ADR Satisfies It) |
|-------------|--------|-------------|--------------------------|
| [例如 `design/gdd/combat.md`] | [例如 Combat] | [例如"命中框检测必须在 1 帧内完成"] | [例如"Jolt 物理碰撞查询在 _physics_process 中同步运行"] |

> 如果这是没有直接 GDD 依赖的基础性决策，请写入：
> "基础性 —— 无 GDD 需求。启用：[列出此决策解锁或约束的 GDD 系统]"

## 相关 (Related)

- [相关 ADR 的链接 —— 注明是否替代、矛盾或依赖]
- [实现后相关代码文件的链接]
