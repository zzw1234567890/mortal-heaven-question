# 技能测试规格：/smoke-check


## 技能概要

`/smoke-check` 是实现与质量保证（QA）交接之间的闸门。它检测测试环境，运行自动化测试套件（通过 Bash），扫描冲刺故事（sprint stories）的测试覆盖情况，并使用 `AskUserQuestion` 与开发者批量确认手动冒烟检查项。它在获得用户明确批准后将报告写入 `production/qa/smoke-[date].md`。

判定结果：PASS（测试通过、所有冒烟检查通过、无缺失测试证据）、PASS WITH WARNINGS（测试通过或 NOT RUN、所有关键检查通过，但存在建议性缺口，例如测试覆盖缺失），或 FAIL（任何自动化测试失败或任何批次 1/批次 2 冒烟检查返回 FAIL）。

不适用任何主管闸门。该技能不会调用任何主管智能体。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键字：PASS、PASS WITH WARNINGS、FAIL
- [ ] 在写入报告前包含"我可以写入"协作协议语言
- [ ] 包含下一步交接（例如，FAIL 时运行 `/bug-report`，PASS 时提供 QA 交接指导）

---

## 主管闸门检查

无。`/smoke-check` 是一项预 QA 实用技能。不适用任何主管闸门。

---

## 测试用例

### 用例 1：快乐路径 —— 自动化测试通过，手动项目已确认，PASS

**测试夹具：**
- `tests/` 目录存在，包含 GDUnit4 运行器脚本
- 从 `technical-preferences.md` 检测到引擎为 Godot
- `production/qa/qa-plan-sprint-005.md` 存在
- 自动化测试运行器报告 12 个测试，12 个通过，0 个失败
- 开发者确认所有批次 1 和批次 2 冒烟检查为 PASS
- 所有冲刺故事都有匹配的测试文件（无 MISSING 覆盖）

**输入：** `/smoke-check`

**预期行为：**
1. 技能检测测试目录和引擎，记录已找到 QA 计划
2. 通过 Bash 运行 `godot --headless --script tests/gdunit4_runner.gd`
3. 解析输出：12/12 通过
4. 扫描测试覆盖——所有故事为 COVERED 或 EXPECTED
5. 使用 `AskUserQuestion` 进行批次 1（核心稳定性）和批次 2（冲刺机制）检查
6. 开发者为所有项目选择 PASS
7. 组装报告：自动化测试 PASS，所有冒烟检查 PASS，无 MISSING 覆盖
8. 询问"我可以将此冒烟检查报告写入 `production/qa/smoke-[date].md` 吗？"
9. 批准后写入报告
10. 给出判定：PASS

**断言：**
- [ ] 通过 Bash 调用自动化测试运行器
- [ ] 对手动冒烟检查批次使用 `AskUserQuestion`
- [ ] 在写入报告文件前询问了"我可以写入"
- [ ] 报告写入到 `production/qa/smoke-[date].md`
- [ ] 判定结果为 PASS

---

### 用例 2：失败路径 —— 自动化测试失败，FAIL 判定

**测试夹具：**
- `tests/` 目录存在，引擎为 Godot
- 自动化测试运行器报告运行 10 个测试：8 个通过，2 个失败
  - 失败的测试：`test_health_clamp_at_zero`、`test_damage_calculation_negative`
- QA 计划存在

**输入：** `/smoke-check`

**预期行为：**
1. 技能通过 Bash 运行自动化测试
2. 解析输出——检测到 2 个失败
3. 记录失败的测试名称
4. 继续进行手动冒烟检查批次
5. 报告显示自动化测试为 FAIL，并列出失败的测试名称
6. 询问写入报告；批准后写入
7. 给出 FAIL 判定，消息为："冒烟检查失败。在解决这些失败之前，不要移交给 QA。"列出失败的测试并建议修复后重新运行 `/smoke-check`

**断言：**
- [ ] 报告中列出失败的测试名称
- [ ] 判定结果为 FAIL
- [ ] 判定后消息引导开发者在移交给 QA 前修复失败
- [ ] 建议修复后重新运行 `/smoke-check`

---

### 用例 3：手动确认 —— 使用 AskUserQuestion，PASS WITH WARNINGS

