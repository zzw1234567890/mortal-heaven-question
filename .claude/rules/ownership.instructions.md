---
name: artifact-ownership
description: RACI matrix defining who creates, reads, updates, and validates each artifact. Prevents duplicate responsibility.
applyTo: "**"
---


# 规则：制品所有权 (Artifact Ownership) —— RACI

本项目中的每个制品恰好有 **一个所有者 (Owner)**（创建它）和一个或多个指定的 **更新者 (Updater)**（在特定条件下可以在创建后修改它）。其他技能可以 **读取 (Read)** 或 **验证 (Validate)**，但绝不可以 **写入 (Write)**。

此规则的存在是为了防止"职责重复"的反模式，即多个技能更新同一个制品却没有明确的权威，导致漂移和冲突。

## Confluence 制品 (Confluence Artifacts)

| 制品 | 所有者（创建者） | 更新者 | 读取者 | 验证者 |
|----------|----------------|---------|---------|------------|
| Demandas/ 标签 | /osk-init | — | /osk-discover | — |
| Visão do Produto | /osk-init | — | all | — |
| Glossário | /osk-init | /osk-discover（退出关卡），/osk-build（仅合并后） | /osk-spec | /osk-spec（只读验证） |
| DD（设计文档） | /osk-spec（通过 `design-doc` 智能体） | /osk-build（合并后，通过 `design-doc` 智能体） | — | — |
| Domínio/Regras | /osk-init | /osk-build（仅合并后） | /osk-discover、/osk-spec | — |
| Domínio/Fluxos | /osk-init | /osk-build（仅合并后） | /osk-discover | — |
| Domínio/Tabelas | /osk-init | — | /osk-discover | — |
| Domínio/Integrações | /osk-init | /osk-build（仅合并后） | /osk-discover | — |
| Features/（父级） | /osk-init | — | all | — |
| 特性页面（内容） | /osk-init + /osk-discover | /osk-discover | /osk-spec、/osk-build | — |
| 特性标签 | 每个技能在其转换时 | — | all | — |
| Arquivados/ | /osk-init | — | — | — |

**Glossário 冲突规则**：如果 /osk-build（合并后）需要更新 /osk-discover 定义的术语，/osk-build 的更新胜出 —— 它反映已实现的实际情况。/osk-build 添加一条注释："Atualizado pós-merge: {reason}"。

**DD 更新协调**：/osk-spec 首先更新 DD（规范阶段期间），/osk-build 在合并后更新（阶段 D 期间）。如果 /osk-build 需要更改 /osk-spec 编写的内容，/osk-build 用已实现的实际情况覆盖（代码在合并后是真理来源）。无需锁定 —— 顺序工作流防止了同时更新。

## 本地制品 (Local Artifacts)

