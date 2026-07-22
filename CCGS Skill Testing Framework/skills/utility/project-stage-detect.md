
# 技能测试规格：/project-stage-detect

## 技能概述 (Skill Summary)

`/project-stage-detect` 自动分析项目工件（artifact），确定当前开发阶段。它在 Haiku 模型上运行（只读），检查 `production/stage.txt`（如存在）、`design/` 中的设计文档、`src/` 中的源代码、`production/` 中的冲刺和里程碑（milestone）文件，以及引擎配置的存在情况，将项目归入七个阶段之一：概念（Concept）、系统设计（Systems Design）、技术搭建（Technical Setup）、预制作（Pre-Production）、制作（Production）、打磨（Polish）或发布（Release）。

该技能为咨询性质——它从不写入 `stage.txt`。该文件仅在 `/gate-check` 通过且用户确认推进时更新。技能报告其置信度（Confidence）级别（HIGH：直接读取了 stage.txt；MEDIUM：根据工件推断；LOW：发现冲突信号）。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含全部七个阶段名称：Concept、Systems Design、Technical Setup、Pre-Production、Production、Polish、Release
- [ ] 不包含"May I write"用语（技能仅用于检测）
- [ ] 包含下一步交接（例如 `/gate-check` 用于正式推进阶段）

---

## 主管关口检查

无。`/project-stage-detect` 是一个只读检测工具。不适用主管关口。

---

## 测试用例

### 用例 1：stage.txt 存在——直接读取并交叉验证工件

**测试夹具：**
- `production/stage.txt` 包含 `Production`
- `design/gdd/` 有 4 个 GDD 文件
- `src/` 包含源代码文件
- `production/sprints/sprint-002.md` 存在

**输入：** `/project-stage-detect`

**预期行为：**
1. 技能读取 `production/stage.txt`——检测到阶段 `Production`
2. 技能交叉验证工件：GDD 存在、源代码存在、冲刺存在
3. 工件与 Production 阶段一致
4. 技能报告：阶段 = Production，置信度 = HIGH（来自 stage.txt，经工件确认）
5. 下一步：继续使用 `/sprint-plan` 或 `/dev-story`

**断言：**
- [ ] 检测到的阶段为 Production
- [ ] stage.txt 存在时，置信度报告为 HIGH
- [ ] 注明交叉验证结果（一致或不一致）
- [ ] 不写入任何文件
- [ ] 判定明确声明检测到的阶段

---

### 用例 2：无 stage.txt 但存在 GDD 和 Epics——推断为 Production

**测试夹具：**
- 无 `production/stage.txt`
- `design/gdd/` 有 3 个 GDD 文件
- `production/epics/` 有 2 个史诗（epic）文件
- `src/` 包含源代码文件
- `production/sprints/sprint-001.md` 存在

**输入：** `/project-stage-detect`

**预期行为：**
1. 技能未找到 stage.txt——切换至工件推断模式
2. 技能找到 GDD（系统设计已完成）、史诗（预制作已完成）、源代码和冲刺（制作进行中）
3. 技能推断：阶段 = Production
4. 置信度为 MEDIUM（根据工件推断，非来自 stage.txt）
5. 技能建议运行 `/gate-check` 以正式化并写入 stage.txt

**断言：**
- [ ] 推断的阶段为 Production
- [ ] 置信度为 MEDIUM（非 HIGH，因为缺少 stage.txt）
- [ ] 包含运行 `/gate-check` 的建议
- [ ] 此技能不写入 stage.txt

---

### 用例 3：无 stage.txt、无文档、无源代码——推断为 Concept

**测试夹具：**
- 无 `production/stage.txt`
- `design/` 目录存在但为空
- `src/` 存在但不包含代码文件
- `technical-preferences.md` 仅有占位符

**输入：** `/project-stage-detect`

**预期行为：**
1. 技能未找到 stage.txt
2. 工件扫描：无 GDD、无源代码、无史诗、无冲刺、引擎未配置
3. 技能推断：阶段 = Concept
4. 置信度为 MEDIUM
5. 技能建议使用 `/start` 开始上手流程

**断言：**
- [ ] 推断的阶段为 Concept
- [ ] 输出列出已检查（且未找到）的工件
- [ ] 建议将 `/start` 作为下一步
- [ ] 不写入任何文件

---

### 用例 4：不一致——stage.txt 显示 Production 但无源代码

**测试夹具：**
- `production/stage.txt` 包含 `Production`
- `design/gdd/` 有 GDD 文件
- `src/` 目录存在但不包含源代码文件
- 无冲刺文件

**输入：** `/project-stage-detect`

**预期行为：**
1. 技能读取 stage.txt——检测到 `Production`
2. 交叉验证发现：无源代码、无冲刺——与 Production 阶段不一致
3. 技能标记不一致："stage.txt 显示 Production，但未找到源代码或冲刺文件"
4. 技能报告检测到的阶段为 Production（尊重 stage.txt），但由于工件不匹配，置信度降至 LOW
5. 技能建议手动审查 stage.txt 或运行 `/gate-check`

**断言：**
- [ ] 输出中明确标记不一致
- [ ] 当工件与 stage.txt 相矛盾时，置信度为 LOW
- [ ] 不会静默覆盖 stage.txt 的值
- [ ] 建议用户手动验证不一致问题

---

### 用例 5：主管关口检查——无关卡；检测为咨询性质

**测试夹具：**
- 任何有或没有 stage.txt 的项目状态

**输入：** `/project-stage-detect`

**预期行为：**
1. 技能完成完整的阶段检测
2. 在任何阶段都不生成主管智能体
3. 输出中不出现关口 ID
4. 未调用写入工具

**断言：**
- [ ] 未调用主管关口
- [ ] 未调用写入工具
- [ ] 检测输出纯属咨询性质
- [ ] 判定命名检测到的阶段，不触发任何关口

---

## 协议合规性

- [ ] 如果 stage.txt 存在则读取；如果不存在则回退至工件推断
- [ ] 始终报告置信度级别（HIGH / MEDIUM / LOW）
- [ ] 将 stage.txt 与工件交叉验证并标记不一致
- [ ] 不写入 stage.txt（那是 `/gate-check` 的职责）
- [ ] 以适合检测到的阶段的下一步建议结束

---

## 覆盖说明

- Technical Setup 阶段（引擎已配置，尚无 GDD）和 Pre-Production 阶段（GDD 已完成，尚无史诗）遵循与用例 2 和 3 相同的工件推断模式，未单独使用夹具测试。
- Polish 和 Release 阶段在此处未使用夹具测试；它们遵循相同的高置信度（stage.txt 存在）或推断逻辑。
- 置信度级别为咨询性质——技能不因此限制任何操作。