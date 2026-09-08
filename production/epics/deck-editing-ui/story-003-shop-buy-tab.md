# Story 003: 买卡标签页——商品网格与购买流

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Logic 内核：灰态判定纯函数）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md` §2 商店-购买卡牌
**Requirement**: 购买 AC 4 条（商品网格/灰态/购买确认/余额显示）+ UX 规范买卡 AC
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0023: 卡组编辑系统（次要——购买 API 契约）；ADR-0014: 探索系统（次要——库存归属）
**ADR Decision Summary**: 2026-09-08 B2 裁决——库存归 ExplorationSystem（`_shop_inventories`），DeckEditingSystem 提供 `execute_purchase(card_id)`（校验+扣费+加卡+委托库存标记已售）；UI 直调 API，操作完成后接收通知信号。UI 零数值计算。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 商品网格 4 列默认（3~6 调优）；商品卡入场从左到右 0.2s/张。

**Control Manifest Rules (this layer)**:
- Required: 灰态判定逻辑提取纯函数（`tests/unit/deck_editing_ui/`）——hud story-002 Logic 内核先例（B4 裁决）
- Forbidden: UI 计算价格或折扣（标价从库存载荷读取）；UI 直接操作灵石/卡组/库存
- Guardrail: 商品悬停 0.3s 内弹出详情浮窗；网格渲染 DC 计入预算（≤6×N 卡）

---

## Acceptance Criteria

*From GDD §2 + UX 规范，scoped to this story:*

**Logic 内核（自动化单测，BLOCKING）：**
- [ ] `shop_item_state(price, balance, deck_count, deck_limit, sold) → 枚举` 纯函数：五状态判定——SOLD（已售优先级最高）/DECK_FULL（卡组 ≥ 上限）/INSUFFICIENT（价格 > 余额）/NORMAL/（加载中不在此函数）
  - 边界用例：已售+灵石不足同时成立 → SOLD；价格=余额 → NORMAL（可购买）；卡组=上限 → DECK_FULL；卡组=上限-1 → NORMAL
  - 测试文件：`tests/unit/deck_editing_ui/shop_item_state_test.gd`（GUT）

**UI（手动验证）：**
- [ ] 商品卡四状态视觉：可购买（正常）/灵石不足（灰色+「灵石不足」文字标记双编码）/卡组已满（灰色+「卡组已满」）/已售（❌标记不可交互）
- [ ] 灰态商品点击 → 卡片抖动 + toast 提示（非静默）
- [ ] 商品悬停 0.3s 内弹出卡牌详情浮窗（复用 story 002 组件——GDD #1 裁决）
- [ ] 可购买商品点击 → 购买确认弹窗「确认购买 [卡名]（[价格]灵石）？」——焦点默认落于「取消」侧
- [ ] 确认购买 → 灵石扣减数字滚动+卡牌飞向卡组图标（0.3s）+商品标记已售+卡组计数+1（减少动态开启时全瞬时+终值直显）
- [ ] 空态：商品全部售罄 → 「本店商品已售罄」提示，仅刷新+离开可用
- [ ] 加载态：商品生成期间（入场动画 0.2s/张）底部按钮禁用
- [ ] 刷新商店按钮（费用从系统载荷读取）→ 刷新确认 → 商品重生成动画

---

## Implementation Notes

*Derived from ADR-0023 渠道 2 + B2/B3a/B7 裁决:*

- **依赖上报（stub+复验——B7 裁决）**：`DeckEditingSystem.execute_purchase(card_id)` 与 `ExplorationSystem` 库存查询/标记已售 API **尚未实现**。本 story 以 stub 先行（stub 返回固定成功+本地库存字典），story 内记录接线缺口；真实 API 就绪后复验购买流（灵石扣减/库存标记/日志写入断言）。
- 灰态判定纯函数放 `src/ui/deck_editing/`（或系统侧裁决后移入 DeckEditingSystem）——输入全部为系统返回值，UI 仅消费枚举。
- 购买成功后经 GSM Cat 1 `batch_updated` 刷新灵石/卡组计数（ADR-0023 信号传播路径）；`shop_purchase_confirmed` 为通知性 Cat 2b 信号（B3a 裁决）。
- 价格数字区按 5 位灵石+千分位预留；卡名 12 字内单行（本地化预算）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: overlay 框架与标签页宿主
- Story 002: 卡牌详情浮窗组件本体
- Story 004: 散功/售卡标签页
- Feature 层: execute_purchase/库存 API 实现（依赖上报项）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic — automated test specs]:**

- **AC-1**: 灰态判定纯函数
  - Given: `{price: 150, balance: 125, deck_count: 28, deck_limit: 30, sold: false}`
  - When: `shop_item_state(...)`
  - Then: 返回 INSUFFICIENT
  - Edge cases: sold=true 且余额不足 → SOLD（优先级）；price=balance → NORMAL；deck_count=deck_limit → DECK_FULL；deck_count=deck_limit-1 → NORMAL

**[UI — manual verification steps]:**

- **AC-2**: 四状态走查
  - Setup: stub 库存构造四状态商品各至少 1 张
  - Verify: 视觉双编码（灰+文字）、点击抖动+toast、悬停详情 0.3s
  - Pass condition: 四状态与 GDD §2 界面规则一致

- **AC-3**: 购买流闭环
  - Setup: 灵石充足的 stub 存档
  - Verify: 确认弹窗内容+焦点默认取消、确认后四联动（扣费动画/已售/计数/飞行动画）、取消无副作用
  - Pass condition: 走查通过 + stub 数值与 stub 返回一致（UI 未计算）

- **AC-4**: 空态与加载态
  - Setup: 库存清空存档；正常进入
  - Verify: 售罄空态提示+仅刷新离开可用；入场动画期间按钮禁用
  - Pass condition: 两态均触发 + 签批

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- `tests/unit/deck_editing_ui/shop_item_state_test.gd` — 必须存在且通过（BLOCKING）
- `production/qa/evidence/shop-buy-tab-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（overlay 宿主）、Story 002（详情浮窗组件）
- Unlocks: Story 007（终验含买卡闭环）
