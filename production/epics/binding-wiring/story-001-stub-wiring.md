# Story 006：BindingManager 存根回调接线

> **Epic**: binding-wiring
> **Story**: 001
> **Type**: Logic
> **Status**: Done
> **Estimate**: 0.5d

## 描述

替换 BindingManager 的 8 个存根 Callable 为 _ready() 自动注入的 CardEffectEngine + CombatSystem 回调。注入仅在 Autoload 实例上触发，BM_SCRIPT.new() 测试实例保留 Callable 接缝不变。CardEffectEngine 新增 6 个桩方法（register_persistent_effect / remove_effects_by_source / suspend_effects_by_source / restore_effects_by_source / get_stat_bonus / card_exists），CombatSystem 新增 2 个牌库操作方法（add_card_to_deck / add_card_to_discard）。

## 验收标准

| # | AC |
|---|---|
| 1 | BindingManager._ready() 在 Autoload 实例上注入 8 个回调 |
| 2 | BM_SCRIPT.new() 测试实例不触发注入（_ready 未执行） |
| 3 | effect_register_cb → CardEffectEngine.register_persistent_effect |
| 4 | effect_remove_cb → CardEffectEngine.remove_effects_by_source |
| 5 | effect_suspend_cb → CardEffectEngine.suspend_effects_by_source |
| 6 | effect_restore_cb → CardEffectEngine.restore_effects_by_source |
| 7 | card_shuffle_cb → CombatSystem.add_card_to_deck |
| 8 | card_discard_cb → CombatSystem.add_card_to_discard |
| 9 | stat_bonus_cb → CardEffectEngine.get_stat_bonus（桩返回 0.0） |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/binding/binding_manager.gd` | _ready() 注入 8 个回调 |
| `src/feature/card_effect_engine/card_effect_engine.gd` | 新增 6 个桩方法 |
| `src/feature/combat_system.gd` | 新增 add_card_to_deck / add_card_to_discard |
| `tests/unit/binding_system/test_stub_wiring.gd` | 10 条 AC 测试 |