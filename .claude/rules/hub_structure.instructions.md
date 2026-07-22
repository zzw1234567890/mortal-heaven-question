---
name: project-structure
description: Rules for maintaining the spec repo structure and conventions.
applyTo: "**"
---


# 规则：规范仓库结构 (Spec Repo Structure)

## 目录约定 (Directory Conventions)

- 规范 (Specs) 位于 `specs/NNN-short-name/`（顺序编号）
- 架构文档位于 `docs/architecture.md`
- ADR 位于 `docs/decisions/ADR-NNN-title.md`
- 经验教训 (Lessons) 位于 `docs/lessons/NNN-short-title.md`
- 项目仓库引用位于 `projects.yml`

## 命名 (Naming)

- 规范目录：`NNN-short-description`（`001-consumer-shipment`）
- ADR 文件：`ADR-NNN-short-title.md`（`ADR-001-multi-repo.md`）
- 经验教训文件：`NNN-short-title.md`（`001-pool-postgres.md`）

## 规范生命周期 (Spec Lifecycle)

1. 创建：规范目录，包含 brief（概要）+ scenarios（场景）+ contracts（契约）+ tasks（任务）
2. 进行中：任务被勾选，links.md 跟踪 PR
3. 合并后同步：如果实现有意识地偏离了规范，/osk-build 会更新 contracts.md 和 scenarios.md 以匹配实际情况（阶段 D.1.5）
4. 完成：所有任务已勾选，规范目录保留（它本身就是历史记录）

规范不会被归档或移动。带有已勾选任务的规范目录就是记录本身。

## 内容存放位置 (What Goes Where)

| 内容 | 位置 |
|---------|----------|
| 特性规范 (Feature specification) | `specs/<spec>/brief.md` |
| 行为场景 (Behavioral scenarios) | `specs/<spec>/scenarios.md` |
| 契约定义 (Contract definitions) | `specs/<spec>/contracts.md` |
| 实现任务 (Implementation tasks) | `specs/<spec>/tasks.md` |
| PR 跟踪 | `specs/<spec>/links.md` |
| 规范质量审计 | `specs/<spec>/audit-report.md` |
| 实现符合性 | `specs/<spec>/conformance-report.json` |
| 符合性历史 | `specs/<spec>/conformance-history.log` |
| OpenAPI 存根（可选） | `specs/<spec>/openapi.yaml` |
| 流水线状态（使用 /osk-hub 时） | `specs/<spec>/pipeline-state.json` |
| 评估报告（使用 /osk-hub 时） | `specs/<spec>/evaluator-report.md` |
| 架构概览 | `docs/architecture.md` |
| 架构决策 | `docs/decisions/ADR-NNN.md` |
| 经验教训 | `docs/lessons/NNN-title.md` |
| 仓库引用 | `projects.yml` |

## 制品层级结构：职责与目标大小 (Artifact Hierarchy: Responsibilities and Target Size)

每个制品有 **一个主要职责** 和一个目标大小。如果内容超过目标大小或涵盖多个职责，请拆分 —— 不要膨胀。

| 制品 | 职责 | 目标大小 | 验证方式 | 禁止内容（应归入其他制品） |
|----------|----------------|-------------|------------|------------------------------------------------|
| `docs/decisions/ADR-NNN.md` | 一个架构决策 + 替代方案 + 后果 | ≤150 行（ERROR >250） | `open-spec-kit lint-adr` 规则 2 | 迁移批次（→ `tasks.md`）、长代码片段（→ `contracts.md`）、跨团队待办项（→ README/issue） |
| `docs/architecture.md` | 系统级视图 + ADR 指针 | ≤500 行 | 惯例 | 单个决策（→ ADR）、具体枚举（→ `projects.yml > po_defaults`） |
| `docs/lessons/NNN-*.md` | 一个经验教训 + 如何应用 | ≤200 行 | 惯例 | 长篇幅事件叙述（→ `docs/post-mortems/` 中的事后分析） |
| `docs/post-mortems/*.md` | 时间线 + 根本原因 + 行动项 | ≤500 行 | 惯例 | 纠正性决策（→ ADR）、通用检查清单（→ lesson） |
| `docs/reunioes/RELATORIO-*.md` | 跨来源研究的综合发现 | ≤800 行 | 惯例 | 已做出的决策（→ 报告后的 ADR） |
| `docs/reference/*.md` | 稳定模式/格式，按需引用（不总是加载） | ≤200 行 | 惯例 | 总是加载的内容（→ `rules/`）、决策（→ ADR） |
| 仓库 README | 上手引导 + 指针 | ≤300 行 | 惯例 | 应归入 `docs/` 的细节 |
| `specs/NNN/brief.md` | 用产品语言描述特性 | ≤80 行 | `open-spec-kit validate` 规则 2 | 场景（→ `scenarios.md`）、契约（→ `contracts.md`） |

