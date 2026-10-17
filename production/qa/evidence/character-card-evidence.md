# character-card 002 角色状态卡证据——手动验证

> **日期**：2026-10-17
> **Story**：combat-ui-layout 002（角色状态卡组件 L0-L5 分层）
> **类型**：UI（Logic 内核 + Integration）
> **自动化证据**：`tests/unit/combat_ui/test_hp_bar_color.gd`（4/4）+ `test_formation_row_scale.gd`（3/3）+ `tests/integration/combat_ui/test_character_card_signal.gd`（13/13）——全量 2780 tests / 2779 passing / 1 pending 占位
> **本文档覆盖**：AC-4 L0-L5 分层与可读性（手动走查）——其余 AC 由自动化测试覆盖

---

## 1. AC-4 手动验证步骤

**Setup**：16 角色位满场场景（前排+后排各阵营）——GUT 环境外运行临时宿主场景验证；本项目实现为单 Control 自绘，验证基于 `_draw()` 分层序列审读 + 属性驱动渲染。

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | L0 头像全幅背景 | 占满卡牌（null → 深色占位块——stub 头像未入库） | [x] 通过（`_draw()` L0 序列：`draw_texture_rect` 全幅 / 占位 `draw_rect`） |
| 2 | L1 渐变遮罩 40-60% | 透明→黑 60%，L3 文字可读（对比度 ≥4.5:1） | [x] 通过（`CombatIconAtlas.get_mask()` GradientTexture2D 0→0.6 + ATK 暖白 `Color(0.96,0.94,0.88)` on 黑 60% 背板——对比度抽检 ≥4.5:1） |
| 3 | L2 左右 28px 栏 | 功法左/法宝右竖排各最多 3 个 20×20px 间距 4px 半透明背板 | [x] 通过（`_draw_side_icons` + `set_bindings` 钳制 3——`test_bindings_clamped_to_side_limit`） |
| 4 | L3 底部条 40px | HP 条 + ATK 数字，不透明背板 | [x] 通过（`_draw_hp_bar` draw_rect 纯色——R-02 §2 非纹理 ProgressBar） |
| 5 | L4 角标 | buff/debuff 左下最多 5 + 境界右下 | [x] 通过（`_draw_badges` + `set_status_effects` 钳制 5；境界仅 realm > player_realm——`test_realm_badge_only_shown_above_player_realm`） |
| 6 | L5 待命标记 | 左上待命/已行动 | [x] 通过（`_draw_standby_badge`——沙漏/对勾 glyph 互异） |
| 7 | 前排实线金 / 后排虚线蓝 85% | 视觉可区分 | [x] 通过（`_draw_border`：前排 `draw_rect` filled=false 金色 / 后排 `draw_dashed_line` 蓝色四边；缩放经 `Rules.formation_row_scale`——`test_front/back_row` 集成锁定） |
| 8 | 每角色位 DC 预算 | ≤009a 定型分组预算（6 DC/位实测基线） | [x] 通过（分组：头像 1 + 图集 1 + HP 条 2 draw_rect + 文字 1——R-02 §3 实测口径内；正式 DC 复测归 009b/story 003 基准复测义务） |

## 2. 实现说明

- **L0-L5 单 Control 自绘**：`_draw()` 按底到顶序列绘制——零子节点拆分
  （R-02 §3「不得拆成 14 个独立子节点」），仅文字一个合并 Label
  （名+HP+ATK 合并——R-02 §3 文字合并条款）。
- **合批**（R-02 §3）：全部图标（功法/法宝/buff/debuff/角标/背板）走
  `CombatIconAtlas` 单图集（程序化 stub 256×32——真实图标归美术管线），
  `draw_texture_rect_region` 同纹理合批；HP 条 `draw_rect` 纯色
  （底槽+前景 2 DC，边框 outline 裁剪——R-02 §5 裁剪建议）。
- **HP 过渡**（GDD 公式 3）：0.3s 线性 Tween；同帧多次信号 kill 重建
  直算终值单次过渡（批量伤害免抖）；数字 Label 终值直显（≤100ms）；
  reduce_motion 直跳。阈值 0.6/0.3 集中于 `CombatUiRules`
  （control-manifest 禁止硬编码 HP 阈值）。
- **零状态所有权**（ADR-0031 §2）：HP/buff/绑定/境界均为渲染快照，
  `apply_hp`/`set_bindings`/`set_status_effects` 由系统信号驱动写入；
  零轮询（无 `_process`——`test_card_has_no_process_polling` 源码级锁定）。
- **境界角标**（story AC-6）：仅 `realm > player_realm` 时显示——
  悬停显示境界名归 interaction epic（本 story 仅图标渲染）。

## 3. 范围外确认

- 待命/已行动**信号切换逻辑**、阵亡动画、飘字、HP 批量过渡编排——story 003
- 布局容器（本组件填充己方/敌方区）——story 001
- 角色卡点击/悬停详情——interaction epic
- 伤害命中音效——audio-manager epic
- 真实图标美术资产（stub 程序化图集替换）——资产管线 story

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | L0-L5 六层单 Control 自绘 + R-02 合批分组 + 信号驱动快照；20 测试全绿 | [x] Approved |
| qa-lead（测试） | AC-1/2/3/5/6/7 全部自动化锁定；AC-4 手动项归档 | [x] Approved |
| lead-programmer（技术） | 零新增 Autoload；零轮询；阈值集中 `CombatUiRules`；纯函数消费禁止内联（源码断言锁定） | [x] Approved |

*独立开发者——所有角色由同一人签收。*
