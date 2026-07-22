
# 技能测试规格：/design-system

## 技能概述

`/design-system` 引导用户逐节编写单个游戏系统的游戏设计文档 (Game Design Document, GDD)。所有 8 个必需章节均需编写：概述 (Overview)、玩家幻想 (Player Fantasy)、详细规则 (Detailed Rules)、公式 (Formulas)、边界情况 (Edge Cases)、依赖关系 (Dependencies)、调优参数 (Tuning Knobs) 和验收标准 (Acceptance Criteria)。该技能采用"骨架优先"方法 —— 在填充任何内容之前，先创建包含全部 8 个章节标题的 GDD 文件 —— 并在批准后逐一写入每个章节。

CD-GDD-ALIGN 关卡（创意总监 (Creative Director)）在 `full` 和 `lean` 模式下均运行。仅在 `solo` 模式下被跳过。如果发现现有 GDD 文件，技能提供改造模式 (Retrofit Mode) 以更新特定章节，而不是重写整个文档。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 包含必需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：APPROVED、NEEDS REVISION、MAJOR REVISION
- [ ] 包含"我可以写入吗"（May I write）协作协议措辞（逐节批准）
- [ ] 末尾包含下一步交接说明
- [ ] 记录骨架优先方法（在填充内容前先创建包含标题的文件）
- [ ] 记录 CD-GDD-ALIGN 关卡：在 full 和 lean 模式下均活动；仅在 solo 模式下跳过
- [ ] 记录针对现有 GDD 文件的改造模式

---

## 总监关卡检查

在 `full` 模式下：CD-GDD-ALIGN（创意总监 (Creative Director)）关卡在每个章节起草后、写入前运行。如果返回 MAJOR REVISION，该章节必须在继续之前重写。

在 `lean` 模式下：CD-GDD-ALIGN 仍然运行（此关卡在 lean 模式下不会跳过 —— 它在 full 和 lean 模式下均运行）。只有 solo 模式会跳过它。

在 `solo` 模式下：CD-GDD-ALIGN 被跳过。输出注明："CD-GDD-ALIGN skipped — solo mode"。章节仅凭用户批准写入。

---

## 测试用例

### 用例 1：正常路径 —— 新 GDD，骨架优先，lean 模式下的 CD-GDD-ALIGN

**测试夹具：**
- `design/gdd/` 中不存在目标系统的现有 GDD
- `production/session-state/review-mode.txt` 包含 `lean`

**输入：** `/design-system [system-name]`

**预期行为：**
1. 技能创建骨架文件 `design/gdd/[system-name].md`，包含全部 8 个章节标题（空主体）
2. 针对每个章节：与用户讨论、起草内容、展示草稿
3. CD-GDD-ALIGN 关卡对每个章节草稿运行（lean 模式 —— 关卡处于活动状态）
4. 关卡对每个章节返回 APPROVED
5. 关卡批准后询问"我可以写入 [章节] 吗？"
6. 用户批准后将章节写入文件
7. 对所有 8 个章节重复此过程

**断言：**
- [ ] 在任何内容写入之前，先创建包含全部 8 个章节标题的骨架文件
- [ ] CD-GDD-ALIGN 在 lean 模式下对每个章节运行（未跳过）
- [ ] 逐节询问"我可以写入吗？"（而非一次性询问所有章节）
- [ ] 每个章节在关卡和用户批准后单独写入
- [ ] 最终 GDD 文件中包含全部 8 个章节

---

### 用例 2：改造模式 —— 现有 GDD，更新特定章节

**测试夹具：**
- `design/gdd/[system-name].md` 已存在，全部 8 个章节均已填充

**输入：** `/design-system [system-name]`

**预期行为：**
1. 技能检测到现有 GDD 文件并读取其当前内容
2. 技能提供改造模式："GDD 已存在。您想更新哪个章节？"
3. 用户选择一个特定章节（例如，公式 Formulas）
4. 技能仅编写该章节，运行 CD-GDD-ALIGN，询问"我可以写入吗？"
5. 仅更新选定的章节 —— 其他章节不被修改

**断言：**
- [ ] 在提供改造模式之前，技能检测并读取现有 GDD
- [ ] 询问用户要更新哪个章节 —— 而非要求重写整个文档
- [ ] 仅重写选定的章节 —— 其他保持不变
- [ ] CD-GDD-ALIGN 仍然在更新的章节上运行
- [ ] 在更新章节前询问"我可以写入吗？"

