# 目录结构 (Directory Structure)


```text
/
├── CLAUDE.md                    # 主配置文件 (Master configuration)
├── .claude/                     # 代理定义、技能、钩子、规则、文档 (Agent definitions, skills, hooks, rules, docs)
├── src/                         # 游戏源代码（核心、玩法、AI、网络、UI、工具）
├── assets/                      # 游戏资源（美术、音频、VFX、着色器、数据）
├── design/                      # 游戏设计文档（GDD、叙事、关卡、平衡）
├── docs/                        # 技术文档（架构、API、事后分析）
│   └── engine-reference/        # 精选引擎 API 快照（版本锁定）
├── tests/                       # 测试套件（单元、集成、性能、试玩测试）
├── tools/                       # 构建与管线工具（CI、构建、资源管线）
├── prototypes/                  # 一次性原型（与 src/ 隔离）
└── production/                  # 生产管理（冲刺、里程碑、发布）
    ├── session-state/           # 临时会话状态（active.md — gitignored）
    └── session-logs/            # 会话审计跟踪 (gitignored)
```
