
# 代理协调与委派映射 (Agent Coordination and Delegation Map)

## 组织层级 (Organizational Hierarchy)

```
                           [Human Developer]
                                 |
                 +---------------+---------------+
                 |               |               |
         creative-director  technical-director  producer
                 |               |               |
        +--------+--------+     |        (coordinates all)
        |        |        |     |
  game-designer art-dir  narr-dir  lead-programmer  qa-lead  audio-dir
        |        |        |         |                |        |
     +--+--+     |     +--+--+  +--+--+--+--+--+   |        |
     |  |  |     |     |     |  |  |  |  |  |  |   |        |
    sys lvl eco  ta   wrt  wrld gp ep  ai net tl ui qa-t    snd
                                 |
                             +---+---+
                             |       |
                          perf-a   devops   analytics

  Additional Leads (report to producer/directors):
    release-manager         -- 发布管线、版本管理、部署 (Release pipeline, versioning, deployment)
    localization-lead       -- 国际化、字符串表、翻译管线 (i18n, string tables, translation pipeline)
    prototyper              -- 快速可抛弃原型、概念验证 (Rapid throwaway prototypes, concept validation)
    security-engineer       -- 反作弊、漏洞利用、数据隐私、网络安全 (Anti-cheat, exploits, data privacy, network security)
    accessibility-specialist -- 无障碍标准、色盲模式、重映射、文本缩放 (WCAG, colorblind, remapping, text scaling)
    live-ops-designer       -- 赛季、活动、战斗通行证、留存、运营经济 (Seasons, events, battle passes, retention, live economy)
    community-manager       -- 补丁说明、玩家反馈、危机沟通 (Patch notes, player feedback, crisis comms)

  Engine Specialists (use the SET matching your engine):
    unreal-specialist  -- UE5 主管：Blueprint/C++、GAS 概览、UE 子系统 (UE5 lead: Blueprint/C++, GAS overview, UE subsystems)
      ue-gas-specialist         -- GAS：能力、效果、属性、标签、预测 (GAS: abilities, effects, attributes, tags, prediction)
      ue-blueprint-specialist   -- Blueprint：BP/C++ 边界、图形标准、优化 (Blueprint: BP/C++ boundary, graph standards, optimization)
      ue-replication-specialist -- 网络：复制、RPC、预测、带宽 (Networking: replication, RPCs, prediction, bandwidth)
      ue-umg-specialist         -- UI：UMG、CommonUI、控件层级、数据绑定 (UI: UMG, CommonUI, widget hierarchy, data binding)

    unity-specialist   -- Unity 主管：MonoBehaviour/DOTS、Addressables、URP/HDRP (Unity lead: MonoBehaviour/DOTS, Addressables, URP/HDRP)
      unity-dots-specialist         -- DOTS/ECS：Jobs、Burst、混合渲染器 (DOTS/ECS: Jobs, Burst, hybrid renderer)
      unity-shader-specialist       -- 着色器：Shader Graph、VFX Graph、SRP 定制 (Shaders: Shader Graph, VFX Graph, SRP customization)
      unity-addressables-specialist -- 资源：异步加载、Bundle、内存、CDN (Assets: async loading, bundles, memory, CDN)
      unity-ui-specialist           -- UI：UI Toolkit、UGUI、UXML/USS、数据绑定 (UI: UI Toolkit, UGUI, UXML/USS, data binding)

    godot-specialist   -- Godot 4 主管：GDScript、节点/场景、信号、资源 (Godot 4 lead: GDScript, node/scene, signals, resources)
      godot-gdscript-specialist    -- GDScript：静态类型、模式、信号、性能 (GDScript: static typing, patterns, signals, performance)
      godot-csharp-specialist      -- C#：.NET 模式、[Signal] 委托、async、类型安全节点访问 (C#: .NET patterns, [Signal] delegates, async, type-safe node access)
      godot-shader-specialist      -- 着色器：Godot 着色语言、可视化着色器、VFX (Shaders: Godot shading language, visual shaders, VFX)
      godot-gdextension-specialist -- 原生：C++/Rust 绑定、GDExtension、构建系统 (Native: C++/Rust bindings, GDExtension, build systems)
```

### 图例 (Legend)
```
sys  = systems-designer          gp  = gameplay-programmer
lvl  = level-designer            ep  = engine-programmer
eco  = economy-designer          ai  = ai-programmer
ta   = technical-artist          net = network-programmer
wrt  = writer                    tl  = tools-programmer
wrld = world-builder             ui  = ui-programmer
snd  = sound-designer            qa-t = qa-tester
narr-dir = narrative-director    perf-a = performance-analyst
art-dir = art-director
```

## 委派规则 (Delegation Rules)

### 谁可以向谁委派 (Who Can Delegate to Whom)

