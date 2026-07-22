
# 技能测试规格：/design-review

## 技能概述 (Skill Summary)

`/design-review` 读取游戏设计文档 (Game Design Document, GDD)，并根据项目的 8 节设计标准（概述、玩家愿景、详细规则、公式、边缘情况、依赖关系、调优参数、验收标准）对其进行评估。它检查内部一致性、可实现性以及跨系统冲突。它产出以下判决 (verdict)：APPROVED（通过）、NEEDS REVISION（需修订）或 MAJOR REVISION NEEDED（需重大修订）。它是一个只读技能（不写入文件），并以 `context: fork` 子智能体 (subagent) 方式运行。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证——无需测试夹具 (fixture)。

- [ ] 包含所需 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题或编号步骤
- [ ] 包含判决关键词：APPROVED、NEEDS REVISION、MAJOR REVISION NEEDED
- [ ] 不要求"我可以写入吗"这一类用语（只读技能——`allowed-tools` 排除 Write/Edit）
- [ ] 输出格式已文档化（技能主体中展示了审查模板）

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径——完整 GDD，全部 8 个章节均存在

**测试夹具 (Fixture)：**
- `design/gdd/light-manipulation.md` 存在（使用 `_fixtures/minimal-game-concept.md` 作为替代——表示一份包含所有必需内容的完整文档）
- 所有 8 个必需章节均包含实质性内容
- "公式"章节至少包含一个有定义变量的公式
- "验收标准"章节至少包含 3 个可测试的标准

**输入：** `/design-review design/gdd/light-manipulation.md`

**预期行为：**
1. 技能完整读取目标文档
2. 技能读取 CLAUDE.md 获取项目上下文和标准
3. 技能评估所有 8 个必需章节（存在/缺失检查）
4. 技能检查内部一致性（公式与所描述行为匹配）
5. 技能检查可实现性（规则足够精确以进行编码）
6. 技能输出结构化审查报告，包含逐章节状态
7. 技能输出 APPROVED 判决

**断言 (Assertions)：**
- [ ] 技能在产出任何输出之前先读取目标文件
- [ ] 输出包含"完整性"部分，显示 X/8 章节已存在
- [ ] 输出包含"内部一致性"部分
- [ ] 输出包含"可实现性"部分
- [ ] 输出以判决行结尾：APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED
- [ ] 当全部 8 个章节均存在且一致时，给出 APPROVED 判决

---

### 用例 2：失败路径——不完整的 GDD（4/8 章节）

**测试夹具 (Fixture)：**
- `design/gdd/light-manipulation.md` 存在，内容来自 `tests/skills/_fixtures/incomplete-gdd.md`（4/8 章节已填充；缺少公式、边缘情况、调优参数、验收标准）

**输入：** `/design-review design/gdd/light-manipulation.md`

**预期行为：**
1. 技能读取文档
2. 技能识别出 4 个缺失章节
3. 技能输出"完整性：4/8 章节已存在"
4. 技能具体列出缺失的是哪 4 个章节
5. 技能输出 MAJOR REVISION NEEDED 判决（非 APPROVED 或 NEEDS REVISION）

**断言：**
- [ ] 输出在完整性部分显示"4/8"（而非更高数字）
- [ ] 输出明确命名每个缺失章节（公式、边缘情况、调优参数、验收标准）
- [ ] 当 ≥3 个章节缺失时，判决为 MAJOR REVISION NEEDED（非 APPROVED 或 NEEDS REVISION）
- [ ] 输出不暗示文档已达到可实施状态
- [ ] 技能不写入任何文件（只读强制）

---

### 用例 3：部分路径——7/8 章节，轻微不一致

**测试夹具 (Fixture)：**
- GDD 包含除公式外的所有章节
- 所描述的行为提及数值但未定义任何公式
- 验收标准存在但表述模糊（"感觉很好"而非可衡量）

**输入：** `/design-review design/gdd/[document].md`

**预期行为：**
1. 技能识别缺失的公式章节
2. 技能将模糊的验收标准标记为可实现性问题
3. 技能输出 NEEDS REVISION 判决（非 APPROVED，非 MAJOR REVISION NEEDED）
4. 技能为每个问题提供具体的修正说明

**断言：**
- [ ] 对于 7/8 章节且存在问题时，判决为 NEEDS REVISION（非 APPROVED，非 MAJOR REVISION NEEDED）
- [ ] 输出具体识别缺失的公式章节
- [ ] 输出将模糊的验收标准标记为可实现性差距
- [ ] 每个被标记的问题都有具体、可操作的修正说明

---

### 用例 4：边缘情况——文件未找到

**测试夹具 (Fixture)：**
- 提供的路径在项目中不存在

**输入：** `/design-review design/gdd/nonexistent.md`

**预期行为：**
1. 技能尝试读取文件
2. 文件未找到
3. 技能输出错误信息，指明缺失的文件
4. 技能建议检查路径或列出 `design/gdd/` 中的文件
5. 技能不产出判决

**断言：**
- [ ] 技能在文件未找到时输出明确的错误信息
- [ ] 技能在文件缺失时不输出 APPROVED、NEEDS REVISION 或 MAJOR REVISION NEEDED
- [ ] 技能建议纠正措施（检查路径、列出可用 GDD）

---

### 用例 5：主管门控——无论审查模式如何，均不启动门控

**测试夹具 (Fixture)：**
- `design/gdd/light-manipulation.md` 存在，全部 8 个章节均完备
- `production/session-state/review-mode.txt` 存在，包含 `full`（最高权限模式）

**输入：** `/design-review design/gdd/light-manipulation.md`（完整审查模式激活）

**预期行为：**
1. 技能读取 GDD 文档
2. 技能不读取 `review-mode.txt`——本技能无主管门控
3. 技能正常产出审查输出
4. 任何时候均不启动主管门控智能体
5. 判决为 APPROVED（测试夹具中全部 8 个章节均存在）

**断言：**
- [ ] 技能不启动任何主管门控智能体（CD-、TD-、PR-、AD- 前缀的智能体）
- [ ] 技能不读取 `review-mode.txt` 或等效的模式文件
- [ ] `--review` 标志或 `full` 模式状态对主管是否启动没有任何影响
- [ ] 输出不包含任何"门控：[GATE-ID]"条目
- [ ] 技能本身就是审查——它不会将审查委托给主管

---

## 协议合规性 (Protocol Compliance)

- [ ] 不使用 Write 或 Edit 工具（只读技能）
- [ ] 在任何判决之前先展示完整发现
- [ ] 在产出输出前不请求批准（无需批准写入操作）
- [ ] 末尾提供推荐的下一步操作（例如，修复问题并重新运行，或继续执行 `/map-systems`）

---

## 覆盖范围说明 (Coverage Notes)

- 跨系统一致性检查（技能自身阶段列表中的用例 3）在此处未直接测试，因为它需要比较多个 GDD 文件；这由 `/review-all-gdds` 规格覆盖。
- 技能的 `context: fork` 行为（作为子智能体运行）未在规格层面测试——这是一个运行时行为，需手动验证。
- 涉及非常大的 GDD 文件的性能和边缘情况不在范围内。
