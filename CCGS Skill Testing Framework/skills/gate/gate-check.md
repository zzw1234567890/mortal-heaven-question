
# 技能测试规范：/gate-check

## 技能概述

`/gate-check` 用于验证项目是否已准备好进入下一个开发阶段。它会检查所需的工件、运行质量检查、向用户询问无法自动验证的项目，并输出 PASS/CONCERNS/FAIL 判定结果。当用户确认 PASS 后，它将新的阶段名称写入 `production/stage.txt`。该技能管控所有 6 个阶段转换，是管线中最关键的关卡技能。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题（编号的 Phase N 或 ## 章节）
- [ ] 包含判定关键词：PASS、CONCERNS、FAIL
- [ ] 包含 "May I write" 协作协议措辞
- [ ] 末尾具有下一步交接（"后续操作" 章节）

---

## 测试用例

### 用例 1：正常路径 — 所有概念阶段工件已就绪，进入系统设计阶段

**测试夹具：**
- `design/gdd/game-concept.md` 存在，包含内容且涵盖所有必需章节
- `design/gdd/game-pillars.md` 存在（或在概念文档中定义了设计支柱）
- 尚无系统索引（该阶段此为正常）

**输入：** `/gate-check systems-design`

**预期行为：**
1. 技能读取 `design/gdd/game-concept.md` 并验证其包含内容
2. 技能检查游戏支柱（在概念文档或单独文件中）
3. 技能检查质量项目（核心循环已描述、目标受众已确定）
4. 技能输出结构化检查清单，所有项目均已标记
5. 技能呈现 PASS/CONCERNS/FAIL 判定结果
6. 若为 PASS：技能询问"我可以将 `production/stage.txt` 更新为 'Systems Design' 吗？"

**断言：**
- [ ] 技能在标记检查通过之前使用 Glob 或 Read 验证 `design/gdd/game-concept.md` 是否存在
- [ ] 输出包含 "Required Artifacts" 章节，每个项目带有检查状态
- [ ] 输出包含 "Quality Checks" 章节，每个项目带有检查状态
- [ ] 输出包含 "Verdict" 行，值为 PASS / CONCERNS / FAIL 之一
- [ ] 技能询问无法自动验证的质量项目（例如"是否已评审？"）而非假定为 PASS
- [ ] 技能在更新 `production/stage.txt` 之前询问"May I write"
- [ ] 未经用户明确确认，技能不会写入 `production/stage.txt`

---

### 用例 2：失败路径 — 从概念阶段到系统设计阶段缺少必需工件

**测试夹具：**
- `design/gdd/game-concept.md` 不存在
- 无游戏支柱文档
- `design/gdd/` 目录为空或不存在

**输入：** `/gate-check systems-design`

**预期行为：**
1. 技能尝试读取 `design/gdd/game-concept.md` — 文件未找到
2. 技能将必需工件标记为缺失
3. 技能输出 FAIL 判定
4. 技能列出阻塞项："未找到游戏概念文档"
5. 技能建议补救措施：运行 `/brainstorm` 创建一个

**断言：**
- [ ] 当必需工件缺失时判定为 FAIL（而非 PASS 或 CONCERNS）
- [ ] 输出明确指出 `design/gdd/game-concept.md` 缺失
- [ ] 输出包含 "Blockers" 章节，至少包含 1 个项目
- [ ] 输出推荐 `/brainstorm` 作为补救措施
- [ ] 判定为 FAIL 时技能不会写入 `production/stage.txt`

---

### 用例 3：无参数 — 自动检测当前阶段

**测试夹具：**
- `production/stage.txt` 包含 `Concept`
- `design/gdd/game-concept.md` 存在且有内容
- 尚无系统索引

**输入：** `/gate-check`（无参数）

**预期行为：**
1. 技能读取 `production/stage.txt` 以确定当前阶段
2. 技能确定下一个关卡为 Concept → Systems Design
3. 技能继续执行系统设计阶段检查
4. 输出明确说明正在验证哪个转换

**断言：**
- [ ] 技能读取 `production/stage.txt`（或使用 project-stage-detect 启发式方法）以确定当前阶段
- [ ] 输出标题同时列出当前阶段和目标阶段（例如"Gate Check: Concept → Systems Design"）
- [ ] 如果当前阶段可确定，技能不会询问用户要检查哪个关卡

---

