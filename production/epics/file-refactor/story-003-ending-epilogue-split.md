# Story 3：ending_evaluator.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 11
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `ending_evaluator.gd`（293 行）中的尾声叙事生成逻辑（_generate_epilogue）提取到 `ending_epilogue.gd` RefCounted 子模块，主文件降至 286 行。

## 拆分内容

| 提取到 `ending_epilogue.gd` (93 行) | 保留在 `ending_evaluator.gd` (286 行) |
|---|---|
| `generate_epilogue`（static） | `ENDING_TEMPLATES` const Dictionary（3 条结局线完整数据）|
| `_get_flag`（static） | `evaluate` 主入口 |
| `EPILOGUE_MAX_LINES` 常量 | `_calculate_scores` / `_resolve_tie` / `_determine_variant` |
| `LINE_PREFIX` / `ENDING_TEMPLATES`（仅 epilogue_base 子集）| `_check_run_condition` / `_get_flag`（主文件保留）|
| | `_generate_epilogue` 薄委托（兼容测试直接调用）|

## 架构特点

- **纯函数 static 方法**：子模块所有方法为 static，无需 `_parent` 引用。
- **const preload**：主文件通过 `const _Epilogue := preload(...)` 引用子模块。
- **薄委托兼容测试**：主文件保留 `_generate_epilogue` 实例方法作为薄委托，转发到 `_Epilogue.generate_epilogue(...)`，避免修改测试中 `evaluator._generate_epilogue(...)` 的调用方式。
- **常量独立声明**：子模块独立声明 `LINE_PREFIX` 和 `ENDING_TEMPLATES`（仅含 `epilogue_base` 子集），避免运行时跨类引用常量。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- ending_branch_system 单元测试：30/30 passed（含 4 个 epilogue 测试 + 6 个 variant 测试 + 20 个评分/平局测试）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `ending_epilogue.gd` 子模块创建（93 行）
- [x] `ending_evaluator.gd` 主文件修改（286 行）
- [x] ending_branch_system 单元测试全部通过（30/30）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
