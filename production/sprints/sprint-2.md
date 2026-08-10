# Sprint 2: Core 层

> **Sprint**: 2
> **Start Date**: 2026-08-06
> **End Date**: 2026-08-19
> **Status**: In Progress
> **Focus**: Core 层 4 个数据/经济系统 + event_system.gd 技术债拆分
> **Milestone**: core-layer-complete（Active，目标 2026-08-19）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05

## Sprint Goal

完成 Core 层 4 个系统（card-system / realm-system / resource-system / faction-system）——卡牌数据模型、境界静态表、资源读写+公式、阵营标签库+判定。同时偿还 Sprint 1 遗留的技术债（拆分 event_system.gd 558→≤300 行）。此冲刺结束后 Core 层基础设施就绪，Feature 层（战斗、效果引擎、流派等）可开始构建。

## 容量

- 总天数：14
- 缓冲（20%）：3 天
- 可用：11 天（~88h @ 8h/天）
- Sprint 1 实际速度：74h / 9 天 ≈ 8.2h/天
- 计划工作量：53.5h（61% 利用率）
- 剩余容量预留：Feature 层 Epic Story 预创建 8h

## Stories

### 必须完成（关键路径）—— 44.5h

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | card-system | CardTemplate + enums | `card-system/story-001-card-template-resource-and-enums.md` | Logic | 3h | GSM✅ | ✅ Done (08-05) |
| 2 | card-system | CardInstance RefCounted | `card-system/story-002-card-instance-refcounted-model.md` | Logic | 2.5h | #1 | ✅ Done (08-06) |
| 3 | card-system | CardSystem Autoload + 注册表异步加载 | `card-system/story-003-card-system-template-registry-async-loading.md` | Integration | 4h | #2 | ✅ Done (08-06) |
| 4 | card-system | 工厂 + GSM 集成 | `card-system/story-004-card-system-factory-gsm-integration.md` | Integration | 3.5h | #3 | ✅ Done (08-06) |
| 5 | card-system | 实例序列化/重组 | `card-system/story-005-instance-serialization-reconstitution.md` | Integration | 3h | #4 | ✅ Done (08-06) |
| 6 | realm-system | realm_table + 查询接口 | `realm-system/story-001-realm-system-autoload-realm-table-query.md` | Logic | 2.5h | GSM✅ | ✅ Done (08-06) |
| 7 | realm-system | 压制计算 + 稀有度权重 | `realm-system/story-002-realm-penalty-map-suppression-rarity-weights.md` | Logic | 3h | #6 | ✅ Done (08-06) |
| 8 | realm-system | realm_up 编排 + 信号 | `realm-system/story-003-realm-up-orchestration-signal-gsm-integration.md` | Integration | 3h | #7 | ✅ Done (08-06) |
| 9 | resource-system | Autoload + 读写 API + GSM 第二层 | `resource-system/story-001-resource-system-autoload-read-write-api.md` | Integration | 4.5h | GSM✅ | ✅ Done (08-08) |
| 10 | resource-system | 6 资源公式纯函数 | `resource-system/story-002-resource-formulas-pure-functions.md` | Logic | 4h | #9 | ✅ Done (08-08) |
| 11 | faction-system | FACTION_LIBRARY + 标签查询 | `faction-system/story-001-faction-system-autoload-library-query-api.md` | Logic | 4h | #3 | ✅ Done (08-08) |
| 12 | faction-system | 场上统计 + 判定 | `faction-system/story-002-field-stats-condition-judgment.md` | Integration | 4h | #4,#11 | ✅ Done (08-09) |
| 13 | tech-debt | 拆分 event_system.gd（558→≤300 行） | （Sprint 1 回顾行动项 #1） | Refactor | 3h | — | ✅ Done (08-09) |
| 15 | infra | project.godot Autoload 顺序验证（第 1 天） | — | Task | 0.5h | — | ✅ Done (08-09) |

### 可以完成 —— 9h

| # | Epic | Story | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|:--:|:--:|:--:|:--:|
| 14 | docs | ADR-0003 §visited_ids 生命周期文档补充 | Doc | 1h | — | Ready |
| 16 | prep | Feature 层 Epic Story 预创建（为 Sprint 3 铺路） | Planning | 8h | — | Ready |

**总计**：必须完成 44.5h + 可以完成 9h = 53.5h（61% 利用率）

## 上一个冲刺的结转项

无（Sprint 1 全部 23 Story 当冲刺完成）

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| faction-system/002 依赖 card-system get_field_characters（跨 Epic） | 高 | 中 | Sprint 排序 card-system 优先；faction/002 排在 card/004 之后 |
| AC 密集 Story 预估偏低（retro 发现 AC>15 偏差 +30%） | 中 | 中 | resource/faction Story AC 19-22，预估已上调 +4h（#9/#10/#11/#12 各 +1h） |
| Autoload #15/#16 初始化顺序（CardSystem #6 需先于 #15/#16） | 中 | 中 | Sprint 第 1 天前置验证（#15 任务，0.5h） |
| event_system.gd 拆分可能引入回归 | 中 | 高 | 拆分后重跑全部 520 测试，零回归才合并 |
| Core 层 4 系统上下文切换成本 | 中 | 中 | Sprint 1 速度 8.2h/天，Core 层保守估计 7-7.5h/天，11 天 × 7h = 77h 仍超 44.5h 计划 |

## 外部因素依赖

无（Core 层仅依赖 Foundation 层，已就绪）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成
- [ ] 所有任务通过验收标准
- [ ] QA 计划已存在 (`production/qa/qa-plan-sprint-2.md`)
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过 (`/smoke-check sprint`)
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] 回顾行动项 #1（拆分 event_system.gd）已完成 ✅ 升级为必须完成
- [ ] Autoload #15/#16 初始化顺序已验证

## 关键依赖链

- **card-system 关键路径**: 001→002→003→004→005（15.5h）—— 必须最先开始
- **faction-system/002**: 依赖 card-system/004 的 get_field_characters + faction-system/001 —— 排在 #4 和 #11 之后
- **realm-system**: 仅依赖 GSM，可与 card-system 并行
- **resource-system**: 仅依赖 GSM，可与 card-system 并行
- **event_system.gd 拆分**: 独立任务，可在任意空闲时段进行，但拆分后须重跑全部测试

## Next Steps

1. `/qa-plan sprint` — **在实现开始前必需** — 为每个故事定义测试用例
2. `/story-readiness production/epics/card-system/story-001-card-template-resource-and-enums.md` — 验证首个 Story 就绪
3. `/dev-story` — 开始实现
4. 实现顺序建议：card-system（关键路径）→ realm-system（并行）→ resource-system（并行）→ faction-system（依赖 card）→ event_system.gd 拆分（独立）
5. Sprint 第 1 天先执行 #15（Autoload 顺序验证）再开始编码
