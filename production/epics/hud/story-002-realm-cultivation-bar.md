# Story 002: 境界+修为条组件（左上）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1.0d（sprint-13 S13-3）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-09（QL-STORY-READY GAPS 裁决修订——8 项缺口落地）

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-001 / AC-hud-002 / AC-hud-003
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（UI 只读）；事件驱动更新（Cat 1 信号 `realm_changed` / `batch_updated`）；阈值类确定性逻辑提取为纯函数单测（Logic 内核模式）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 本组件交互仅鼠标悬停 tooltip，无键盘/手柄焦点需求。悬停检测用 Control 内建 mouse_filter，不涉及 4.6 双焦点 API。

**Control Manifest Rules (this layer)**:
- Required: 阈值/状态判定逻辑提取为纯函数（可单测），UI 节点只消费判定结果
- Forbidden: UI 脚本内联硬编码游戏数值（阈值必须来自数据驱动配置）
- Guardrail: 修为条平滑填充动画 0.3s 内完成，不得逐帧重绘整条

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story（含 2026-09-09 QL-STORY-READY 裁决修订）:*

- [ ] 所有 HUD 可见场景显示当前境界名称 + 修为进度条（AC-hud-001）
- [ ] 修为≥90% 时进度条金色脉动动画（AC-hud-002——脉动呼吸周期 1.0s，design/ux/hud.md L186）
- [ ] 修为满（current == max_val）时显示「可突破！」文字提示（GDD L66——G3 裁决补入 scope；与 ≥90% 脉动为两个不同触发点：90% 起脉动、100% 满加文字）
- [ ] 炼气·落难状态境界名称显示「炼气·落难」+ 破碎光效（AC-hud-003；破碎光效**替代**脉动——design/ux/hud.md L189，落难时 pulsing=false）
- [ ] 进度条颜色：<50% 蓝色、50~90% 紫色、≥90% 金色
- [ ] 鼠标悬停显示具体数值（如 1800/2250）
- [ ] 化神期满修为显示「可飞升」替代进度条
- [ ] 修为条平滑填充动画 0.3s（G5 裁决：以 GDD hud-system.md L254 为准——与 design/ux/hud.md L195 的 0.4s 冲突已裁决为 0.3s，UX 文档待同步修订）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines（含 2026-09-09 QL-STORY-READY 裁决修订）:*

**Logic 内核（BLOCKING 单测目标）**：`get_cultivation_bar_state(realm_id, realm_name, is_fallen, current, max_val) -> Dictionary` 纯函数，返回 `{color: "blue"|"purple"|"gold", pulsing: bool, label: String, show_bar: bool, breakthrough_hint: bool}`。阈值（50%/90%）来自数据驱动配置常量。该函数是本 story 的必测逻辑内核——UI 节点只消费其返回值。[br]
**签名说明（G2 裁决）**：`realm_name: String` 为第 2 参数——正常态 label 显示传入的境界名称（如「金丹期」，来源 RealmSystem 静态数据，由 UI 节点读取后传入——纯函数不访问 Autoload）；`breakthrough_hint`（G3 裁决）：current == max_val 且非化神期时 true（化神期满由 show_bar=false + label「可飞升」接管）。[br]
**落难语义（G7 裁决）**：is_fallen=true → label 为「炼气·落难」、pulsing=false（破碎光效由 Visual 层基于 label 驱动，替代脉动——design/ux/hud.md L189）。

- 信号绑定（G6 裁决）：订阅 `GSM.realm_changed(old, new)`、`GSM.cultivation_changed(delta, current, max_val)`、`GSM.batch_updated(changes)`（过滤 `player.cultivation` 与 `player.max_cultivation` 两条路径——突破后分母变更）。刷新统一走幂等的 `_refresh()`，忽略重复触发（cultivation_changed 与 batch_updated 对同一变更双发射）。
- **is_fallen 数据源（G1 裁决）**：GSM player 域新增 `is_fallen: bool` 字段——gsm_serializer 默认值 false + 落难/重新筑基写入路径。本 story 实现该字段的读取接线；落难写入端（跌落判定）归 realm-system 后续 story，此处只建字段与默认值。
- 禁止在 UI 脚本内联阈值 if-else——判定必须走纯函数。
- 悬停 tooltip：仅数值文本，无跨屏导航，不涉及焦点管理。
- **mouse_filter 提示（G8）**：RealmBarArea 容器为 `mouse_filter = IGNORE`（HUD.tscn L18）——组件根 Control 须显式设置 `mouse_filter = STOP`（或 PASS）并配置 hover 区域，否则悬停事件不送达。

