
# 技能流程图

跨 7 个开发阶段展示技能如何串联的可视化地图。
这些图展示每个技能前后运行什么，以及在它们之间流动什么工件。

---

## 完整流水线概览（从零到发布）

```
PHASE 1: CONCEPT
  /start ──────────────────────────────────────────────────────► routes to A/B/C/D
  /brainstorm ──────────────────────────────────────────────────► design/gdd/game-concept.md
  /setup-engine ────────────────────────────────────────────────► CLAUDE.md + technical-preferences.md
  /prototype [core-mechanic] ───────────────────────────────────► prototypes/[name]-concept/REPORT.md
        │ PROCEED                                                  (validate idea BEFORE writing GDDs)
        ▼
  /design-review [game-concept.md] ────────────────────────────► concept validated
  /gate-check ─────────────────────────────────────────────────► PASS → advance to systems-design
        │
        ▼
PHASE 2: SYSTEMS DESIGN
  /map-systems ────────────────────────────────────────────────► design/gdd/systems-index.md
        │
        ▼ (for each system, in dependency order)
  /design-system [name] ──────────────────────────────────────► design/gdd/[system].md
  /design-review [system].md ─────────────────────────────────► per-GDD review comments
        │
        ▼ (after all MVP GDDs done)
  /review-all-gdds ────────────────────────────────────────────► design/gdd/gdd-cross-review-[date].md
  /gate-check ─────────────────────────────────────────────────► PASS → advance to technical-setup
        │
        ▼
PHASE 3: TECHNICAL SETUP
  /create-architecture ────────────────────────────────────────► docs/architecture/master.md
  /architecture-decision (×N) ─────────────────────────────────► docs/architecture/[adr-nnn].md
  /architecture-review ────────────────────────────────────────► review report + docs/architecture/tr-registry.yaml
  /create-control-manifest ────────────────────────────────────► docs/architecture/control-manifest.md
  /gate-check ─────────────────────────────────────────────────► PASS → advance to pre-production
        │
        ▼
PHASE 4: PRE-PRODUCTION
  [UX — before epics, so specs exist when stories are written]
  /ux-design [screen/hud/patterns] ────────────────────────────► design/ux/*.md
  /ux-review ──────────────────────────────────────────────────► UX specs approved (HARD gate for /team-ui)

  [Test infrastructure — scaffold before stories reference tests]
  /test-setup ─────────────────────────────────────────────────► test framework + CI/CD pipeline
  /test-helpers ───────────────────────────────────────────────► tests/helpers/[engine-specific].gd

  [Vertical slice — before epics, validate full game loop]
  /vertical-slice ─────────────────────────────────────────────► prototypes/[name]-vertical-slice/REPORT.md
  /playtest-report ────────────────────────────────────────────► production/playtests/

  [Stories + sprint plan — only after vertical slice PROCEEDS]
  /create-epics [layer] ───────────────────────────────────────► production/epics/*/EPIC.md
  /create-stories [epic-slug] ─────────────────────────────────► production/epics/*/story-*.md
  /sprint-plan new ────────────────────────────────────────────► production/sprints/sprint-01.md
  /gate-check ─────────────────────────────────────────────────► PASS → advance to production
        │
        ▼
PHASE 5: PRODUCTION (repeating sprint loop)
  /sprint-status ──────────────────────────────────────────────► sprint snapshot
  /story-readiness [story] ────────────────────────────────────► story validated READY
        │
        ▼ (pick up and implement)
  /dev-story [story] ──────────────────────────────────────────► routes to correct programmer agent
        │
        ▼ (during implementation, as needed)
  /code-review ────────────────────────────────────────────────► code review report
  /scope-check ────────────────────────────────────────────────► scope creep detected / clear
  /content-audit ──────────────────────────────────────────────► GDD content gaps identified
  /bug-report ─────────────────────────────────────────────────► production/qa/bugs/bug-NNN.md
  /bug-triage ─────────────────────────────────────────────────► bugs re-prioritized + assigned

  [Team skills for feature areas — spawn when working a full feature]
  /team-combat / /team-narrative / /team-ui / /team-level / /team-audio

  [QA cycle per sprint]
  /qa-plan ────────────────────────────────────────────────────► production/qa/qa-plan-sprint-NN.md
  /smoke-check ────────────────────────────────────────────────► smoke test gate (PASS/FAIL)
  /regression-suite ───────────────────────────────────────────► coverage gaps + missing regression tests
  /test-evidence-review ───────────────────────────────────────► evidence quality report
  /test-flakiness ─────────────────────────────────────────────► flaky test report
        │
        ▼
  /story-done [story] ─────────────────────────────────────────► story closed + next surfaced
  /sprint-plan [next] ─────────────────────────────────────────► next sprint
        │
        ▼ (after Production milestone)
  /milestone-review ───────────────────────────────────────────► milestone report
  /gate-check ─────────────────────────────────────────────────► PASS → advance to polish
        │
        ▼
PHASE 6: POLISH
  /perf-profile ───────────────────────────────────────────────► perf report + fixes
  /balance-check ──────────────────────────────────────────────► balance report + fixes
  /asset-audit ────────────────────────────────────────────────► asset compliance report
  /tech-debt ──────────────────────────────────────────────────► docs/tech-debt-register.md
  /soak-test ──────────────────────────────────────────────────► soak test protocol + results
  /localize ───────────────────────────────────────────────────► localization readiness report
  /team-polish ────────────────────────────────────────────────► polish sprint orchestrated
  /team-qa ────────────────────────────────────────────────────► full QA cycle sign-off
  /gate-check ─────────────────────────────────────────────────► PASS → advance to release
        │
        ▼
PHASE 7: RELEASE
  /launch-checklist ───────────────────────────────────────────► launch readiness report
  /release-checklist ──────────────────────────────────────────► platform-specific checklist
  /changelog ──────────────────────────────────────────────────► CHANGELOG.md
  /patch-notes ────────────────────────────────────────────────► player-facing notes
  /team-release ───────────────────────────────────────────────► release pipeline orchestrated
        │
        ▼ (post-launch, ongoing)
  /hotfix ─────────────────────────────────────────────────────► emergency fix with audit trail
  /team-live-ops ──────────────────────────────────────────────► live-ops content plan
```

