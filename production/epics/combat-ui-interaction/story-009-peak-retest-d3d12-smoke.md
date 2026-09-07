# Story 009: 峰值场景复测与拖拽 D3D12 烟雾（R-01/R-02 收口）

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel（性能关卡收口）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 性能（非功能性）AC 5 条中 interaction 侧留白项（拖拽半透明第 4 项烟雾 + 峰值场景真实元素复测）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§4 双焦点/§5 渲染预算）
**ADR Decision Summary**: R-01 双焦点行为在真实交互流程中的回归验证；R-02 峰值场景 stub 替换为真实交互元素后复测（layout 009b 关口的补充收口——其 epic 关口提示）。

**Engine**: Godot 4.6 | **Risk**: HIGH（D3D12 默认渲染器）
**Engine Notes**: DC 测量沿用 layout 009a 核验的 `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` 方法；D3D12 须窗口模式本地运行。

**Control Manifest Rules (this layer)**:
- Required: 实测记录 + 主管签批；DC 数据回填 layout 009b 基准表
- Forbidden: 以 stub 实测替代真实元素复测（本 story 存在的理由）
- Guardrail: 帧时间采样 60s 分布（p50/p95/p99）人工签批

---

## Acceptance Criteria

*From GDD 性能 AC + layout 009b 留白项，scoped to this story:*

- [ ] 峰值场景复测（真实元素版）：胜利结算面板+真实攻击箭头（story 005）+阵法光环+飘字满发+拖拽中状态（story 003）同时出现——DC ≤200（替换 layout 009b 的 stub 版数据）
- [ ] 拖拽半透明 D3D12 烟雾：modulate.a 三档 0.3/0.5/0.7 的拖拽中卡牌在 D3D12 下无 alpha 混合异常（009b 留白的第 4 项）
- [ ] R-01 双焦点回归：焦点环/悬停双视觉在真实交互流程（拖拽/目标选择/焦点循环）中行为正确——spike 结论未被业务实现破坏
- [ ] 全量输入回归：锁栈/ESC 仲裁/排队基建（story 001）在全部交互 story 完成后的端到端验证——弹窗冻结/ESC 归属/撤退排队无回归
- [ ] 手柄全流程终验：无鼠标完成「备战→出牌→目标选择→结算」完整战斗
- [ ] R-01/R-02 风险状态更新：presentation-layer-risks.md 收口记录 + evidence 归档
- [ ] DC 数据回填：layout 009b 的 r02-benchmark-evidence.md 补充真实元素版峰值数据

---

## Implementation Notes

*Derived from ADR-0031 §4/§5 Implementation Guidelines:*

- 复测场景构造：复用 layout 009b 的本地关卡脚本，将 stub 替换为真实交互元素（攻击箭头连线/拖拽跟随卡牌/弹窗）。
- 本地运行（D3D12 窗口模式）——不进 CI 阻塞关卡（同 layout 009b 策略）。
- 双焦点回归：对照 R-01 spike 的验证清单逐项走查（焦点环视觉/悬停优先级/设备独立判定）。
- 本 story 无代码产出预期（若实测超标，修复归对应组件 story 的返工——本 story 记录问题并上报）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- layout story 009b: 标准场景 DC 基准与首批峰值数据（本 story 仅补真实元素版）
- 性能优化实施（若超标——回填问题给对应 story 返工）
- 60fps 的 CI 化（明确排除——flaky）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Visual/Feel — manual verification steps（本地关卡脚本辅助）]:**

- **AC-1**: 峰值复测 DC
  - Setup: 峰值场景（真实元素版），D3D12 窗口模式
  - Verify: 连续 60 帧 DC 采样 ≤200
  - Pass condition: 稳定值 ≤200；超标项定位并回填对应 story

- **AC-2**: 拖拽三档烟雾
  - Setup: 阶段 2 拖拽卡牌，分别固定 modulate.a=0.3/0.5/0.7
  - Verify: D3D12 下无 alpha 混合异常（截图对比）
  - Pass condition: 三档视觉正常，evidence 截图归档

- **AC-3**: 双焦点与输入回归
  - Setup: 完整战斗流程（含暂停/弹窗/拖拽/目标选择）
  - Verify: R-01 spike 清单逐项通过；ESC 仲裁/弹窗冻结/排队无回归
  - Pass condition: 手柄全流程走查通过 + 签批

---

## Test Evidence

**Story Type**: Visual/Feel（性能关卡收口）
**Required evidence**:
- `production/qa/evidence/r01-r02-closeout-evidence.md`（峰值真实元素版 DC+三档烟雾+双焦点回归）+ sign-off
- `production/risk-register/presentation-layer-risks.md` R-01/R-02 收口更新
- layout 009b 的 evidence 补充回填

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001-008（全部交互 story 完成）、layout story 009b（基准脚本与首批数据）
- Unlocks: presentation-layer 里程碑收口（R-01/R-02 风险关闭）
