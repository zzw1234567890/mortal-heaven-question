# 回顾：Sprint 16 — 核心循环第一跳打通

周期：2026-10-24 -- 2026-11-02（计划 10 天，按期）｜生成日期：2026-11-02

---

## 指标

| 指标 | 计划 | 实际 | 偏差 |
|--------|---------|--------|-------|
| 任务数（全量） | 9（3 must + 3 should + 3 nice） | **7 完成（3 must + 4 should）+ 2 nice 结转** | 范围调整 |
| must-have 完成率 | 3 | **3（100%）** | 0 |
| should-have 完成率 | 3 | **4（100%，手牌弧形调整进来）** | +1 |
| nice-to-have 完成率 | 3 | **0（全部 backlog）** | -3 |
| 日历日 | 10（10-24→11-02） | **10（按期）** | 0 |
| 发现的缺陷 | -- | 1（S16-3 代码未提交，流程缺陷非代码 bug） | -- |
| story 提交数 | -- | 7 | -- |
| 自动化测试 | 基线 2920 | **3104（+184）**，0 确认失败，1 pending 存量 | 零回归 ✅ |

---

## 速度趋势

| 冲刺 | 计划 must | 完成 | 完成率 | 日历日 |
|--------|---------|-----------|------|------|
| Sprint 13 | 7 | 7 | 100% | 5 |
| Sprint 14 | 8 | 8 | 100% | ~19（计划 10） |
| Sprint 15 | 4 must（9 全量） | 9/9 | 100% | ~11（计划 10） |
| Sprint 16（当前） | 3 must | 7/7 完成（3 must + 4 should） | must 100% | 10（按期） |

**趋势**：稳定——「UI story = 2 日历日/story」校准连续两冲刺精确兑现，must 按期交付且 should 超额（+1）。nice 层归零是范围仲裁的直接结果（非速度问题）。

---

## 做得好的方面

- **核心循环第一跳打通**：主菜单「新游戏」→ 身份选择 → 地图选择 → 节点图，兑现 S15 行动项 #1，消除「新游戏无法开始」冒烟留桩（`identity_select.tscn` 落盘 + SCENE_PATHS 串联）。
- **should 层超额完成**：计划 3 项 should 全部完成，额外拉入 combat-ui-layout 006 手牌弧形（S16-7）也完成——战斗 UI 顶部条/费用栏/手牌三连全链路闭合。
- **零回归 + 自动化 +184**：2920 → 3104，combat_ui 测试目录从 S15 的 9 文件扩展到 13 文件（新增 hand_arc 4 文件 + topbar/cost 补强）。
- **audio 004 过渡矩阵**：24 行真源 + 环解耦 + N/A 回滚，SceneManager TRANSITION_AUDIO_PARAMS 对齐。

---

## 做得不好的方面

- **S16-3「done 但未提交」**：节点图 story 已 story-done 关闭（completed 2026-10-27），但 16 个文件（源码 + 测试）留工作区 5 天未提交，直到 QA 冒烟检查才暴露。这是流程缺口——story-done 关闭前未验证 git 状态。
- **nice-to-have 全空**：audio 005（被换出）/ hud 008 / main-menu 005 三项全部 backlog，且 audio 005 的替换（→手牌弧形）未在 sprint-16.md 计划文档同步，导致 sprint-status.yaml 与计划、qa-plan 三者编号映射不一致。
- **手动 QA 未实际走查**：5 个 UI 证据文档仅建立框架（68 用例），实际结果列全空——headless 环境无法做视觉走查，签收被迫 APPROVED WITH CONDITIONS。
- **QA 计划 S16-7 条目陈旧**：`qa-plan-sprint-16-2026-10-24.md` 仍记作「audio 005 暂停/静音」，与实际「combat-ui-layout 006 手牌弧形」不符。

---

## 遇到的阻塞项

| 阻塞项 | 持续时间 | 解决方案 | 预防措施 |
|---------|----------|------------|------------|
| S16-3 代码未提交（story-done 已关闭） | 5 天（10-27 至 11-02） | 冒烟暴露后补提交 97845bb | story-done 关闭前强制校验 `git status` 无本 story 残留 |