| 制品 | 所有者（创建者） | 更新者 | 读取者 | 验证者 |
|----------|----------------|---------|---------|------------|
| `projects.yml` | /osk-init | /osk-spec（添加计划中的仓库），/osk-build（仓库 URL + 状态） | all | — |
| `docs/architecture.md` | /osk-init | /osk-discover（解决决策），/osk-build（合并后添加已解决的决策） | /osk-spec、/osk-build | /osk-spec（验证无阻塞项） |
| `docs/lessons/` | /osk-build | /osk-build | all | — |
| `docs/decisions/` | manual / spec-agent | — | all | — |
| `docs/pending-confluence-updates.md` | 任何技能（MCP 故障时） | 任何技能（重试时） | all | — |
| `specs/NNN/brief.md` | /osk-spec | — | /osk-build | — |
| `specs/NNN/scenarios.md` | /osk-spec | /osk-build（合并后同步 D.1.5 —— 仅当符合性报告显示有意的偏离时） | /osk-build | — |
| `specs/NNN/contracts.md` | /osk-spec | /osk-build（合并后同步 D.1.5 —— 仅当符合性报告显示有意的偏离时） | /osk-build | — |
| `specs/NNN/tasks.md` | /osk-spec | — | /osk-build | — |
| `specs/NNN/links.md` | /osk-spec（模板） | /osk-build（合并后 MR 链接），/osk-hub（阶段 3 PR URL） | — | — |
| `specs/NNN/audit-report.md` | spec-auditor 智能体（hub 模式）；/osk-spec 自我审查（独立模式） | — | /osk-build（阶段 B 前读取，若 ❌ 则阻塞） | — |
| `specs/NNN/openapi.yaml` | /osk-spec（可选，如果有 REST 端点） | /osk-build（可能扩展） | — | — |
| `specs/NNN/evaluator-report.md` | /osk-hub（阶段 2.5） | — | /osk-build（仅上下文） | — |
| `specs/NNN/pipeline-state.json` | /osk-hub（阶段 1 首次写入） | /osk-hub（每个阶段后） | all | — |
| `specs/NNN/conformance-report.json` | conformance-verify CLI（hub 模式阶段 3.B）；/osk-build 阶段 C.3（独立模式） | /osk-build（每次运行覆盖；合并后同步） | CI Guard | — |
| `specs/NNN/conformance-history.log` | conformance-verify CLI（hub 模式阶段 3.B）；/osk-build 阶段 C.3（独立模式） | /osk-build（每次运行追加） | — | — |
| `specs/NNN/internal-libs.md` | /osk-hub（阶段 3.1.5 步骤 3） | /osk-hub（重新运行时重写） | 编码智能体（在提出依赖前读取） | — |
| `CHANGELOG.md`（实现仓库 —— 仅 `main_repo`） | `main_repo` 的编码智能体（阶段 3 / C.6.7 —— 在 PR 开启前提交到特性分支内） | — | all | /osk-build（阶段 D.4.5 —— 在合并提交中只读验证；绝不推送到 `main`） |

**符合性版本控制**：`conformance-report.json` 在每次 /osk-build 运行时被覆盖。为了保留历史，/osk-build 向 `specs/NNN/conformance-history.log` 追加一行摘要：`{timestamp} | {result} | {matching}/{total} endpoints | {matching}/{total} fields`

## 关键规则 (Key Rules)

1. **每个制品一个所有者** —— 每个制品恰好有一个创建它的所有者。更新者在上述矩阵中明确指定，并附带条件（例如"仅合并后"）。如果某个技能写入它未被列为所有者或更新者的制品，那就是错误的。

2. **验证 ≠ 更新** —— /osk-spec 验证 Glossário（检查所有术语是否存在）但 **不**添加术语。如果缺少术语，它会停止并要求开发者重新运行 /osk-discover。

3. **合并后 = 实际情况** —— 当 /osk-build 在合并后更新 Confluence 时，它反映的是 **已被实现的内容**（已合并的代码），而不是计划的内容。如果实现与规范偏离，Confluence 必须匹配代码，而非规范。

4. **DD 所有权** —— 设计文档 (Design Document) 由 `design-doc` 智能体拥有。技能委派给它。仅当智能体不可用时，才将直接 MCP 作为回退方案。

5. **标签累积** —— MCP Confluence 只添加标签（不删除）。"当前"工作流状态始终是最近添加的标签。先前的标签作为历史保留。

   **标签状态解析算法**：当存在多个标签时确定当前状态，比较标签创建时间戳（通过 Confluence 中的页面元数据）。创建时间戳最新的标签定义当前状态。如果时间戳不可用，使用以下优先级顺序（最高者胜出）：`done` > `em-dev` > `em-spec` > `prd-aprovado` > `prd-rejeitado` > `prd-review` > `aguardando-po` > `em-discovery`。

