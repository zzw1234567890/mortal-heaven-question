# Story 009: 辅助面板（新地图解锁提示/地图状态概览/卡组查看）

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 新地图解锁 3 条 AC + 地图状态 2 条 AC + 卡组查看 3 条 AC
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（地图统计数据从探索系统读取；卡组列表从卡牌系统读取）；筛选/排序为瞬态交互状态（ADR-0031 §2.1——UI 本地合法持有）；「不可编辑」由只读消费满足。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 新地图解锁弹窗 3s 自动关闭（调优 2~5s）+ 卡片翻转 0.5s；地图状态/卡组面板打开期间节点图输入冻结。

**Control Manifest Rules (this layer)**:
- Required: 面板内容按需读取（打开时构建，关闭时释放）；地图状态数据（难度/层数/击败数/收集统计/到 Boss 步数）全部从探索系统 API 读取
- Forbidden: 卡组查看提供任何编辑入口（探索中只读）；UI 计算统计数值
- Guardrail: 卡组网格渲染 DC 计入预算（≤30 卡牌+筛选标签）

---

## Acceptance Criteria

*From GDD 新地图解锁/地图状态/卡组查看 AC，scoped to this story:*

- [ ] 突破新境界回到探索 → 新地图解锁提示弹出（地图名列表+「前往查看」按钮，3s 自动关闭）
- [ ] 多张地图同时解锁 → 列表形式展示全部
- [ ] 点击「前往查看」→ 跳转地图选择界面（新地图 ⭐NEW 标记——002 卡片渲染协作）
- [ ] 点击信息按钮 → 地图状态概览面板（当前地图+难度+层数+击败节点数+收集统计+当前节点+到Boss步数）
- [ ] 地图状态面板「关闭」→ 返回节点图
- [ ] 探索中点击 HUD 卡组图标 → 打开卡组浏览 overlay（**界面本体由 deck-editing-ui story 005 实现**——2026-09-08 B8 裁决：本 story 仅提供探索侧入口与打开/关闭调用，不实现网格/筛选/排序/详情）
- [ ] 卡组浏览计数分母为境界上限（境界系统返回值，非硬编码 30）
- [ ] 卡组浏览关闭后返回节点图

> **2026-09-08 B8 裁决改写说明**：原 AC「卡组查看网格展示/筛选/排序/详情」移交 deck-editing-ui story 005（卡组浏览界面本体——含历史标签）。本 story 缩窄为：入口触发 + overlay 打开调用 + 关闭返回节点图。若 deck-editing-ui 尚未实现，本 AC 以 stub overlay（空面板）验证入口通路，界面验收归 deck-editing-ui 005。

---

## Implementation Notes

*Derived from ADR-0031 §2.1 + qa-lead 裁决（story 009 ADEQUATE）:*

- 三个面板互相独立（可同 story 实现——均为只读辅助面板，交互模式同族：打开→浏览→关闭）。
- 筛选/排序状态为瞬态交互状态（UI 本地字典）——面板关闭即弃（不持久化、不写 GSM）。
- 卡组数据：卡牌系统 API 只读快照（打开时拉取）；卡牌详情弹窗复用交互模式库-卡牌详情（combat-ui 悬停详情先例）。
- 新地图解锁触发时机（UX OQ#7——突破动画后 vs 通关结算后两入口）：按探索系统/渡劫系统信号驱动（事件监听），两入口都接——具体优先级不阻塞本 story（弹窗为幂等展示）。
- 地图状态「到Boss步数」：探索系统 API 按需查询（同 004 悬停详情数据源）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 地图选择卡片本体与 NEW 标记渲染（本 story 只做解锁提示弹窗+跳转）
- deck-editing-ui story 005: 卡组浏览界面本体（网格/筛选/排序/详情/历史标签——2026-09-08 B8 裁决：本 story 仅入口）
- 探索系统域: 解锁判定与统计数据源

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[UI — manual verification steps]:**

- **AC-1**: 新地图解锁提示
  - Setup: 存档含突破后待解锁地图（单张与多张两种）
  - Verify: 弹窗列表完整性、3s 自动关闭、「前往查看」跳转+NEW 标记
  - Pass condition: 双场景走查通过 + 签批

- **AC-2**: 地图状态概览
  - Setup: 探索中（有击败节点与收集数据）
  - Verify: 面板七项数据与探索系统查询值一致（抽查对照）
  - Pass condition: 数据一致 + 打开期间节点图冻结 + 关闭返回

- **AC-3**: 卡组查看入口（2026-09-08 B8 裁决缩窄后）
  - Setup: 探索中的存档
  - Verify: HUD 卡组图标点击打开 overlay、计数分母为境界系统返回值（非硬编码 30）、关闭返回节点图
  - Pass condition: 入口通路正确 + 界面本体验收归 deck-editing-ui 005（本 story 不验网格/筛选/排序/详情）

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/auxiliary-panels-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003（节点图宿主与输入冻结基建）
- Unlocks: Story 010（终验走查含三面板）
