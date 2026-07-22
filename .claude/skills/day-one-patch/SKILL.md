---
name: day-one-patch
description: "为游戏发布准备首日补丁。界定范围、确定优先级、实现并通过 QA 门禁验证一个聚焦的补丁，解决在黄金主版本锁定之后但在公开发布之前或之后立即发现的已知问题。将补丁视为一个微冲刺，拥有自己的 QA 门禁和回滚计划。"
argument-hint: "[scope: known-bugs | cert-feedback | all]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion

---


# 首日补丁（Day-One Patch）

每个发布的游戏都有一个首日补丁。在发布日之前规划它可防止混乱。本 skill 将补丁范围限定在安全且必要的范围内，通过轻量级 QA 检查进行门禁，并确保在发布任何内容之前存在回滚计划。这是一个微冲刺——不是热修复，也不是完整冲刺。

**运行时机：**
- 在黄金主版本（gold master）构建锁定后（认证通过或发布候选标记）
- 当存在在黄金主版本中修复风险过大的已知 bug 时
- 当认证反馈需要提交后进行微小修复时
- 当发布前试玩在发布门禁通过后暴露出必须修复的问题时

**首日补丁范围规则：**
- 仅限可以安全快速修复的 P1/P2 bug
- 无新功能——这仅限修复
- 无重构——最小可行变更
- 任何需要超过 4 小时开发时间的修复属于补丁 1.1，而非首日补丁

**输出：** `production/releases/day-one-patch-[version].md`

---

## 第一阶段：加载发布上下文

读取：
- `production/stage.txt` — 确认项目处于 Release 阶段
- `production/gate-checks/` 中最近的文件 — 读取发布门禁结论
- `production/qa/bugs/*.md` — 加载所有状态为 Open 或 Fixed — Pending Verification 的 bug
- `production/sprints/` 最近一个 — 了解发布了什么
- `production/security/security-audit-*.md` 最近一个 — 检查是否有任何未解决的安全问题

如果 `production/stage.txt` 不是 `Release` 或 `Polish`：
> "Day-one patch prep is for Release-stage projects. Current stage: [stage]. This skill is not appropriate until you are approaching launch."

---

## 第二阶段：界定补丁范围

### 步骤 2a — 对开放 bug 进行分类以决定是否纳入补丁

对于每个开放的 bug，评估：

| 标准 | 纳入首日补丁？ |
|-----------|-------------------|
| 严重性 S1 或 S2 | 是——如果安全修复则必须包含 |
| 优先级 P1 | 是 |
| 修复估计 < 4 小时 | 是 |
| 修复需要架构变更 | 否——推迟到 1.1 |
| 修复引入新代码路径 | 否——风险过大 |
| 修复仅涉及数据/配置（无代码变更） | 是——风险极低 |
| 认证反馈要求 | 是——平台批准必需 |
| 严重性 S3/S4 | 仅限琐碎的配置修复；否则推迟 |

### 步骤 2b — 向用户展示补丁范围

使用 `AskUserQuestion`：
- 提示："Based on open bugs and cert feedback, here is the proposed day-one patch scope. Does this look right?"
- 展示：已纳入 bug 表（ID、严重性、描述、预估工作量）
- 展示：已推迟 bug 表（ID、严重性、推迟原因）
- 选项：`[A] Approve this scope` / `[B] Adjust — I want to add or remove items` / `[C] No day-one patch needed`

如果 [C]：输出 "No day-one patch required. Proceed to `/launch-checklist`." 停止。

### 步骤 2c — 检查总范围

汇总预估工作量。如果总计超过 1 天的工作量：
> "⚠️ Patch scope is [N hours] — this exceeds a safe day-one window. Consider deferring lower-priority items to patch 1.1. A bloated day-one patch introduces more risk than it removes."

使用 `AskUserQuestion` 确认继续或缩减范围。

---

## 第三阶段：回滚计划

在编写任何代码之前，定义回滚程序。这是不可协商的。

通过 Task 生成 `release-manager`。要求其生成回滚计划，包含：
- 在每个目标平台上如何恢复到黄金主版本构建
- 平台特定的回滚约束（某些平台无法回滚认证构建）
- 谁负责触发回滚
- 如果发生回滚，需要向玩家传达什么信息

展示回滚计划。询问："May I write this rollback plan to `production/releases/rollback-plan-[version].md`?"

在回滚计划写入之前，不要进入第四阶段。

---

## 第四阶段：实施修复

对于批准范围内的每个 bug，生成一个专注的实现循环：

