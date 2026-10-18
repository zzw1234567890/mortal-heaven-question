# character-state-death 003 状态标记、阵亡处理与飘字证据——手动验证

> **日期**：2026-10-18
> **Story**：combat-ui-layout 003（角色状态标记切换、阵亡处理与飘字）
> **类型**：UI（Integration 核心）
> **自动化证据**：`tests/integration/combat_ui/test_hp_batch_transition.gd`（24 场景含 CountingCard 计数断言 + H-1 坐标回归 2 例 + 沙漏淡出 2 例）+ `test_death_flow.gd`（5）+ `test_floater_pool.gd`（池上限/复用/reduce_motion 8）——combat_ui 套件 57/57 全绿；全量 2843 tests / 2842 passing / 1 pending 存量（CI 5289133/65a4eca success）
> **本文档覆盖**：AC-4 阵亡动画与飘字手动走查 + AC「待命/已行动」标记视觉走查（自动化覆盖 AC-1/2/3 及 AC-4 的池化逻辑）

---

## 1. AC-4 手动验证步骤（阵亡动画与飘字）

**Setup**：战斗场景中造成伤害与角色阵亡（mock 信号宿主验证 + `_draw()`/Tween 序列审读——同 character-card 002 证据口径：本项目实现为信号驱动自绘，走查基于渲染序列与 Tween 轨迹审读）。

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 伤害飘字 | 红色 `-N` 数字从目标卡中心飘出下落消失 0.5s（GDD 动画表） | [x] 通过（`FloaterPool.spawn` DAMAGE 路径：`-N` 文本 + `DAMAGE_COLOR(0.85,0.25,0.22)` + `position:y` tween +40px/0.5s——`test_damage_floater_falls` + `test_damage_floater_red_text_with_minus`） |
| 2 | 治疗飘字 | 绿色 `+N` 上浮消失 0.5s | [x] 通过（HEAL 路径 `+N` + `HEAL_COLOR(0.22,0.72,0.30)` + y tween -40px——`test_heal_floater_green_rises`） |
| 3 | 飘字起点坐标 | 目标卡视觉中心（含容器偏移与后排 85% 缩放） | [x] 通过（H-1 回归：`test_floater_origin_offset_container_and_scaled_card`——三层嵌套偏移 + 缩放断言全局中心命中容差 0.5px；stash 对照验证修复前红） |
| 4 | 12+ 同帧飘字无卡顿 | 池上限 16 预创建复用，无节点风暴 | [x] 通过（`test_pool_cap_never_instantiates_beyond_limit` 30 请求恒 16 节点 + `test_floater_pool_cap_never_exceeds_16` 20 请求） |
| 5 | 阵亡动画 | 0.5s 淡出（碎裂 stub）→ 卡移除 → 空位虚线框原位接替 | [x] 通过（`_play_death` modulate:a 0.5s → `_finish_death` 移除 + `EmptySlotFrame` 同父局部坐标接替——`test_death_flow_animates_then_removes_and_shows_empty_frame` + H-1 回归 `test_death_frame_position_offset_container`） |
| 6 | 全灭短路 | 不逐个播阵亡动画，立即转发结算信号 | [x] 通过（`_on_battle_ended` 清队列杀动画 + `battle_result_forwarded` 同帧发射——`test_total_wipe_skips_death_animations_and_forwards_immediately`） |
| 7 | 减少动态替代 | 飘字纯淡出无位移；阵亡直接移除+空位框；HP 直跳 | [x] 通过（`test_pool_reduce_motion_fade_only` + `test_death_flow_reduce_motion_immediate` + `test_floater_pool_reduce_motion_no_displacement`） |

## 2. 标记视觉走查（AC-1/AC-2 手动补充）

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 待命沙漏 | 头像左上角沙漏角标（BADGE_STANDBY 图集 glyph） | [x] 通过（`_draw_standby_badge` is_standby 分支——`test_standby_cleared_switches_marker_off` 锁定信号切换） |
| 2 | 待命→已就绪淡出 | 沙漏 0.3s 淡出（GDD 动画表 L611 前半句） | [x] 通过（`BADGE_FADE_SEC=0.3` + `_badge_alpha` tween_method 渐隐——`test_standby_to_ready_hourglass_fades_0_3s` 中点/终值双断言） |
| 3 | 已行动灰遮罩 | 全卡幅半透明灰 `Color(0.5,0.5,0.52,0.5)` + 对勾（互斥清沙漏） | [x] 通过（`_draw` is_acted 遮罩层 + `set_acted_state` 互斥路径——`test_request_acted_sets_overlay_and_check`） |
| 4 | 文字通道 | 「待命/已行动」文字——**推迟**（game-designer 裁决方案 B，图形双通道已满足可辨识性） | [x] 裁决归档（DEBT-CUI-003——本地化系统落地时一次实现） |

## 3. 实现说明

- **编排器**（`CombatFeedbackCoordinator`）：五信号订阅（attack_resolved/
  character_died/battle_ended/standby_cleared/character_deployed——`_connect_once`
  防重）；AC-1 增量入队 + `call_deferred` 结算帧合并（每目标一次
  `apply_hp` 终值——CountingCard 计数断言锁定）；HP 终值经 `hp_reader_cb`
  注入读源系统（零状态所有权——不缓存 HP）。
- **飘字池**（`FloaterPool`）：16 上限预创建 Label；耗尽回收时间戳最早者；
  零 `_process`（一次性 Tween + `finished` 信号回收）；spawn 接受全局坐标
  内部换算池局部（H-1 修复——池可在任意非原点容器下）。
- **空位框**（`EmptySlotFrame`）：四边 `draw_dashed_line` 蓝色虚线（后排边框
  同族）；同父局部坐标 `add_child` 后接替（H-1 修复——树外节点 global
  换算不可靠规避）。
- **沙漏淡出**：语义位即时翻转 + 视觉通道 `_badge_alpha` 0.3s 渐隐
  （tween_method）；reduce_motion 瞬时；`set_acted_state` 互斥路径直接
  终结淡出（对勾+遮罩接替，无残留半透明沙漏）。

## 4. 范围外确认

- ACTED 逐角色信号——deployment 系统无该信号，`request_acted()` 外部驱动
  入口（战斗侧阶段接线 story 消费）
- 治疗按 damage 符号判定（CardEffectEngine 独立信号时需同步——
  `healing` 字段现存于 EffectEvaluation，接线 story 处理）
- 结算面板本体——story 008
- 碎裂美术素材（当前 modulate 淡出 stub）——美术管线 story
- 阵亡音效/命中声——audio-manager epic

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | 编排器五信号 + 池化飘字 + 阵亡流程 + 沙漏淡出全链；57 测试全绿；LP 定向复审 APPROVED（5289133） | [x] Approved |
| qa-lead（测试） | AC-1/2/3 全自动化锁定（含计数断言）；AC-4 手动走查 7 项归档；H-1 坐标回归 stash 对照验证 | [x] Approved |
| lead-programmer（技术） | H-1/M-2/AC 裁决三项 Required Changes 闭合并定向复审确认；M-1/L-1/L-2/死 API 建议项一并修复 | [x] Approved |

*独立开发者——所有角色由同一人签收。录屏证据可后续补挂（当前以测试+走查审读覆盖——与 character-card 002 证据同口径）。*
