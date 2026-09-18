---
name: hud-story004-ql-review
description: hud Story 004（通知系统）QL-STORY-READY 对抗审查 2026-09-10——GAPS 8 项（4 BLOCKING：时间注入 API 缺失、全重要裁决未锁、映射表零测试规格、战斗事件双色不可表达）
metadata:
  type: project
---

hud Story 004（通知/提示系统）QL-STORY-READY full 模式审查（2026-09-10）：**GAPS（8 项，4 BLOCKING）**——主审 21 项全过但漏了接口层缺口。

BLOCKING（实现开始前必须修复）：
1. **时间注入 API 未定义**——AC-1「时间推进 3s」无接口；NotificationStack 只有 push。项目先例：`src/core/status_effect/status_effect_system.gd` L240 `tick_all()` 离散步进。修复：`advance(delta_seconds)` 显式方法，UI Timer 调用同一入口。
2. **全重要满队裁决推迟给实现者**（story L46「允许临时超限或按实现定义的确定性规则」）+ 未定义「队列全重要时 push 普通通知」的行为（按字面规则会丢弃刚 push 的自己——荒谬）。
3. **类型→(时长,颜色,重要) 映射零自动化测试规格**——AC 列表第 5 条在 QA Test Cases 中无对应条目；story-003 先例是 7 类型全值表测试。
4. **战斗事件双色**（GDD 类型表「红色/蓝色」）无法用 type→单色映射表达——需裁决（可选参数/细分类型/锁定单色）。

HIGH：dismiss 接口与 push 返回值（id）未定义；颜色应返回 String 标识而非 Color（先例 LingshiFormatter），错误提示「红色闪烁」需 blink 标志。MEDIUM：通知请求接口（story L48）无验收归属、无 ADR-0007 信号分类。LOW：t=duration 恰好边界。

**Why:** 接口形状（时间步进、id、映射返回类型）是实现者无法自行裁决且测试规格依赖的契约——左移关卡应在实现前锁死。

**How to apply:** 复审 story-004 时核对 8 项修复文本是否写入 story（尤其 Implementation Notes 的接口定义与 AC-2/AC-6 规格修订）；实现后 QL-TEST-COVERAGE 时核对测试是否经 advance() 注入时间而非真实等待。

相关：[[hud-story003-ql-test-coverage]] [[qa-lead-working-conventions]]

**后续（2026-09-11 QL-TEST-COVERAGE）**：前次 G1-G8 裁决落地核验 **ADEQUATE**——Logic/Integration 双 BLOCKING 关卡通过（unit 77/77 + integration 43/43 全绿）。G8 边界（t=duration 恰达/差 0.01）、G2 全重要拒收、G4 战斗双子类型、未知类型安全默认均有专项测试函数。遗留：AC-5 视觉项 ADVISORY 证据文档 `production/qa/evidence/notification-stack-evidence.md` 未创建，冲刺评审签批前需补。