**"验证方式"列**：`open-spec-kit ...` = 由工具强制执行（CI 中断）；`convention`（惯例）= 预期指南，无自动强制执行（依赖人工审查者）。

### 硬性规则：禁止重复 (Hard Rule: No Duplication)

如果一个事实出现在 2 个以上制品中，**选择一个作为其归属地**（范围最窄 + 稳定性最高的那个），所有其他制品 **引用和链接**。绝不在制品之间复制段落 —— 重复必然导致漂移。

示例：
- "认证使用 JWT HS256" → 归属地 = `projects.yml > po_defaults.auth`。README/ADR/architecture **引用它**，不重复。
- "迁移分 3 批完成" → 归属地 = 该规范的 `tasks.md`。ADR 引用"参见 tasks NNN-001 到 NNN-003"而不复制。
- "Charles 于 2026-05-16 传递了过时的上下文" → 归属地 = 研究报告或事后分析（两者选一，不能同时）。

OSK 技能应用此规则：`/osk-spec` 通过链接引用 ADR 而非重复决策；`/osk-build` 引用 `docs/lessons/` 而非重新叙述经验教训。

### 报告中的时效性声明 (Temporal Disclaimer in Reports)

`docs/reunioes/RELATORIO-*.md` 或 `docs/auditoria-*.md` 中的每个文件必须以明确的时效性头部开始：

```markdown
> **Data**: 2026-05-17
> **Validade**: ~90 dias (re-validar após 2026-08-15)
> **Itens voláteis**: versões de lib, URLs, owners de repo, decisões "em discussão"
```

若无此声明，读者无法判断信息是否仍然有效。报告很快就会过时。

### 行内 Confluence 链接（强制性）

每个对 Confluence 页面的引用使用带有真实 URL 的 **markdown 行内链接**，**绝不**仅使用裸 ID：

✗ 错误：`Ver Confluence TLOG 6041763955.`
✓ 正确：`Ver [Confluence TLOG 6041763955](https://magazine.atlassian.net/wiki/x/...).`

MCP `mcp-atlassian` 在载荷中返回 `url` —— 使用它。没有行内 URL 的 ADR 将违反 `open-spec-kit lint-adr` 的规则 7。

## 契约的工作方式 (How Contracts Work)

契约模式在 `contracts.md` 中 **定义**（字段、类型、规则、针对项目栈的代码示例）。代码仓库 **本地实现**，以 contracts.md 作为真理来源。

### 包版本固定 (Package Version Pinning)（条目 34）

当 `contracts.md` 包含依赖于外部包（RabbitMQ.Client、Npgsql、MassTransit、Axios 等）的代码片段时，`## Versões de pacotes` 部分是 **强制性的**，并声明每个栈的最低预期版本：

```markdown
## Versões de pacotes (lockadas para esta feature)

| Stack | Pacote | Versão mínima | Motivo |
|-------|--------|---------------|--------|
| dotnet | RabbitMQ.Client | 7.1.0 | API async IChannel; v6 sync IModel deprecated |
| dotnet | Npgsql | 8.0.4 | Compatível com PostgreSQL 16 do projeto |
```

编码智能体（dotnet-engineer、nodejs-engineer、java-engineer、python-engineer）必须遵循该确切版本（或最低兼容的更高版本）。**绝不要自主采用最新的主版本** —— TA-000 展示了一个风险：一个 API 使用 RMQ.Client v6 + Worker 使用 v7 导致了两个仓库之间的 API 表面不兼容。