---

## 技能链：/design-system 详解

单个 GDD 如何被编写、评审并交接给架构：

```
systems-index.md (input)
game-concept.md (input)
upstream GDDs (input, if any)
        │
        ▼
/design-system [name]
        │
        ├── Pre-check: feasibility table + engine risk flags
        │
        ├── Section cycle × 8:
        │     question → options → decision → draft → approval → WRITE
        │     [each section written to file immediately after approval]
        │
        └── Output: design/gdd/[system].md (complete, all 8 sections)
                │
                ▼
        /design-review design/gdd/[system].md
                │
                ├── APPROVED → mark DONE in systems-index, proceed to next system
                ├── NEEDS REVISION → agent shows specific issues, re-enter section cycle
                └── MAJOR REVISION → significant redesign needed before next system
                        │
                        ▼ (after all MVP GDDs + cross-review)
                /review-all-gdds
                        │
                        └── Output: gdd-cross-review-[date].md
```

---

## 技能链：UX / UI 流水线详解

UX 规格在阶段 4（Pre-Production）编写，在 epic 之前，以便 story 验收标准可引用具体 UX 工件。

```
design/gdd/*.md (UI/UX requirements extracted)
design/player-journey.md (emotional arc, if authored)
        │
        ▼
/ux-design hud              → design/ux/hud.md
/ux-design screen [name]    → design/ux/screens/[name].md
/ux-design patterns         → design/ux/interaction-patterns.md
        │
        ▼
/ux-review design/ux/
        │
        ├── APPROVED → UX specs ready, proceed to /create-epics
        ├── NEEDS REVISION → blocking issues listed → fix → re-run review
        └── MAJOR REVISION → fundamental UX problems → redesign before epics
                │
                ▼ (after APPROVED — in Phase 5 when implementing UI features)
        /team-ui
                │
                ├── Phase 1: /ux-design (if any specs still missing) + /ux-review
                ├── Phase 2: visual design (art-director)
                ├── Phase 3: layout implementation (ui-programmer)
                ├── Phase 4: accessibility audit (accessibility-specialist)
                └── Phase 5: final review

Note: /ux-design and /ux-review belong in Phase 4 (Pre-Production).
      /team-ui belongs in Phase 5 (Production) when a UI feature is being built.
```

---

## 技能链：Dev Story 流程详解

一个 story 如何从待办走向关闭：

```
/story-readiness [story]
        │
        ├── READY → Status: ready-for-dev → pick up for implementation
        ├── NEEDS WORK → agent shows specific gaps → resolve → re-run readiness
        └── BLOCKED → ADR still Proposed, or upstream story incomplete
                │
                ▼ (after READY)
        /dev-story [story]
                │
                ├── Reads: story file, linked GDD requirement, ADR decisions, control manifest
                ├── Routes to: gameplay-programmer / engine-programmer / ui-programmer / etc.
                │
                └── Implementation begins
                        │
                        ▼ (optional, during/after implementation)
                /code-review          → architectural review of changeset
                /scope-check          → verify no scope creep vs. original story criteria
                /test-evidence-review → validate test files and manual evidence quality
                        │
                        ▼
                /story-done [story]
                        │
                        ├── COMPLETE → Status: Complete, sprint-status.yaml updated, next story surfaced
                        ├── COMPLETE WITH NOTES → complete but some criteria deferred (logged)
                        └── BLOCKED → acceptance criteria cannot be verified → investigate blocker
```

---

## 技能链：Story 生命周期（从待办到关闭）

