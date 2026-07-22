
# 概念原型报告 (Concept Prototype Report): [概念名称]

> **日期 (Date)**: [YYYY-MM-DD]
> **原型路径 (Prototype Path)**: [HTML / Engine / Paper]
> **概念文件 (Concept File)**: design/gdd/game-concept.md（如存在）

---

## 假设 (Hypothesis)

[本原型旨在验证的可证伪假设：
"如果玩家 [执行 X]，他们会感到 [Y] —— 通过 [可衡量的信号 Z] 体现。"]

---

## 最高风险假设 (Riskiest Assumption Tested)

[概念中被识别为最大风险的内容，以及是否得到了验证。]

---

## 方法 (Approach)

[构建了什么、耗时多久、有意采取了哪些捷径。]

**选择的路径 (Path chosen):** [HTML / Engine / Paper]
**选择该路径的理由 (Reason for path):** [为什么此路径适合此假设]

**有意采取的捷径 (Shortcuts taken, intentional):**
- [例如：硬编码数值、占位美术素材、无菜单等]

---

## 结果 (Result)

[实际发生的事情——具体的观察，而非意见。尽可能直接引用试玩者的话。]

---

## 指标 (Metrics)

| 指标 (Metric) | 值 (Value) |
|--------|-------|
| 使用的路径 | [HTML / Engine / Paper] |
| 迭代至可玩版本的次数 | [N——仅 Engine 路径；否则 N/A] |
| 原型制作时长 | [例如：4 小时] |
| 试玩者 (Playtesters) | [N 内部 / N 外部] |
| 手感评估 (Feel assessment) | [具体——"响应在 200ms 时感觉迟钝"而非"感觉不好"] |
| 假设裁决 (Hypothesis verdict) | [CONFIRMED / PARTIALLY CONFIRMED / REFUTED] |

---

## 建议: [PROCEED / PIVOT / KILL]

[一段话解释建议，引用上文的结果作为证据。]

---

## 如果继续 (If Proceeding)

[原型揭示的、应直接指导 GDD 编写的内容：]

- **发现的核心调优值 (Core tuning values discovered):** [例如："跳跃高度 3.5 单位感觉最佳"]
- **已确认的假设 (Assumptions confirmed):** [概念文档中被证实正确的假设]
- **被推翻的假设 (Assumptions disproved):** [概念文档中被证实错误的假设]
- **涌现的机制 (Emergent mechanics):** [测试期间出现的值得正式化的行]

> 注意：如果使用了 HTML 路径且手感不确定，考虑在确定 GDD 之前做一个以手感为目标的引擎原型。

**后续步骤 (Next steps):**
1. `/design-review design/gdd/game-concept.md`
2. `/gate-check`
3. `/map-systems`
4. `/design-system [mechanic]`（将学到的东西用于 Tuning Knobs 和 Formulas 章节）

---

## 如果转向 (If Pivoting)

[结果暗示的替代方向——什么几乎可行，什么需要调整。具体说明要更改什么，而不仅仅说需要更改。]

**转向方向 (Pivot direction):** [要尝试什么不同]
**保留什么 (What to keep):** [什么有效且应保留]
**后续步骤 (Next step):** `/prototype [revised-concept]`

---

## 如果终止 (If Killing)

[为什么此概念不可行——什么具体信号导致了此裁决。
本报告即为最终交付物；此概念无需进一步行动。]

**后续步骤 (Next step):** `/brainstorm [new-direction]`

---

## 经验教训 (Lessons Learned)

- **实际构建中推翻了哪些假设？**
  [...]

- **什么让我们感到意外，在头脑风暴中没有出现？**
  [...]

- **下次我们会如何改变测试方式？**
  [...]

---

> *原型代码位置 (Prototype code location): `prototypes/[concept-name]-concept/`*
> *此代码为一次性使用。绝不要重构进生产环境。*
