---
name: soak-test
description: "生成长时间游戏会话的浸泡测试协议。定义在长时间游戏过程中需要观察、测量和记录的内容，以发现缓慢泄漏、疲劳效应和仅在持续游戏后出现的边缘情况。主要用于打磨和发布阶段。"
argument-hint: "[duration: 30m | 1h | 2h | 4h] [focus: memory | stability | balance | all]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write

---


# 浸泡测试 (Soak Test)

浸泡测试（也称为耐力测试）是一种带有特定观察目标的长时间游戏会话。与冒烟检查（广泛关键路径，约 10 分钟）或单功能试玩测试（约 30 分钟）不同，浸泡测试运行 **30 分钟到数小时**，以发现：

- **内存泄漏 (Memory leaks)** — 仅在场景切换后出现的渐进式堆增长
- **性能漂移 (Performance drift)** — 随时间恶化的帧时间退化
- **状态累积缺陷 (State accumulation bugs)** — 仅在某个机制重复 N 次后出现的问题（库存满、分数溢出、AI 状态损坏）
- **趣味疲劳 (Fun fatigue)** — 在第一次会话中感觉良好但在长时间游戏中变得重复的机制
- **内容耗尽 (Content exhaustion)** — 玩家用完新颖内容的时间点

**本技能生成观察协议和分析框架 — 实际游玩由人类完成。**

**输出：** `production/qa/soak-test-[date]-[duration].md`

**运行时机：**
- 打磨阶段 — 在 `/gate-check release` 之前
- 在修复内存或稳定性问题之后（回归浸泡测试）
- 当长时间游戏尚未被正式追踪时

---

## 1. 解析参数 (Parse Arguments)

**时长 (Duration)**（默认：`1h`）：
- `30m` — 短浸泡；适合测试单个机制或场景
- `1h` — 标准浸泡；覆盖大多数常见泄漏类别
- `2h` — 延长浸泡；推荐用于首次完整打磨浸泡
- `4h` — 深度浸泡；对于具有长会话设计的游戏必需（RPG、模拟类）

**焦点 (Focus)**（默认：`all`）：
- `memory` — 关注堆大小、对象数量、泄漏模式
- `stability` — 关注崩溃/冻结/卡死检测
- `balance` — 关注趣味疲劳、内容耗尽、难度感知
- `all` — 以上所有

---

## 2. 加载上下文 (Load Context)

读取：
- `.claude/docs/technical-preferences.md` — 引擎（用于引擎特定的内存监控指导）、性能预算（内存上限、目标 FPS）
- `design/gdd/game-concept.md` — 预期会话时长（用于与浸泡时长对比）、核心循环描述
- `production/playtests/` 中最近的文件 — 先前的试玩测试发现结果（避免重复记录已知问题）
- `production/qa/qa-plan-*.md` 中最近的文件 — 当前冲刺测试覆盖范围（了解已正式测试的内容与浸泡覆盖的内容）

记录 technical-preferences.md 中的任何性能预算目标：
- 内存上限：[N MB，或"未设置"]
- 目标 FPS：[N，或"未设置"]
- 帧预算：[N ms，或"未设置"]

---

## 3. 定义观察检查点 (Define Observation Checkpoints)

基于时长生成定时检查点：

**30 分钟浸泡**: T+0, T+10, T+20, T+30
**1 小时浸泡**: T+0, T+15, T+30, T+45, T+60
**2 小时浸泡**: T+0, T+20, T+40, T+60, T+80, T+100, T+120
**4 小时浸泡**: T+0, T+30, T+60, T+90, T+120, T+180, T+240

在每个检查点，观察者记录阶段 4 中定义的观察项。

---

## 4. 生成浸泡测试协议 (Generate the Soak Test Protocol)

### 内存 / 稳定性观察项（如果焦点 = memory 或 all）

引擎特定的监控指导：

**Godot 4：**
- 打开调试器 → Monitors 选项卡；跨检查点跟踪 `Memory → Static Memory` 和 `Object Count → Objects`
- 记录：Static Memory（KB）、Object Count、Orphan Nodes 计数
- 警告阈值：前 15 分钟后内存增长超过 T+0 的 20%（加载时有一定增长是正常的；持续增长表明泄漏）
- 注意：`Performance.get_monitor(Performance.MEMORY_STATIC)` 在 Godot 4.6 中返回字节数

**Unity：**
- 打开 Memory Profiler（Window → Analysis → Memory Profiler）
- 记录：每个检查点的 Total Reserved Memory（MB）、GC Allocated（MB）、Object Count
- 警告阈值：GC Allocated 在 3 个以上检查点单调增长

**Unreal Engine：**
- 在每个检查点使用 `stat memory` 控制台命令
- 记录：Physical Memory Used（MB）、Physical Memory Available
- 警告阈值：整个浸泡过程中 Physical Memory Used 增长超过 50MB

### 稳定性观察项（如果焦点 = stability 或 all）

在每个检查点，记录：
- [ ] 自上次检查点以来未发生崩溃、卡死或冻结
- [ ] 帧率仍在目标预算内（[目标 FPS] fps）
- [ ] 音频仍正常播放（无不同步或静音）
- [ ] 所有 HUD 元素仍正确渲染
- [ ] 输入按预期响应（无输入丢失或延迟尖峰）

### 平衡 / 疲劳观察项（如果焦点 = balance 或 all）

