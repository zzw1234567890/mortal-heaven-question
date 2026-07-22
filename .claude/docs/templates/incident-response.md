
# 事件响应报告：Incident Response: [事件标题 Incident Title]

**严重级别 (Severity)**： [S1-Critical / S2-Major / S3-Moderate / S4-Minor]
**状态 (Status)**： [Active / Mitigated / Resolved / Post-Mortem Complete]
**检测时间 (Detected)**： [Date Time UTC]
**解决时间 (Resolved)**： [Date Time UTC or ONGOING]
**持续时间 (Duration)**： [Total time from detection to resolution]
**事件指挥官 (Incident Commander)**： [Name/Role]

---

## 影响总结 (Impact Summary)

[用 2-3 句话描述玩家经历了什么。从玩家视角而非技术视角撰写。]

- **受影响玩家 (Players affected)**： [estimated count or percentage]
- **受影响平台 (Platforms affected)**： [PC / Console / Mobile / All]
- **受影响区域 (Regions affected)**： [All / specific regions]
- **收入影响 (Revenue impact)**： [estimated if applicable]

---

## 时间线 (Timeline)

| 时间 (UTC) | 事件 | 已采取的行动 |
| ---- | ---- | ---- |
| [HH:MM] | 通过 [monitoring/player report/etc.] 检测到事件 | 已指派事件指挥官 |
| [HH:MM] | 已确定根本原因 | [简要说明原因] |
| [HH:MM] | 已部署缓解措施 | [已采取的措施] |
| [HH:MM] | 服务已恢复 / 修复已确认 | 持续监控以防复发 |
| [HH:MM] | 已宣布解除警报 | 已安排事后复盘 |

---

## 根本原因 (Root Cause)

### 发生了什么 (What Happened)
[根本原因的技术描述。具体说明导致事件的因果链。]

### 为何发生 (Why It Happened)
[系统性原因——说明现有流程、测试或防护措施为何未能阻止该事件。这比技术原因更重要。]

### 促成因素 (Contributing Factors)
- [因素 1 —— 例如："新匹配系统的负载测试不足"]
- [因素 2 —— 例如："监控告警阈值设置过高"]
- [因素 3]

---

## 缓解与解决 (Mitigation and Resolution)

### 即时措施（事件期间）(Immediate Actions)
1. [为阻止事态恶化采取的行动]
2. [为恢复服务采取的行动]
3. [为验证解决方案采取的行动]

### 后续措施（解决之后）(Follow-Up Actions)
1. [若即时措施仅为临时方案，此处为永久性修复]
2. [新增的测试或监控措施]
3. [为防止再次发生而进行的流程变更]

---

## 玩家沟通 (Player Communication)

### 初始确认 (Initial Acknowledgment)
*发送时间：[Time] 渠道：[channel]*
> [首次公开确认问题的确切文本]

### 状态更新 (Status Updates)
*发送时间：[Time] 渠道：[channel]*
> [每次后续更新的文本]

### 解决通知 (Resolution Notice)
*发送时间：[Time] 渠道：[channel]*
> [宣布修复及任何补偿的文本]

### 补偿（如适用）(Compensation)
- **补偿内容 (What)**： [补偿说明 —— 例如："500 高级货币 + 24 小时经验加成"]
- **适用对象 (Who)**： [所有玩家 / 仅受影响玩家 / 事件期间登录的玩家]
- **发放时间 (When)**： [交付日期和方式]
- **理由 (Rationale)**： [说明为何该补偿与影响程度相匹配]

---

## 预防 (Prevention)

### 我们正在改变的内容 (What We Are Changing)

| 行动项 (Action Item) | 负责人 (Owner) | 截止日期 (Deadline) | 状态 (Status) |
| ---- | ---- | ---- | ---- |
| [具体预防措施] | [Role] | [Date] | [TODO/Done] |
| [为 X 添加监控] | [Role] | [Date] | [TODO/Done] |
| [为 Y 增加测试覆盖] | [Role] | [Date] | [TODO/Done] |
| [更新 Z 的运行手册] | [Role] | [Date] | [TODO/Done] |

### 流程改进 (Process Improvements)
- [为预防类似事件进行的流程变更]
- [监控/告警改进]
- [测试改进]

---

## 经验教训 (Lessons Learned)

### 做得好的方面 (What Went Well)
- [事件响应的积极方面 —— 例如："由于监控告警，检测速度很快"]
- [积极方面]

### 做得不好的方面 (What Went Poorly)
- [响应过程中的问题 —— 例如："花了 20 分钟才找到正确的值班人员"]
- [问题]

### 我们侥幸之处 (Where We Got Lucky)
- [偶然而非设计降低了影响的因素 —— 这些是需要解决的隐藏风险]

---

## 签署确认 (Sign-Offs)

- [ ] 技术总监 (Technical Director) —— 根本原因准确，预防方案充分
- [ ] QA 主管 (QA Lead) —— 测试覆盖缺口已解决
- [ ] 制作人 (Producer) —— 时间线和沟通已审核
- [ ] 社区经理 (Community Manager) —— 玩家沟通已审核

---

*本文档存档于 `production/hotfixes/`，并在修复版本的发布说明中提供链接。*