6. **双平台共享（Claude + Copilot）** —— Open Spec Kit 将技能、规则和智能体安装到 `~/.claude/`，该目录被 Claude Code 和 GitHub Copilot（VS Code 2026+）原生读取。

   | 真理来源 | 安装到 | 被读取者 |
   |-----------------|-------------|---------|
   | `cli/templates/agents/skills/` | `~/.claude/skills/` | Claude Code（原生）+ Copilot（`chat.agentSkillsLocations` 默认） |
   | `cli/templates/agents/rules/` | `~/.claude/rules/` | Claude Code（原生）+ Copilot（`chat.instructionsFilesLocations`） |
   | `cli/templates/agents/agents/` | `~/.claude/agents/` | Claude Code（原生）+ Copilot（`chat.agentFilesLocations`） |

   **`cli/templates/agents/` 是真理来源。** 运行 `open-spec-kit update` 以同步到 `~/.claude/`。

   需要 `open-spec-kit update` 的更改：
   - 修改任何技能、规则或智能体定义
   - 添加/移除子智能体或技能
   - MCP 配置（`.mcp.json`、`.vscode/mcp.json`）保持在每个项目中，由 `open-spec-kit init` 生成

## 标签转换 (Label Transitions)

### Demandas/ 标签（由 /osk-init 拥有）

```
(none) → novo → processando → processado
```

### 特性标签（顺序流程）

```
em-discovery → aguardando-po → prd-review → prd-aprovado → em-spec → em-dev → done
                     ↑                            |
                     └──── prd-rejeitado ─────────┘
```

- `prd-aprovado` 由 **PO 手动**添加（人工关卡）
- `prd-rejeitado` 由 **PO 手动**添加（触发 /osk-discover 重新运行）
- 所有其他标签由相应的技能自动添加

## MCP 故障恢复 (MCP Failure Recovery)

所有 5 个技能必须处理 MCP 故障：
- /osk-init：重新执行检查现有页面，仅创建缺失的页面
- /osk-discover：将挂起的操作保存到 `docs/pending-confluence-updates.md`
- /osk-spec：将挂起的操作保存到 `docs/pending-confluence-updates.md`
- /osk-build：将挂起的更新保存到 `docs/pending-confluence-updates.md`，在下一次执行时重试
- /osk-hub：在每个 MCP 操作前持久化 `pipeline-state.json`；故障时，报告被中断的阶段并指示开发者检查 `docs/pending-confluence-updates.md` 并使用 `resume spec NNN` 恢复

## 架构决策格式 (Architecture Decisions Format)

`docs/architecture.md` 中的"Decisões em Aberto"表使用此模式：

```
| # | Decisão | Impacto | Bloqueia | Status |
```

Status 值：`aberta`、`resolvida — [decisão tomada]`

/osk-discover 在其退出关卡期间更新此列。/osk-build 也可以在实现过程中发现新决策时，在合并后（阶段 D.4）添加已解决的决策。/osk-spec 验证没有 `aberta` 决策阻塞 /osk-build。

## links.md PR 表格式

```markdown
## PRs

| Repo | Branch | MR/PR | Status |
|------|--------|-------|--------|
```

状态值：`open`、`em-review`、`merged`、`closed`。由 /osk-spec 创建为空；/osk-hub 在阶段 3 中以 `em-review` 状态写入 PR URL；/osk-build 在阶段 D.1 中更新为 `merged` 状态（必须 APPEND/UPDATE 现有行，而不是覆盖表）。

## 特性间共享类型 (Shared Types Between Features)

当 `contracts.md` 定义了其他特性将重用的类型时（例如 ErrorResponse、PaginatedResponse）：
- 将它们标记在 `## Tipos compartilhados` 部分中
- 使用另一个特性的类型的特性必须 **引用** 它们（"Ver contracts.md da feature NNN"）—— 绝不要重新定义

## 特性范围阈值 (Feature Scope Thresholds)

/osk-discover 和 /osk-spec 都使用相同的标准：
- 超过 **15 个行为/需求** → 标记为可能过大
- 涉及 **4 个以上仓库** → 标记为可能过大
- 这是建议，而非阻塞项。PO/开发者决定是否拆分。
