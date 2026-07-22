---
name: team-polish
description: "编排打磨团队：协调 performance-analyst（性能分析师）、technical-artist（技术美术）、sound-designer（音效设计师）和 qa-tester（QA 测试员），对功能或区域进行优化、打磨和加固，达到发布质量。"
argument-hint: "[feature or area to polish] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TodoWrite

---


如果未提供参数，直接输出使用指南并退出，不生成任何子代理：
> 用法：`/team-polish [功能或区域]` — 指定要打磨的功能或区域（例如 `combat`、`main menu`、`inventory system`、`level-1`）。请勿在此处使用 `AskUserQuestion`；直接输出指南。

当本 skill 被调用并带有参数时，通过结构化管线编排打磨团队。

**决策节点：** 在每个阶段过渡时，使用 `AskUserQuestion` 向用户展示子代理的提案作为可选选项。在对话中完整记录代理的分析，然后以简洁的标签记录决策。用户必须批准后才能进入下一阶段。

## 阶段 0：解析审查模式

1. 如果 `--review [mode]` 作为参数传入，使用该模式。
2. 否则读取 `production/review-mode.txt` — 使用其中写入的内容。
3. 否则默认为 `lean`。

模式：
- `full` — 按描述生成所有总监和主管关卡
- `lean` — 跳过总监关卡，除非是阶段关卡类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` — 完全跳过所有总监关卡生成；在没有任何代理关卡的情况下运行 skill

将解析后的模式存储起来，用于所有后续阶段。

**总监关卡跳过规则**：在生成任何 Tier 1 总监或主管进行审查之前（阶段关卡触发器除外），应用已解析的模式：如果为 solo 模式则跳过；如果为 lean 模式且不是阶段关卡则跳过。

## 团队组成
- **performance-analyst（性能分析师）** — 性能分析、优化、内存分析、帧预算
- **engine-programmer（引擎程序员）** — 引擎级瓶颈：渲染管线、内存、资源加载（当性能分析师确定底层根原因时调用）
- **technical-artist（技术美术）** — VFX 打磨、着色器优化、视觉质量
- **sound-designer（音效设计师）** — 音频打磨、混音、环境层、反馈音效
- **tools-programmer（工具程序员）** — 内容管线工具验证、编辑器工具稳定性、自动化修复（当内容创作工具涉及打磨区域时调用）
- **qa-tester（QA 测试员）** — 边界情况测试、回归测试、浸泡测试

## 如何委派

使用 Task 工具将每个团队成员生成为子代理：
- `subagent_type: performance-analyst` — 性能分析、优化、内存分析
- `subagent_type: engine-programmer` — 引擎级修复，涉及渲染、内存、资源加载
- `subagent_type: technical-artist` — VFX 打磨、着色器优化、视觉质量
- `subagent_type: sound-designer` — 音频打磨、混音、环境层
- `subagent_type: tools-programmer` — 内容管线和编辑器工具验证
- `subagent_type: qa-tester` — 边界情况测试、回归测试、浸泡测试

始终为每个代理提供完整的上下文（目标功能/区域、性能预算、已知问题）。在管线允许的情况下并行启动独立代理（例如阶段 3 和阶段 4 可以同时运行）。

## 管线

### 阶段 1：评估
委派给 **performance-analyst**：
- 使用 `/perf-profile` 对目标功能/区域进行性能分析
- 识别性能瓶颈和帧预算违规
- 测量内存使用情况并检查泄漏
- 对照目标硬件规格进行基准测试
- 输出：包含按优先级排序的优化列表的性能报告

### 阶段 2：优化
委派给 **performance-analyst**（根据需要配合相关程序员）：
- 修复阶段 1 中确定的性能热点
- 优化 draw call，减少过度绘制
- 修复内存泄漏并减少分配压力
- 验证优化不会改变游戏行为
- 输出：包含优化前后指标的优化代码

如果阶段 1 识别出引擎级根原因（渲染管线、资源加载、内存分配器），并行将这些修复委派给 **engine-programmer**：
- 优化引擎系统中的热路径
- 修复核心循环中的分配压力
- 输出：经过分析器验证的引擎级修复

### 阶段 3：视觉打磨（与阶段 2 并行）
委派给 **technical-artist**：
- 审查 VFX 的质量和与艺术圣经的一致性
- 优化粒子系统和着色器效果
- 在适当位置添加屏幕震动、摄像机效果和视觉增强
- 确保效果在较低设置下优雅降级
- 输出：打磨后的视觉效果

### 阶段 4：音频打磨（与阶段 2 并行）
委派给 **sound-designer**：
- 审查音频事件的完整性（是否有任何动作缺少音效反馈？）
- 检查音频混音电平——没有任何内容相对于混音过响或过轻
- 添加环境音频层营造氛围
- 验证音频在空间定位下正确播放
- 输出：音频打磨列表和混音说明

### 阶段 5：加固
委派给 **qa-tester**：
- 测试所有边界情况：边界条件、快速输入、异常序列
- 浸泡测试：长时间运行该功能，检查是否存在性能下降
- 压力测试：最大实体数、最坏情况场景
- 回归测试：验证打磨更改没有破坏现有功能
- 在最低规格硬件上测试（如可用）
- 输出：包含任何遗留问题的测试结果

### 阶段 6：签收
- 收集所有团队成员的成果
- 将性能指标与预算进行对比
- 报告：READY FOR RELEASE / NEEDS MORE WORK
- 列出任何遗留问题及其严重性和建议

## 错误恢复协议

如果任何生成的代理（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即上报**：在继续依赖阶段之前向用户报告"[代理名称]：BLOCKED — [原因]"
2. **评估依赖关系**：检查被阻塞代理的输出是否为后续阶段所需。如果是，在没有用户输入的情况下不要越过该依赖点继续。
3. **通过 AskUserQuestion 提供选项**，包含以下选择：
   - 跳过此代理并在最终报告中记录缺口
   - 以更窄的范围重试
   - 在此停止，先解决阻塞因素
4. **始终生成部分报告** — 输出已完成的内容。绝不要因为一个代理阻塞而丢弃已完成的工作。

常见阻塞因素：
- 输入文件缺失（故事未找到，GDD 不存在）→ 重定向到创建该文件的 skill
- ADR 状态为 Proposed → 不实施；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间的指令冲突 → 上报冲突，不要猜测

## 文件写入协议

所有文件写入（性能报告、测试结果、证据文档）都委派给通过 Task 生成的子代理。每个子代理执行"May I write to [path]?"协议。此编排器不直接写入文件。

## 输出

一份总结报告，涵盖：性能优化前后指标、视觉打磨更改、音频打磨更改、测试结果和发布就绪性评估。

## 后续步骤

- 如果 READY FOR RELEASE：运行 `/release-checklist` 进行最终预发布验证。
- 如果 NEEDS MORE WORK：在 `/sprint-plan update` 中安排剩余问题并在修复后重新运行 `/team-polish`。
- 在移交给发布之前，运行 `/gate-check` 获取正式阶段关卡裁决。
