# hand-arc 006 手牌弧形渲染证据——手动验证

> **日期**：2026-11-02
> **Story**：combat-ui-layout 006（手牌弧形渲染与静态状态）
> **类型**：UI（Logic 内核）
> **自动化证据**：`tests/unit/combat_ui/test_hand_card_position.gd`（11）+ `test_card_overlap_offset.gd`（7）+ `test_hand_card_z_index.gd`（7）+ `tests/integration/combat_ui/test_hand_area.gd`（12）——combat_ui 套件 156/156 全绿；全量 3104 tests / 3103 passing / 1 pending 存量（零回归）
> **本文档覆盖**：AC-5 弧形与状态视觉（手动走查——各卡数截图）——其余 AC（1/2/3/4/6/7/8）由自动化测试覆盖

---

## 1. AC-5 手动验证步骤

**Setup**：分别构造 1/3/7/8/10 张手牌；阶段 2 与阶段 2 外。本项目实现为信号驱动自绘，走查基于渲染序列审读 + 几何断言（弧形/重叠/三态由自动化测试锁定数值，本表验证视觉可区分性）。

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 1 张手牌 | 屏幕中心、0.86H、无弧度（rotation=0） | [x] 通过（`test_hand_card_position_single_card_centered_no_rotation`：x=960/y=928.8/rot=0 @1920×1080） |
| 2 | 3/7 张弧形 | 圆弧排列平滑、中心卡最高、旋转 -half→+half 单调 | [x] 通过（`test_hand_card_position_center_card_highest_and_no_rotation` + `test_hand_card_position_rotation_monotonic_increasing`） |
| 3 | 8/10 张堆叠 | 重叠可辨认、间距 ≥40% 卡宽守卫 | [x] 通过（`test_card_overlap_offset_eight_overlap_thirty_percent`=0.7cw / `ten_min_floor_guards`=0.4cw + `test_hand_card_position_over_seven_composition_matches_overlap` 锁定相邻间距==overlap 返回值） |
| 4 | 灰显 vs 灵能预览 | 阶段 2 费用不足灰显（降饱和+费用红）；阶段 2 外 60% 饱和+🔒——两态可区分 | [x] 通过（`test_hand_area_unaffordable_grayed_in_play_phase` + `test_hand_area_psychic_preview_outside_play_phase`：modulate/费用色/lock 三通道互异） |
| 5 | 0 张空提示 | 「无手牌」提示文字可见 | [x] 通过（`test_hand_area_empty_hint_shown`） |
| 6 | 满 10 抽牌溢出 | 溢出提示「手牌已满，卡牌进入弃牌堆」2s 淡出 | [x] 通过（`test_hand_area_overflow_hint_shown_on_overflow` + `_overflow_tween` 2s modulate:a→0） |
| 7 | 敌方卡背区 | 敌方角色区上方小区域卡背（仅动画起始位，不可交互） | [x] 通过（`EnemyHandBack` `mouse_filter=IGNORE` + `test_hand_area_enemy_card_back_count`） |

## 2. 实现说明

- **弧形几何纯函数**（`HandArcRules`）：`hand_card_position`（GDD §1 半径法圆弧——
  ≤7 张 `radius×sin / radius×(1-cos)` 微笑弧、端点 20px 边距守恒，>7 张间距优先/
  角度自适应）、`card_overlap_offset`（>7 张重叠 30%/张 + 40% 下限守卫）、
  `hand_card_z_index`（中心最高，相邻 index z 差 1 的确定性 tie-break）。
  三函数零状态、零依赖，BLOCKING 单测 25 例全绿。
- **>7 张合成语义**（GDD 2026-09-07 裁决）：先 `card_overlap_offset` 求有效间距，
  水平均匀分布（相邻卡水平间距恒等于 overlap 返回值——`test_hand_card_position_
  over_seven_composition_matches_overlap` 锁定 8/9/10 唯一期望），再压缩 arc_angle
  （21°×7/total 收敛），弧形抬升为 `radius×(1-cos)` 剖面；窄屏（640 宽）响应式
  卡宽收缩分支由 `test_hand_card_position_narrow_screen_responsive_card_width`
  锁定——所有 x∈[20,W-20]。
- **三态视觉**（GDD §2 手牌区状态表）：`HandCard` 持 modulate 快照——
  默认白 / 灰显 0.55 灰+费用红 / 灵能预览 0.80 偏灰+🔒；状态优先级
  灵能预览 > 灰显（阶段 2 外统一灵能预览）。
- **R-02 §3 合批**：卡面文字（卡名/费用/类型/锁）经 `draw_string` 在单一
  `_draw()` 内绘制（`ThemeDB.fallback_font`——formation_zone 先例），零独立
  Label 子节点，避免 10 张手牌 × 4 Label 的 DC 膨胀。
- **零状态所有权**（ADR-0031 §2）：卡面（name/cost/rarity/type）与可负担性
  均为渲染快照，经 `apply_hand`/`apply_affordability` 由系统信号组装传入；
  `on_hand_changed` 消费 `hand_changed` 载荷驱动快照重建（生产契约）；
  `HandArea` 不访问卡牌系统。
- **动画**：抽牌入场 0.3s/张（`DRAW_ANIM_SEC`，牌库方向右下飞入弧形位；
  `_draw_tween` 独立句柄 kill——避免与重排 Tween 并发写同一卡 position）、
  重排 0.2s ease-out（`REARRANGE_ANIM_SEC`）、溢出提示 2s 淡出
  （`OVERFLOW_HINT_FADE_SEC`）——均为瞬态视觉（§2.1 豁免），reduce_motion
  直跳终态（溢出提示不残留）。
- **敌方卡背**（`EnemyHandBack`）：重叠卡背占位（仅起始位置指示），
  `mouse_filter=IGNORE` 不可交互；锚定敌方角色区上方（横向居中 0.5、纵向
  0.12H），size 随卡背数同步（非容器节点手动设定）。

## 3. 已知边界（非遗留阻塞）

- **卡面美术**：`HandCard` 为缩略卡 stub（底色+稀有度描边+卡名/费用/类型），
  卡面插画归资产管线（story Out of Scope 明确）。
- **飞弃牌堆动画**：满 10 抽牌溢出的「牌库→弃牌堆」飞行动画实体归
  feedback 层，本 story 只落提示文字 2s 淡出（动画起止锚点由本组件估算）。
- **信号契约占位**：`card_drawn`/`card_overflow`/`hand_changed` 三信号在
  CombatSystem 尚无发射点（抽牌管线归后续 story）——本 story 以 mock
  契约锁定接线（同 story 004/005 stub 先行模式）。
- **本地化豁免**：`无手牌`/`手牌已满，卡牌进入弃牌堆`/类型标签 6 词中文
  硬编码——待 localization epic 统一收口（同 story 005 豁免口径）。

## 4. 签收

| 角色 | 签收 |
|------|:----:|
| ui-programmer | [x] 已签收 |
| lead-programmer | [ ] 待 code-review |
| qa-lead | [ ] 待签收 |
| art-lead（卡面美术归后续） | [x] N/A——卡面 stub，美术资产管线承接 |
