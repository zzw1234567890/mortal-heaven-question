# Story 003：_determine_variant / _generate_epilogue 变体与尾声

> **Epic**: ending-branch-system
> **Story**: 003
> **Type**: Logic
> **ADR**: ADR-0029
> **Status**: Done
> **Estimate**: 0.5d

## 描述

补充 EndingEvaluator 的变体判定 `_determine_variant()` 和尾声叙事生成 `_generate_epilogue()` 专项测试覆盖——验证 6 种变体的判定逻辑、尾声文本中 story_flags 驱动的插入段落、以及尾声长度上限。

## 验收标准

| # | AC |
|---|---|
| 1 | ch4=ascend_with_yinyue + line=ascend → variant="duo"（仙侣同行）|
| 2 | ch4=ascend_alone + line=ascend → variant="solo"（仙道孤独）|
| 3 | yinyue_alive=true + ch4=ascend_with_yinyue + line=guard → variant="order"（建立新秩序）|
| 4 | yinyue_alive=false + line=guard → variant="lone"（孤身守望）|
| 5 | yinyue_alive=true + unlocked_talents≥10 + total_completions≥3 + line=return → variant="sect"（开宗立派）|
| 6 | yinyue_alive=true + unlocked_talents=5 + line=return → variant="home"（归隐凡间）|
| 7 | ending_id="ascension_solo" → 尾声以飞升线基础文本开头 |
| 8 | ch1_accepted_mo_condition=true → 尾声含「墨渊的夺舍条件」插入段 |
| 9 | ch2_took_bone_secret=false → 尾声含「摧毁枯骨洞府」插入段 |
| 10 | yinyue_alive=true → 尾声含「银翎在你身旁」插入段 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/ending_evaluator.gd` | _determine_variant + _generate_epilogue（已实现）|
| `tests/unit/ending_branch_system/test_variant_and_epilogue.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/ending-branch-system.md` §公式 3 变体判定、§7 叙事文本的剧情引用
- ADR-0029 §决策 2 + §尾声叙事文本生成
