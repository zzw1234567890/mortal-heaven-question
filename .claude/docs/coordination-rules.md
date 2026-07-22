# 代理协调规则 (Agent Coordination Rules)


1. **垂直委派 (Vertical Delegation)**：领导层代理委派给部门主管，部门主管再委派给专家。复杂决策不得跳过层级。
2. **横向咨询 (Horizontal Consultation)**：同层级的代理可以相互咨询，但不得在其领域之外做出具有约束力的决策。
3. **冲突解决 (Conflict Resolution)**：当两个代理意见不一致时，上报给共同的父级。如果没有共同的父级，设计冲突上报给 `creative-director`，技术冲突上报给 `technical-director`。
4. **变更传播 (Change Propagation)**：当设计变更影响到多个领域时，由 `producer` 代理协调传播。
5. **禁止单方面跨域变更 (No Unilateral Cross-Domain Changes)**：未经明确委派，代理不得修改其指定目录之外的文件。

## 子代理与代理团队 (Subagents vs Agent Teams)

本项目使用两种不同的多代理模式：

### 子代理 (Subagents —— 当前活跃，始终可用)

通过 `Task` 在单个 Claude Code 会话中生成。所有 `team-*` 技能和编排技能均使用此模式。子代理共享会话的权限上下文，在会话内顺序或并行运行，并将结果返回给父级。

**何时并行生成**：如果两个子代理的输入相互独立（各自无需等待对方的输出即可开始），则应同时发出两个 Task 调用，而不是等待。示例：`/review-all-gdds` 第一阶段（一致性检查）和第二阶段（设计理论）相互独立 —— 应同时生成。

### 代理团队 (Agent Teams —— 实验性，需选择启用)

多个独立的 Claude Code *会话*同时运行，通过共享任务列表进行协调。每个会话拥有自己的上下文窗口和 token 预算。需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 环境变量。

**使用代理团队的时机**：
- 工作跨越多个子系统，且这些子系统不会触及相同的文件
- 每个工作流预计耗时超过 30 分钟，且能从真正的并行中受益
- 需要高级代理（如 technical-director、producer）同时协调 3 个以上处理不同特性的专家会话

**不使用代理团队的时机**：
- 一个会话的输出是另一个会话的输入（应使用顺序子代理）
- 任务适合在单个会话的上下文中完成（应使用子代理）
- 成本是一个考量因素 —— 每个团队成员独立消耗 tokens

**当前状态**：通过 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 选择启用。在此处记录首次使用情况。

## 并行任务协议 (Parallel Task Protocol)

当一个编排技能生成多个独立代理时：

1. 在等待任何结果之前，先发出所有独立的 Task 调用
2. 在进入依赖阶段之前，收集所有结果
3. 如果任何代理被 BLOCKED（阻塞），立即上报 —— 不要静默跳过
4. 如果部分代理完成而其他代理阻塞，始终生成部分报告
