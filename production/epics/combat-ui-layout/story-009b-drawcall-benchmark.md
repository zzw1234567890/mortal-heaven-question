# Story 009b: R-02 Draw Call 满场实测关口（stub 版）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel（性能关卡）
> **Estimate**: 0.5d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-19（QL-STORY-READY 裁决修订：stub 版声明+R-02 provisional 关闭+双复测义务登记）

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 性能（非功能性）AC 5 条（Draw Call/帧时间/720p 字号/D3D12 烟雾）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§5 渲染预算）
**ADR Decision Summary**: R-02 红色风险关卡（epic DoD 锚定）——QL-STORY-READY 2026-09-07 验证策略裁决：DC 数可半自动化断言（本地关卡脚本，不进 CI 阻塞）；60fps 降级 advisory 人工签批；峰值场景用占位 stub（interaction 完成后复测）。

**Engine**: Godot 4.6 | **Risk**: HIGH（D3D12 默认渲染器；烟雾 4 项中拖拽半透明留待 interaction）
**Engine Notes**: D3D12 烟雾测试本 epic 覆盖 3/4 项（费用消散粒子/伤害数字淡出/阵法光环）——拖拽半透明归 interaction epic 完成后补测。

**Control Manifest Rules (this layer)**:
- Required: 实测记录 + 帧时间采样分布 + 主管签批
- Forbidden: 以理论估算替代实测
- Guardrail: 峰值场景（stub 版）与标准场景双测

---

## Acceptance Criteria

*From GDD 性能 AC，scoped to this story:*

- [ ] 标准战斗场景实测（16 角色位全满+7 张手牌+2 阵法+费用栏+日志折叠）——**本 sprint 为 stub 版：占位原型构造，见 Implementation Notes**：Draw Call ≤200（get_rendering_info 实测）
- [ ] 峰值场景实测（胜利结算+攻击箭头 stub+阵法光环+飘字+弹窗同时出现）——**stub 版**：Draw Call ≤200
- [ ] 标准场景帧时间 ≤16.6ms（60fps）——采样分布记录，人工签批（不进 CI）
- [ ] 1280×720 下所有 UI 文字 ≥12pt 中文——**stub 版以抽检占位文字字号代替**（font_size_responsive 模块归 story 001，Sprint 15 建立；组件级验证随 001-006 复测）
- [ ] D3D12 烟雾测试 3 项：费用消散粒子/伤害数字淡出/阵法光环——无 alpha 混合异常（拖拽半透明留待 interaction）
- [ ] fallback 优先级验证：模拟超预算时按优先级裁剪（日志→飘字→图标上限）
- [ ] R-02 风险**有条件关闭（provisional）**（PR-SPRINT 监督条件 #3）：stub 版实测结论记录 + presentation-layer-risks.md R-02 状态更新为「有条件关闭（stub 版原型级验证）」；**复测义务双登记**——① combat-ui-layout epic DoD（001-008 完成后组件级复测）② combat-ui-interaction epic（拖拽半透明+峰值场景含真实交互元素复测）

---

## Implementation Notes

*Derived from ADR-0031 §5 Implementation Guidelines:*

- 关卡脚本：本地运行（D3D12 窗口模式），构造标准/峰值两场景采样 DC 与帧时间——**不进 CI 阻塞关卡**（headless DC 不具代表性，QL-STORY-READY 裁决），结果记录 evidence。
- **stub 版声明**（QL-STORY-READY 2026-09-19）：本 sprint 执行的为 stub 版——标准/峰值场景由 009a 原型扩展的程序化占位节点构造（角色卡/手牌/阵法/费用栏均为占位原型，非 002-006 组件），实测结论为**原型级**，仅验证合批方案的架构可行性；组件级验证推迟至 001-008 完成后的 epic 关口复测（Sprint 15）。
- 峰值场景 stub：攻击箭头/拖拽态等 interaction 侧元素用占位节点模拟——**interaction epic 完成后复测**（写入其 epic 关口提示）。
- 帧时间：采样 60s 分布（p50/p95/p99），人工签批——flaky 帧级断言不写。
- R-02 provisional 关闭流程：stub 版实测结论写入 `production/risk-register/presentation-layer-risks.md`（R-02 状态更新为「有条件关闭（stub 版原型级验证）」）+ evidence 归档 + 复测义务双登记（epic DoD 关口 + interaction epic 关口）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009a: 合批方案定型（本 story 消费其测量方法与方案）
- interaction epic: 拖拽半透明 D3D12 烟雾项 + 峰值场景复测（其 epic 关口）
- 60fps 的 CI 化：明确排除（flaky）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Visual/Feel — manual verification steps（本地关卡脚本辅助）]:**

- **AC-1**: 标准场景 DC 关口（stub 版）
  - Setup: 16 位满场+7 手牌+阵法+费用栏+日志折叠——**占位原型构造**（009a 原型扩展），D3D12 窗口模式
  - Verify: 连续 60 帧 DC 采样 ≤200
  - Pass condition: 稳定值 ≤200（非瞬时尖峰），记录归档；实测结论标注「原型级」

- **AC-2**: 峰值场景 DC 关口（stub 版）
  - Setup: 标准场景 + 结算面板+箭头 stub+光环+飘字满发
  - Verify: DC ≤200
  - Pass condition: 稳定值 ≤200；超预算时 fallback 优先级按序生效

- **AC-3**: 帧时间与烟雾
  - Setup: 标准场景运行 60s
  - Verify: p95 帧时间 ≤16.6ms；费用粒子/飘字淡出/光环三项 D3D12 视觉正常
  - Pass condition: 帧时间分布记录+签批；三项烟雾截图无异常

- **AC-4**: 720p 字号
  - Setup: 1280×720 运行
  - Verify: 占位文字抽检 ≥12pt（stub 版——font_size_responsive 模块归 story 001，Sprint 15）
  - Pass condition: 抽检 HP/ATK/阶段名/日志占位文字；组件级验证随 001-006 复测

---

## Test Evidence

**Story Type**: Visual/Feel（性能关卡）
**Required evidence**:
- `production/qa/evidence/r02-benchmark-evidence.md`（两场景 DC 实测+帧时间分布+烟雾记录）+ sign-off
- `production/risk-register/presentation-layer-risks.md` R-02 状态更新

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009a（测量方法 + 合批方案原型）
- Unlocks: interaction epic 进入（峰值场景复测留给其关口）；**Sprint 15 story 001-008 完成后的组件级复测**（epic DoD 锚定——复测义务已双登记）
