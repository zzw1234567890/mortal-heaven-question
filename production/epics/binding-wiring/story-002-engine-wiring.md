# Story 002：CardEffectEngine 子模块接线

> **Epic**: binding-wiring
> **Story**: 002
> **Type**: Logic
> **Status**: Done
> **Estimate**: 0.5d

## 描述

接线 CardEffectEngine Autoload 持有的三个子模块实例（PRDEngine / CardEffectEvaluator / ResolutionStack）。_ready() 从 GSM.meta.seed 获取种子注入 PRDEngine。暴露 getter 方法供外部访问子模块。新增 create_evaluation_snapshot 桩方法。

## 验收标准

| # | AC |
|---|---|
| 1 | CardEffectEngine._ready() 初始化 PRDEngine 实例 |
| 2 | CardEffectEngine._ready() 初始化 CardEffectEvaluator 实例 |
| 3 | CardEffectEngine._ready() 初始化 ResolutionStack 实例 |
| 4 | _ready() 从 GSM.meta.seed 获取种子注入 PRDEngine |
| 5 | GSM 不可用时使用默认种子 0（不崩溃） |
| 6 | get_prd_engine() 返回非 null PRDEngine 实例 |
| 7 | get_evaluator() 返回非 null CardEffectEvaluator 实例 |
| 8 | get_resolution_stack() 返回非 null ResolutionStack 实例 |
| 9 | create_evaluation_snapshot() 返回 GameStateSnapshot（不崩溃） |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/card_effect_engine/card_effect_engine.gd` | 子模块实例化 + getter |
| `tests/unit/card_effect_engine/test_engine_wiring.gd` | 10 条 AC 测试 |