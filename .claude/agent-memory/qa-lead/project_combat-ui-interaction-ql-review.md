---
name: project-combat-ui-interaction-ql-review
description: combat-ui-interaction epic 9-story 分解 QL-STORY-READY 审查（2026-09-07）——2 ADEQUATE / 7 GAPS，10 项 BLOCKING 待裁决
metadata:
  type: project
---

2026-09-07 对 combat-ui-interaction epic 的 9 story 分解草案执行 QL-STORY-READY 对抗性审查。

**裁决**：008/009 ADEQUATE；001-007 GAPS。**10 项 BLOCKING**（story 写入前须裁决/修正）：

1. GDD 内部矛盾：§12 互斥用 MOUSE_FILTER_STOP，边界情况行 527 写 IGNORE——须按 §12/AC 裁决为 STOP 并修 GDD。
2. ESC 优先级仲裁未定义（UX"随时暂停" vs 牌库/攻击选择/战利品/撤退/备战的 ESC 关闭）。
3. 备战事件流撞车：006 草案 character_deployed/undeployed 每次点选发射 vs ADR-0016 setup_field 一次性部署 + layout 007 瞬态选择 + ADR-0031 §2。
4. 替换确认流未指定替换哪名已选角色（GDD/UX 均缺）。
5. 战斗日志展开/收起交互在 9 story 中无归属（建议并入 008）。
6. 攻击目标选择键盘/手柄路径缺失（UX #4/#9 有，005 草案无；己方攻击者键盘选择 UX 本身也缺）。
7. 数字键出牌目标子流程二义（UX"进入拖拽目标选择（或直接出牌到默认目标）"）+ >7 张时 1-7 映射。
8. Phase 3 手牌禁拖执行机制：锁栈 GAMEPLAY 粒度不区分出牌/选目标，需 UI 层阶段门控。
9. 撤退按钮"始终可点击" vs ANIMATION 锁阻止 GAMEPLAY 的动作类型归类。
10. Story 001 时序：引用 story 002-008 尚不存在的交互入口/弹窗——应收窄为机制+stub。

**Why**: 先例标准（[[project-qa-conventions]]）：GDD 矛盾须 story 创建前裁决；跨 epic 归属显式声明；确定性逻辑纯函数单测 BLOCKING。
**How to apply**: /create-stories combat-ui-interaction 时逐项核对 BLOCKING 是否已裁决；006/007 事件流须改为"UI 瞬态 + 确认时一次性系统 API 调用"。
