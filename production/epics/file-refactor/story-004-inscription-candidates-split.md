# Story 4：inscription_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 0.5d

## 目标

将 `inscription_system.gd`（427 行）中的候选生成逻辑（6 步权重变换管线 + 加权不放回抽取 + 中间结果查询）提取到 `inscription_candidates.gd` 纯函数 RefCounted 子模块，主文件降至 289 行。

## 拆分内容

| 提取到 `inscription_candidates.gd` (235 行) | 保留在 `inscription_system.gd` (289 行) |
|---|---|
| `generate_candidates`（6 步权重变换管线） | `Direction` / `InscribeResult` 枚举 |
| `_weighted_sample_without_replacement` | 常量 + `SUBSTAT_WEIGHTS` 权重表 |
| `get_candidate_weights`（中间结果查询） | `_Candidates` preload 常量 |
| `Direction` 枚举（子模块独立声明） | `inscription_cost` / `dismantle_inscription_refund` |
| `SUBSTAT_WEIGHTS` 权重表（子模块独立声明） | `inscribe` / `apply_inscription` 编排 |
| `DIRECTION_BONUS_MULTIPLIER` / `DUPLICATE_PENALTY_MULTIPLIER` / `CANDIDATE_COUNT` 常量 | 系统引用辅助 + 安全属性访问 + 薄委托 |

## 架构特点

- **纯函数 RefCounted 类**：子模块无需 `_parent` 引用——所有方法为 static，不访问父节点状态。
- **`const _Candidates := preload(...)`**：使用 preload 常量引用子模块（同 Sprint 9 alchemy_quality_roller.gd 先例），避免 `class_name` 全局注册冲突。
- **枚举/常量/权重表独立声明**：子模块自带 `Direction` 枚举和 `SUBSTAT_WEIGHTS` 权重表，避免跨类引用。
- **薄委托**：主文件保留 3 个方法签名作为 static 薄委托。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- inscription_system 单元测试：30/30 passed（3 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `inscription_candidates.gd` 子模块创建（235 行）
- [x] `inscription_system.gd` 主文件修改（289 行）
- [x] inscription_system 单元测试全部通过（30/30）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
