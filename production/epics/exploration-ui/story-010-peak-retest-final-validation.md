# Story 010: 峰值复测与全流程终验

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel（性能收口+终验）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 性能（非功能性）AC 4 条剩余部分（720p 自适应/弹窗模糊帧率终验）+ EPIC DoD（11 界面闭环可演示）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§5 渲染预算）
**ADR Decision Summary**: R-05 收口——story 001 stub 基准替换为真实交互元素复测；720p 下限分辨率自适应验证；键盘/手柄全路径终验（002-009 控件已内建焦点——A3，本 story 只验不改）。

**Engine**: Godot 4.6 | **Risk**: HIGH（D3D12 默认渲染器）
**Engine Notes**: DC/帧时间测量沿用 story 001 方法；D3D12 须窗口模式本地运行——不进 CI 阻塞关卡。

**Control Manifest Rules (this layer)**:
- Required: 实测记录 + 主管签批；与 story 001 stub 基准对照（真实元素增量分析）
- Forbidden: 以 stub 数据充当真实元素复测（本 story 存在的理由）
- Guardrail: 帧时间采样 60s 分布（p50/p95/p99）人工签批

---

## Acceptance Criteria

*From GDD 性能 AC + EPIC DoD，scoped to this story:*

- [ ] 标准探索场景（节点图 12 节点+行动力指示器+卡组查看面板）D3D12 实测 DC ≤200（真实元素版，对照 001 stub 基准）
- [ ] 帧时间 ≤16.6ms（60fps）——含缩放平移+移动动画+揭雾+弹窗模糊的混合操作场景
- [ ] 1280×720 分辨率：节点图（13 格行动力+12 节点）所有元素可见且不溢出屏幕（节点间距自适应+图标按比例缩小——GDD 边界情况）
- [ ] 节点弹窗背景实时模糊 40% 帧率 ≥60fps（006 已抽查——本 story 终验全部弹窗类型）
- [ ] 11 界面闭环演示：地图选择→节点图→节点交互（五类弹窗）→Boss 确认→战斗切换→返回恢复→通关结算/探索结束→新地图解锁→状态概览/卡组查看
- [ ] 键盘全路径：方向键节点跳转+Enter 移动+Tab 焦点循环（顶部条→可达节点→HUD 入口）+ESC 弹窗关闭
- [ ] 手柄全路径：磁性光标节点选择+LB/RB 缩放+A/B 确认取消——无鼠标完成完整探索流程
- [ ] 「减少动态」终验：揭雾瞬时揭示+AP 危急静态红边框+弹窗动画简化
- [ ] R-05 风险状态收口：presentation-layer-risks.md 更新 + evidence 归档

---

## Implementation Notes

*Derived from ADR-0031 §4/§5:*

- 复测场景构造：复用 story 001 的本地关卡脚本，替换为真实探索系统数据+全部交互元素。
- 720p 自适应：验证 GDD 边界情况「节点间距自动调整+图标按比例缩小」——若超标（拥挤/溢出）记录问题并回填对应 story 返工（本 story 无代码产出预期，同 combat-ui 009 模式）。
- 键盘/手柄：A3 裁决——002-009 控件已内建焦点，本 story 只做路径验证；发现缺口回填对应 story。
- 11 界面闭环：准备一个可演示存档（多地图+突破前状态），走查全程录屏归档。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: stub 版基准（本 story 为真实元素对照）
- 性能优化实施（若超标——回填问题给对应 story 返工）
- 60fps 的 CI 化（明确排除——flaky，同 combat-ui 009 裁决）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Visual/Feel — manual verification steps（本地关卡脚本辅助）]:**

- **AC-1**: 真实元素性能复测
  - Setup: 标准探索场景+混合操作（缩放/移动/揭雾/弹窗模糊），D3D12 窗口模式
  - Verify: 60s 采样 DC ≤200 + 帧时间 p95 ≤16.6ms
  - Pass condition: 双指标达标；超标项定位并回填对应 story

- **AC-2**: 720p 自适应
  - Setup: 1280×720 分辨率，13 格 AP+12 节点
  - Verify: 全元素可见不溢出；节点间距/图标自适应生效
  - Pass condition: 截图对照 + 签批

- **AC-3**: 全路径终验
  - Setup: 可演示存档（键盤断电鼠标、手柄断电鼠标两种模式）
  - Verify: 键盘/手柄各完成一次 11 界面闭环（含减少动态开关）
  - Pass condition: 双输入路径走查通过 + 录屏归档 + 签批

---

## Test Evidence

**Story Type**: Visual/Feel（性能收口+终验）
**Required evidence**:
- `production/qa/evidence/exploration-ui-final-evidence.md`（真实元素 DC/帧时间分布+720p 截图+双输入录屏）+ sign-off
- `production/risk-register/presentation-layer-risks.md` R-05 收口更新
- story 001 基准 evidence 补充真实元素对照数据

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001-009（全部前置完成）
- Unlocks: presentation-layer 探索侧里程碑收口（R-05 风险关闭）