如果 `contracts.md` 没有为片段使用的包声明版本，则应用以下回退顺序（审查员 H1 —— 改造友好）：

1. **目标仓库已声明该包**（`.csproj`、`package.json`、`pom.xml`、`pyproject.toml` 等）→ 采用仓库已在使用的主版本，尊重当前的最低要求。例如：仓库有 `RabbitMQ.Client 6.8.1` 且规范片段使用与 v6 兼容的 API → 保持 v6。
2. **目标仓库为空**（绿地项目）且片段的 API 需要特定的主版本 → 使用该主版本（例如：片段使用 `IChannel` async = RMQ.Client 7+）。
3. **以上两者都不适用**：停止并向开发者询问。

此顺序避免了编码智能体因改造旧规范（在 `## Versões de pacotes` 部分成为强制要求之前创建的）而受阻，同时为绿地项目保留保护。

## po_defaults 是具体值的真理来源 (po_defaults is Source of Truth for Concrete Values)（条目 22）

默认的项目级技术决策（Status 枚举、认证机制、分页默认值、重试策略等）存在于 **`projects.yml` → `po_defaults`** 中。这是 /osk-discover 和 /osk-spec 在询问 PO 之前参考的操作来源。

- `docs/architecture.md` **不**重复这些值。它只引用它们（例如 `"see projects.yml > po_defaults.auth"`）。
- /osk-init 生成带有引用部分的 `architecture.md`；它从不复制值。
- 当值发生变化时，在 `projects.yml` 中更改（单一触点）—— 消除漂移。

如果某个特性需要偏离默认值，在 PRD/brief 中记录原因。

## OSK 插件真理来源 (OSK Plugin Source-of-Truth)（NEW-029）

OSK 插件的技能、智能体和规则位于 **两个不同的位置**，角色明确：

| 路径 | 角色 | 谁编辑 |
|------|------|-----------|
| `cli/templates/agents/`（在 `open-spec-kit` 仓库中） | **真理来源** — 唯一允许编辑的地方 | 插件开发者 |
| `~/.claude/`（skills/、agents/、rules/） | **部署目标** — 由 Claude Code 和 Copilot 读取 | 由 `open-spec-kit update` 生成 |

**规则**：绝不要直接编辑 `~/.claude/`。那里会被下一次 `open-spec-kit update` 覆盖。始终在 `cli/templates/agents/` 中编辑并通过 `update` 传播。

### 传播 `cli/templates/agents/` → `~/.claude/`

```bash
# 编辑 cli/templates/agents/ 下的任何文件后
open-spec-kit update
```

**全局安装解析模式** —— 从 `cli/` 运行 `npm install -g .` 可能会创建指向开发树的符号链接（npm 7+ 默认在许多设置中；参见 `ls -la <npm-prefix>/node_modules/<package>` 并查找箭头目标）或复制文件（旧版 npm、某些配置、或通过 tarball 发布/安装）。行为很重要：

- **符号链接模式**：`TEMPLATES_DIR` 直接解析到开发树，因此 `cli/templates/agents/` 中的任何编辑都会被下一次 `open-spec-kit update` 拾取，无需重新安装。
- **复制模式**：`TEMPLATES_DIR` 解析到安装时捕获的 node_modules 快照。对开发树的编辑对 `update` **不可见**，直到您重新安装二进制文件：

```bash
cd cli && npm install -g .   # 从当前开发树刷新快照
open-spec-kit update         # 现在将开发树编辑传播到 ~/.claude/
```

如果不确定是哪种模式，运行下面的强制性更新后验证 —— 非空的 diff 是您处于复制模式需要重新安装的明确信号。

**强制性更新后验证** —— 确认开发树和部署已同步：

```bash
diff cli/templates/agents/skills/osk-hub/SKILL.md ~/.claude/skills/osk-hub/SKILL.md && echo "SKILL OK"
for f in cli/templates/agents/agents/*.agent.md; do
  name=$(basename "$f")
  diff "$f" ~/.claude/agents/$name > /dev/null && echo "$name OK" || echo "$name DIFFERS"
done
```