| 委派方 (From) | 可委派给 (Can Delegate To) |
|------|----------------|
| creative-director | game-designer、art-director、audio-director、narrative-director |
| technical-director | lead-programmer、devops-engineer、performance-analyst、technical-artist（技术决策） |
| producer | 任何代理（仅限其领域内的任务分配） |
| game-designer | systems-designer、level-designer、economy-designer |
| lead-programmer | gameplay-programmer、engine-programmer、ai-programmer、network-programmer、tools-programmer、ui-programmer |
| art-director | technical-artist、ux-designer |
| audio-director | sound-designer |
| narrative-director | writer、world-builder |
| qa-lead | qa-tester |
| release-manager | devops-engineer（发布构建）、qa-lead（发布测试） |
| localization-lead | writer（字符串审核）、ui-programmer（文本适配） |
| prototyper | （独立工作，向制作人和相关主管报告发现） |
| security-engineer | network-programmer（安全审查）、lead-programmer（安全模式） |
| accessibility-specialist | ux-designer（无障碍模式）、ui-programmer（实现）、qa-tester（可访问性测试） |
| [engine]-specialist | 引擎子专家（委托子系统特定工作） |
| [engine] sub-specialists | （就引擎子系统模式和优化向所有程序员提供建议） |
| live-ops-designer | economy-designer（运营经济）、community-manager（活动沟通）、analytics-engineer（参与度指标） |
| community-manager | （与制作人协调审批，与发布经理协调补丁说明时间） |

### 升级路径 (Escalation Paths)

| 情况 (Situation) | 升级至 (Escalate To) |
|-----------|------------|
| 两位设计师对某一机制有分歧 | game-designer |
| 游戏设计与叙事的冲突 | creative-director |
| 游戏设计与技术可行性的冲突 | producer（协调），然后 creative-director + technical-director |
| 美术与音频调性的冲突 | creative-director |
| 代码架构分歧 | technical-director |
| 跨系统代码冲突 | lead-programmer，然后 technical-director |
| 部门间进度冲突 | producer |
| 范围超出容量 | producer，然后由 creative-director 决定削减内容 |
| 质量关卡分歧 | qa-lead，然后 technical-director |
| 性能预算违规 | performance-analyst 标记，technical-director 决定 |

## 常见工作流模式 (Common Workflow Patterns)

### 模式 1：新功能（完整管线）(Pattern 1: New Feature (Full Pipeline))

```
1. creative-director  -- 批准符合愿景的功能概念
2. game-designer      -- 创建包含完整规格的设计文档
3. producer           -- 安排工作，识别依赖关系
4. lead-programmer    -- 设计代码架构，创建接口草图
5. [specialist-programmer] -- 实现功能
6. technical-artist   -- 实现视觉效果（如需）
7. writer             -- 创建文本内容（如需）
8. sound-designer     -- 创建音频事件列表（如需）
9. qa-tester          -- 编写测试用例
10. qa-lead           -- 审核并批准测试覆盖范围
11. lead-programmer   -- 代码审查
12. qa-tester         -- 执行测试
13. producer          -- 标记任务完成
```

### 模式 2：Bug 修复 (Pattern 2: Bug Fix)

```
1. qa-tester          -- 使用 /bug-report 提交 Bug 报告
2. qa-lead            -- 评估严重性和优先级
3. producer           -- 分配到冲刺（若非 S1）
4. lead-programmer    -- 识别根因，分配给程序员
5. [specialist-programmer] -- 修复 Bug
6. lead-programmer    -- 代码审查
7. qa-tester          -- 验证修复并运行回归测试
8. qa-lead            -- 关闭 Bug
```

### 模式 3：平衡性调整 (Pattern 3: Balance Adjustment)

```
1. analytics-engineer -- 从数据（或玩家报告）识别不平衡
2. game-designer      -- 根据设计意图评估问题
3. economy-designer   -- 建模调整方案
4. game-designer      -- 批准新数值
5. [data file update] -- 更改配置数值
6. qa-tester          -- 回归测试受影响的系统
7. analytics-engineer -- 监控变更后的指标
```

### 模式 4：新区域/关卡 (Pattern 4: New Area/Level)

```
1. narrative-director -- 定义该区域的叙事目的和节拍
2. world-builder      -- 创建传说和环境背景
3. level-designer     -- 设计布局、遭遇、节奏
4. game-designer      -- 审查遭遇的机制设计
5. art-director       -- 定义该区域的视觉方向
6. audio-director     -- 定义该区域的音频方向
7. [相关程序员和美术师的实现]
8. writer             -- 创建区域特定文本内容
9. qa-tester          -- 测试完整区域
```

### 模式 5：冲刺周期 (Pattern 5: Sprint Cycle)