---

## 预估准确性

7 个 story 全部按期（UI 2 日历日/story、Logic/Integration 1.0-1.5d），无一超预估。**容量模型连续两冲刺稳定。**

---

## 结转分析

| 任务 | 原始冲刺 | 结转次数 | 原因 | 处理方式 |
|------|----------------|---------------|--------|--------|
| hud 008 静音图标 | S16（nice） | 1 | nice 层未排 | Sprint 17 |
| main-menu 005 语言切换 | S16（nice） | 1 | nice 层未排 | Sprint 17 |
| audio 005 暂停静音 | S16（被换出） | 1 | 换入手牌弧形（scope 调整） | Sprint 17 |
| R-02 组件级复测（D3D12） | S15→16 | 2 | combat-ui 004-006 实现优先 | Sprint 17 |
| R-05 复测（真实图标 + 揭雾动画） | S15→16 | 2 | exploration 主体未完成 | Sprint 17 |

---

## 技术债务状态

- 当前 TODO：2 / FIXME：0 / HACK：0 —— 稳定无新增
- **SCENE_PATHS 8 个占位场景仍在**：deck_editing / combat / tribulation / shop / event_panel / result_screen / defeat_screen / cultivation（identity_select 已在 S16-1 消除，剩余归后续 story 落地）

---

## 先前行动项跟进（Sprint 15）

| 行动项 | 状态 | 备注 |
|--------|------|------|
| #1 身份选择 UI 场景落地 | ✅ 兑现 | S16-1，消除「新游戏无法开始」留桩 |
| #2 R-02 组件级复测 + R-05 复测义务 | ⚠️ 部分 | combat-ui 004-006 实现完成，组件级 D3D12 复测顺延 S17 |
| #3 audio 004 承接四项 S 建议 | ⚠️ 部分 | audio 004 完成；四项 S 建议补登 register 未见，需确认 |
| #4 S15-9 四项 S 建议补登 tech-debt-register | ❌ 未兑现 | grep 未见独立条目 |
| #5 SCENE_PATHS 占位路径清单化 | ⚠️ 部分 | identity_select 已消除，其余 8 个占位未清单化 |

---

## 下个迭代的行动项

| # | 行动 | 负责人 | 优先级 | 截止日期 |
|---|--------|-------|----------|----------|
| 1 | 5 个 UI 证据文档手动走查回填 + 签收（QA 签收条件 1） | qa-lead | 高 | Sprint 17 首周 |
| 2 | S16-3 三条缺陷风险走查确认，不符则开缺陷报告（QA 签收条件 2） | qa-tester | 高 | Sprint 17 首周 |
| 3 | QA 计划 S16-7 条目勘误 + sprint-16.md 计划 scope 调整同步 | producer | 中 | Sprint 17 规划时 |
| 4 | nice 结转三项（hud 008 / main-menu 005 / audio 005）规划入 Sprint 17 | producer | 中 | Sprint 17 规划时 |
| 5 | S15-9 四项 S 建议 + audio 004 四项 S 建议补登 tech-debt-register | qa-lead | 中 | Sprint 17 首周 |

---

## 流程改进

- **story-done 关闭前校验 git 提交状态**：在 `/story-done` 阶段 7 更新故事状态前，强制校验 `git status` 无本 story 相关文件残留——S16-3 的「done 但未提交」缺口应成为 story-done 的内置检查。
- **scope 调整三方同步**：当 story 编号/范围调整时，同步更新 sprint-status.yaml + sprint 计划 + qa-plan 三处映射，避免「S16-7 是 audio 005 还是手牌弧形」的歧义。

---

## 总结

Sprint 16 是一个「must 按期、should 超额、nice 归零」的冲刺：核心循环第一跳（主菜单→身份→地图→节点图）按期打通，战斗 UI 三组件 + 手牌弧形 + audio 过渡矩阵全链路闭合，零回归、自动化 +184。唯一的实质性遗憾是 S16-3 的「done 但未提交」暴露了 story-done 流程缺口——这是最需要改变的一件事：**story-done 关闭必须与 git 提交状态校验绑定**，否则「完成」的成色会被工作区残留稀释。
