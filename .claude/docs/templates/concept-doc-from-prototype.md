# [原型名称 (Prototype Name)]——概念文档 (Concept Document)


---
**Status**: Reverse-Documented from Prototype
**Prototype Path**: `prototypes/[name]/`
**Date**: [YYYY-MM-DD]
**Creator**: [User name]
**Outcome**: [Success | Partial Success | Failed | Needs More Testing]
---

> **⚠️ 逆向文档说明 (Reverse-Documentation Notice)**
>
> 此概念文档是在原型**已经构建后**创建的。它记录了通过原型制作发现的核心机制、经验教训和设计洞见。这是对实验工作的正式化，而非预先计划的设计。

---

## 1. 原型概述 (Prototype Overview)

**原始假设 (Original Hypothesiss)**：
[这个原型测试了什么想法或问题？]

**方法 (Approach)**：
[原型是如何构建的？快速粗糙？专注于一个机制？]

**时长 (Duration)**：
- 花费时间：[X 小时/天]
- 复杂度：[可丢弃 | 可成为生产级 | 需要完全重写]

**结果（已澄清）(Outcome, clarified)**：
- ✅ **已验证 (Validated)**：[什么有效并且应该继续推进]
- ⚠️ **需要改进 (Needs Work)**：[什么显示出潜力但需要打磨]
- ❌ **被否定 (Invalidated)**：[什么无效并且应该放弃]

---

## 2. 核心机制 (Core Mechanic)

**原型做什么 (What the Prototype Does)**：
[描述被原型化的机制或系统]

**感觉如何（用户反馈）(How It Feels, user feedback)**：
- [感觉 1 —— 例如："令人满意"、"笨拙"、"太复杂"]
- [感觉 2 —— 例如："直观"、"令人困惑"、"需要教程"]
- [感觉 3 —— 例如："有趣"、"无聊"、"有潜力"]

**玩家幻想 (Player Fantasy)**：
[此机制创造了什么幻想或体验？]

**核心循环（如适用）(Core Loop, if applicable)**：
```
[动作 1] → [结果 1] → [动作 2] → [结果 2] → [重复或结束]
```

**涌现行为（意外但有趣）(Emergent Behaviors, unintended but interesting)**：
- [行为 1]：[玩家做了未计划的行为]
- [行为 2]：[意外的策略或交互]

---

## 3. 什么有效 (What Worked)

### 机制成功 (Mechanic Successes)

✅ **[成功 1]**：[什么效果好]
- **原因 (Why)**：[什么使其成功]
- **保留用于生产 (Keep for Production)**：[是否应保留？]

✅ **[成功 2]**：[什么效果好]
- **原因 (Why)**：[什么使其成功]
- **保留用于生产 (Keep for Production)**：[是否应保留？]

### 技术成功 (Technical Successes)

✅ **[技术成果 1]**：[什么技术方法有效]
- **经验教训 (Lesson)**：[我们学到了什么]
- **可复用 (Reusable)**：[此代码/方法能否在生产中使用？]

✅ **[技术成果 2]**：[什么有效]
- **经验教训 (Lesson)**：[我们学到了什么]

---

## 4. 什么无效 (What Didn't Work)

### 机制失败 (Mechanic Failures)

❌ **[失败 1]**：[什么无效]
- **原因 (Why)**：[根本原因]
- **能否修复 (Could It Be Fixed)**：[是可挽救的还是根本性的缺陷？]

❌ **[失败 2]**：[什么无效]
- **原因 (Why)**：[根本原因]
- **能否修复 (Could It Be Fixed)**：[是/否 + 如何修复]

### 技术失败 (Technical Failures)

❌ **[技术问题 1]**：[什么导致了问题]
- **经验教训 (Lesson)**：[生产中应避免什么]

❌ **[技术问题 2]**：[什么导致了问题]
- **经验教训 (Lesson)**：[应避免什么]

---

## 5. 需要改进的内容 (What Needs Refinement)

⚠️ **[元素 1]**：[什么显示出潜力但需要改进]
- **问题 (Issue)**：[当前问题]
- **前进路径 (Path Forward)**：[如何改进]
- **工作量 (Effort)**：[小 | 中 | 大重构]

⚠️ **[元素 2]**：[需要改进的内容]
- **问题 (Issue)**：[当前问题]
- **前进路径 (Path Forward)**：[改进方法]
- **工作量 (Effort)**：[估计]

---

## 6. 关键经验教训 (Key Learnings)

### 设计洞见 (Design Insights)

💡 **[洞见 1]**：[关于游戏设计的经验教训]
- **影响 (Implication)**：[这对未来工作有何影响]

💡 **[洞见 2]**：[设计经验教训]
- **影响 (Implication)**：[对 GDD 或其他系统的影响]

### 技术洞见 (Technical Insights)

💡 **[洞见 3]**：[技术经验教训]
- **影响 (Implication)**：[架构或实现指导]

💡 **[洞见 4]**：[技术经验教训]
- **影响 (Implication)**：[未来技术决策]

### 玩家心理学洞见 (Player Psychology Insights)

💡 **[洞见 5]**：[关于玩家行为我们学到了什么]
- **影响 (Implication)**：[这对设计理念有何影响]

---

## 7. 生产就绪评估 (Production Readiness Assessment)

**是否应成为完整功能 (Should This Become a Full Feature?)**: [Yes | No | Needs More Testing | Pivot to Different Approach]

**如果是——生产要求 (If Yes — Production Requirements)**：
- [ ] [要求 1 —— 例如："为性能重写"]
- [ ] [要求 2 —— 例如："添加适当的 UI"]
- [ ] [要求 3 —— 例如："设计 10 个以上变体"]
- [ ] [要求 4 —— 例如："与进度系统集成"]

