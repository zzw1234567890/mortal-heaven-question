
# 技能测试规范 (Skill Test Spec)：/[skill-name]

## 技能摘要 (Skill Summary)

[一段话：该技能做什么、何时使用、产出什么。包括主要产出产物、使用的判定格式，以及所属管线阶段。]

---

## 静态断言 (Static Assertions) —— 结构检查

由 `/skill-test static` 自动验证 —— 无需测试夹具 (fixture)。

- [ ] 包含必需的 frontmatter 字段：`name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- [ ] 包含 ≥2 个阶段标题（## Phase N 或编号的 ## 章节）
- [ ] 包含判定关键词：[列出预期的关键词，例如 PASS, FAIL, CONCERNS]
- [ ] 包含"May I write"协作协议用语（如果技能会写入文件）
- [ ] 末尾有下一步交接指引

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径 (Happy Path) —— [简短描述]

**测试夹具 (Fixture)**：[描述假设的项目状态。哪些文件存在？内容是什么？例如："game-concept.md 存在且所有 8 个必需部分已完成。systems-index.md 存在。所有 MVP GDD 均已存在并单独审查通过。"]

**输入 (Input)**：`/[skill-name] [args]`

**预期行为 (Expected behavior)**：
1. [阶段 1 操作 —— 技能应读取或检查的内容]
2. [阶段 2 操作 —— 技能应评估的内容]
3. [阶段 N 操作 —— 技能应输出的内容]

**断言 (Assertions)**：
- [ ] 技能在产出输出前读取 [特定文件]
- [ ] 输出包含判定关键词 [PASS/FAIL/等]
- [ ] 输出列出测试夹具中的 [特定内容]
- [ ] 技能在写入任何文件前请求批准

---

### 用例 2：失败路径 (Failure Path) —— [简短描述，例如"缺少必需产物"]

**测试夹具 (Fixture)**：[描述失败状态。例如："game-concept.md 缺失。design/gdd/ 中不存在任何文件。"]

**输入 (Input)**：`/[skill-name] [args]`

**预期行为 (Expected behavior)**：
1. [阶段 1：技能检测到缺失文件]
2. [阶段 2：技能呈现缺口，而非假定一切正常]
3. [输出：FAIL 或 BLOCKED 判定，并列出具体阻塞项]

**断言 (Assertions)**：
- [ ] 当测试夹具不完整时，技能不会输出 PASS
- [ ] 技能明确指出缺失的具体产物
- [ ] 技能建议修复措施（例如"运行 /[other-skill]"）
- [ ] 技能不会在未经询问的情况下创建文件来填补缺口

---

### 用例 3：边界情况 (Edge Case) —— [简短描述，例如"未提供参数"]

**测试夹具 (Fixture)**：[此用例的项目文件状态]

**输入 (Input)**：`/[skill-name]`（无参数）

**预期行为 (Expected behavior)**：
1. [技能在无参数调用时应执行的操作]

**断言 (Assertions)**：
- [ ] [断言]

---

## 协议合规性 (Protocol Compliance)

- [ ] 在写入所有文件前使用"May I write"
- [ ] 在请求写入批准前展示发现或报告
- [ ] 以推荐的下一个步骤或后续技能结束
- [ ] 未经用户明确批准，绝不自动创建文件
- [ ] 不会跳过阶段或未经检查直接得出判定

---

## 覆盖说明 (Coverage Notes)

[记录本规范有意不测试的内容及其原因。示例：
- "用例 3（全模式）未涵盖，因其运行检查过多，无法在单一规范中评估 —— 请单独测试每个子模式。"
- "数据库集成路径未涵盖，因其需要真实环境。"
- "涉及损坏 YAML 文件的边界情况推迟至未来规范。"]
