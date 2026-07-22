
# 技能测试规格：/art-bible

## 技能概述

`/art-bible` 是一个引导式、逐节编写的艺术圣经 (Art Bible) 创作技能。它生成一份全面的视觉方向文档，涵盖：视觉风格概述 (Visual Style)、调色板 (Color Palette)、字体排印 (Typography)、角色设计规则 (Character Design Rules)、环境风格 (Environment Style) 和 UI 视觉语言 (UI Visual Language)。该技能遵循"骨架优先"模式：立即创建包含所有章节标题的文件，然后通过讨论填充每个章节，并在用户批准后逐一写入磁盘。

在 `full` 审查模式下，AD-ART-BIBLE 总监关卡（艺术总监 (Art Director)）在草稿完成之后、任何章节写入之前运行。在 `lean` 和 `solo` 模式下，AD-ART-BIBLE 被跳过，仅需用户批准。当所有章节写入完成时，判定结果为 COMPLETE。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 包含必需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE
- [ ] 包含逐节的"我可以写入吗"（May I write）措辞
- [ ] 记录 AD-ART-BIBLE 总监关卡及其模式行为
- [ ] 包含下一步交接说明（例如 `/asset-spec` 或 `/design-system`）

---

## 总监关卡检查

| 关卡 ID      | 触发条件              | 模式守卫            |
|--------------|--------------------------------|-----------------------|
| AD-ART-BIBLE | 草稿完成后        | 仅 full 模式（非 lean/solo） |

---

## 测试用例

### 用例 1：正常路径 —— Full 模式，艺术圣经草稿完成，AD-ART-BIBLE 批准

**测试夹具：**
- 不存在现有的 `design/art-bible.md`
- `production/session-state/review-mode.txt` 包含 `full`
- `design/gdd/game-concept.md` 存在并描述了视觉基调

**输入：** `/art-bible`

**预期行为：**
1. 技能创建骨架文件 `design/art-bible.md`，包含所有章节标题
2. 技能与用户协作讨论并起草每个章节
3. 所有章节起草完成后，调用 AD-ART-BIBLE 关卡（艺术总监审查）
4. AD-ART-BIBLE 返回 APPROVED
5. 技能逐节询问"我可以将章节 [N] 写入 `design/art-bible.md` 吗？"
6. 批准后写入所有章节；判定结果为 COMPLETE

**断言：**
- [ ] 首先创建骨架文件（在写入任何章节内容之前）
- [ ] 在 full 模式下，草稿完成后调用 AD-ART-BIBLE 关卡
- [ ] 关卡批准先于"我可以写入吗？"的逐节询问
- [ ] 最终文件中包含所有章节
- [ ] 判定结果为 COMPLETE

---

### 用例 2：AD-ART-BIBLE 返回 CONCERNS —— 写入前修订章节

**测试夹具：**
- 艺术圣经草稿已完成
- `production/session-state/review-mode.txt` 包含 `full`
- AD-ART-BIBLE 关卡返回 CONCERNS："调色板与游戏概念中描述的黑暗氛围基调冲突"

**输入：** `/art-bible`

**预期行为：**
1. AD-ART-BIBLE 关卡返回 CONCERNS，附带关于调色板的具体反馈
2. 技能向用户展示反馈："艺术总监对调色板有疑虑"
3. 技能返回调色板章节进行修订
4. 用户和技能修订调色板以与游戏概念的基调保持一致
5. AD-ART-BIBLE 不会被重新调用（用户决定在修订后继续）
6. 在获得"我可以写入吗？"的批准后写入修订后的章节；判定结果为 COMPLETE

**断言：**
- [ ] 在任何章节写入之前，向用户展示 CONCERNS
- [ ] 技能返回受影响的章节进行修订（而非所有章节）
- [ ] 修订后的内容（而非原始内容）被写入文件
- [ ] 修订和批准后判定结果为 COMPLETE

---

