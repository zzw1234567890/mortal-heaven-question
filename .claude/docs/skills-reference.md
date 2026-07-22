
# 可用技能（斜杠命令）

按阶段组织的 73 个斜杠命令。在 Claude Code 中键入 `/` 即可访问其中任何一个。

## 入门引导与导航

| 命令 | 用途 |
|---------|---------|
| `/start` | 首次使用引导——询问您当前状态，然后引导您进入正确的工作流程 |
| `/help` | 上下文感知的「我下一步该做什么？」——读取当前阶段并展示所需的下一步操作 |
| `/project-stage-detect` | 完整项目审计——检测阶段、识别存在性缺口、推荐后续步骤 |
| `/setup-engine` | 配置引擎 + 版本、检测知识缺口、填充版本感知的参考文档 |
| `/adopt` | 棕地格式审计——检查现有 GDD/ADR/story 文件的内部结构，生成迁移计划 |

## 游戏设计

| 命令 | 用途 |
|---------|---------|
| `/brainstorm` | 引导式创意生成，使用专业工作室方法（MDA、SDT、Bartle、动词优先） |
| `/map-systems` | 将游戏概念拆解为系统，映射依赖关系，优先排序设计顺序 |
| `/design-system` | 针对单个游戏系统的引导式、逐章节 GDD 编写 |
| `/quick-design` | 小型变更的轻量级设计规格——调优、微调、小幅度新增 |
| `/review-all-gdds` | 跨所有设计文档的跨 GDD 一致性和游戏设计整体性审查 |
| `/propagate-design-change` | 当 GDD 被修订时，找到受影响的 ADR 并生成影响报告 |

## 美术与资产

| 命令 | 用途 |
|---------|---------|
| `/art-bible` | 引导式、逐章节的艺术圣经编写——在资产制作开始前创建视觉身份规格 |
| `/asset-spec` | 根据 GDD、关卡文档或角色档案生成逐资产的视觉规格和 AI 生成提示词 |
| `/asset-audit` | 审计资产的命名规范、文件大小预算和管线合规性 |

## 用户体验与界面设计

| 命令 | 用途 |
|---------|---------|
| `/ux-design` | 引导式、逐章节的用户体验规格编写（屏幕/流程、HUD 或模式库） |
| `/ux-review` | 验证用户体验规格是否符合 GDD 对齐性、可访问性和模式合规性 |

## 架构

| 命令 | 用途 |
|---------|---------|
| `/create-architecture` | 引导式编写主架构文档 |
| `/architecture-decision` | 创建架构决策记录 (ADR) |
| `/architecture-review` | 验证所有 ADR 的完整性、依赖顺序和 GDD 覆盖度 |
| `/create-control-manifest` | 从已接受的 ADR 生成程序员规则清单 |

## 故事与冲刺

| 命令 | 用途 |
|---------|---------|
| `/create-epics` | 将 GDD + ADR 转化为史诗（Epic）——每个架构模块一个 |
| `/create-stories` | 将单个史诗拆解为可实现的 story 文件 |
| `/dev-story` | 读取 story 并实现——路由到正确的程序员代理 |
| `/sprint-plan` | 生成或更新冲刺计划；初始化 sprint-status.yaml |
| `/sprint-status` | 快速 30 行冲刺快照（读取 sprint-status.yaml） |
| `/story-readiness` | 验证 story 是否已经准备好可供实现（READY/NEEDS WORK/BLOCKED） |
| `/story-done` | 实现后的 8 阶段完成审查；更新 story 文件，展示下一个 story |
| `/estimate` | 结构化工作量估算，包含复杂性、依赖项和风险分解 |

## 审查与分析

| 命令 | 用途 |
|---------|---------|
| `/design-review` | 审查游戏设计文档的完整性和一致性 |
| `/code-review` | 对文件或变更集进行架构级代码审查 |
| `/balance-check` | 分析游戏平衡数据、公式和配置——标记异常值 |
| `/content-audit` | 审计 GDD 指定的内容数量与已实现内容的对比 |
| `/scope-check` | 分析功能或冲刺范围与原计划的对比，标记范围蔓延 |
| `/perf-profile` | 结构化性能分析，识别瓶颈 |
| `/tech-debt` | 扫描、跟踪、优先级排序和报告技术债务 |
| `/gate-check` | 验证在开发阶段之间推进的准备工作（PASS/CONCERNS/FAIL） |
| `/consistency-check` | 扫描所有 GDD 与实体注册表，检测跨文档不一致（相互矛盾的属性、名称、规则） |
| `/security-audit` | 审计游戏的安全漏洞：存档篡改、作弊向量、网络攻击、数据泄露和输入验证缺口 |