非空 diff = 同步不完整。典型原因：编辑开发树后忘记重新安装全局二进制文件。

## 约定式提交 (Conventional Commits) — 标题 ≤60 字符（NEW-021）

SKILL.md、智能体和模板中 **示例** 的提交标题必须 **≤60 字符**，而非 ≤72。

原因：Luiza Labs 公司级 commitlint 验证 `header-max-length: 72`（规范 50/72 规则），但在合并到 `main` 时 GitHub 会自动附加 PR 号（` (#1234)` = +8 字符）。70 字符的标题能通过本地提交检查，却在最终合并时失败。12 字符的余量覆盖了自动附加。

适用于：
- SKILL.md、`.agent.md` 智能体以及注入编码智能体的提示中的 `git commit -m "..."` 示例。
- 不适用于开发者/智能体在运行时生成的真实消息 —— 这些遵循每个项目配置的 ≤72 commitlint 限制。
- 定期审计：`grep -rE 'git commit -m "[^"]{61,}"' cli/templates/agents/` 必须返回零匹配。

## pending-confluence-updates.md 格式

当任何技能因 MCP 故障而无法应用 Confluence 更新时，它使用以下模式附加一个条目到 `docs/pending-confluence-updates.md`：

```markdown
## Entry {id} — {ISO timestamp}

- **skill**: osk-discover | osk-spec | osk-build | osk-hub
- **action**: update_page | add_label | create_page
- **page_id**: {Confluence page ID}
- **description**: {human-readable summary of what needs to be applied}
- **payload**: {JSON or Markdown content to apply}
- **status**: pending | applied | expired
- **created_at**: {ISO timestamp}
- **apply_before**: {ISO timestamp — typically created_at + 7 days}
- **applied_at**: {ISO timestamp or null}
```

`{id}` 是一个顺序整数：在写入时计算文件中已有的 `## Entry` 标题数量，然后使用计数 + 1。示例：如果文件已有条目 1 和 2，下一个条目是 `## Entry 3 — 2026-04-17T15:00:00Z`。

状态转换：
- `pending` → `applied`：当技能在重试时通过 MCP 成功应用更新
- `pending` → `expired`：当 `apply_before` 已过期且更新从未被应用（osk-hub 阶段 0 标记这些）
- 绝不要删除条目 —— 作为历史保留（已过期条目是无害的）

每当 MCP 可用时，该文件在 osk-hub 阶段 0 中被检查；重试失败的条目保持 `pending` 状态，并在下一次阶段 0 中再次重试。

## links.md PR 表格式

```markdown
## PRs

| Repo | Branch | MR/PR | Status | Pre-review | Merge commit | Merged at |
|------|--------|-------|--------|------------|--------------|-----------|
```

状态值：`open`、`em-review`、`merged`、`closed`。由 /osk-spec 创建为空；/osk-hub 在阶段 3 中以 `em-review` 状态写入 PR URL；/osk-build 在阶段 D.1 中更新为 `merged` 状态（必须 APPEND/UPDATE 现有行，而不是覆盖表）。

Pre-review 值：`PASS (N iter)` | `SKIPPED (no agent)` | `FALLBACK (post-PR, Copilot mode)` | blank（尚未审查）

合并提交 / 合并时间 (NEW-014)：由 /osk-build 在阶段 D.1 中通过 `gh pr view {number} --json mergeCommit,mergedAt` 填充。`merge_commit` 是短 SHA（7 字符）；`merged_at` 是 ISO-8601（例如：`2026-04-21T15:30:00Z`）。对于 `open`/`em-review` 状态的 PR 保持空白。支持发布后审计，并将符合性报告锚定到确切的合并提交。

## 可执行经验教训模式 (Executable Lesson Schema)（NEW-027）

完整的可执行经验教训模式 —— `detect:` 前置内容块、字段表、code-reviewer 如何使用它（阶段 C.5.5）、规则 42 的强制执行以及工作示例 —— 位于 `docs/reference/lesson-schema.md` 中。它由 code-reviewer 和 `open-spec-kit validate`（规则 42）按需查阅，并非在每个会话中都使用，因此它是一个参考文档，而非总是加载的规则内容（ADR-006）。