**测试夹具：**
- `tests/` 目录存在，引擎为 Godot
- 自动化测试运行器报告所有测试通过（8/8）
- 一个逻辑故事没有匹配的测试文件（MISSING 覆盖）
- 开发者确认所有批次 1 和批次 2 冒烟检查为 PASS

**输入：** `/smoke-check`

**预期行为：**
1. 自动化测试 PASS
2. 覆盖扫描发现逻辑故事有 1 个 MISSING 条目
3. 对批次 1 和批次 2 使用 `AskUserQuestion`——开发者确认全部 PASS
4. 报告显示：自动化测试 PASS，手动检查全部 PASS，1 个 MISSING 覆盖条目
5. 判定结果为 PASS WITH WARNINGS——构建已准备好给 QA，但 MISSING 条目必须在 `/story-done` 关闭受影响故事之前解决
6. 询问写入报告；批准后写入

**断言：**
- [ ] 对手动冒烟检查批次使用 `AskUserQuestion`（而非内联文本提示）
- [ ] MISSING 测试覆盖条目出现在报告中
- [ ] 判定结果为 PASS WITH WARNINGS（非 PASS，非 FAIL）
- [ ] 建议性说明解释 MISSING 条目必须在 `/story-done` 前解决
- [ ] 报告文件写入到 `production/qa/smoke-[date].md`

---

### 用例 4：无测试目录 —— 技能停止并给出指导

**测试夹具：**
- `tests/` 目录不存在
- 引擎已配置为 Godot

**输入：** `/smoke-check`

**预期行为：**
1. 阶段 1 检查 `tests/` 目录——未找到
2. 技能输出："在 `tests/` 未找到测试目录。运行 `/test-setup` 来搭建测试基础设施，或者如果测试存放在别处，请手动创建该目录。"
3. 技能停止——不运行自动化测试，不进行手动冒烟检查，不写入报告

**断言：**
- [ ] 错误消息引用缺失的 `tests/` 目录
- [ ] 建议 `/test-setup` 作为修复步骤
- [ ] 技能在此消息后停止（不再运行后续阶段）
- [ ] 未写入报告文件

---

### 用例 5：主管闸门检查 —— 无闸门；smoke-check 是 QA 预检实用技能

**测试夹具：**
- 有效的测试设置，自动化测试通过，手动冒烟检查已确认

**输入：** `/smoke-check`

**预期行为：**
1. 技能运行所有阶段并产生 PASS 或 PASS WITH WARNINGS 判定
2. 任何时候都不生成主管智能体
3. 输出中不出现闸门 ID（CD-*、TD-*、AD-*、PR-*）
4. 不调用 `/gate-check`

**断言：**
- [ ] 未调用主管闸门
- [ ] 无闸门跳过消息出现
- [ ] 判定结果为 PASS、PASS WITH WARNINGS 或 FAIL——不涉及闸门判定

---

## 协议合规性

- [ ] 对所有手动冒烟检查批次（批次 1、批次 2、批次 3）使用 `AskUserQuestion`
- [ ] 在询问任何手动问题前通过 Bash 运行自动化测试
- [ ] 在创建报告文件前询问"我可以写入"——未经批准绝不写入
- [ ] 判定词汇严格限于 PASS / PASS WITH WARNINGS / FAIL——无其他判定
- [ ] FAIL 由自动化测试失败或批次 1/批次 2 FAIL 响应触发
- [ ] PASS WITH WARNINGS 在存在 MISSING 测试覆盖但无关键失败时触发
- [ ] NOT RUN（引擎二进制不可用）记录为警告，而非 FAIL
- [ ] 在任何时候都不调用主管闸门

---

## 覆盖说明

- `quick` 参数（跳过阶段 3 覆盖扫描和批次 3）未单独进行夹具测试；它遵循与用例 1 相同的模式，并在输出中带有覆盖跳过说明。
- `--platform` 参数添加平台特定的 AskUserQuestion 批次和按平台的判定表；此处未单独测试。
- 引擎二进制不在 PATH 中（NOT RUN）的情况遵循 PASS WITH WARNINGS 模式，由上述协议合规性断言覆盖。
