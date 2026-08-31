# Story 001：EndingEvaluator 纯函数工具类 + evaluate_ending

> **Epic**: ending-branch-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0029
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 EndingEvaluator RefCounted 纯函数工具类和 `evaluate()` 主入口——收集输入（story_flags + chapter_path + run_data）→ 计算得分 → 解析平局 → 判定变体 → 生成尾声 → 返回 EndingResult。同时定义 ENDING_TEMPLATES const Dictionary（3 条结局线 × 条件/权重/变体/尾声）。

## 验收标准

| # | AC |
|---|---|
| 1 | `evaluate()` 返回 ending_id 字段 |
| 2 | `evaluate()` 返回 ending_line 字段（ascend/guard/return）|
| 3 | `evaluate()` 返回 variant 字段（solo/duo/lone/order/home/sect）|
| 4 | `evaluate()` 返回 scores 字典（含 ascend/guard/return 三线得分）|
| 5 | `evaluate()` 返回 epilogue 非空字符串 |
| 6 | ch5=ascend + 前4章偏向飞升 → ending_line="ascend" |
| 7 | ch5=guard + 前4章偏向守护 → ending_line="guard" |
| 8 | ch5=return + 前4章偏向回归 → ending_line="return" |
| 9 | `ENDING_TEMPLATES` 包含 3 条结局线 |
| 10 | `ENDING_TEMPLATES` 每条线含 conditions + variants + epilogue_base |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/ending_evaluator.gd` | EndingEvaluator RefCounted + ENDING_TEMPLATES + evaluate() |
| `tests/unit/ending_branch_system/test_ending_evaluator.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/ending-branch-system.md` §1 全局结局判定模型、§2 三条结局主线
- ADR-0029 §决策 1/2 + §关键接口 + §评分计算算法