---

### 用例 3：总监关卡 —— CD-GDD-ALIGN 返回 MAJOR REVISION

**测试夹具：**
- 正在编写新 GDD
- `production/session-state/review-mode.txt` 包含 `lean`
- CD-GDD-ALIGN 关卡对玩家幻想 (Player Fantasy) 章节返回 MAJOR REVISION

**输入：** `/design-system [system-name]`

**预期行为：**
1. 玩家幻想章节已起草
2. CD-GDD-ALIGN 关卡运行并返回 MAJOR REVISION，附带具体反馈
3. 技能向用户展示反馈
4. 在 MAJOR REVISION 未解决时，章节不会被写入文件
5. 用户与技能协作重写该章节
6. CD-GDD-ALIGN 对修订后的章节再次运行
7. 如果修订后的章节通过，询问"我可以写入吗？"后写入该章节

**断言：**
- [ ] 当 CD-GDD-ALIGN 返回 MAJOR REVISION 时，章节不会被写入
- [ ] 在请求修订之前，关卡反馈展示给用户
- [ ] 章节修订后 CD-GDD-ALIGN 再次运行
- [ ] 在 MAJOR REVISION 未解决时，技能不会自动进入下一个章节

---

### 用例 4：Solo 模式 —— CD-GDD-ALIGN 跳过；章节仅凭用户批准写入

**测试夹具：**
- 正在编写新 GDD
- `production/session-state/review-mode.txt` 包含 `solo`

**输入：** `/design-system [system-name]`

**预期行为：**
1. 创建包含 8 个章节标题的骨架文件
2. 针对每个章节：起草、展示给用户
3. CD-GDD-ALIGN 被跳过 —— 逐节注明："CD-GDD-ALIGN skipped — solo mode"
4. 用户审查草稿后询问"我可以写入 [章节] 吗？"
5. 用户批准后写入章节
6. 在任何阶段均无关卡审查

**断言：**
- [ ] 每个章节均注明"CD-GDD-ALIGN skipped — solo mode"
- [ ] 仅凭用户批准即可写入章节（无需关卡）
- [ ] 在 solo 模式下技能不会启动任何 CD-GDD-ALIGN 关卡
- [ ] 在 solo 模式下，仅凭用户批准即可写入完整 GDD

---

### 用例 5：总监关卡 —— 空章节不写入文件

**测试夹具：**
- GDD 编写进行中
- 用户和技能讨论了一个章节但未产生任何批准的内容（例如，讨论无果而终，或用户说"先跳过"）

**输入：** `/design-system [system-name]`

**预期行为：**
1. 章节讨论未产生批准的内容
2. 技能不会向章节写入空主体或占位内容
3. 章节标题保留在骨架文件中，但主体保持为空
4. 技能进入下一个章节，不写入空章节
5. 最后，列出未完成的章节并提醒用户返回处理

**断言：**
- [ ] 空的或未经批准的章节不被写入文件
- [ ] 骨架章节标题保留（保持结构）
- [ ] 技能在会话结束时跟踪并列出未完成的章节
- [ ] 未经用户批准，技能不会写入"待定"（TBD）或占位内容

---

## 协议合规性

- [ ] 在任何内容写入之前，先创建包含全部 8 个标题的骨架文件
- [ ] CD-GDD-ALIGN 在 full 和 lean 模式下均运行（不仅限 full）
- [ ] CD-GDD-ALIGN 仅在 solo 模式下被跳过 —— 逐节注明
- [ ] 逐节询问"我可以写入 [章节] 吗？"（而非一次性针对整个文档）
- [ ] CD-GDD-ALIGN 的 MAJOR REVISION 将阻塞章节写入直至解决
- [ ] 只有经过批准的、非空的章节才被写入文件
- [ ] 以下一步交接结束：`/review-all-gdds` 或 `/map-systems next`

---

## 覆盖说明

- 8 个必需章节根据 `CLAUDE.md` 中定义的项目设计文档标准进行验证 —— 此处不再重新列举。
- 技能内部的章节排序逻辑（先编写哪个章节）未独立测试 —— 顺序遵循标准 GDD 模板。
- CD-GDD-ALIGN 中的设计支柱对齐性检查由关卡代理进行整体评估 —— 具体的支柱检查在此未通过测试夹具进行测试。
