# Story 002：CombatSystem 回调接线 CardEffectEngine+CardSystem

> **Epic**: combat-wiring
> **Story**: 002
> **Type**: Logic
> **Status**: In Progress
> **Estimate**: 0.5d

## 描述

替换 CombatSystem 的 3 个 Callable 桩（validate_targets_cb / resolve_cb / get_card_instance_cb）为生产代码中使用 CardEffectEngine + CardSystem Autoload 直接调用。保留 Callable 字段作为测试接缝（deprecated 但不移除），生产代码在 _ready() 中注入真实回调。

## 验收标准

| # | AC |
|---|---|
| 1 | _ready() 中注入 CardEffectEngine.validate_targets 为 validate_targets_cb 默认值 |
| 2 | _ready() 中注入 CardSystem.get_instance 为 get_card_instance_cb 默认值 |
| 3 | validate_targets_cb 未注入时回退到 CardEffectEngine Autoload 查询 |
| 4 | resolve_cb 未注入时回退到 CardEffectEngine Autoload 查询 |
| 5 | get_card_instance_cb 未注入时回退到 CardSystem Autoload 查询 |
| 6 | play_card 使用注入回调路径不变（测试兼容） |
| 7 | _get_card_instance 优先 Callable，回退 CardSystem Autoload |
| 8 | _validate_targets 优先 Callable，回退 CardEffectEngine Autoload |
| 9 | _resolve_effects 优先 Callable，回退 CardEffectEngine Autoload |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/combat_system.gd` | _ready() 注入 + 回退逻辑 |
| `tests/unit/combat_system/test_callback_wiring.gd` | 10 条 AC 测试 |
