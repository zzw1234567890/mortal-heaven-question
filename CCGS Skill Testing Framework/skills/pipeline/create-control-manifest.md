
# 技能测试规范：/create-control-manifest

## 技能概述

`/create-control-manifest` 读取 `docs/architecture/` 中所有状态为 Accepted 的 ADR（架构决策记录），并生成一个控制清单（control manifest）— 一份汇总文档，将所有的架构约束、必需模式和禁止模式汇集在一处。该清单是 story 作者在编写 story 文件时使用的参考文档，确保 story 继承正确的架构规则，而无需逐一阅读所有 ADR。

该技能仅包含状态为 Accepted 的 ADR；状态为 Proposed 的 ADR 将被排除并注明。无总监关卡。技能在写入 `docs/architecture/control-manifest.md` 前会询问"May I write"。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含判定关键词：CREATED、BLOCKED
- [ ] 包含 "May I write" 协作协议措辞（用于 control-manifest.md）
- [ ] 末尾具有下一步交接（`/create-epics` 或 `/create-stories`）
- [ ] 文档注明仅包含状态为 Accepted 的 ADR（不包含 Proposed）

---

## 总监关卡检查

无总监关卡 — 该技能不派生任何总监关卡代理。控制清单是从状态为 Accepted 的 ADR 中机械提取的结果；无需创意或技术评审关卡。

---

## 测试用例

### 用例 1：正常路径 — 4 个 Accepted ADR 生成正确的清单

**测试夹具：**
- `docs/architecture/` 包含 4 个 ADR 文件，全部状态为 `Status: Accepted`
- 每个 ADR 具有 "Required Patterns" 和/或 "Forbidden Patterns" 章节
- 尚无 `docs/architecture/control-manifest.md`

**输入：** `/create-control-manifest`

**预期行为：**
1. 技能读取 `docs/architecture/` 中所有 ADR 文件
2. 从每个 ADR 中提取必需模式、禁止模式和关键约束
3. 起草具有正确章节结构的清单
4. 向用户展示清单草稿
5. 询问"我可以写入 `docs/architecture/control-manifest.md` 吗？"
6. 获得批准后写入清单

**断言：**
- [ ] 清单中包含全部 4 个 Accepted ADR
- [ ] 清单包含独立的 "Required Patterns" 和 "Forbidden Patterns" 章节
- [ ] 清单包含每条约束所来源的 ADR 编号
- [ ] 写入前已询问 "May I write"
- [ ] 未经批准，技能不会写入
- [ ] 写入后判定为 CREATED

---

### 用例 2：失败路径 — 未找到 ADR

**测试夹具：**
- `docs/architecture/` 目录存在但不包含任何 ADR 文件

**输入：** `/create-control-manifest`

**预期行为：**
1. 技能读取 `docs/architecture/` 且未找到 ADR 文件
2. 技能输出："未找到 ADR。请在生成控制清单前运行 `/architecture-decision` 创建 ADR。"
3. 技能退出，不创建任何文件
4. 判定为 BLOCKED

**断言：**
- [ ] 未找到 ADR 时技能输出清晰的错误信息
- [ ] 未写入任何控制清单文件
- [ ] 技能推荐 `/architecture-decision` 作为下一步操作
- [ ] 判定为 BLOCKED（而非错误崩溃）

---

### 用例 3：混合 ADR 状态 — 仅包含 Accepted ADR

**测试夹具：**
- `docs/architecture/` 包含 3 个 Accepted ADR 和 2 个 Proposed ADR

**输入：** `/create-control-manifest`

**预期行为：**
1. 技能读取所有 ADR 文件，并按 Status: Accepted 过滤
2. 仅基于 3 个 Accepted ADR 起草清单
3. 输出注明："已排除 2 个 Proposed ADR：[adr-NNN-name, adr-NNN-name]"
4. 用户在批准写入前看到哪些 ADR 被排除
5. 询问"我可以写入 `docs/architecture/control-manifest.md` 吗？"

**断言：**
- [ ] 清单内容中仅出现 3 个 Accepted ADR
- [ ] 被排除的 Proposed ADR 在输出中按名称列出
- [ ] 用户在批准写入前看到排除列表
- [ ] 技能不会在未注明的情况下静默忽略 Proposed ADR

---

### 用例 4：边界情况 — 清单已存在

**测试夹具：**
- `docs/architecture/control-manifest.md` 已存在（版本 1，上周创建）
- `docs/architecture/` 包含 Accepted ADR（部分为上次清单创建后的新增）

**输入：** `/create-control-manifest`

**预期行为：**
1. 技能检测到现有清单并读取其版本号/日期
2. 技能提供重新生成的选项："control-manifest.md 已存在（v1，[日期]）。使用当前 ADR 重新生成吗？"
3. 如果用户确认：技能起草更新后的清单，递增版本号
4. 询问"我可以写入 `docs/architecture/control-manifest.md` 吗？"（覆盖）
5. 获得批准后写入更新后的清单

**断言：**
- [ ] 在提供重新生成选项前，技能读取并报告现有清单版本
- [ ] 向用户提供重新生成/跳过选项 — 不会自动覆盖
- [ ] 更新后的清单具有递增的版本号
- [ ] 覆盖现有文件前已询问 "May I write"

---

### 用例 5：总监关卡 — 不派生关卡；不读取 review-mode.txt

**测试夹具：**
- 4 个 Accepted ADR 存在
- `production/session-state/review-mode.txt` 存在，内容为 `full`

**输入：** `/create-control-manifest`

**预期行为：**
1. 技能读取 ADR 并起草清单
2. 技能不读取 `production/session-state/review-mode.txt`
3. 在任何时候都不派生总监关卡代理
4. 起草后技能直接进入"May I write"环节
5. 评审模式设置对该技能的行为无影响

**断言：**
- [ ] 不派生任何总监关卡代理（无 CD-、TD-、PR-、AD- 前缀的关卡）
- [ ] 技能不读取 `production/session-state/review-mode.txt`
- [ ] 输出不包含 "Gate: [GATE-ID]" 或关卡跳过条目
- [ ] 清单仅从 ADR 生成，无需外部关卡评审

---

## 协议合规性

- [ ] 在起草清单前读取所有 ADR 文件
- [ ] 仅包含 Accepted ADR — Proposed 的注明为已排除
- [ ] 在 "May I write" 询问前向用户展示清单草稿
- [ ] 写入前询问 "May I write `docs/architecture/control-manifest.md`？"
- [ ] 无总监关卡 — 不读取 review-mode.txt
- [ ] 以下一步交接结尾：`/create-epics` 或 `/create-stories`

---

## 覆盖说明

- 所生成清单的确切章节结构（约束表格、模式列表）由技能主体定义，未在测试断言中重新枚举。
- `version` 字段递增逻辑（v1 → v2）通过用例 4 测试，但确切的版本编号格式未在夹具中锁定。
- ADR 解析（提取必需/禁止模式）取决于一致的 ADR 结构 — 通过用例 1 的夹具隐式测试。
