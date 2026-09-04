# Story 6：card_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `card_system.gd`（422 行）中的序列化/反序列化逻辑提取到 `card_serializer.gd` 纯函数 RefCounted 子模块，主文件降至 354 行。

## 拆分内容

| 提取到 `card_serializer.gd` (130 行) | 保留在 `card_system.gd` (354 行) |
|---|---|
| `serialize_instance` | 信号声明 + 常量 + 模板注册表 |
| `deserialize_instance` | 模板加载（`_load_templates_from` / `_process` / `_on_all_templates_loaded`）|
| `reconstitute_instances` | 查询 API（`get_template` / `has_template` / `get_templates_by_type`）|
| `_get_int_field` / `_to_stringname` / `_get_inscriptions_field`（static） | 实例工厂（`create_instance`）|
| | `_resolve_chapter_number` + `_validate_template` |
| | `_extract_instance_id` / `_extract_template_id` / `_to_stringname`（主文件保留——查询路径用）+ 薄委托 |

## 架构特点

- **纯函数 RefCounted 类**：子模块所有方法为 static，不访问父节点状态。
- **`const _Serializer := preload(...)`**：使用 preload 常量引用子模块（同 Sprint 9 alchemy_quality_roller.gd 先例）。
- **`_to_stringname` 保留**：主文件保留 `_to_stringname`（被 `get_template_by_instance_id` 和 `_extract_template_id` 调用），子模块有独立 static 版本。
- **`_get_int_field` / `_get_inscriptions_field` 仅在子模块**：这两个辅助方法仅被 `deserialize_instance` 调用，完全移入子模块。
- **薄委托**：主文件保留 3 个方法签名作为薄委托。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- card_system 单元测试：45/45 passed（2 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `card_serializer.gd` 子模块创建（130 行）
- [x] `card_system.gd` 主文件修改（354 行）
- [x] card_system 单元测试全部通过（45/45）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
