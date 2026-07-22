
# 技能测试规格：/propagate-design-change

## 技能概述

`/propagate-design-change` 处理 GDD 修订级联。当一个 GDD 被更新时，
该技能追踪所有引用它的下游工件：ADR、TR-registry 条目、故事和史诗。
它生成一份结构化的影响报告，显示需要更改的内容及原因。该技能不会
自动应用更改——它为每个受影响的工件提出编辑建议，并在进行任何修改
之前针对每个工件询问"May I write"。

该技能在分析期间为只读模式，在更新阶段按工件进行写入关卡控制。
它没有总监关卡——分析本身是机械式的追踪，而非创造性评审。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、BLOCKED、NO IMPACT
- [ ] 包含"May I write"协作协议语言（按工件批准）
- [ ] 末尾有下一步交接
- [ ] 记录更改是提议的，而非自动应用的

---

## 总监关卡检查

无总监关卡——该技能在分析期间不生成任何总监关卡代理。
影响报告是机械式的追踪操作；分析阶段不需要创意或技术
总监评审。

---

## 测试用例

### 用例 1：正常路径 — GDD 修订影响 2 个故事和 1 个史诗

**测试夹具：**
- `design/gdd/[system].md` 存在且最近被修订过（git diff 显示更改）
- `production/epics/[layer]/EPIC-[system].md` 引用了此 GDD
- 2 个故事文件引用了此 GDD 中的 TR-ID
- 被更改的 GDD 章节影响了两个故事的验收标准

**输入：** `/propagate-design-change design/gdd/[system].md`

**预期行为：**
1. 技能读取修订后的 GDD 并识别变更内容（git diff 或内容比较）
2. 技能扫描 ADR、TR-registry、史诗和故事中对此 GDD 的引用
3. 技能生成影响报告：1 个史诗受影响，2 个故事受影响
4. 技能展示每个工件的建议更改
5. 针对每个工件：分别询问"May I update [文件路径]？"
6. 仅在逐个工件批准后应用更改

**断言：**
- [ ] 影响报告识别出全部 3 个受影响工件（1 个史诗 + 2 个故事）
- [ ] 每个受影响工件的建议更改在询问写入前展示
- [ ] "May I write"按工件询问（而非一次询问所有工件）
- [ ] 未经逐个工件批准，技能不会应用任何更改
- [ ] 所有批准的更改应用完成后，判定为 COMPLETE

---

### 用例 2：无影响 — 被更改的 GDD 没有下游引用

**测试夹具：**
- `design/gdd/[system].md` 存在且已被修订
- 没有 ADR、故事或史诗引用此 GDD 的 TR-ID 或 GDD 路径

**输入：** `/propagate-design-change design/gdd/[system].md`

**预期行为：**
1. 技能读取修订后的 GDD
2. 技能扫描所有 ADR、故事和史诗以查找引用
3. 未找到引用
4. 技能输出："未发现 [system].md 的下游影响 — 没有工件引用此 GDD。"
5. 不执行任何写入操作

**断言：**
- [ ] 技能输出"未发现下游影响"的消息
- [ ] 判定为 NO IMPACT
- [ ] 未发出"May I write"询问（无内容可更新）
- [ ] 未找到引用时，技能不会出错或崩溃

---

### 用例 3：进行中故事警告 — 被引用的故事正在开发中

**测试夹具：**
- 一个引用此 GDD 的故事的状态为 `Status: In Progress`
- 开发者已开始实现该故事

**输入：** `/propagate-design-change design/gdd/[system].md`

**预期行为：**
1. 技能识别出该 In Progress 故事为受影响工件
2. 技能输出一条升级警告："注意：[story-file] 当前状态为 In Progress — 可能有开发者正在处理。请在更新前协调。"
3. 该警告出现在影响报告中，位于针对该故事的"May I write"询问之前
4. 用户仍可批准或跳过对该故事的更新

**断言：**
- [ ] In Progress 故事被标记为升级警告（与常规受影响工件条目有所区别）
- [ ] 警告出现在针对该故事的"May I write"询问之前
- [ ] 技能仍提供更新该故事的选项——警告不阻止该选项
- [ ] 其他（非 In Progress）工件不受此警告影响

---

### 用例 4：边界情况 — 未提供参数

**测试夹具：**
- `design/gdd/` 中存在多个 GDD

**输入：** `/propagate-design-change`（无参数）

**预期行为：**
1. 技能检测到未提供参数
2. 技能输出用法错误："未指定 GDD。用法：/propagate-design-change design/gdd/[system].md"
3. 技能列出最近修改的 GDD 作为建议（git log）
4. 不执行分析

**断言：**
- [ ] 未提供参数时，技能输出用法错误
- [ ] 显示正确的路径格式用法示例
- [ ] 在未指定目标 GDD 的情况下不执行影响分析
- [ ] 技能不会未经用户输入就静默选择一个 GDD

---

### 用例 5：总监关卡 — 无论评审模式如何，均不生成关卡

**测试夹具：**
- 一个已修订的 GDD 带有下游引用
- `production/session-state/review-mode.txt` 存在，内容为 `full`

**输入：** `/propagate-design-change design/gdd/[system].md`

**预期行为：**
1. 技能读取 GDD 并追踪下游引用
2. 技能不读取 `production/session-state/review-mode.txt`
3. 在任何阶段均不生成总监关卡代理
4. 生成影响报告，按工件的批准正常进行

**断言：**
- [ ] 未生成任何总监关卡代理（无 CD-、TD-、PR-、AD- 前缀的关卡）
- [ ] 技能不读取 `production/session-state/review-mode.txt`
- [ ] 输出中不包含"Gate: [关卡ID]"或关卡跳过条目
- [ ] 评审模式对该技能的行为无影响

---

## 协议合规性

- [ ] 在生成影响报告之前，读取修订后的 GDD 和所有可能受影响的工件
- [ ] 在任何"May I write"询问之前，完整展示影响报告
- [ ] "May I write"按工件询问——从不一次性询问整个集合
- [ ] In Progress 故事在批准询问前被标记为升级警告
- [ ] 无总监关卡——不读取 review-mode.txt
- [ ] 以与判定结果相适应的下一步交接结尾（COMPLETE 或 NO IMPACT）

---

## 覆盖说明

- ADR 影响（当 GDD 变更需要更新 ADR 或创建新 ADR 时）遵循与故事/史诗更新相同的按工件批准模式——未单独进行夹具测试。
- TR-registry 影响（当变更的 GDD 需要新的或更新的 TR-ID 时）属于分析阶段的一部分，但未单独进行夹具测试。
- git diff 比较方法（检测 GDD 中变更的内容）是运行时关注点——夹具使用预先安排的内容差异。
