
# CCGS 技能测试框架 (CCGS Skill Testing Framework)

面向 **Claude Code Game Studios** 框架的质量保障基础设施。
测试技能和代理本身——而非使用它们构建的任何游戏。

> **本文件夹是自包含且可选的。**
> 使用 CCGS 的游戏开发者不需要它。要完全删除它：
> `rm -rf "CCGS Skill Testing Framework"` —— `.claude/` 中没有任何内容依赖它。

---

## 内部结构

```
CCGS Skill Testing Framework/
├── README.md              ← 你在这里
├── CLAUDE.md              ← 告诉 Claude 如何使用本框架
├── catalog.yaml           ← 主注册表：全部 73 个技能 + 49 个代理，覆盖跟踪
├── quality-rubric.md      ← 按类别划分的通过/失败度量标准，供 /skill-test category 使用
│
├── skills/                ← 技能的行为规格文件（每个技能一个）
│   ├── gate/              ← 关卡类别规格
│   ├── review/            ← 评审类别规格
│   ├── authoring/         ← 创作类别规格
│   ├── readiness/         ← 就绪类别规格
│   ├── pipeline/          ← 管线类别规格
│   ├── analysis/          ← 分析类别规格
│   ├── team/              ← 团队类别规格
│   ├── sprint/            ← 冲刺类别规格
│   └── utility/           ← 工具类别规格
│
├── agents/                ← 代理的行为规格文件（每个代理一个）
│   ├── directors/         ← creative-director, technical-director, producer, art-director
│   ├── leads/             ← lead-programmer, narrative-director, audio-director 等
│   ├── specialists/       ← 引擎/代码/着色器/UI 专家
│   ├── godot/             ← Godot 特定专家
│   ├── unity/             ← Unity 特定专家
│   ├── unreal/            ← Unreal 特定专家
│   ├── operations/        ← QA、运营、发布、本地化等
│   └── creative/          ← writer、world-builder、game-designer 等
│
├── templates/             ← 用于编写新规格的文件模板
│   ├── skill-test-spec.md ← 技能行为规格模板
│   └── agent-test-spec.md ← 代理行为规格模板
│
└── results/               ← 测试运行输出（由 /skill-test spec 写入，已 gitignore）
```

---

## 如何使用

所有测试由框架中已有的两个技能驱动：

### 检查结构合规性

```
/skill-test static [skill-name]     # 检查一个技能（7 项检查）
/skill-test static all              # 检查全部 73 个技能
```

### 运行行为规格测试

```
/skill-test spec gate-check         # 根据书面规格评估技能
/skill-test spec design-review
```

### 按类别评分标准检查

```
/skill-test category gate-check     # 根据其类别度量评估一个技能
/skill-test category all            # 对所有分类技能运行评分标准检查
```

### 查看完整覆盖情况

```
/skill-test audit                   # 技能 + 代理：是否有规格、最后测试时间、结果
```

### 改进一个失败的技能

```
/skill-improve gate-check           # 测试 → 诊断 → 提出修复 → 重新测试循环
```

---

## 技能类别 (Skill categories)

| 类别 | 技能 | 关键度量 |
|----------|--------|-------------|
| `gate` | gate-check | 读取评审模式，full/lean/solo 总监面板，无自动推进 |
| `review` | design-review, architecture-review, review-all-gdds | 只读，8 章节检查，正确判定 |
| `authoring` | design-system, quick-design, art-bible, create-architecture, … | 逐章节 May-I-write，骨架优先 |
| `readiness` | story-readiness, story-done | 暴露阻塞项，full 模式下的总监关卡 |
| `pipeline` | create-epics, create-stories, dev-story, map-systems, … | 上游依赖检查，交接路径清晰 |
| `analysis` | consistency-check, balance-check, code-review, tech-debt, … | 只读报告，判定关键词，无写入 |
| `team` | team-combat, team-narrative, team-audio, … | 所有必需代理已生成，阻塞项已上报 |
| `sprint` | sprint-plan, sprint-status, milestone-review, … | 读取冲刺数据，状态关键词存在 |
| `utility` | start, adopt, hotfix, localize, setup-engine, … | 通过静态检查 |

---

## 代理层级 (Agent tiers)

| 层级 | 代理 |
|------|--------|
| `directors` | creative-director, technical-director, producer, art-director |
| `leads` | lead-programmer, narrative-director, audio-director, ux-designer, qa-lead, release-manager, localization-lead |
| `specialists` | gameplay-programmer, engine-programmer, ui-programmer, tools-programmer, network-programmer, ai-programmer, level-designer, sound-designer, technical-artist |
| `godot` | godot-specialist, godot-gdscript-specialist, godot-csharp-specialist, godot-shader-specialist, godot-gdextension-specialist |
| `unity` | unity-specialist, unity-ui-specialist, unity-shader-specialist, unity-dots-specialist, unity-addressables-specialist |
| `unreal` | unreal-specialist, ue-gas-specialist, ue-replication-specialist, ue-umg-specialist, ue-blueprint-specialist |
| `operations` | devops-engineer, security-engineer, performance-analyst, analytics-engineer, community-manager |
| `creative` | writer, world-builder, game-designer, economy-designer, systems-designer, prototyper |

---

## 更新目录 (catalog)

`catalog.yaml` 跟踪每个技能和代理的测试覆盖情况。运行测试后：

- `/skill-test spec [name]` 会提议更新 `last_spec` 和 `last_spec_result`
- `/skill-test category [name]` 会提议更新 `last_category` 和 `last_category_result`
- `last_static` 和 `last_static_result` 手动更新或通过 `/skill-improve` 更新

---

## 编写新的规格

1. 在 `templates/skill-test-spec.md` 找到规格模板
2. 将其复制到 `skills/[category]/[skill-name].md`
3. 将 `catalog.yaml` 中的 `spec:` 字段更新为指向新文件
4. 运行 `/skill-test spec [skill-name]` 进行验证

---

## 移除本框架

本文件夹与主项目没有任何钩子。要移除：

```bash
rm -rf "CCGS Skill Testing Framework"
```

技能 `/skill-test` 和 `/skill-improve` 仍将继续运行——它们只会
报告 `catalog.yaml` 缺失，并建议运行 `/skill-test audit` 来
初始化它。
