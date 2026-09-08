# Story 005: 卡组浏览界面（只读+稀有度筛选+历史标签）

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Logic 内核：筛选排序管线纯函数）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md` §5 卡组浏览界面
**Requirement**: 浏览 AC 2 条（筛选/详情）+ 机制层 GDD §5 卡组查看功能表 + 历史 AC 2 条
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0023: 卡组编辑系统（次要——卡组快照与变更日志查询）
**ADR Decision Summary**: 零状态所有权（卡组快照从系统读取）；筛选/排序为瞬态交互状态（ADR-0031 §2.1 UI 本地合法持有）；严格只读（2026-09-08 B1 裁决——无任何出售/拆解/移除入口）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: overlay 中央面板 ~1400×900（1080p 基准）；卡组网格类型分组展示；打开 0.3s 扩散动画。

**Control Manifest Rules (this layer)**:
- Required: 筛选排序管线提取纯函数（`tests/unit/deck_editing_ui/`）——B4 裁决
- Forbidden: 任何卡组写操作入口（只读防回归）；UI 持有卡组持久状态
- Guardrail: 卡组快照构建 ≤0.3s（数据本地无旋转等待）；网格 DC 计入预算（≤40 卡）

---

## Acceptance Criteria

*From GDD §5 + 机制层 GDD §5 + UX 规范，scoped to this story:*

**Logic 内核（自动化单测，BLOCKING）：**
- [ ] `deck_filter_sort(cards, type_filter, rarity_filter, sort_key, sort_dir) → Array` 纯函数：
  - 类型筛选 7 值（全部/角色/功法/法宝/阵法/丹药/符箓）× 稀有度筛选 6 值（全部/白/蓝/紫/金/暗金——2026-09-08 B6 裁决双维度）叠加过滤
  - 排序 4 键（费用/稀有度/类型/获得顺序），费用与稀有度含升/降序（A7 裁决固化）
  - 边界用例：双筛选叠加无匹配 → 空数组（UI 显示空态）；类型分组模式下筛选后重新分组；费用相同卡稳定排序（获得顺序为次键）
  - 测试文件：`tests/unit/deck_editing_ui/deck_filter_sort_test.gd`（GUT）

**UI（手动验证）：**
- [ ] 打开 ≤0.3s，从任意入口（HUD 图标/坊市/战利品面板）打开，关闭返回来源界面
- [ ] 统计条：「X/上限」计数（分母=境界系统返回值，非硬编码）+ 暗金计数「1/2」
- [ ] 「全部/历史」二级标签切换
- [ ] 类型筛选 7 标签+稀有度筛选 6 档双维度叠加；筛选结果为 0 显示「没有符合条件的卡牌」空态
- [ ] 排序 4 方式正确（费用/稀有度含升降序切换）
- [ ] 点击卡牌 → 卡牌详情浮窗（story 002 组件——含获得来源）
- [ ] **只读防回归断言（B1 裁决）**：界面无任何出售/拆解/移除/添加操作入口——遍历全部可交互元素验证无写操作
- [ ] 「历史」标签：变更日志列表（回合数/来源渠道/卡牌名称/操作类型），读档后完整恢复（存档往返验证）
- [ ] 历史为空（开局初期）：「尚无卡组变更记录」提示
- [ ] 「减少动态」开启：网格扩散/筛选重排动画瞬时替代

---

## Implementation Notes

*Derived from ADR-0031 + B1/B6/B8 裁决:*

- **界面本体归属（B8 裁决）**：本 story 实现卡组浏览界面**本体**（网格/筛选/排序/详情/历史标签）；exploration-ui story 009 已缩窄为探索侧入口（HUD 图标→打开本 overlay），不实现界面内容。
- 历史标签数据：`DeckEditingSystem.get_change_log()`（ADR-0023 已定义，GSM `player.deck.change_log` 持久化）——读档恢复验证走 SaveSystem 往返测试。
- 战斗中「已抽出/仍在牌库」标注变体（UX OQ#3）：**Out of Scope**——combat-ui 实现时以参数变体认领。
- 流派标签统计（机制 GDD §5 ✅）：列为可选显示（统计条第二行）——低优先级，验收不阻塞。
- exploration-ui 009 的入口调用（stub overlay → 真实界面）在本 story 完成时自动接通。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- exploration-ui story 009: 探索侧入口（HUD 图标触发+关闭返回节点图——本 story 提供打开接口）
- Story 002: 详情浮窗组件本体
- combat-ui: 战斗中牌库标注变体（UX OQ#3——显式排除防隐性需求）
- 坊市内卡组查看入口形态（UX OQ#4——倾向卡组计数点击，实现时按交互实测微调）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic — automated test specs]:**

- **AC-1**: 筛选排序管线
  - Given: 8 张卡（3 功法 2 白 1 蓝/2 丹药 1 紫 1 蓝/2 符箓 1 金/1 角色 白）
  - When: `deck_filter_sort(cards, "功法", "蓝", "费用", "asc")`
  - Then: 仅返回功法蓝色卡，按费用升序
  - Edge cases: ("全部","全部")→全量；(类型,稀有度)双筛选无匹配→[]；费用相同→获得顺序次键稳定；稀有度降序暗金在前

**[UI — manual verification steps]:**

- **AC-2**: 只读防回归+筛选排序走查
  - Setup: 35 张卡组存档（多类型多稀有度）
  - Verify: 逐可交互元素无写操作入口；双维度筛选叠加；4 排序+升降序；空态触发
  - Pass condition: 只读断言通过 + 筛选排序结果与纯函数输出一致

- **AC-3**: 历史标签持久化
  - Setup: 有变更日志的存档（≥3 条不同来源渠道）
  - Verify: 条目字段（回合/来源/卡名/操作）、读档→保存→读档后完整恢复、空日志空态
  - Pass condition: 往返一致 + 签批

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- `tests/unit/deck_editing_ui/deck_filter_sort_test.gd` — 必须存在且通过（BLOCKING）
- `production/qa/evidence/deck-browse-screen-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（详情浮窗组件）
- Unlocks: Story 007（终验含卡组浏览闭环）、exploration-ui 009 接通（其 stub overlay 替换为真实界面）
