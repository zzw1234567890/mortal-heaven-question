
# 规则：OSK 核心技能之外的主动智能体委派 (Proactive Agent Delegation Outside OSK Skills)

当用户提出的任务对应到专门的 OSK 智能体（**在**核心技能 `/osk-init`、`/osk-discover`、`/osk-spec`、`/osk-build`、`/osk-hub` **之外**）时，主动提供或调用对应的智能体，而不是使用主模型手动编写制品。

此规则防止了促使此规则建立的静默失败模式："用户在自由聊天中要求 ADR → 主 LLM 写了约 350 行的独白，没有检查清单或对抗性审查"（审计 2026-05-16，差距 2.1）。

## 任务 → 智能体映射表 (Task → Agent Map)

| 用户要求/正在处理的内容 | 需委派的智能体 | 调用方式 |
|--------------------------|-----------------------|---------------|
| ADR（架构决策记录）、DD（设计文档）、RFC | `design-doc` | "需要委派给 `design-doc` 吗？它内置了 MADR 模板 + 检查清单。" 或当明确的 `design-doc ADR-NNN` 模式出现时自动调用 |
| PR/MR 审查（链接 `https://github.com/...` 或 `https://gitlab.com/.../merge_requests/...`） | `code-reviewer` | "要我在 PR/MR 上运行 `code-reviewer` 吗？它会并行进行安全 + 架构 + 性能审查。" |
| 对已编写的 ADR/DD 进行对抗性审查（决策质量，而非代码） | `code-reviewer` 以 **ADR 模式**（见 `code-reviewer.agent.md` §"When invoked for ADR/DD review"） | "我可以在 `{path}` 上运行 `code-reviewer adr_review: true` 吗？在标记为"已接受"之前进行 7 项对抗性检查。" |
| 技术选型（数据库、框架、库、基础设施选择） | `principal-engineer` | "需要我调用 `principal-engineer` 来做这个选择吗？它会用客观标准比较权衡。" |
| 安全分析（STRIDE、威胁模型、WAF、密钥轮换、SAST/DAST 审查） | `secops-agent` | "要用 `secops-agent` 吗？它会进行 STRIDE + OWASP 交叉检查。" |
| 规范质量审计（brief/scenarios/contracts/tasks） | `spec-auditor`（在 `/osk-spec` 流程内时） | 已在 `/osk-spec` 中集成 — 除非在技能之外审查现有规范，否则无需手动提供 |
| 测试策略 / E2E / 契约测试 / 质量关卡 | `qa-engineer` | "要升级到 `qa-engineer` 吗？它会制定测试计划 + CI 关卡。" |
| .NET / C# 后端 | `dotnet-engineer` | "要委派给 `dotnet-engineer` 吗？" |
| Node.js / TypeScript 后端 | `nodejs-engineer` | 同上 |
| Java / Spring 后端 | `java-engineer` | 同上 |
| Python / FastAPI 后端 | `python-engineer` | 同上 |
| 前端（React、Vite、A11y、设计系统） | `frontend-expert` | 同上 |
| 移动端（React Native、Kotlin、Swift） | `mobile-engineer` | 同上 |
| Shell 运维、kubectl、docker、CI/CD 诊断 | `terminal-operator` | 同上 |

## 委派模式 — 主动提供 vs 自动调用 (Delegation Modes — Proactive Offer vs Auto-Invoke)

**自动调用（无需询问）** 当用户提示明确无误时：
- 包含明确的智能体名称："使用 `design-doc`……"、"在……上运行 `code-reviewer`"、"调用 `principal-engineer`……"。
- 包含与智能体一一对应的字面制品路径："审查 `docs/decisions/ADR-008.md`" → `code-reviewer` ADR 模式。

**主动提供（询问一次，根据回答行动）** 当意图隐含时：
- "起草关于 X 的 ADR" → "要委派给 `design-doc`（MADR 模板 + 对抗性检查）吗？(是/否)"。
- "看看这个 PR：{URL}" → "要在这个 PR 上运行 `code-reviewer` 吗？(是/否)"。
- "我决定用 Postgres 而不是 MongoDB，因为……" → "需要我通过 `design-doc` 将其实现为 ADR 吗？它能确保 rationale + 替代方案的明确记录。"

**完全跳过委派** 当：
- 用户明确说"不委派"或"直接回答"。
- 任务属于简单的对话性质（澄清问题、意见、"X 是如何工作的？"）。
- 用户已经开始手动编写制品，只是寻求零散帮助。

## 决策的强制性接受前对抗性审查 (Mandatory Pre-Acceptance Adversarial Review for Decisions)

每个在 `/osk-spec` 流程 **之外** 编写的架构决策（ADR/DD/RFC）在将其状态从 `proposed` 翻转为 `accepted` 之前，必须通过 `code-reviewer` 的 **ADR 模式**。这相当于 `/osk-spec` 的 `spec-auditor` 关卡，但用于自由聊天的决策。

协议：
1. 用户（或 `design-doc`）编写决策文件。
2. 在将状态翻转为 `accepted` 之前，调用 `code-reviewer adr_review: true`。
3. 处理发现结果：BLOCKER 必须解决；HIGH 需要在 ADR 中明确确认（如有意为之则移至"已接受的风险 (Riscos aceitos)"）；LOW 为参考信息。
4. 如果在第一轮中 BLOCKER 数量 > 0，则在修复后重新调用 `code-reviewer`。
5. 然后才能将状态翻转为 `accepted`。

如果用户希望跳过对抗性关卡（对于低风险决策可接受，如"使用 2 个空格缩进"），他们必须明确说明。不要静默跳过。

## 此规则存在的原因 (Why This Rule Exists)

审计 `docs/auditoria-qualidade-artefatos-2026-05-16.md` 的差距 2.1 记录了确切的失败模式：`design-doc.agent.md` 的 `disable-model-invocation: false`，意味着它可以被调用，但没有规则告诉主 LLM 调用它。结果：`tms-finance-bills-spec` 中的 ADR-008 由主 LLM 手动编写了约 350 行，缺少 `design-doc` 自第 105 行起内置的 MADR 检查清单。"驾驶员 (motorista)" 角色被遗忘，仅由人工手动发现 — 而 `code-reviewer` 的 ADR 模式本来可以在同一轮中捕获它。

此规则弥补了两个差距：
- 差距 2.1：上文的主动委派表。
- 差距 2.4：接受前的强制性对抗性审查。

## 相关制品 (Related Artifacts)

- `~/.claude/agents/design-doc.agent.md` — ADR/DD/RFC 模板 + MADR 格式 + 大小预算
- `~/.claude/agents/code-reviewer.agent.md` §"When invoked for ADR/DD review" — 对抗性检查协议
- `~/.claude/rules/hub_structure.instructions.md` §"Artifact hierarchy" — 此处强制执行的大小预算
- `~/.claude/rules/ownership.instructions.md` — RACI：谁拥有什么制品
