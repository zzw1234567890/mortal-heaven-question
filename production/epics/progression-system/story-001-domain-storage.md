# Story 001：域存储 + initialize + serialize/deserialize

> **Epic**: progression-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: In Progress
> **Estimate**: 0.5d

## 描述

实现 ProgressionSystem Autoload #12 的核心基础——6 个领域存储（_achievements / _talents / _card_gallery / _endings / _stats / _meta）、_ready() 初始化序列（直接调用 SaveLoadSystem.load_progression()）、initialize(data) 填充、serialize()/deserialize() JSON 往返、has_unsaved_changes()/mark_saved() 脏标志、progression_initialized 信号。

## 验收标准

| # | AC |
|---|---|
| 1 | ProgressionSystem 为 Autoload，_ready() 后 _initialized_and_loaded = true |
| 2 | _ready() 调用 SaveLoadSystem.load_progression() 获取数据（首局返回空字典）|
| 3 | initialize(data) 填充全部 6 个域存储（achievements/talents/card_gallery/endings/stats/meta）|
| 4 | 首局（无 progression.dat）initialize({}) 后所有域为空/默认值，不报错 |
| 5 | serialize() 返回包含全部 6 个域的 JSON 兼容 Dictionary |
| 6 | deserialize(data) 从 JSON Dictionary 填充全部 6 个域，缺失字段用默认值填充 |
| 7 | serialize→deserialize→serialize 往返保真（数据一致）|
| 8 | has_unsaved_changes() 初始 false，写入后 true，mark_saved() 后 false |
| 9 | progression_initialized 信号在 _ready() 结束时发射 |
| 10 | serialize() 不包含 _dirty / _batch_depth / _initialized_and_loaded 内部标志 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/meta/progression_system.gd` | ProgressionSystem Autoload #12 |
| `tests/unit/progression_system/test_domain_storage.gd` | 10 条 AC 测试 |
| `project.godot` | Autoload 注册 |

## GDD 来源

- ADR-0012 §决策（架构图 + 关键接口 + 初始化策略 + 域存储声明）
