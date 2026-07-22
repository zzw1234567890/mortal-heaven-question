
# 技能测试规格：/test-flakiness

## 技能概述

`/test-flakiness` 通过分析测试历史日志（如有）或扫描测试源代码中常见的不稳定模式（无种子的随机数、实时等待、外部 I/O）来检测非确定性测试。不调用任何总监关卡（director gate）。该技能在未经用户批准的情况下不会写入文件。判定结果：NO FLAKINESS（无不稳定测试）、SUSPECT TESTS FOUND（发现可疑测试）或 CONFIRMED FLAKY（确认不稳定）。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证 —— 无需测试夹具（fixture）。

- [ ] 包含必需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：NO FLAKINESS、SUSPECT TESTS FOUND、CONFIRMED FLAKY
- [ ] 不要求使用"我可以写入吗"（May I write）的措辞（只读模式；可选报告需要批准）
- [ ] 包含下一步交接说明（发现不稳定测试后的处理方式）

---

## 总监关卡检查

无。不稳定测试检测是面向质量保证负责人 (QA Lead) 的建议性质检技能；不调用任何关卡。

---

## 测试用例

### 用例 1：正常路径 —— 测试历史干净，无不稳定测试

**测试夹具：**
- `production/qa/test-history/` 中包含 10 次测试运行的日志
- 所有测试在所有 10 次运行中一致通过（每个测试的通过率为 100%）
- 没有任何测试存在失败模式

**输入：** `/test-flakiness`

**预期行为：**
1. 技能从 `production/qa/test-history/` 读取测试历史日志
2. 技能计算每个测试在 10 次运行中的通过率
3. 所有测试均通过全部 10 次运行 —— 未检测到不一致
4. 判定结果为 NO FLAKINESS

**断言：**
- [ ] 技能在有可用数据时读取测试历史日志
- [ ] 计算每个测试在所有可用运行中的通过率
- [ ] 当所有测试一致通过时，判定结果为 NO FLAKINESS
- [ ] 不写入任何文件

---

### 用例 2：发现可疑测试 —— 测试在历史中间歇性失败

**测试夹具：**
- `production/qa/test-history/` 中包含 10 次测试运行的日志
- `test_combat_damage_applies_crit_multiplier` 通过 7 次，失败 3 次
- 失败消息各不相同（有时超时，有时数值错误）

**输入：** `/test-flakiness`

**预期行为：**
1. 技能读取测试历史日志 —— 计算通过率
2. `test_combat_damage_applies_crit_multiplier` 的通过率为 70%（阈值：95%）
3. 技能将其标记为 SUSPECT（可疑），注明通过率（7/10）和失败模式
4. 判定结果为 SUSPECT TESTS FOUND
5. 技能建议调查该测试是否存在时序或状态依赖问题

**断言：**
- [ ] 低于通过率阈值的测试会被按名称标记
- [ ] 为每个可疑测试显示通过率（分数和百分比）
- [ ] 如果可检测到，记录失败模式（例如，不一致的错误消息）
- [ ] 判定结果为 SUSPECT TESTS FOUND
- [ ] 技能建议调查步骤

---

### 用例 3：源代码模式 —— 使用无种子的随机数

**测试夹具：**
- 无测试历史日志
- `tests/unit/loot/loot_drop_test.gd` 包含：
  ```gdscript
  var roll = randf()  # unseeded random — non-deterministic
  assert_gt(roll, 0.5, "Loot should drop above 50%")
  ```

**输入：** `/test-flakiness`

**预期行为：**
1. 技能未找到测试历史日志
2. 技能回退到源代码分析
3. 技能检测到 `randf()` 调用前没有 `seed()` 调用
4. 技能将该测试标记为 FLAKINESS RISK（不稳定风险，基于源代码模式，未确认）
5. 判定结果为 SUSPECT TESTS FOUND（检测到模式，但未被历史确认）
6. 技能建议在调用前为随机数设定种子，或模拟随机函数

**断言：**
- [ ] 在无历史日志时，使用源代码分析作为回退方案
- [ ] 未设种子的随机数使用被检测为不稳定风险
- [ ] 判定结果为 SUSPECT TESTS FOUND（而非 CONFIRMED FLAKY —— 无历史数据确认）
- [ ] 修复建议包括设定种子或模拟

---

### 用例 4：无测试历史 —— 仅进行含常见模式的源代码分析

**测试夹具：**
- `production/qa/test-history/` 不存在
- `tests/` 包含 15 个测试文件
- 扫描发现 2 个测试使用 `OS.get_ticks_msec()` 进行时序断言
- 未发现其他不稳定模式

**输入：** `/test-flakiness`

**预期行为：**
1. 技能检查测试历史 —— 未找到
2. 技能注明："无可用测试历史 —— 仅分析源代码中的不稳定模式"
3. 技能扫描所有测试文件中的已知模式：未设种子的随机数、实时等待、系统时钟使用
4. 发现 2 个测试使用 `OS.get_ticks_msec()` —— 标记为 FLAKINESS RISK
5. 判定结果为 SUSPECT TESTS FOUND

**断言：**
- [ ] 技能明确注明正在执行仅源代码分析（无历史数据）
- [ ] 扫描常见不稳定模式：随机数、基于时间的断言、外部 I/O
- [ ] 将对 `OS.get_ticks_msec()` 用于断言的行为标记为不稳定风险
- [ ] 当发现源代码模式时，判定结果为 SUSPECT TESTS FOUND

---

### 用例 5：关卡合规 —— 无关卡；不稳定报告为建议性质

**测试夹具：**
- 测试历史显示 1 个 CONFIRMED FLAKY 测试（10 次运行中失败 6 次）
- `review-mode.txt` 包含 `full`

**输入：** `/test-flakiness`

**预期行为：**
1. 技能分析测试历史；确认 1 个不稳定测试
2. 无论审查模式为何，均不调用总监关卡
3. 判定结果为 CONFIRMED FLAKY
4. 技能展示发现结果并提供可选书面报告
5. 如果用户选择："我可以写入 `production/qa/flakiness-report-[date].md` 吗？"

**断言：**
- [ ] 在任何审查模式下均不调用总监关卡
- [ ] CONFIRMED FLAKY 判定需要基于历史的证据（而非仅源代码模式）
- [ ] 可选报告在写入前需要征求"我可以写入吗？"
- [ ] 不稳定报告对质量保证负责人 (QA Lead) 为建议性质；技能不会自动禁用测试

---

## 协议合规性

- [ ] 在有可用数据时读取测试历史日志；无历史数据时回退到源代码分析
- [ ] 明确注明正在使用的分析模式（基于历史或仅源代码）
- [ ] 使用不稳定阈值（例如 95% 通过率）进行 SUSPECT 分类
- [ ] CONFIRMED FLAKY 需要历史证据；SUSPECT 仅覆盖源代码模式
- [ ] 不禁用或修改任何测试文件
- [ ] 不调用总监关卡
- [ ] 判定结果为以下之一：NO FLAKINESS、SUSPECT TESTS FOUND、CONFIRMED FLAKY

---

## 覆盖说明

- SUSPECT 分类的通过率阈值（上述建议为 95%）是实施细节；测试验证的是间歇性失败被标记，而非确切的阈值数值。
- 因环境问题（缺少资源、错误平台）而失败的测试不属于不稳定 —— 技能会区分环境失败与测试本身的非确定性；此区分在此未做显式测试。
