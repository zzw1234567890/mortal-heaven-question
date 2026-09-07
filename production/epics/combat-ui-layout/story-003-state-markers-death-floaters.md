# Story 003: 角色状态标记切换、阵亡处理与飘字

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Integration 核心）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 角色状态视觉标记 AC（待命/已行动）+ HP条与视觉反馈 AC（批量过渡/阵亡）+ 动画表（伤害/治疗飘字）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权；系统信号驱动的显示动画（无用户输入——QL-STORY-READY 2026-09-07 裁决归本 story）。HP 批量结算直达终值一次过渡。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 飘字（伤害红色下落/治疗绿色上浮 0.5s）用 Label + Tween 池化（防 12+ 同帧飘字节点风暴——R-02 峰值估算中飘字计项，需池化或按 009a 方案合并）。

**Control Manifest Rules (this layer)**:
- Required: HP 批量过渡断言（可自动化的确定性部分）；飘字池化
- Forbidden: 逐次伤害串行播放过渡动画
- Guardrail: 同帧 12+ 飘字不产生节点风暴（池上限）

---

## Acceptance Criteria

*From GDD，scoped to this story:*

- [ ] 待命角色：头像外圈沙漏标记 + HP 条上方「待命」文字（上场系统信号驱动切换）
- [ ] 已行动角色：灰色遮罩 + 「已行动」标记
- [ ] 同一目标连续多次伤害：HP 条直接过渡到最终值一次（不串行多次）
- [ ] 角色阵亡（HP=0）：碎裂+光点消散动画 0.5s → 角色移除 → 阵位变空位（虚线框）
- [ ] 场上角色全灭立即切结算面板（不逐个播阵亡动画）
- [ ] 伤害飘字：红色数字从目标位置飘出下落消失 0.5s；治疗飘字绿色上浮消失 0.5s
- [ ] 阵亡动画+空位+飘字均有减少动态替代（直接淡出/直接显示）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- 待命/已行动切换：消费上场系统信号（角色行动状态变更），驱动 story 002 已渲染的 L5 标记节点——**本 story 实现状态机映射（信号→标记显示），渲染节点在 002**。
- HP 批量过渡：伤害入队后在下一帧合并计算终值，仅创建一次 Tween（GDD 公式 3 阈值理由段）。12+ 同时 Tween 若掉帧改共享 lerp 管理器（GDD 已备方案）。
- 阵亡流程：HP=0 信号 → 动画 0.5s → 移除节点 → 显示空位虚线框。全灭短路：任一方全灭时跳过动画直接触发结算信号（结算面板本体归 008）。
- 飘字池：预创建 Label 池（上限如 16），复用而非每帧实例化。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 角色卡组件本体与 L5 标记渲染节点
- Story 008: 结算面板本体（全灭信号的目标端）
- interaction epic: 攻击结算的受击闪白交互联动
- 音效（阵亡消散音/命中声）：audio-manager epic

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: HP 批量过渡（BLOCKING，`tests/integration/combat_ui/test_hp_batch_transition.gd`）
  - Given: 同一目标连续 3 次伤害入队
  - When: 结算帧处理
  - Then: 仅创建一次 Tween 且终值为最终 HP
  - Edge cases: 伤害+治疗混合（终值代数和）；伤害致死（终值 0 + 阵亡流程触发）

- **AC-2**: 待命/已行动信号映射
  - Given: 角色处于待命
  - When: 上场系统发射行动状态变更信号
  - Then: 标记切换为对应视觉态
  - Edge cases: 同帧信号多次（最终态生效）

- **AC-3**: 全灭短路
  - Given: 最后一个敌方角色 HP 将归零
  - When: 伤害结算
  - Then: 不播放阵亡动画序列，结算信号立即触发
  - Edge cases: 双方同时全灭（按战斗系统规则裁定，UI 不自行决定）

**[UI — manual verification steps]:**

- **AC-4**: 阵亡动画与飘字
  - Setup: 战斗中造成伤害与角色阵亡
  - Verify: 伤害红色飘字下落 0.5s/治疗绿色上浮；阵亡碎裂消散 0.5s 后空位虚线框
  - Pass condition: 动画流畅、12+ 同帧飘字无卡顿、减少动态开关生效

---

## Test Evidence

**Story Type**: UI（Integration 核心）
**Required evidence**:
- Integration: `tests/integration/combat_ui/test_hp_batch_transition.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/character-state-death-evidence.md` + sign-off（录屏）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（角色卡组件与 L5 标记节点）
- Unlocks: Story 008（全灭信号→结算面板）