## 质量保证与测试

| 命令 | 用途 |
|---------|---------|
| `/qa-plan` | 为冲刺或功能生成 QA 测试计划 |
| `/smoke-check` | 在 QA 移交前运行关键路径冒烟测试门禁 |
| `/soak-test` | 为长时间游戏会话生成浸泡测试方案 |
| `/regression-suite` | 映射测试覆盖到 GDD 关键路径，识别缺少回归测试的已修复缺陷 |
| `/test-setup` | 为项目引擎搭建测试框架和 CI/CD 管道 |
| `/test-helpers` | 为测试套件生成引擎特定的测试辅助库 |
| `/test-evidence-review` | 对测试文件和手动证据文档进行质量审查 |
| `/test-flakiness` | 从 CI 运行日志中检测非确定性（不稳定）测试 |
| `/skill-test` | 验证技能文件的结构合规性和行为正确性 |
| `/skill-improve` | 使用测试-修复-重测循环改进技能——诊断、提出修复、重写、验证 |

## 生产

| 命令 | 用途 |
|---------|---------|
| `/milestone-review` | 审查里程碑进度并生成状态报告 |
| `/retrospective` | 运行结构化的冲刺或里程碑回顾 |
| `/bug-report` | 创建结构化的缺陷报告 |
| `/bug-triage` | 读取所有未关闭缺陷，重新评估优先级与严重性，分配负责人和标签 |
| `/reverse-document` | 从现有实现生成设计或架构文档 |
| `/playtest-report` | 生成结构化的游玩测试报告或分析现有的游玩测试笔记 |

## 发布

| 命令 | 用途 |
|---------|---------|
| `/release-checklist` | 生成并验证当前构建的预发布检查清单 |
| `/launch-checklist` | 跨所有部门的完整发布就绪验证 |
| `/changelog` | 从 Git 提交和冲刺数据自动生成变更日志 |
| `/patch-notes` | 从 Git 历史和内部数据生成面向玩家的补丁说明 |
| `/hotfix` | 带审计追踪的热修复工作流，绕过正常的冲刺流程 |
| `/day-one-patch` | 为黄金主版本之后但在公开发布之前或之时发现的已知问题准备首日补丁 |

## 创意与内容

| 命令 | 用途 |
|---------|---------|
| `/prototype` | 概念原型——头脑风暴后立即制作可丢弃的构建，以验证核心想法（阶段 1） |
| `/vertical-slice` | 预生产验证——在投入全面生产之前，制作生产品质的端到端构建（阶段 4） |
| `/onboard` | 为新贡献者或代理生成上下文相关的入门文档 |
| `/localize` | 本地化工作流：字符串提取、验证、翻译准备 |

## 团队编排

在单个功能领域协调多个代理：

| 命令 | 协调对象 |
|---------|-------------|
| `/team-combat` | 游戏设计师 (game-designer) + 玩法程序员 (gameplay-programmer) + AI 程序员 (ai-programmer) + 技术美术 (technical-artist) + 音效设计师 (sound-designer) + QA 测试员 (qa-tester) |
| `/team-narrative` | 叙事总监 (narrative-director) + 编剧 (writer) + 世界构建师 (world-builder) + 关卡设计师 (level-designer) |
| `/team-ui` | 用户体验设计师 (ux-designer) + UI 程序员 (ui-programmer) + 美术总监 (art-director) + 无障碍专家 (accessibility-specialist) |
| `/team-release` | 发布经理 (release-manager) + QA 主管 (qa-lead) + 运维工程师 (devops-engineer) + 制作人 (producer) |
| `/team-polish` | 性能分析师 (performance-analyst) + 技术美术 (technical-artist) + 音效设计师 (sound-designer) + QA 测试员 (qa-tester) |
| `/team-audio` | 音频总监 (audio-director) + 音效设计师 (sound-designer) + 技术美术 (technical-artist) + 玩法程序员 (gameplay-programmer) |
| `/team-level` | 关卡设计师 (level-designer) + 叙事总监 (narrative-director) + 世界构建师 (world-builder) + 美术总监 (art-director) + 系统设计师 (systems-designer) + QA 测试员 (qa-tester) |
| `/team-live-ops` | 运营设计师 (live-ops-designer) + 经济设计师 (economy-designer) + 社区经理 (community-manager) + 分析工程师 (analytics-engineer) |
| `/team-qa` | QA 主管 (qa-lead) + QA 测试员 (qa-tester) + 玩法程序员 (gameplay-programmer) + 制作人 (producer) |