```
1. producer           -- 使用 /sprint-plan new 规划冲刺
2. [所有代理]         -- 执行分配的任务
3. producer           -- 使用 /sprint-plan status 每日状态检查
4. qa-lead            -- 冲刺期间持续测试
5. lead-programmer    -- 冲刺期间持续代码审查
6. producer           -- 使用冲刺后钩子进行冲刺回顾
7. producer           -- 整合经验教训规划下一冲刺
```

### 模式 6：里程碑检查点 (Pattern 6: Milestone Checkpoint)

```
1. producer           -- 运行 /milestone-review
2. creative-director  -- 审查创意进展
3. technical-director -- 审查技术健康度
4. qa-lead            -- 审查质量指标
5. producer           -- 协调通过/不通过讨论
6. [所有主管]         -- 必要时就范围调整达成一致
7. producer           -- 记录决策并更新计划
```

### 模式 7：发布管线 (Pattern 7: Release Pipeline)

```text
1. producer             -- 声明发布候选版本，确认里程碑标准已满足
2. release-manager      -- 切分发布分支，生成 /release-checklist
3. qa-lead              -- 运行完整回归测试，签署质量批准
4. localization-lead    -- 验证所有字符串已翻译，文本适配通过
5. performance-analyst  -- 确认性能基准在目标范围内
6. devops-engineer      -- 构建发布产物，运行部署管线
7. release-manager      -- 生成 /changelog，打发布标签，创建发布说明
8. technical-director   -- 重大发布的最终签署批准
9. release-manager      -- 部署并监控 48 小时
10. producer            -- 标记发布完成
```

### 模式 8：概念原型（早期——在 GDD 之前）(Pattern 8: Concept Prototype (early — before GDDs))

```text
1. game-designer        -- 定义假设和成功标准
2. prototyper           -- 使用 /prototype 搭建概念原型
3. prototyper           -- 构建最小实现（1-3 天）
4. game-designer        -- 根据标准评估原型
5. prototyper           -- 在 REPORT.md 中记录发现
6. creative-director    -- PROCEED / PIVOT / KILL 决策（仅完整模式）
7. game-designer        -- 若 PROCEED，将原型经验融入 GDD 编写
```

### 模式 8b：垂直切片（预制作——在 GDD 和架构之后）(Pattern 8b: Vertical Slice (pre-production — after GDDs and architecture))

```text
1. game-designer        -- 根据 GDD 确认切片范围
2. prototyper           -- 使用 /vertical-slice 构建生产质量的端到端构建
3. prototyper           -- 进行内部试玩会议（至少 1 次）
4. prototyper           -- 在 REPORT.md 中记录发现
5. creative-director    -- 关于是否进入制作的通过/不通过决策（完整模式）
6. producer             -- 若 PROCEED，安排制作史诗/冲刺
```

### 模式 9：运营活动 / 赛季发布 (Pattern 9: Live Event / Season Launch)

```text
1. live-ops-designer     -- 设计活动/赛季内容、奖励、时间表
2. game-designer         -- 验证活动玩法机制
3. economy-designer      -- 平衡活动经济和奖励数值
4. narrative-director    -- 提供赛季叙事主题
5. writer                -- 创建活动描述和传说
6. producer              -- 安排实现工作
7. [相关程序员的实现]
8. qa-lead               -- 端到端测试活动流程
9. community-manager     -- 起草活动公告和补丁说明
10. release-manager      -- 部署活动内容
11. analytics-engineer   -- 监控活动参与度和指标
12. live-ops-designer    -- 活动后分析与经验教训
```

## 跨领域沟通协议 (Cross-Domain Communication Protocols)

### 设计变更通知 (Design Change Notification)

当设计文档变更时，游戏设计师 (game-designer) 必须通知：
- lead-programmer（实现影响评估）
- qa-lead（测试计划更新）
- producer（进度影响评估）
- 根据变更内容相关的专业代理

### 架构变更通知 (Architecture Change Notification)

当 ADR 被创建或修改时，技术总监 (technical-director) 必须通知：
- lead-programmer（所需代码变更）
- 所有受影响的专业程序员
- qa-lead（测试策略可能需要调整）
- producer（进度影响）

### 资源标准变更通知 (Asset Standard Change Notification)

当美术圣经或资源标准变更时，艺术总监 (art-director) 必须通知：
- technical-artist（管线变更）
- 所有处理受影响资源的内容创作者
- devops-engineer（若构建管线受影响）

## 需避免的反模式 (Anti-Patterns to Avoid)

1. **越级绕过层级**：专业代理未经咨询主管不得做出属于主管决策范围的决定。
2. **跨领域实现**：代理未经相关负责人的明确委派不得修改其指定区域之外的文件。
3. **暗箱决策**：所有决策必须文档化。无书面记录的口头协议会导致矛盾。
4. **单体式任务**：分配给代理的每个任务应在 1-3 天内可完成。若任务更大，必须先拆解细分。
5. **基于假设的实现**：若规格不明确，实现者必须询问规格制定者而非自行猜测。错误的猜测比提问代价更高。
