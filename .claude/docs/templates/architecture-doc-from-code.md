# ADR：[决策名称]


---
**Status**: Reverse-Documented
**Source**: `[path to implementation code]`
**Date**: [YYYY-MM-DD]
**Decision Makers**: [User name or "inferred from code"]
**Implementation Status**: [Deployed | Partial | Planned]
---

> **⚠️ 逆向文档说明 (Reverse-Documentation Notice)**
>
> 此架构决策记录 (ADR) 是在实现**已经存在后**创建的。它基于代码分析和用户咨询记录了当前的实现方法和澄清后的理由。部分上下文可能是重构而非同时记录的。

---

## 背景 (Context)

**问题陈述 (Problem Statement)**：[此实现解决了什么问题？]

**背景（从代码推断）(Background, inferred from code)**：
- [背景 1 —— 为何需要解决此问题]
- [背景 2 —— 当时的约束]
- [背景 3 —— 可能考虑过的替代方案]

**系统范围 (System Scope)**：[这影响到代码库的哪些部分？]

**利益相关方 (Stakeholders)**：
- [角色 1]：[他们的关注点或需求]
- [角色 2]：[他们的关注点或需求]

---

## 决策 (Decision)

**采取的方法（已实现）(Approach Taken, as implemented)**：

[描述代码中发现的架构方法]

**关键实现细节 (Key Implementation Details)**：
- [细节 1]：[如何工作]
- [细节 2]： [使用的模式或结构]
- [细节 3]：[值得注意的设计选择]

**澄清后的理由（来自用户）(Clarified Rationale, from user)**：
- [理由 1 —— 为什么选择此方法]
- [理由 2 —— 它解决了什么问题]
- [理由 3 —— 它带来了什么好处]

**代码位置 (Code Locations)**：
- `[file/path 1]`：[内容]
- `[file/path 2]`：[内容]

---

## 考虑的替代方案 (Alternatives Considered)

*(这些可基于推断或经用户澄清)*

### 方案 1：[方法名称]

**描述 (Description)**：[此替代方案会是怎样的]

**优点 (Pros)**：
- ✅ [优势 1]
- ✅ [优势 2]

**缺点 (Cons)**：
- ❌ [劣势 1]
- ❌ [劣势 2]

**为何未选择 (Why Not Chosen)**：[理由 —— 来自用户澄清或推断]

### 方案 2：[方法名称]

**描述 (Description)**：[此替代方案会是怎样的]

**优点 (Pros)**：
- ✅ [优势 1]
- ✅ [优势 2]

**缺点 (Cons)**：
- ❌ [劣势 1]
- ❌ [劣势 2]

**为何未选择 (Why Not Chosen)**：[理由]

### 方案 3：[维持现状 / 不做改变]

**描述 (Description)**：["什么都不做"意味着什么]

**为何不可接受 (Why Not Acceptable)**：[为什么需要解决此问题]

---

## 后果 (Consequences)

### 正面后果（已实现的好处）(Positive Consequences, Benefits Realized)

✅ **[好处 1]**：[实现如何提供此好处]

✅ **[好处 2]**：[影响]

✅ **[好处 3]**：[影响]

### 负面后果（已接受的权衡）(Negative Consequences, Trade-offs Accepted)

⚠️ **[权衡 1]**：[牺牲了什么或使什么更困难]

⚠️ **[权衡 2]**：[限制或代价]

⚠️ **[权衡 3]**：[复杂性或维护负担]

### 中性后果（观察结果）(Neutral Consequences, Observations)

ℹ️ **[观察 1]**：[涌现的属性或副作用]

ℹ️ **[观察 2]**：[意外的结果]

---

## 实现说明 (Implementation Notes)

**使用的模式 (Patterns Used)**：
- [模式 1]：[在哪里以及为什么]
- [模式 2]：[在哪里以及为什么]

**引入的依赖 (Dependencies Introduced)**：
- [依赖 1]：[为什么需要]
- [依赖 2]：[为什么需要]

