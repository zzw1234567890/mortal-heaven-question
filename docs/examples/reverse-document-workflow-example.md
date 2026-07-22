
# 逆向文档工作流示例

## 场景
开发者构建了一个可用的技能树系统但从未写过设计文档。
代码存在于 `src/gameplay/skills/`，但 `design/gdd/` 下没有 skill-system.md。

---

## 会话记录

**User:**
```
I have a working skill tree system in src/gameplay/skills/ with about 1200 lines
of code. I never wrote a design doc. Can we create one from the implementation?
```

**Game-Designer (reads code, analyzes):**
```
I've analyzed your skill tree implementation. Here's what I found:

STRUCTURE:
- 3 skill trees: Combat, Survival, Tech
- 5 tiers per tree (unlock via level + prerequisites)
- Total 45 skills (15 per tree)
- Cost: skill points (1 per level, can respec for gold)

MECHANICS:
- Passive skills (stat bonuses)
- Active skills (abilities with cooldowns)
- Synergy bonuses (cross-tree unlocks at tier 4+)

IMPLEMENTATION DETAILS:
- Data-driven (JSON files in assets/data/skills/)
- Save-compatible (skill state serialized)
- UI shows locked/unlocked/available states

QUESTIONS before I draft the design doc:

1. **Design Intent:** Was the 3-tree structure meant to represent player archetypes
   (fighter/survivor/engineer) or playstyle flexibility?

2. **Respec Cost:** Respec costs gold - is this meant to:
   - Discourage frequent respecs (commitment to builds)?
   - Create a gold sink (economy balance)?
   - Or should it be free (experimentation encouraged)?

3. **Synergy System:** Cross-tree synergies appear at tier 4. Was this:
   - Intentional (reward hybrid builds late-game)?
   - Or emergent (accidentally creates hybrid meta)?

4. **Balance Philosophy:** I see some skills are clearly better (tier-5 passive
   is +50% damage). Is this:
   - Power fantasy (late-game should feel OP)?
   - Or unbalanced (needs tuning)?
```

**User:**
```
Good questions! Here's the intent:

1. Yes, the 3 trees are archetypes but I want flexibility
2. Respec should be cheap - I want experimentation
3. Synergies were intentional - hybrid builds are a feature
4. Yeah, tier 5 is meant to be powerful, but +50% might be too much
```

**Game-Designer:**
```
Perfect, that clarifies the vision. Let me draft the design doc:

[Shows draft of design/gdd/skill-system.md]

SECTIONS:
1. Overview (3-tree system, hybrid-friendly, respec-encouraged)
2. Design Pillars:
   - Archetype clarity (each tree has identity)
   - Build flexibility (no lock-in, cheap respec)
   - Synergy rewards (cross-tree combinations viable)
3. Detailed Design (tree structure, unlock rules, respec)
4. Balance Framework (tier power curve, synergy limits)
5. Edge Cases (respec during combat? max skills? cap?)
6. Dependencies (UI, save system, tutorial)
7. Acceptance Criteria (all trees viable, 10+ hybrid builds, clear tooltips)
8. Open Questions:
   - Should respec cost scale with level or stay flat?
   - Tier 5 damage bonus: tune to +30% or keep +50%?

**May I write this to design/gdd/skill-system.md?**
```

**User:**
```
Yes, write it. But let's tune tier 5 to +30% and make respec cost scale.
```

**Game-Designer:**
```
✅ Written to design/gdd/skill-system.md
✅ Marked as [REVERSE-DOCUMENTED FROM IMPLEMENTATION]
✅ Added TODO: Update tier-5 passive to +30% in assets/data/skills/combat-tree.json
✅ Added TODO: Implement scaling respec cost formula

Next steps:
- Run /balance-check to validate skill tree progression curve?
- Create ADR documenting why 3 trees instead of 5?
- Update tutorial to explain hybrid synergies?
```

---

## 关键观察

1. **代理提出了澄清问题** — 不只是描述代码
2. **将意图与实现分离** — 用户纠正了"意外"的不平衡
3. **设计文档捕捉"为什么"** — 不只是"代码做什么"
4. **识别出缺失部分** — 代码中未覆盖的边界情况
5. **标记后续工作** — 平衡调整、ADR、教程

## 结果

设计文档现在存在并**与现实匹配**，同时捕捉了**预期愿景**。未来的变更将引用此文档，新团队成员能理解决策背后的*为什么*。
