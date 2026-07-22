
# 技能测试规格：/code-review（代码审查）

## 技能概述（Skill Summary）

`/code-review` 对 `src/` 中的源代码文件进行架构级代码审查，检查 `CLAUDE.md` 中定义的编码标准（公开 API 的文档注释、依赖注入而非单例、数据驱动值、可测试性）。发现结果为建议性质。不调用任何主管关卡（Director Gate）。不进行代码编辑。裁决结果（Verdict）：APPROVED（批准）、CONCERNS（关注）或 NEEDS CHANGES（需要修改）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：APPROVED、CONCERNS、NEEDS CHANGES
- [ ] 不需要"May I write"用语（只读；发现结果为建议性输出）
- [ ] 具有下一步交接说明（如何处理发现结果）

---

## 主管关卡检查（Director Gate Checks）

无。代码审查是一项只读建议性技能；不调用任何关卡。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 源文件遵循所有编码标准

**测试夹具（Fixture）：**
- `src/gameplay/health_component.gd` 存在，且：
  - 所有公开方法均有文档注释（`##` 标记）
  - 未使用单例；依赖通过构造函数注入
  - 无硬编码值；所有常量引用 `assets/data/`
  - 文件头部包含架构决策记录（Architecture Decision Record, ADR）引用：`# ADR: docs/architecture/adr-004-health.md`
  - 引用的 ADR 状态为 `Status: Accepted`

**输入：** `/code-review src/gameplay/health_component.gd`

**预期行为：**
1. 技能读取源文件
2. 技能检查所有编码标准：文档注释、依赖注入（Dependency Injection, DI）、数据驱动、ADR 状态
3. 所有检查通过
4. 技能输出发现结果摘要，所有检查显示 PASS
5. 裁决结果为 APPROVED

**断言：**
- [ ] 每条编码标准检查均在输出中列出
- [ ] 符合标准时所有检查显示 PASS
- [ ] 技能读取引用的 ADR 以确认其状态
- [ ] 裁决结果为 APPROVED
- [ ] 不编辑任何文件

---

### 用例 2：需要修改 —— 缺少文档注释且使用了单例

**测试夹具：**
- `src/ui/inventory_ui.gd` 存在以下问题：
  - 2 个公开方法缺少文档注释
  - 使用了 `GameManager.instance`（单例模式）
  - 所有其他标准符合要求

**输入：** `/code-review src/ui/inventory_ui.gd`

**预期行为：**
1. 技能读取源文件
2. 技能检测到：2 个公开方法缺少文档注释
3. 技能检测到：在特定行使用了单例（例如第 42 行、第 87 行）
4. 发现结果列出具体的方法名称和行号
5. 裁决结果为 NEEDS CHANGES

**断言：**
- [ ] 缺失的文档注释连同方法名称一并列出
- [ ] 单例使用连同文件和行号被标记
- [ ] 当存在 BLOCKING 级别的标准违规时，裁决结果为 NEEDS CHANGES
- [ ] 技能不编辑文件 —— 发现结果供开发者采取行动
- [ ] 输出建议用依赖注入替代单例

---

### 用例 3：架构风险 —— ADR 引用状态为 Proposed（提议），而非 Accepted（已接受）

**测试夹具：**
- `src/core/save_system.gd` 有头部注释：`# ADR: docs/architecture/adr-010-save.md`
- `adr-010-save.md` 存在但状态为 `Status: Proposed`
- 代码本身遵循所有其他编码标准

**输入：** `/code-review src/core/save_system.gd`

**预期行为：**
1. 技能读取源文件
2. 技能读取引用的 ADR —— 发现 `Status: Proposed`
3. 技能将此标记为 ARCHITECTURE RISK（架构风险）（代码正在实现未接受的 ADR）
4. 其他编码标准检查通过
5. 裁决结果为 CONCERNS（风险标记为建议性质，非硬性 NEEDS CHANGES）

**断言：**
- [ ] 技能读取引用的 ADR 文件以检查其状态
- [ ] 当 ADR 状态为 Proposed 时标记 ARCHITECTURE RISK
- [ ] 对于 ADR 风险，裁决结果为 CONCERNS（而非 NEEDS CHANGES）—— 建议级别严重程度
- [ ] 输出建议在代码投入生产前解决 ADR 问题

---

### 用例 4：边界情况 —— 指定路径下未找到源文件

**测试夹具：**
- 用户调用 `/code-review src/networking/`
- `src/networking/` 目录不存在

**输入：** `/code-review src/networking/`

**预期行为：**
1. 技能尝试读取 `src/networking/` 中的文件
2. 目录或文件未找到
3. 技能输出错误："在 `src/networking/` 未找到源文件"
4. 技能建议检查 `src/` 中的有效目录
5. 不发出裁决结果（未审查任何内容）

**断言：**
- [ ] 路径不存在时技能不会崩溃
- [ ] 输出在错误消息中指明尝试的路径
- [ ] 输出建议检查 `src/` 中的有效文件路径
- [ ] 当没有可审查的内容时不发出裁决结果

---

### 用例 5：关卡合规性 —— 无关卡；可单独咨询主程

**测试夹具：**
- 源文件遵循大多数标准，但有 1 个 CONCERNS 级别的发现结果（一个魔数）
- `review-mode.txt` 包含 `full`

**输入：** `/code-review src/gameplay/loot_system.gd`

**预期行为：**
1. 技能读取并审查源文件
2. 不调用任何主管关卡（代码审查发现结果为建议性质）
3. 技能展示发现结果，裁决结果为 CONCERNS
4. 输出提示："建议请求主程（Lead Programmer）审查架构问题"
5. 技能不自动调用任何智能体

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 输出中建议（而非强制）咨询主程
- [ ] 不进行任何代码编辑
- [ ] 对于建议级别的发现结果，裁决结果为 CONCERNS

---

## 协议合规性（Protocol Compliance）

- [ ] 在审查前读取源文件和编码标准
- [ ] 在发现结果输出中列出每条编码标准检查
- [ ] 不编辑任何源文件（只读技能）
- [ ] 不调用任何主管关卡
- [ ] 裁决结果为以下之一：APPROVED、CONCERNS、NEEDS CHANGES

---

## 覆盖范围说明（Coverage Notes）

- 批量审查目录中所有文件的情况未进行明确测试；行为假定为逐文件应用相同检查并汇总裁决结果。
- 测试覆盖范围检查（验证是否存在对应的测试文件）是一个未在此处测试的扩展目标；这主要是 `/test-evidence-review` 的领域。