### 用例 3：Lean 模式 —— AD-ART-BIBLE 跳过，仅凭用户批准写入

**测试夹具：**
- 不存在现有的艺术圣经
- `production/session-state/review-mode.txt` 包含 `lean`

**输入：** `/art-bible`

**预期行为：**
1. 技能读取审查模式 —— 确定为 `lean`
2. 技能与用户协作起草所有章节
3. AD-ART-BIBLE 关卡被跳过：输出注明"[AD-ART-BIBLE] skipped — lean mode"
4. 技能请求用户直接批准每个章节
5. 用户确认后写入章节；判定结果为 COMPLETE

**断言：**
- [ ] 在 lean 模式下不调用 AD-ART-BIBLE 关卡
- [ ] 明确注明跳过："[AD-ART-BIBLE] skipped — lean mode"
- [ ] 每个章节仍需用户批准（关卡跳过 ≠ 批准跳过）
- [ ] 判定结果为 COMPLETE

---

### 用例 4：现有艺术圣经 —— 改造模式 (Retrofit Mode)

**测试夹具：**
- `design/art-bible.md` 已存在，所有章节均已填充
- 用户想要更新角色设计规则 (Character Design Rules) 章节

**输入：** `/art-bible`

**预期行为：**
1. 技能读取现有的艺术圣经，检测到所有章节均已填充
2. 技能提供改造模式："艺术圣经已存在 —— 您想更新哪个章节？"
3. 用户选择角色设计规则 (Character Design Rules)
4. 技能起草更新后的内容；在 full 模式下，在写入前对修订后的章节调用 AD-ART-BIBLE
5. 技能询问"我可以将角色设计规则写入 `design/art-bible.md` 吗？"
6. 仅更新该章节；其他章节保持不变；判定结果为 COMPLETE

**断言：**
- [ ] 检测到现有的艺术圣经并提供改造模式
- [ ] 仅更新选定的章节
- [ ] 在 full 模式下：即使是单章节改造，AD-ART-BIBLE 关卡也会运行
- [ ] 其他章节保持不变
- [ ] 判定结果为 COMPLETE

---

### 用例 5：Solo 模式 —— AD-ART-BIBLE 跳过，在输出中注明

**测试夹具：**
- 不存在现有的艺术圣经
- `production/session-state/review-mode.txt` 包含 `solo`

**输入：** `/art-bible`

**预期行为：**
1. 技能读取审查模式 —— 确定为 `solo`
2. 艺术圣经起草并写入，仅需用户批准
3. AD-ART-BIBLE 关卡被跳过：输出注明"[AD-ART-BIBLE] skipped — solo mode"
4. 不启动任何总监代理
5. 判定结果为 COMPLETE

**断言：**
- [ ] 在 solo 模式下不调用 AD-ART-BIBLE 关卡
- [ ] 明确注明跳过，带有"solo mode"标签
- [ ] 不启动任何类型的总监代理
- [ ] 判定结果为 COMPLETE

---

## 协议合规性

- [ ] 立即创建包含所有章节标题的骨架文件
- [ ] 一次讨论并起草一个章节
- [ ] AD-ART-BIBLE 关卡在 full 模式下，所有章节起草完成后运行
- [ ] AD-ART-BIBLE 在 lean 和 solo 模式下被跳过 —— 按名称注明
- [ ] 逐节询问"我可以写入章节 [N] 吗？"
- [ ] 当所有章节写入完成时，判定结果为 COMPLETE

---

## 覆盖说明

- AD-ART-BIBLE 返回 REJECT（而非仅 CONCERNS）的情况未单独测试；技能将阻止写入并询问用户如何继续（修订或覆盖）。
- 字体排印 (Typography) 章节被列为必需的艺术圣经章节，但其具体内容要求在此未做断言测试。
- 艺术圣经为 `/asset-spec` 提供输入 —— 此关系在交接中已注明，但不作为本技能规格的一部分进行测试。
