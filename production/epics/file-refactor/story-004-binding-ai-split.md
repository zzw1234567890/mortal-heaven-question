# Story 004：binding_manager.gd + ai_system.gd 拆分

> **Epic**: file-refactor
> **Story**: 004
> **Type**: Refactor
> **Status**: Done
> **Estimate**: 1.0d

## 描述

将 binding_manager.gd（~823 行）的序列化/反序列化方法提取到 `binding_serializer.gd`（RefCounted 子模块）。将 ai_system.gd（769 行）的决策引擎逻辑提取到 `ai_decision_engine.gd`（RefCounted 子模块），Boss 阶段转换逻辑提取到 `ai_boss_phases.gd`（RefCounted 子模块）。主文件通过薄委托调用子模块。

## 验收标准

| # | AC |
|---|---|
| 1 | binding_serializer.gd 提取序列化/反序列化（serialize_all / deserialize_all / write_snapshot_to_gsm / _serialize_record / _deserialize_record） |
| 2 | deserialize_all 保留 _query_card_exists 验证 + stack_slots _card_to_character 映射 |
| 3 | ai_decision_engine.gd 提取决策引擎（execute_turn / _decide_* / _evaluate_skills / _calculate_* / _select_* / _check_retreat） |
| 4 | ai_boss_phases.gd 提取 Boss 阶段转换（check_phase_transition / should_transition / do_boss_phase_transition / get_phase / check / transition） |
| 5 | 主文件通过薄委托方法调用子模块 |
| 6 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/binding/binding_manager.gd` | 主文件 ~823→755 行，薄委托 |
| `src/feature/binding/binding_serializer.gd` | 序列化/反序列化 133 行 |
| `src/feature/ai_system.gd` | 主文件 769→583 行，薄委托 |
| `src/feature/ai/ai_decision_engine.gd` | 决策引擎 239 行 |
| `src/feature/ai/ai_boss_phases.gd` | Boss 阶段转换 130 行 |

## 测试结果

- 单系统测试：binding_system 67/67 通过；ai_system 101/101 通过
- 全量测试：142 scripts / 2438 tests / 2437 passing / 1 pending / 0 failing
- 零回归