**性能特征 (Performance Characteristics)**：
- 时间复杂度： [O(n) 等]
- 空间复杂度：[内存使用]
- 瓶颈：[已知的性能问题]

**线程安全 (Thread Safety)**：
- [线程安全方法 —— 单线程、互斥保护、无锁等]

**测试策略 (Testing Strategy)**：
- [如何测试 —— 单元测试、集成测试等]
- 覆盖率：[估计或测量值]

---

## 验证 (Validation)

**我们如何知道这有效 (How We Know This Works)**：
- ✅ [证据 1 —— 例如："在生产中运行 6 个月无问题"]
- ✅ [证据 2 —— 例如："在 60FPS 下处理 10000 个实体"]
- ⚠️ [证据 3 —— 例如："有效但需要监控"]

**已知问题（分析中发现）(Known Issues, discovered during analysis)**：
- ⚠️ [问题 1]：[问题和潜在的修复]
- ⚠️ [问题 2]：[问题和潜在的修复]

**风险 (Risks)**：
- [风险 1]：[如果 X 发生的潜在问题]
- [风险 2]：[可扩展性问题]

---

## 未决问题 (Open Questions)

**逆向文档期间未解决 (Unresolved During Reverse-Documentation)**：
1. **[问题 1]**：[关于决策或实现有什么不清楚的？]
   - 需从何人澄清：[谁]
   - 如果不解决的影响：[后果]

2. **[问题 2]**：[未来工作需要决定的？]

---

## 后续工作 (Follow-Up Work)

**立即 (Immediate)**：
- [ ] [任务 1 —— 例如："添加缺失的单元测试"]
- [ ] [任务 2 —— 例如："记录边缘情况处理"]

**短期 (Short-Term)**：
- [ ] [任务 3 —— 例如："重构 X 以提高清晰度"]
- [ ] [任务 4 —— 例如："添加性能监控"]

**长期 (Long-Term)**：
- [ ] [任务 5 —— 例如："当 Y 可用时重新审视决策"]

---

## 相关决策 (Related Decisions)

**依赖 (Depends On)**（此 ADR 基于的 ADR）：
- [ADR-XXX]：[相关决策]

**影响 (Influences)**（受此影响的 ADR）：
- [ADR-YYY]：[这对其有何影响]

**替代 (Supersedes)**：
- [ADR-ZZZ]：[此替代的旧决策（如有）]

**被替代 (Superseded By)**：
- [暂无 | ADR-WWW 如果此决策后来被替代]

---

## 参考 (References)

**代码位置 (Code Locations)**：
- `[path/file 1]`：[主要实现]
- `[path/file 2]`：[相关代码]

**外部资源 (External Resources)**：
- [文章/书籍]：[相关模式或技术参考]
- [文档]：[查阅的引擎或库文档]

**设计文档 (Design Documents)**：
- [GDD 章节]：[如果是实现某个设计]

---

## 版本历史 (Version History)

| 日期 (Date) | 作者 (Author) | 变更 (Changes) |
|------|--------|---------|
| [日期] | Claude (reverse-doc) | 从 `[source path]` 初始逆向文档 |
| [日期] | [用户] | 澄清了 [X] 的理由 |

---

## 状态图例 (Status Legend)

- **Proposed**：讨论中，未实现
- **Accepted**：已决定，实现进行中
- **Deprecated**：不再推荐，但可能存在于代码中
- **Superseded**：已被其他决策替代
- **Reverse-Documented**：实现后创建（本文档）

---

**当前状态 (Current Status)**：**Reverse-Documented**

---

*此 ADR 由 `/reverse-document architecture [path]` 生成*

---

## 附录：代码片段 (Appendix: Code Snippets)

**关键实现模式 (Key Implementation Pattern)**：

```[language]
[展示核心模式或决策的代码片段]
```

**理由 (Rationale)**：[为什么此代码结构体现了该决策]

**替代方案（未选）(Alternative Approach, not chosen)**：

```[language]
[展示替代方案样子的代码片段]
```

**为何不选 (Why Not)**：[为什么更偏好已实现的方法]
