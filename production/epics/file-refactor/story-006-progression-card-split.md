# Story 006: progression_system.gd + card_system.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 9-10
> **状态**: Done
> **预估**: 2.0d

## 拆分内容

### progression_system.gd（520→456 行）— Sprint 9

| 提取到 `progression_serializer.gd` (124 行) | 保留在 `progression_system.gd` (456 行) |
|---|---|
| `init_empty_stores` / `load_progression_data` / `initialize` / `serialize` / `deserialize` / `_safe_dict` / `_safe_str` / `_safe_int` (static) | 信号声明 / 6 个域存储字段 / 6 个领域 API / 批量更新 API / 脏标志 API / `_mark_dirty_and_emit` + 薄委托 |

### card_system.gd（422→354 行）— Sprint 10

| 提取到 `card_serializer.gd` (130 行) | 保留在 `card_system.gd` (354 行) |
|---|---|
| `serialize_instance` / `deserialize_instance` / `reconstitute_instances` / `_get_int_field` / `_to_stringname` / `_get_inscriptions_field` (static) | 信号/常量/模板注册表 / 模板加载 / 查询 API / 实例工厂 / `_resolve_chapter_number` / `_validate_template` + 薄委托 |

## 验证

- progression_system: 50/50；card_system: 45/45
- 全量测试零回归
- 无新增 Autoload
