# Sprint 1: Foundation 层

> **Sprint**: 1
> **Start Date**: 2026-07-27
> **End Date**: 2026-08-10（2 周时间盒）
> **Status**: Planned
> **Focus**: Foundation 层全部 5 个系统——游戏运行的根基

## Sprint Goal

完成 Foundation 层的 5 个 Autoload 系统实现——GSM、输入管理器、场景管理器、存档加载系统、事件系统。此冲刺结束后，游戏引擎框架可运行、输入可被仲裁、场景可被转换、状态可被持久化、事件可被调度。这是所有后续开发的基石——任何 Foundation 层的 bug 在此之后修复成本将急剧上升。

## Stories

| # | Epic | Story | 文件 | 类型 | 预估 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|
| 1 | gsm | Autoload 基础结构与第一层属性读取 | `gsm/story-001-autoload-structure-and-tier1-read.md` | Logic | 2.5h | ✅ Done |
| 2 | gsm | 第二层原子写入方法 | `gsm/story-002-atomic-write-methods.md` | Logic | 4h | ✅ Done |
| 3 | gsm | 第三层信号订阅 + batch_updated | `gsm/story-003-signal-layer-batch-updated.md` | Logic | 3h | ✅ Done |
| 4 | gsm | 序列化与反序列化 | `gsm/story-004-serialize-deserialize.md` | Logic | 2.5h | ✅ Done |
| 5 | gsm | 校验跳过 + enable_validation | `gsm/story-005-validation-skip-enable.md` | Integration | 3h | ✅ Done |
| 6 | input-manager | 四级锁栈核心实现 | `input-manager/story-001-lock-stack-core.md` | Logic | 3h | ✅ Done |
| 7 | input-manager | 双焦点输入判定 | `input-manager/story-002-dual-focus-judgment.md` | Logic | 3h | ✅ Done |
| 8 | input-manager | GSM 同步与信号传播 | `input-manager/story-003-gsm-sync-signal-routing.md` | Integration | 3h | ✅ Done |
| 9 | input-manager | MODAL 覆盖与边缘情况 | `input-manager/story-004-modal-override-edge-cases.md` | Integration | 3h | ✅ Done |
| 10 | scene-manager | 5 阶段转换管线核心 | `scene-manager/story-001-five-phase-pipeline-core.md` | Logic | 5h | ✅ Done |
| 11 | scene-manager | TransitionType + 音频过渡矩阵 | `scene-manager/story-002-transition-type-audio-matrix.md` | Logic | 2.5h | ✅ Done |
| 12 | scene-manager | 转场前自动存档 + 输入锁集成 | `scene-manager/story-003-autosave-input-lock-integration.md` | Integration | 3.5h | ✅ Done |
| 13 | scene-manager | 加载画面 + 异步加载 + 错误恢复 | `scene-manager/story-004-loading-screen-async-error-recovery.md` | Integration | 4.5h | ✅ Done |
| 14 | save-load | JSON 引擎 + 枚举定义 | `save-load/story-001-json-engine-enums.md` | Logic | 2.5h | — |
| 15 | save-load | 原子双写 + Windows 重试 | `save-load/story-002-atomic-write-retry.md` | Integration | 3h | — |
| 16 | save-load | 容器 schema + 完整性校验 | `save-load/story-003-container-schema-validation.md` | Integration | 3h | — |
| 17 | save-load | 公共 API + GSM 集成 | `save-load/story-004-public-api-gsm-integration.md` | Integration | 4h | — |
| 18 | save-load | 迁移链 + VERSION_MISMATCH | `save-load/story-005-migration-chain-version-mismatch.md` | Logic | 3h | — |
| 19 | event-system | EventTemplate Resource 数据模型 | `event-system/story-001-event-template-resource-model.md` | Logic | 3h | — |
| 20 | event-system | EventInstance + 触发/判定/结算 | `event-system/story-002-event-instance-trigger-resolve.md` | Logic | 4h | — |
| 21 | event-system | story_flags 写入契约 | `event-system/story-003-story-flags-ownership-delegation.md` | Logic+Integration | 3h | — |
| 22 | event-system | 连锁事件 + 循环检测 | `event-system/story-004-chain-events-depth-cycle-detection.md` | Logic | 2.5h | — |
| 23 | event-system | 结果执行器 + ADD_CARD 信号委托 | `event-system/story-005-outcome-executor-add-card-delegation.md` | Integration | 4h | — |

**总计**：23 个 Story — 14 Logic, 9 Integration — ~74h |

## Definition of Done

- 5 个 Foundation Autoload 全部实现并通过测试
- GSM 三层 API 可以端到端调用
- 输入锁栈可正确阻塞/释放输入
- 场景可通过 SceneManager 转换
- 存档可写入、读取、迁移
- 事件可解析并触发结果

## Risk Register

| 风险 | 严重度 | 缓解措施 |
|------|:--:|------|
| Godot 4.6 双焦点（InputManager）——API 行为与 LLM 训练数据不同 | HIGH | 参考 engine-reference VERSION.md + 原型验证 |
| FileAccess 返回类型变更（SaveLoadSystem） | MEDIUM | ADR-0002 已显式要求检查返回值 |
| Autoload 初始化顺序冲突 | MEDIUM | GSM #1 位保证——其他 Autoload 在 _ready() 中延迟查询 GSM |

## Next Steps

1. ~~`/create-stories gsm`~~ ✅ 5 stories
2. ~~`/create-stories input-manager`~~ ✅ 4 stories
3. ~~`/create-stories scene-manager`~~ ✅ 4 stories
4. ~~`/create-stories save-load`~~ ✅ 5 stories
5. ~~`/create-stories event-system`~~ ✅ 5 stories
6. **`/story-readiness production/epics/gsm/story-001-autoload-structure-and-tier1-read.md`** —— 验证首个 Story 就绪
7. **`/dev-story`** —— 开始实现
8. 实现顺序：gsm → input-manager → scene-manager → save-load → event-system