一个 story 如何从待办走向关闭（概览）：

```
/create-epics [layer]
        │
        └── Output: production/epics/[slug]/EPIC.md
                │
                ▼
        /create-stories [epic-slug]
                │
                └── Output: production/epics/[slug]/story-NNN-[slug].md
                            (Status: Ready or Blocked if ADR is Proposed)
                │
                ▼
        /story-readiness [story]
                │
                ├── READY → /dev-story → implement → /story-done
                ├── NEEDS WORK → resolve gaps → re-run
                └── BLOCKED → fix upstream dependency first
```

---

## 技能链：QA 流水线详解

```
[Phase 4 — one-time infrastructure setup]
/test-setup ────────────────────────────────────────────────────► test framework scaffolded + CI/CD wired
/test-helpers ──────────────────────────────────────────────────► tests/helpers/[engine].gd (GDUnit4, NUnit, etc.)

[Phase 5 — per-sprint QA cycle]
/qa-plan [sprint or feature]
        │
        ├── Reads: story files, GDDs, acceptance criteria
        ├── Classifies each story by test type:
        │     Logic → automated unit test (BLOCKING)
        │     Integration → integration test or documented playtest (BLOCKING)
        │     Visual/Feel → screenshot + lead sign-off (ADVISORY)
        │     UI → manual walkthrough or interaction test (ADVISORY)
        │     Config/Data → smoke check (ADVISORY)
        └── Output: production/qa/qa-plan-sprint-NN.md
                │
                ▼
        /smoke-check
                │
                ├── PASS → QA hand-off cleared
                └── FAIL → block sprint close → fix critical paths first
                        │
                        ▼
                /regression-suite
                        │
                        └── Coverage gaps + list of fixed bugs without regression tests
                                │
                                ▼
                        /test-evidence-review
                                │
                                └── Validates evidence quality, not just existence
                                        │
                                        ▼ (if CI run history available)
                        /test-flakiness
                                │
                                └── Flaky test report + fix recommendations

[Phase 6 — extended stability testing]
/soak-test ─────────────────────────────────────────────────────► soak test protocol + observed results
/team-qa ───────────────────────────────────────────────────────► full QA cycle sign-off for release gate

[Ongoing — bug management]
/bug-report ────────────────────────────────────────────────────► production/qa/bugs/bug-NNN.md
/bug-triage ────────────────────────────────────────────────────► open bugs re-prioritized + assigned

[Meta — harness validation]
/skill-test [lint|spec|catalog] ────────────────────────────────► skill file structural + behavioral check
```

---

## Brownfield 接入流程

对于有现有工作的项目（使用 `/start` 选项 D 或直接运行）：

```
/project-stage-detect    → stage detection report
        │
        ▼
/adopt
        │
        ├── Phase 1: detect what exists
        ├── Phase 2: FORMAT audit (not just existence)
        ├── Phase 3: classify gaps (BLOCKING / HIGH / MEDIUM / LOW)
        ├── Phase 4: ordered migration plan
        ├── Phase 5: write docs/adoption-plan-[date].md
        └── Phase 6: fix most urgent gap inline (optional)
                │
                ▼
        /design-system retrofit [path]    → fills missing GDD sections
        /architecture-decision retrofit [path] → fills missing ADR sections
        /gate-check                       → where are you in the pipeline?
```

---

## 如何阅读这些图

| 符号 | 含义 |
|--------|---------|
| `──►` | 产出此工件 |
| `│ ▼` | 流入下一步 |
| `├──` | 分支（多种可能结果） |
| `×N` | 运行 N 次（每个系统、story 等） |
| `(input)` | 被该技能读取但非在此产出 |
| `[optional]` | 非闸门通过所必需 |
| `WRITE`（大写） | 文件立即写入磁盘 |

---

## 常见入口

| 你处于何处 | 运行此命令 |
|---------------|---------|
| 全新开始，无想法 | `/start` → `/brainstorm` |
| 有概念，无引擎 | `/setup-engine` |
| 有概念 + 引擎 | `/map-systems` |
| 系统设计中 | `/design-system [next system]` 或 `/map-systems next` |
| 所有 GDD 完成 | `/review-all-gdds` → `/gate-check` |
| 技术设置中 | `/create-architecture` → `/architecture-decision` |
| 开始 UX 设计 | `/ux-design screen [name]` 或 `/ux-design hud` |
| 脚手架测试 | `/test-setup` → `/test-helpers` |
| 有 story，准备编码 | `/story-readiness [story]` → `/dev-story [story]` |
| Story 完成 | `/story-done [story]` |
| 为冲刺运行 QA | `/qa-plan` → `/smoke-check` → `/regression-suite` |
| Bug 待办需整理 | `/bug-triage` |
| 扩展稳定性测试 | `/soak-test` |
| 不确定 | `/help` |
| 现有项目 | `/adopt` |