1. 通过 Task 生成 `lead-programmer`，附上：
   - Bug 报告（确切的复现步骤和已知的根本原因）
   - 约束条件：仅最小可行修复，不做清理
   - 受影响的文件（来自 bug 报告的技术上下文部分）

2. 主程序员（lead-programmer）实现并运行定向测试。

3. 通过 Task 生成 `qa-tester` 以验证：修复后 bug 是否还能复现？

对于仅涉及配置/数据的修复：直接进行更改（无需程序员代理）。确认值已更改并重新运行任何相关的冒烟测试。

---

## 第五阶段：补丁 QA 门禁

这是轻量级 QA 检查——不是完整的 `/team-qa`。补丁已通过发布门禁的 QA 批准；我们仅重新验证更改过的区域。

通过 Task 生成 `qa-lead`，附上：
- 所有已更改文件的列表
- 已修复 bug 的列表（附第四阶段的验证状态）
- 受影响系统的冒烟检查范围

要求 qa-lead 确定：**定向冒烟检查是否足够，还是任何修复触及需要更广泛回归测试的系统？**

运行所需的 QA 范围：
- **定向冒烟检查** — 运行 `/smoke-check [affected-systems]`
- **更广泛的回归测试** — 为受影响系统运行 `tests/unit/` 和 `tests/integration/` 中的定向测试

QA 结论必须为 PASS 或 PASS WITH WARNINGS 才能继续。如果为 FAIL：将该失败修复从首日补丁中排除并推迟到 1.1。

---

## 第六阶段：生成补丁记录

```markdown
# Day-One Patch: [Game Name] v[version]

**Date prepared**: [date]
**Target release**: [launch date or "day of launch"]
**Base build**: [gold master tag or commit]
**Patch build**: [patch tag or commit]

---

## Patch Notes (Internal)

### Bugs Fixed
| BUG-ID | Severity | Description | Fix summary |
|--------|----------|-------------|-------------|
| BUG-NNN | S[1-4] | [description] | [one-line fix] |

### Deferred to 1.1
| BUG-ID | Severity | Description | Reason deferred |
|--------|----------|-------------|-----------------|
| BUG-NNN | S[1-4] | [description] | [reason] |

---

## QA Sign-Off

**QA scope**: [Targeted smoke / Broader regression]
**Verdict**: [PASS / PASS WITH WARNINGS]
**QA lead**: qa-lead agent
**Date**: [date]
**Warnings (if any)**: [list or "None"]

---

## Rollback Plan

See: `production/releases/rollback-plan-[version].md`

**Trigger condition**: If [N] or more S1 bugs are reported within [X] hours of launch, execute rollback.
**Rollback owner**: [user / producer]

---

## Approvals Required Before Deploy

- [ ] lead-programmer: all fixes reviewed
- [ ] qa-lead: QA gate PASS confirmed
- [ ] producer: deployment timing approved
- [ ] release-manager: platform submission confirmed

---

## Player-Facing Patch Notes

[Draft for community-manager to review before publishing]

[list player-facing changes in plain language]
```

询问："May I write this patch record to `production/releases/day-one-patch-[version].md`?"

---

## 第七阶段：后续步骤

写入补丁记录后：

1. 运行 `/patch-notes` 生成面向玩家的补丁说明版本
2. 补丁上线后，对每个已修复的 bug 运行 `/bug-report verify [BUG-ID]`
3. 对每个已验证的修复运行 `/bug-report close [BUG-ID]`
4. 在发布后 48–72 小时使用 `/retrospective launch` 安排发布后回顾

**如果补丁后仍有任何 S1 bug 未解决：**
> "⚠️ S1 bugs remain open and were not patched. These are accepted risks. Document them in the rollback plan trigger conditions — if they occur at scale, rollback may be preferable to a follow-up patch."

使用 `AskUserQuestion`：
- 提示："Day-one patch complete. What's next?"
- 选项：
  - `[A] Run /patch-notes — generate player-facing patch notes`
  - `[B] Run /bug-report to log any issues found post-deploy`
  - `[C] Stop here`

---

## 协作协议

- **范围纪律就是一切** — 抵制范围蔓延；每增加一项都会增加风险
- **回滚计划优先，始终如此** — 没有回滚计划的补丁是不负责任的
- **推迟不等于遗忘** — 每个推迟的 bug 自动获得一个 1.1 票证
- **玩家沟通是补丁的一部分** — `/patch-notes` 是必需输出，而非可选项