**手动验证前提（G4 裁决）——AC-5~AC-7 可达路径**：当前无可运行游戏场景，手动验证使用**临时 debug 宿主场景**（`tests/manual/hud_debug.tscn` 或运行时脚本）：实例化 HUD.tscn + 直接调用 `GSM.add_cultivation()` 调至四档数值（45% 蓝 / 80% 紫 / 95% 金脉动 / 100% 脉动+可突破提示）。证据文档（`production/qa/evidence/cultivation-bar-evidence.md`）须含截图：四档颜色、脉动动画、落难破碎光效（临时设 is_fallen=true）、可飞升、tooltip 数值——由 lead-programmer 签批。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载与可见性（本组件假定挂载点存在）
- Story 003: 灵石+卡组计数
- 敌方境界标记（⬆）：归 combat-ui（边界澄清 2026-09-07）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 进度条颜色阈值判定
  - Given: 修为进度百分比 p
  - When: 调用 `get_cultivation_bar_state()` 并检查返回的 color 字段
  - Then: p<50% 返回 "blue"、50%≤p<90% 返回 "purple"、p≥90% 返回 "gold"
  - Edge cases: p=49.9%、p=50%、p=89.9%、p=90%、p=100%、max_val=0（防除零）、负数输入、**current>max_val 溢出（按 100% 处理——gold）**、**非法 realm_id（如 0/6——返回安全默认：blue/不脉动/正常 label + push_warning）**

- **AC-2**: 脉动动画触发判定
  - Given: 修为进度 p
  - When: 检查返回的 pulsing 字段
  - Then: p≥90% 为 true，否则 false；**is_fallen=true 时恒 false（G7 裁决——破碎光效替代脉动）**
  - Edge cases: p=89.99%、p=90%、**化神期 95%（pulsing=true 且 show_bar=true——AC-2 与 AC-4 交互点）**

- **AC-3**: 落难状态显示判定
  - Given: is_fallen == true
  - When: 检查返回的 label 字段
  - Then: label 为「炼气·落难」
  - Edge cases: is_fallen == true 且修为满（label 仍为落难显示）

- **AC-4**: 化神期满修为
  - Given: realm 为化神期且 current == max_val
  - When: 检查 show_bar 与 label
  - Then: show_bar == false，label 为「可飞升」
  - Edge cases: 化神期未满、非化神期满

- **AC-8**: 正常态 label（G2 裁决补充）
  - Given: is_fallen == false 且非化神期满
  - When: 检查返回的 label 字段
  - Then: label 为传入的 realm_name 参数（如「金丹期」）

- **AC-9**: 可突破提示判定（G3 裁决补充）
  - Given: current == max_val 且 realm 非化神期
  - When: 检查返回的 breakthrough_hint 字段
  - Then: breakthrough_hint == true；化神期满时 false（由 show_bar=false 接管）

**[Visual/Feel — manual verification steps]:**

- **AC-5**: 金色脉动动画
  - Setup: 修为调至 ≥90%
  - Verify: 进度条金色脉动光效持续播放
  - Pass condition: 动画循环播放无卡顿，颜色为金色系

- **AC-6**: 修为条平滑填充
  - Setup: 触发一次修为变更事件
  - Verify: 进度条 0.3s 内平滑过渡到新值
  - Pass condition: 无瞬跳、无超过 0.5s 的延迟感

- **AC-7**: 悬停数值显示
  - Setup: 鼠标悬停境界区域
  - Verify: tooltip 显示「1800/2250」格式数值
  - Pass condition: 悬停即现、移开即消、数值与 GSM 一致

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/hud/test_cultivation_bar_state.gd` — must exist and pass（BLOCKING）
- Visual/Feel: `production/qa/evidence/cultivation-bar-evidence.md` + sign-off（动画/光效/tooltip 手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（挂载点——Complete 2026-09-09）
- Unlocks: None（独立组件）
- **扩 scope 注记（G1 裁决）**：含 GSM player 域 `is_fallen` 字段新增（gsm_serializer 默认值+读取接线）——落难写入端归 realm-system 后续 story
