
# CCGS 技能测试框架 —— Claude 使用说明

本文件夹是 Claude Code Game Studios 技能/代理框架的质量保障层。
它是自包含的，与任何游戏项目相互独立。

## 关键文件

| 文件 | 用途 |
|------|---------|
| `catalog.yaml` | 全部 73 个技能和 49 个代理的主注册表。包含类别、规格路径和最近测试跟踪字段。运行任何测试命令时始终先读取它。 |
| `quality-rubric.md` | 按类别划分的通过/失败度量标准。运行 `/skill-test category` 时，阅读与该技能类别匹配的 `###` 小节。 |
| `skills/[category]/[name].md` | 技能的行为规格 —— 5 个测试用例 + 协议合规断言。 |
| `agents/[tier]/[name].md` | 代理的行为规格 —— 5 个测试用例 + 协议合规断言。 |
| `templates/skill-test-spec.md` | 编写新技能规格文件的模板。 |
| `templates/agent-test-spec.md` | 编写新代理规格文件的模板。 |
| `results/` | 由 `/skill-test spec` 在保存结果时写入。已被 gitignore。 |

## 路径约定

- 技能规格：`CCGS Skill Testing Framework/skills/[category]/[name].md`
- 代理规格：`CCGS Skill Testing Framework/agents/[tier]/[name].md`
- 目录：`CCGS Skill Testing Framework/catalog.yaml`
- 评分标准：`CCGS Skill Testing Framework/quality-rubric.md`

`catalog.yaml` 中的 `spec:` 字段是每个技能/代理规格的权威路径。
始终读取它，不要猜测路径。

## 技能类别

```
gate        → gate-check
review      → design-review, architecture-review, review-all-gdds
authoring   → design-system, quick-design, architecture-decision, art-bible,
              create-architecture, ux-design, ux-review
readiness   → story-readiness, story-done
pipeline    → create-epics, create-stories, dev-story, create-control-manifest,
              propagate-design-change, map-systems
analysis    → consistency-check, balance-check, content-audit, code-review,
              tech-debt, scope-check, estimate, perf-profile, asset-audit,
              security-audit, test-evidence-review, test-flakiness
team        → team-combat, team-narrative, team-audio, team-level, team-ui,
              team-qa, team-release, team-polish, team-live-ops
sprint      → sprint-plan, sprint-status, milestone-review, retrospective,
              changelog, patch-notes
utility     → all remaining skills
```

## 代理层级

```
directors   → creative-director, technical-director, producer, art-director
leads       → lead-programmer, narrative-director, audio-director, ux-designer,
              qa-lead, release-manager, localization-lead
specialists → gameplay-programmer, engine-programmer, ui-programmer,
              tools-programmer, network-programmer, ai-programmer,
              level-designer, sound-designer, technical-artist
godot       → godot-specialist, godot-gdscript-specialist, godot-csharp-specialist,
              godot-shader-specialist, godot-gdextension-specialist
unity       → unity-specialist, unity-ui-specialist, unity-shader-specialist,
              unity-dots-specialist, unity-addressables-specialist
unreal      → unreal-specialist, ue-gas-specialist, ue-replication-specialist,
              ue-umg-specialist, ue-blueprint-specialist
operations  → devops-engineer, security-engineer, performance-analyst,
              analytics-engineer, community-manager
creative    → writer, world-builder, game-designer, economy-designer,
              systems-designer, prototyper
```

## 测试技能的工作流程

1. 读取 `catalog.yaml` 获取该技能的 `spec:` 路径和 `category:`
2. 读取 `.claude/skills/[name]/SKILL.md` 中的技能
3. 读取 `spec:` 路径处的规格
4. 逐用例评估断言
5. 提议将结果写入 `results/` 并更新 `catalog.yaml`

## 改进技能的工作流程

使用 `/skill-improve [name]`。它处理完整闭环：
测试 → 诊断 → 提出修复 → 重写 → 复测 → 保留或回退。

## 规格有效性说明

本文件夹中的规格描述的是**当前行为**，而非理想行为。它们是通过阅读技能
编写的，因此可能固化了 bug。当某个技能在实际中表现异常时，先修正技能，
然后更新规格以匹配修正后的行为。将规格失败视为"这需要调查"，而不是
"技能肯定有错"。

## 本文件夹可以删除

`.claude/` 中没有任何内容从这里导入。删除本文件夹对 CCGS 技能或代理
本身没有任何影响。`/skill-test` 和 `/skill-improve` 会报告 `catalog.yaml`
缺失，并引导用户进行初始化。