在每个检查点收集主观观察：
- [ ] 核心机制仍然感觉有回报（是/否）
- [ ] 感知难度级别：[太简单 / 合适 / 太难]
- [ ] 自上次检查点以来有任何"我以前见过这个"的时刻吗？（新颖内容耗尽）
- [ ] 自上次检查点以来有任何挫折时刻吗？记录原因。
- [ ] 自上次检查点以来有任何投入感高峰时刻吗？记录原因。

---

## 5. 生成协议文档 (Generate the Protocol Document)

```markdown
# 浸泡测试协议 (Soak Test Protocol)

> **日期**: [日期]
> **时长**: [duration]
> **焦点**: [memory | stability | balance | all]
> **引擎**: [engine]
> **生成者**: /soak-test

---

## 会话前准备 (Pre-Session Setup)

在开始浸泡之前：

- [ ] 游戏从**全新启动**运行（非从先前会话恢复）
- [ ] 所有后台应用程序已关闭（最小化操作系统内存干扰）
- [ ] 性能监控工具已打开并录制：
  - **Godot**: 调试器 → Monitors 选项卡 → Memory 部分可见
  - **Unity**: Memory Profiler 窗口已打开
  - **Unreal**: `stat memory` 已在控制台中准备就绪
- [ ] 浸泡目标已确认：[来自游戏概念的会话设计意图]
- [ ] 要关注的先前已知问题：[来自最近的试玩测试 / qa-plan]

---

## 基线 (Baseline)（T+0）— 在开始游戏前记录

| 指标 | 基线值 |
|--------|---------------|
| 内存 / 堆 | [在游戏的第一帧之前记录] |
| 对象数量 | [记录] |
| FPS（前 30 秒） | [记录] |
| [引擎特定指标] | [记录] |

---

## 检查点日志 (Checkpoint Log)

### T+[N] 分钟

**内存 / 稳定性** *（如适用）*：

| 指标 | 值 | 与基线差值 | 触发警报？ |
|--------|-------|-----------------|--------|
| 内存 / 堆 | | | |
| 对象数量 | | | |
| FPS | | | |
| 崩溃 / 卡死 | | | |

**稳定性检查**：
- [ ] 自上次检查点以来无崩溃或卡死
- [ ] 帧率在预算内（[N] fps 目标）
- [ ] 音频正常
- [ ] HUD 渲染正确
- [ ] 输入响应正确

**平衡 / 疲劳** *（如适用）*：
- 核心机制仍然有回报：是 / 否
- 难度感知：太简单 / 合适 / 太难
- 值得注意的时刻：[记录任何投入感高峰或挫折]
- 内容耗尽迹象：是 / 否 — [描述]

**自由观察**：
*（记录自上次检查点以来观察到的任何意外情况）*

---

[为每个定时检查点重复检查点日志部分]

---

## 会话后分析 (Post-Session Analysis)

### 内存趋势 (Memory Trend)

| 检查点 | 内存 | 外推每小时差值 |
|------------|--------|-------------------|
| T+0 | | |
| [T+N] | | |

**检测到泄漏？** 是 / 否
**按当前速率预计内存耗尽时间**: [N 小时 / 不适用]

### 稳定性摘要 (Stability Summary)

总崩溃次数：[N]
总卡死次数：[N]
观察到的最差 FPS：[N] fps，在 [检查点]
性能退化：稳定 / 轻微 / 严重

### 平衡 / 疲劳摘要 (Balance / Fatigue Summary)

趣味曲线：[全程投入 / 在 T+N 出现疲劳 / 从头开始重复]
内容耗尽点：[从未 / 在 T+N / 过早]
难度曲线：[合适 / 全程太简单 / 在 T+N 出现难度尖峰]

### 发现的问题 (Issues Found)

| ID | 严重性 | 检查点 | 描述 |
|----|----------|------------|-------------|
| SOAK-001 | S[1-4] | T+[N] | [描述] |

---

## 判定: PASS / PASS WITH CONCERNS / FAIL

**PASS**: 未检测到泄漏，稳定性保持，趣味因素一致
**PASS WITH CONCERNS**: 注意到轻微漂移或疲劳；可在打磨阶段处理
**FAIL**: 确认内存泄漏，稳定性违规，或严重的趣味疲劳

---

## 签字 (Sign-Off)

- **测试员**: [姓名] — [日期]
- **QA 主管审查**: [姓名] — [日期]
```

---

## 6. 写入输出 (Write Output)

在对话中呈现协议摘要，然后询问：

"我可以将此浸泡测试协议写入
`production/qa/soak-test-[date]-[duration].md` 吗？"

仅在获得批准后写入。

写入后：

"协议已写入。进行浸泡测试：
1. 打开文件并遵循会话前准备检查清单
2. 在游戏过程中记录每个检查点
3. 完成后填写会话后分析部分
4. 将'发现的问题'中的缺陷归档到 `production/qa/bugs/`
5. 会话后运行 `/bug-triage sprint` 以整合任何 S1/S2 问题

如果判定为 FAIL，在修复问题后重新运行 `/smoke-check`。"

---

## 协作协议 (Collaborative Protocol)

- **本技能生成协议 — 由人类执行** — 绝不要尝试自动运行浸泡测试。观察需要人类观察者。
- **时长应与游戏的会话设计匹配** — 一个 5 分钟的游戏不需要 4 小时浸泡；一个城市建造类游戏可能需要。根据判断，如果不确定请询问。
- **首次浸泡应为 `all` 焦点** — 窄焦点（仅内存）适用于特定修复后的回归浸泡测试，而非首次测试
- **写入前询问** — 在创建协议文件之前始终确认