**预估生产工作量 (Estimated Production Effort)**：[小 | 中 | 大]
- 原型可复用性：[X%] 的代码可以保留
- 从头开始的工作量：[X 小时/天达到生产就绪]

**如果不——为何不 (If No — Why Not?)**：
- [理由 1 —— 例如："有趣但不符游戏支柱"]
- [理由 2 —— 例如："对目标受众太复杂"]
- [理由 3 —— 例如："规模化后技术上不可行"]

**如果转向——建议方向 (If Pivot — Suggested Direction)**：
- [替代方法 1]
- [替代方法 2]

---

## 8. 设计支柱一致性 (Design Pillars Alignment)

**这与游戏支柱的关系（如果游戏支柱已定义）(How This Relates to Game Pillars)**：

| 支柱 (Pillar) | 一致性 (Alignment) | 说明 (Notes) |
|--------|-----------|-------|
| [支柱 1] | ✅ 强 (Strong) / ⚠️ 弱 (Weak) / ❌ 冲突 (Conflicts) | [解释] |
| [支柱 2] | ✅ 强 / ⚠️ 弱 / ❌ 冲突 | [解释] |
| [支柱 3] | ✅ 强 / ⚠️ 弱 / ❌ 冲突 | [解释] |

**总体支柱契合度 (Overall Pillar Fit)**：[这属于这个游戏吗？]

---

## 9. 下一步 (Next Steps)

### 立即（如果继续推进）(Immediate, If Moving Forward)
1. **[任务 1]**：[例如："为此系统创建完整设计文档"]
2. **[任务 2]**：[例如："为技术方法编写 ADR"]
3. **[任务 3]**：[例如："添加到冲刺 X 的待办列表"]

### 生产前（如果仍需更多工作）(Before Production, If Needs More Work)
1. **[任务 1]**：[例如："构建测试 X 变体的第二个原型"]
2. **[任务 2]**：[例如："与 5 名以上玩家进行试玩测试"]
3. **[任务 3]**：[例如："调研 Y 的技术可行性"]

### 如果放弃 (If Abandoning)
1. **[任务 1]**：[例如："将原型与此文档一同归档"]
2. **[任务 2]**：[例如："提取可复用的代码/经验教训"]
3. **[任务 3]**：[例如："如果这改变了思路，更新游戏支柱"]

---

## 10. 技术说明 (Technical Notes)

**原型实现 (Prototype Implementation)**：
- 语言/引擎：[使用了什么]
- 架构：[如何组织的]
- 采取的捷径：[什么做得粗糙或一次性]

**可复用代码（如有）(Reusable Code, if any)**：
- `[file/path 1]`：[功能，可复用性]
- `[file/path 2]`：[功能，可复用性]

**技术债务（如果转移到生产）(Technical Debt, if moving to production)**：
- [债务 1]：[需要重写什么]
- [债务 2]：[需要正确实现什么]

---

## 11. 试玩反馈 (Playtest Feedback)

*(如果原型经过试玩测试)*

**测试者 (Testers)**：[N 人，[internal/external]]

**正面反馈 (Positive Feedback)**：
- "[引用 1]" —— [测试者姓名/角色]
- "[引用 2]" —— [测试者姓名/角色]

**负面反馈 (Negative Feedback)**：
- "[引用 1]" —— [测试者姓名/角色]
- "[引用 2]" —— [测试者姓名/角色]

**建议 (Suggestions)**：
- "[建议 1]" —— [测试者姓名]
- "[建议 2]" —— [测试者姓名]

**主题 (Themes)**：
- [主题 1]：[多个测试者一致认同的观点]
- [主题 2]：[常见反馈]

---

## 12. 相关工作 (Related Work)

**灵感来源 (Inspired By)**（受其影响的游戏/机制）：
- [游戏 1]：[什么机制或感觉]
- [游戏 2]：[借鉴或改编了什么]

**不同之处 (Differs From)**（独特性或差异）：
- [差异 1]
- [差异 2]

**集成对象 (Integrates With)**（现有游戏系统）：
- [系统 1]：[它们如何连接]
- [系统 2]：[它们如何连接]

---

## 13. 未决问题 (Open Questions)

**设计问题 (Design Questions)**：
1. **[问题 1]**：[设计上仍未决定什么？]
2. **[问题 2]**：[需要试玩测试或迭代什么？]

**技术问题 (Technical Questions)**：
3. **[问题 3]**：[还有什么技术未知？]
4. **[问题 4]**：[需要可行性测试什么？]

---

## 14. 附录：原型资源 (Appendix: Prototype Assets)

**代码 (Code)**：
- 位置：`prototypes/[name]/src/`
- 状态：[归档 | 部分复用 | 完全复用]

**美术/音频（如有）(Art/Audio, if any)**：
- 位置：`prototypes/[name]/assets/`
- 状态：[占位 | 生产就绪 | 需要替换]

**文档 (Documentation)**：
- README：[存在 | 缺失]
- 构建说明：[存在 | 缺失]

---

## 版本历史 (Version History)

| 日期 (Date) | 作者 (Author) | 变更 (Changes) |
|------|--------|---------|
| [日期] | Claude (reverse-doc) | 从原型分析初始概念文档 |
| [日期] | [用户] | 澄清结果，添加试玩反馈 |

---

**最终建议 (Final Recommendation)**：[推进 (GO) | 不推进 (NO-GO) | 转向 (PIVOT)]

**理由 (Rationale)**：[1-2 句话总结原因]

---

*此概念文档由 `/reverse-document concept prototypes/[name]` 生成*
