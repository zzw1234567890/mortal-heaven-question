
# 技能测试规格：/onboard

## 技能概述 (Skill Summary)

`/onboard` 为新的团队成员生成上下文相关的项目入手指南。它读取 CLAUDE.md、`technical-preferences.md`、当前冲刺（sprint）文件、最近的 git 提交记录以及 `production/stage.txt`，生成一份结构化的导航文档。该技能在 Haiku 模型上运行（只读、格式化任务），不产生文件写入——所有输出均为对话形式。

该技能可选地接受一个角色参数（例如 `/onboard artist`），以将摘要调整为特定职能。当项目处于早期阶段或尚未配置时，输出会相应调整，反映当前已知的有限信息。判定结果始终为 ONBOARDING COMPLETE——该技能纯属信息性用途。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：ONBOARDING COMPLETE
- [ ] 不包含"May I write"用语（技能为只读）
- [ ] 包含下一步交接，建议相关后续技能

---

## 主管关口检查

无。`/onboard` 是一个只读导航技能。不适用主管关口。

---

## 测试用例

### 用例 1：正常路径——已配置项目，处于 Production 阶段，有活跃冲刺

**测试夹具：**
- `production/stage.txt` 包含 `Production`
- `technical-preferences.md` 已填写引擎、语言和专家信息
- `production/sprints/sprint-005.md` 存在且包含进行中的故事（story）
- Git 日志包含 5 条最近提交

**输入：** `/onboard`

**预期行为：**
1. 技能读取 stage.txt、technical-preferences.md、当前冲刺文件和 git 日志
2. 技能生成包含以下章节的入手指南：项目概览（Project Overview）、技术栈（Tech Stack）、当前阶段（Current Stage）、当前冲刺摘要（Active Sprint Summary）、近期活动（Recent Activity）
3. 摘要格式化为便于阅读（标题、要点列表）
4. 下一步建议适合 Production 阶段（例如 `/sprint-status`、`/dev-story`）
5. 声明判定结果 ONBOARDING COMPLETE

**断言：**
- [ ] 输出包含来自 stage.txt 的当前阶段名称
- [ ] 输出包含来自 technical-preferences.md 的引擎和语言信息
- [ ] 总结了当前冲刺中的故事（不仅仅是冲刺文件名）
- [ ] 包含最近的提交上下文
- [ ] 判定结果为 ONBOARDING COMPLETE
- [ ] 不写入任何文件

---

### 用例 2：全新项目——无引擎、无冲刺，建议运行 /start

**测试夹具：**
- `technical-preferences.md` 仅包含占位符（`[TO BE CONFIGURED]`）
- 无 `production/stage.txt`
- 无冲刺文件
- 无超出默认值的 CLAUDE.md 覆盖

**输入：** `/onboard`

**预期行为：**
1. 技能读取所有配置文件并检测到未配置状态
2. 技能生成最小化摘要："此项目尚未配置"
3. 输出解释上手流程：`/start` → `/setup-engine` → `/brainstorm`
4. 技能建议立即运行 `/start` 作为下一步
5. 判定结果为 ONBOARDING COMPLETE（信息性，并非失败）

**断言：**
- [ ] 输出明确提及项目尚未配置
- [ ] 建议将 `/start` 作为下一步
- [ ] 技能不会报错退出——它优雅地处理空项目状态
- [ ] 判定结果仍为 ONBOARDING COMPLETE

---

### 用例 3：未找到 CLAUDE.md——带补救措施的错误提示

**测试夹具：**
- `CLAUDE.md` 文件不存在（已删除或从未创建）
- 其他文件可能存在也可能不存在

**输入：** `/onboard`

**预期行为：**
1. 技能尝试读取 CLAUDE.md 但失败
2. 技能输出错误："未找到 CLAUDE.md——无法生成入手指南"
3. 技能提供补救措施："运行 `/start` 以初始化项目配置"
4. 不生成部分摘要

**断言：**
- [ ] 错误信息明确指出了缺失文件为 CLAUDE.md
- [ ] 明确命名了补救步骤（`/start`）
- [ ] 当根配置文件缺失时，技能不生成部分输出
- [ ] 判定结果为 ONBOARDING COMPLETE（带有错误上下文，非崩溃）

---

### 用例 4：角色特定入职——用户指定"artist"角色

**测试夹具：**
- 已完全配置的项目，处于 Production 阶段
- `design/` 中存在 `art-bible.md`
- 当前冲刺包含视觉类故事类型（动画、VFX）

**输入：** `/onboard artist`

**预期行为：**
1. 技能读取所有标准文件以及任何与美术相关的文档（艺术圣经、资产规格）
2. 摘要针对美术师角色进行调整：艺术圣经概览、资产管线、当前冲刺中的视觉故事
3. 技术架构细节（代码结构、ADR）被弱化
4. 摘要中突出显示艺术/音频方面的专家智能体
5. 判定结果为 ONBOARDING COMPLETE

**断言：**
- [ ] 输出中确认了角色参数（"入职对象：美术师 (Artist)"）
- [ ] 如果艺术圣经文件存在，则包含其摘要
- [ ] 显示当前冲刺中的视觉故事
- [ ] 技术实现细节不是主要关注点
- [ ] 判定结果为 ONBOARDING COMPLETE

---

### 用例 5：主管关口检查——无关卡；onboard 是只读导航

**测试夹具：**
- 任何已配置的项目状态

**输入：** `/onboard`

**预期行为：**
1. 技能完成完整的入手指南
2. 在任何阶段都不生成主管智能体
3. 输出中不出现关口 ID
4. 不出现"May I write"提示

**断言：**
- [ ] 未调用主管关口
- [ ] 未调用写入工具
- [ ] 不出现关口跳过消息
- [ ] 判定结果为 ONBOARDING COMPLETE，不附带任何关口检查

---

## 协议合规性

- [ ] 在生成输出前读取所有源文件（不臆想项目状态）
- [ ] 根据项目阶段调整输出（Production ≠ Concept）
- [ ] 在提供角色参数时予以尊重
- [ ] 不写入任何文件
- [ ] 在所有路径中均以 ONBOARDING COMPLETE 判定结束

---

## 覆盖说明

- `technical-preferences.md` 完全缺失（而非包含占位符）的情况未单独测试；行为遵循用例 3 的优雅错误模式。
- 假设可以读取 git 历史记录；此处未测试离线/无 git 场景。
- 超出"artist"之外的职能角色（例如程序员、设计师、制作人）遵循与用例 4 相同的定制模式，未单独测试。