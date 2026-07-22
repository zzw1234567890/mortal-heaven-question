
# 技能测试规格：/release-checklist

## 技能概述 (Skill Summary)

`/release-checklist` 生成内部发布就绪检查清单，涵盖：冲刺故事完成情况、开放 Bug 严重性、QA 签收状态、构建稳定性和变更日志就绪性。它是一个内部关口——而非平台/商店检查清单（那是 `/launch-checklist`）。当存在先前发布的检查清单时，它会显示已解决和新引入问题的差异对比（delta）。

技能在征询"May I write"后将检查清单报告写入 `production/releases/release-checklist-[date].md`。不适用主管关口——`/gate-check` 处理正式的阶段关口逻辑。判定结果：RELEASE READY、RELEASE BLOCKED 或 CONCERNS。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：RELEASE READY、RELEASE BLOCKED、CONCERNS
- [ ] 在写入报告前包含"May I write"协作协议用语
- [ ] 包含下一步交接（例如 `/launch-checklist` 用于外部发布，或 `/gate-check` 用于阶段推进）

---

## 主管关口检查

无。`/release-checklist` 是一个内部审计工具。正式的阶段推进由 `/gate-check` 管理。

---

## 测试用例

### 用例 1：正常路径——所有冲刺故事完成，QA 通过，RELEASE READY

**测试夹具：**
- `production/sprints/sprint-008.md`——所有故事均为 `Status: Done`
- `production/bugs/` 中没有严重级别为 HIGH 或 CRITICAL 的开放 Bug
- `production/qa/qa-plan-sprint-008.md` 包含 QA 签收注释
- 此版本的变更日志条目存在
- `production/stage.txt` 包含 `Polish`

**输入：** `/release-checklist`

**预期行为：**
1. 技能读取 sprint-008：所有故事已完成
2. 技能读取 Bug：无 HIGH 或 CRITICAL 级别的开放 Bug
3. 技能确认 QA 计划已签收
4. 技能确认变更日志条目存在
5. 所有检查通过；技能询问"我可以写入 `production/releases/release-checklist-2026-04-06.md` 吗？"
6. 写入报告；判定结果为 RELEASE READY

**断言：**
- [ ] 评估了所有 4 个检查类别（故事、Bug、QA、变更日志）
- [ ] 所有项目带有 PASS 标记
- [ ] 判定结果为 RELEASE READY
- [ ] 写入前询问"May I write"

---

### 用例 2：存在 HIGH 严重性开放 Bug——RELEASE BLOCKED

**测试夹具：**
- 所有冲刺故事已完成
- `production/bugs/` 包含 2 个严重级别为 HIGH 的开放 Bug

**输入：** `/release-checklist`

**预期行为：**
1. 技能读取冲刺——故事完成
2. 技能读取 Bug——2 个 HIGH 严重性 Bug 开放
3. 技能报告："发布被阻塞 (RELEASE BLOCKED)——必须解决 2 个开放的 HIGH 严重性 Bug"
4. 报告中列出两个 Bug 文件名
5. 判定结果为 RELEASE BLOCKED

**断言：**
- [ ] 判定结果为 RELEASE BLOCKED（而非 CONCERNS）
- [ ] 明确列出两个 Bug 文件名
- [ ] 技能明确说明 HIGH 严重性 Bug 是阻塞性的（而非咨询性）

---

### 用例 3：变更日志未生成——CONCERNS

**测试夹具：**
- 所有故事完成，无 HIGH/CRITICAL Bug
- 未找到当前版本/冲刺的变更日志条目

**输入：** `/release-checklist`

**预期行为：**
1. 技能检查所有项目
2. 变更日志检查失败：未找到变更日志条目
3. 技能报告："存在问题 (CONCERNS)——此版本的变更日志尚未生成"
4. 技能建议运行 `/changelog` 以生成
5. 判定结果为 CONCERNS（咨询性——非硬性阻塞）

**断言：**
- [ ] 判定结果为 CONCERNS（而非 RELEASE BLOCKED——变更日志为咨询性）
- [ ] 建议将 `/changelog` 作为补救措施
- [ ] 报告中显示其他通过的检查项目
- [ ] 缺失的变更日志被描述为咨询性，而非阻塞性

---

### 用例 4：存在先前发布的检查清单——与上次发布的差异对比

**测试夹具：**
- `production/releases/release-checklist-2026-03-20.md` 存在
- 上次：1 个故事未完成，1 个 HIGH Bug 开放
- 本次：所有故事已完成，HIGH Bug 已解决，但现在出现了 1 个 MEDIUM Bug

**输入：** `/release-checklist`

**预期行为：**
1. 技能找到先前的检查清单并加载
2. 生成新的检查清单并进行对比：
   - 新解决："故事 [X]——曾为开放，现为已完成 (Done)"
   - 新解决："HIGH Bug [filename]——曾为开放，现为已关闭"
   - 新增项目："出现 1 个 MEDIUM Bug（咨询性）"
3. 差异对比章节突出显示所有变更
4. 判定结果为 CONCERNS（MEDIUM Bug 为咨询性，非阻塞性）

**断言：**
- [ ] 报告中出现差异对比章节，包含已解决和新增项目
- [ ] 注明了先前检查清单中已解决的项目
- [ ] 突出显示先前检查清单中未出现的新项目
- [ ] 判定反映当前状态（而非先前状态）

---

### 用例 5：主管关口检查——无关卡；release-checklist 是内部审计

**测试夹具：**
- 包含故事和 Bug 报告的活跃冲刺

**输入：** `/release-checklist`

**预期行为：**
1. 技能运行完整检查清单并写入报告
2. 不生成任何主管智能体
3. 输出中不出现关口 ID

**断言：**
- [ ] 未调用主管关口
- [ ] 不出现关口跳过消息
- [ ] 判定结果为 RELEASE READY、RELEASE BLOCKED 或 CONCERNS——无关口判定

---

## 协议合规性

- [ ] 检查冲刺故事完成状态
- [ ] 检查开放 Bug 严重性（CRITICAL/HIGH = BLOCKED；MEDIUM/LOW = CONCERNS）
- [ ] 检查 QA 计划签收状态
- [ ] 检查变更日志存在性
- [ ] 当存在先前检查清单时进行对比
- [ ] 在写入报告前询问"May I write"
- [ ] 判定结果为 RELEASE READY、RELEASE BLOCKED 或 CONCERNS

---

## 覆盖说明

- 构建稳定性验证（无失败的 CI 运行）被列为一个检查类别，但依赖于外部 CI 系统状态；如果 CI 集成未配置，技能将其标记为手动检查（MANUAL CHECK）。
- CRITICAL Bug 始终导致 RELEASE BLOCKED，无论其他项目如何；这与用例 2 中的 HIGH 严重性情况相同。
- 状态为 `Status: In Review`（而非 Done）的故事被视为未完成，并导致 RELEASE BLOCKED；此边缘情况遵循与 HIGH Bug 情况相同的模式。