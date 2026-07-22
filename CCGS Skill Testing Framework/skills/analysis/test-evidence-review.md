
# 技能测试规格：/test-evidence-review（测试证据审查）

## 技能概述（Skill Summary）

`/test-evidence-review` 对 `tests/` 中的测试文件进行质量审查，检查测试命名约定、确定性、隔离性以及是否缺少硬编码魔数 —— 所有这些均依据 `coding-standards.md` 中定义的项目测试标准。发现结果可能会被标记以供质量保证主管（QA Lead）审查。不调用任何主管关卡（Director Gate）。该技能在未经用户批准的情况下不会写入文件。裁决结果（Verdict）：PASS（通过）、WARNINGS（警告）或 FAIL（失败）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：PASS、WARNINGS、FAIL
- [ ] 不需要"May I write"用语（只读；写入为可选标记报告）
- [ ] 具有下一步交接说明（审查发现结果后的操作建议）

---

## 主管关卡检查（Director Gate Checks）

无。测试证据审查是一项建议性质检技能；QL-TEST-COVERAGE 关卡是单独的技能调用，不在此处触发。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 测试遵循所有标准

**测试夹具（Fixture）：**
- `tests/unit/combat/health_system_take_damage_test.gd` 存在，且：
  - 命名：`test_health_system_take_damage_reduces_health()`（遵循 `test_[system]_[scenario]_[expected]` 格式）
  - 具有 Arrange/Act/Assert 结构
  - 无 `sleep()`、带时间值的 `await` 或随机种子
  - 无对外部 API 或文件 I/O 的调用
  - 无行内魔数（使用 `tests/unit/combat/fixtures/` 中的常量）

**输入：** `/test-evidence-review tests/unit/combat/`

**预期行为：**
1. 技能从 `coding-standards.md` 读取测试标准
2. 技能读取测试文件；检查所有 5 项标准
3. 所有检查通过：命名、结构、确定性、隔离性、无硬编码数据
4. 裁决结果为 PASS

**断言：**
- [ ] 5 项测试标准中的每一项均被检查并报告
- [ ] 符合标准时所有检查显示 PASS
- [ ] 裁决结果为 PASS
- [ ] 不写入任何文件

---

### 用例 2：失败 —— 检测到时序依赖

**测试夹具：**
- `tests/unit/ui/hud_update_test.gd` 包含：
  ```gdscript
  await get_tree().create_timer(1.0).timeout
  assert_eq(label.text, "Ready")
  ```
- 使用了 1 秒实时等待，而非模拟或基于信号的断言

**输入：** `/test-evidence-review tests/unit/ui/hud_update_test.gd`

**预期行为：**
1. 技能读取测试文件
2. 技能检测到实时等待（`create_timer(1.0)`）—— 非确定性时序依赖
3. 技能将其标记为 FAIL 级别的发现结果
4. 裁决结果为 FAIL
5. 技能建议用基于信号的断言或模拟替代计时器

**断言：**
- [ ] 实时等待被检测为非确定性时序依赖
- [ ] 发现结果被归类为 FAIL 严重程度（阻塞性 —— 违反确定性标准）
- [ ] 裁决结果为 FAIL
- [ ] 修复建议引用基于信号或模拟的方法
- [ ] 技能不编辑测试文件

---

### 用例 3：失败 —— 测试直接调用外部 API

**测试夹具：**
- `tests/unit/networking/auth_test.gd` 包含：
  ```gdscript
  var result = HTTPRequest.new().request("https://api.example.com/auth")
  ```
- 直接向外部 API 发起 HTTP 调用，没有使用模拟

**输入：** `/test-evidence-review tests/unit/networking/auth_test.gd`

**预期行为：**
1. 技能读取测试文件
2. 技能检测到直接的外部 API 调用（向真实 URL 发起 HTTPRequest）
3. 技能将其标记为 FAIL 级别的发现结果 —— 违反隔离性标准
4. 裁决结果为 FAIL
5. 技能建议注入一个模拟 HTTP 客户端

**断言：**
- [ ] 直接的外部 API 调用被检测并标记
- [ ] 发现结果被归类为 FAIL 严重程度（违反隔离性标准）
- [ ] 裁决结果为 FAIL
- [ ] 修复建议引用使用模拟 HTTP 客户端的依赖注入
- [ ] 技能不修改测试文件

---

### 用例 4：边界情况 —— 未找到测试文件

**测试夹具：**
- 用户调用 `/test-evidence-review tests/unit/audio/`
- `tests/unit/audio/` 目录不存在

**输入：** `/test-evidence-review tests/unit/audio/`

**预期行为：**
1. 技能尝试读取 `tests/unit/audio/` 中的文件 —— 未找到
2. 技能输出："在 `tests/unit/audio/` 未找到测试文件 —— 运行 `/test-setup` 来搭建测试目录结构"
3. 不发出裁决结果

**断言：**
- [ ] 路径不存在时技能不崩溃
- [ ] 输出在消息中指明尝试的路径
- [ ] 输出建议使用 `/test-setup` 进行搭建
- [ ] 当没有可审查的内容时不发出裁决结果

---

### 用例 5：关卡合规性 —— 无关卡；QL-TEST-COVERAGE 是单独技能

**测试夹具：**
- 测试文件有 1 个 WARNINGS 级别的发现结果（非边界测试中的魔数）
- `review-mode.txt` 包含 `full`

**输入：** `/test-evidence-review tests/unit/combat/`

**预期行为：**
1. 技能审查测试；发现 1 个 WARNINGS 级别的发现结果
2. 不调用任何主管关卡（QL-TEST-COVERAGE 单独调用，不在此处）
3. 裁决结果为 WARNINGS
4. 输出说明："如需完整的测试覆盖范围关卡，请运行 `/gate-check`，它将调用 QL-TEST-COVERAGE"
5. 技能提供可选的报告写入；如果用户选择写入则询问"May I write"

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 输出将该技能与 QL-TEST-COVERAGE 关卡调用区分开来
- [ ] 可选报告在写入前需要"May I write"确认
- [ ] 对于建议级别的测试质量问题，裁决结果为 WARNINGS

---

## 协议合规性（Protocol Compliance）

- [ ] 在审查测试文件前读取 `coding-standards.md` 中的测试标准
- [ ] 检查命名、Arrange/Act/Assert 结构、确定性、隔离性、无硬编码数据
- [ ] 不编辑任何测试文件（只读技能）
- [ ] 不调用任何主管关卡
- [ ] 裁决结果为以下之一：PASS、WARNINGS、FAIL

---

## 覆盖范围说明（Coverage Notes）

- 批量审查 `tests/` 中所有测试文件的情况未进行明确测试；行为假定为逐文件应用相同检查并汇总裁决结果。
- QL-TEST-COVERAGE 主管关卡（检查测试覆盖率百分比）是一个单独的关注点，有意不由此技能调用。
