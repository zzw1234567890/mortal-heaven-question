# 技能测试规格：/skill-test


## 技能概要

`/skill-test` 验证技能文件的结构正确性、行为合规性以及类别评分标准得分。它以三种模式运行：

- **static（静态）**：检查单个技能文件的结构要求（元数据字段、阶段标题、判定关键字、"我可以写入"措辞、下一步交接），无需测试夹具。生成逐项检查的 PASS/FAIL 表格。
- **spec（规格）**：读取 `tests/skills/` 中的测试规格文件，并根据每个测试用例的断言评估技能，生成逐用例判定结果。
- **audit（审计）**：生成 `.claude/skills/` 中所有技能和 `.claude/agents/` 中所有智能体的覆盖表，显示哪些有规格文件，哪些没有。

额外的 **category（类别）** 模式读取技能类别（例如，闸门技能）的质量评分标准，并根据评分标准标准对技能进行评分。不同模式的判定系统有所不同。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定结果：COMPLIANT、NON-COMPLIANT、WARNINGS（静态模式）；PASS、FAIL、PARTIAL（规格模式）；COMPLETE（审计模式）
- [ ] 不包含"我可以写入"措辞（该技能在所有模式下均为只读）
- [ ] 包含下一步交接（例如，运行 `/skill-improve` 以修复发现的问题）

---

## 主管闸门检查

无。`/skill-test` 是一项元实用技能。不适用任何主管闸门。

---

## 测试用例

### 用例 1：静态模式 —— 格式良好的技能，全部 7 项检查通过，COMPLIANT

**测试夹具：**
- `.claude/skills/brainstorm/SKILL.md` 存在且格式良好：
  - 包含所有必需的元数据字段
  - 包含 ≥2 个阶段标题
  - 包含判定关键字
  - 包含"我可以写入"措辞
  - 包含下一步交接
  - 记录主管闸门
  - 记录闸门模式行为（精简模式/单人模式跳过）

**输入：** `/skill-test static brainstorm`

**预期行为：**
1. 技能读取 `.claude/skills/brainstorm/SKILL.md`
2. 技能运行全部 7 项结构检查
3. 全部 7 项检查通过
4. 技能输出 PASS/FAIL 表格，全部 7 项检查标记为 PASS
5. 判定结果为 COMPLIANT

**断言：**
- [ ] 报告了恰好 7 项结构检查
- [ ] 全部 7 项标记为 PASS
- [ ] 判定结果为 COMPLIANT
- [ ] 未写入任何文件

---

### 用例 2：静态模式 —— 技能在 allowed-tools 中有 Write 工具但缺少"我可以写入"措辞

**测试夹具：**
- `.claude/skills/some-skill/SKILL.md` 在 `allowed-tools` 元数据中有 `Write`
- 技能主体中没有"我可以写入"或"我可以更新"措辞

**输入：** `/skill-test static some-skill`

**预期行为：**
1. 技能读取 `some-skill/SKILL.md`
2. 检查 4（协作写入协议）失败：`allowed-tools` 中有 `Write` 但未找到"我可以写入"措辞
3. 所有其他检查可能通过
4. 判定结果为 NON-COMPLIANT，检查 4 为失败断言
5. 输出列出检查 4 为 FAIL 并附有说明

**断言：**
- [ ] 检查 4 标记为 FAIL
- [ ] 说明指出了具体的失配（有 Write 工具但没有"我可以写入"措辞）
- [ ] 判定结果为 NON-COMPLIANT
- [ ] 其他通过的检查也会显示（不仅仅是失败项）

---

### 用例 3：规格模式 —— gate-check 技能对照规格进行评估

**测试夹具：**
- `tests/skills/gate-check.md` 存在，包含 5 个测试用例
- `.claude/skills/gate-check/SKILL.md` 存在

**输入：** `/skill-test spec gate-check`

**预期行为：**
1. 技能读取技能文件和规格文件
2. 技能评估全部 5 个测试用例的断言与技能行为是否匹配
3. 对于每个用例：如果技能行为与规格断言匹配则为 PASS，否则为 FAIL
4. 技能生成逐用例结果表
5. 总体判定：PASS（全部 5 个）、PARTIAL（部分）或 FAIL（多数失败）

**断言：**
- [ ] 规格中的所有 5 个测试用例均被评估
- [ ] 每个用例有单独的 PASS/FAIL 结果
- [ ] 总体判定基于用例结果为 PASS、PARTIAL 或 FAIL
- [ ] 未写入任何文件

---

### 用例 4：审计模式 —— 所有技能和智能体的覆盖表

**测试夹具：**
- `.claude/skills/` 包含 72+ 个技能目录
- `.claude/agents/` 包含 49+ 个智能体文件
- `tests/skills/` 包含部分技能的规格文件

**输入：** `/skill-test audit`

**预期行为：**
1. 技能枚举 `.claude/skills/` 中的所有技能和 `.claude/agents/` 中的所有智能体
2. 技能检查 `tests/skills/` 中每个技能/智能体是否有对应的规格文件
3. 技能生成覆盖表：
   - 列出每个技能/智能体
   - "有规格"列：YES 或 NO
   - 摘要："Y 个技能中的 X 个有规格；B 个智能体中的 A 个有规格"
4. 判定结果为 COMPLETE

**断言：**
- [ ] 所有技能目录均被枚举（不仅仅是样本）
- [ ] 每个条目的"有规格"列准确无误
- [ ] 摘要计数正确
- [ ] 判定结果为 COMPLETE

---

### 用例 5：类别模式 —— 闸门技能对照质量评分标准进行评估

**测试夹具：**
- `tests/skills/quality-rubric.md` 存在，包含一个"闸门技能"章节，定义了标准 G1-G5（例如，G1：有模式守卫，G2：有判定表等）
- `.claude/skills/gate-check/SKILL.md` 是一项闸门技能

**输入：** `/skill-test category gate-check`

**预期行为：**
1. 技能读取 `quality-rubric.md` 并识别出"闸门技能"章节
2. 技能对照标准 G1-G5 评估 `gate-check/SKILL.md`
3. 每个标准评分：PASS、PARTIAL 或 FAIL
4. 计算总体类别得分（例如，5 项标准中 4 项通过）
5. 判定结果为 COMPLIANT（全部通过）、WARNINGS（部分通过）或 NON-COMPLIANT（有失败）

**断言：**
- [ ] quality-rubric.md 中的所有闸门标准（G1-G5）均被评估
- [ ] 每个标准有单独的评分
- [ ] 总体判定反映得分分布
- [ ] 未写入任何文件

---

## 协议合规性

- [ ] 静态模式恰好检查 7 项结构断言
- [ ] 规格模式单独评估规格文件中的每个测试用例
- [ ] 审计模式覆盖所有技能和智能体（不仅仅是单一类别）
- [ ] 类别模式读取 quality-rubric.md 以获取标准（非硬编码）
- [ ] 任何模式下都不写入文件
- [ ] 当发现问题时，建议运行 `/skill-improve` 作为下一步

---

## 覆盖说明

- skill-test 技能是自引用的（它可以测试自身）。skill-test 自身 SKILL.md 的静态模式用例未单独进行夹具测试，以避免测试设计中的无限递归。
- 具体的 7 项结构检查在技能主体中定义；此处仅单独测试检查 4（我可以写入），因其逻辑最为微妙。
- 审计模式计数为近似值——技能和智能体的确切数量将随系统增长而变化；断言使用"全部"而非固定计数。
