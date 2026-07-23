# 资源系统 — 审查日志

## Review — 2026-07-23 — Verdict: MAJOR REVISION NEEDED → 已修订
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 4 (全部已修复) | Recommended: 6 (全部已修复)
Summary: 首次审查发现两个拆解公式 bug（F1: 满级暗金实际值 3900 非 2095，F2: level 偏移多算 5%）、境界差额惩罚跨文档矛盾（乘法 vs 加法）、铭刻软上限三文档不一致、灵石→灵材不可转换导致百艺炼丹流 RNG 软锁死、后期灵石无沉没洞、出售=拆解×0.8 死代码。修订内容：(1) 修复 dismantle_value 公式 + 新增炼制物折价50%，(2) realm-system.md 文案修正为乘法惩罚，(3) 铭刻消耗对齐软上限5 + 新增第6次起灵石双重消耗，(4) 坊市溢价兑换灵材安全阀，(5) 移除出售卡牌，保留拆解和灵材出售，(6) 重写 21 条验收标准为分类独立可测试形式。创意总监综合裁决：修订后可通过。
Prior verdict resolved: First review