### 用例 4：边界情况 — 手动检查项目标记正确

**测试夹具：**
- 从概念阶段到系统设计阶段的所有必需工件均已就绪
- 无试玩或评审记录（无法自动验证质量检查）

**输入：** `/gate-check systems-design`

**预期行为：**
1. 技能验证所有工件文件存在
2. 技能遇到质量检查："游戏概念已评审（非 MAJOR REVISION NEEDED）"
3. 由于无评审记录，技能将该项目标记为 MANUAL CHECK NEEDED
4. 技能询问用户："游戏概念的设计质量是否已经过评审？"
5. 技能在最终确定判定前等待用户输入

**断言：**
- [ ] 无法自动验证的项目标记为 `[?] MANUAL CHECK NEEDED` 而非假定为 PASS
- [ ] 技能至少对一项无法自动验证的质量项目向用户提问
- [ ] 技能不会默认将无法验证的项目标记为 PASS

---

### 用例 5：总监关卡 — 完整模式 vs 精简模式 vs 单人模式

**测试夹具：**
- `production/session-state/review-mode.txt` 存在（或等效的状态文件）
- 目标关卡所有必需工件均已就绪
- `design/gdd/game-concept.md` 存在

**用例 5a — full 模式：**
- `review-mode.txt` 包含 `full`

**输入：** `/gate-check systems-design`（full 模式激活）

**预期行为：**
1. 技能读取评审模式 — 判定为 `full`
2. 技能并行派生全部 4 个 PHASE-GATE 总监提示：
   - CD-PHASE-GATE（创意总监，creative-director）
   - TD-PHASE-GATE（技术总监，technical-director）
   - PR-PHASE-GATE（制作人，producer）
   - AD-PHASE-GATE（艺术总监，art-director）
3. 如果任一总监返回 CONCERNS → 整体关卡判定至少为 CONCERNS
4. 在产生最终输出前收集全部 4 个判定结果

**断言（5a）：**
- [ ] 技能在决定派生哪些总监之前读取 review-mode
- [ ] 全部 4 个 PHASE-GATE 总监提示均已派生（而非仅 1 或 2 个）
- [ ] 总监并行派生（同时，非顺序）
- [ ] 任一总监的 CONCERNS 判定会传播至整体判定
- [ ] 如果任一总监返回 CONCERNS 或 REJECT，判定不会自动为 PASS

**用例 5b — solo 模式：**
- `review-mode.txt` 包含 `solo`

**输入：** `/gate-check systems-design`（solo 模式激活）

**预期行为：**
1. 技能读取评审模式 — 判定为 `solo`
2. 每个总监被注明为已跳过："[CD-PHASE-GATE] skipped — Solo mode"
3. 关卡判定仅来自工件/质量检查
4. 不派生任何总监关卡

**断言（5b）：**
- [ ] solo 模式下不派生任何总监关卡
- [ ] 每个跳过的关卡在输出中明确注明："[GATE-ID] skipped — Solo mode"
- [ ] 判定仅基于工件和质量检查

**关于用例 3 的修正说明：**
用例 3 的断言先前指出"如果当前阶段可确定，技能不会询问用户要检查哪个关卡。"这是正确的。然而，技能确实会使用 AskUserQuestion 来确认自动检测到的转换，然后再运行完整检查 — 这是确认步骤，而非关卡选择。用例 3 的断言不应将此确认视为失败。

---

## 协议合规性

- [ ] 在更新 `production/stage.txt` 之前使用 "May I write"
- [ ] 在请求写入批准之前呈现完整的检查清单报告
- [ ] 以 "Follow-Up Actions" 章节结尾，列出每个判定结果的后续步骤
- [ ] 未经用户明确确认，决不推进阶段
- [ ] 如果 `production/stage.txt` 不存在，未经询问决不自动创建

---

## 覆盖说明

- Production → Polish 和 Polish → Release 关卡未在此覆盖，因为它们需要复杂的多工件设置（冲刺计划、试玩数据、QA 签收）；这些推迟至专门的后续规格。
- "CONCERNS" 判定路径（有轻微缺口但不阻塞）未在此显式测试；它介于用例 1 和用例 2 之间，遵循相同模式。
- 垂直切片（Vertical Slice）验证块（Pre-Production → Production 关卡）未覆盖，因为它需要可玩的构建环境，无法以文档夹具形式表达。
