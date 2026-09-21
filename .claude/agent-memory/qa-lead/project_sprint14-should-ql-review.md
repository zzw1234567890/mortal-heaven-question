---
name: sprint14-should-ql-review
description: QL-STORY-READY 对 Sprint 14 should 层三 story（main-menu 004 / hud 006 / hud 007）的裁决（2026-09-20，均 GAPS）——action_points_changed max_val 恒 0 陷阱、地图名无数据源（is_fallen 模式再现）、shop 场景不存在、004 注册机制裁决未承接
metadata:
  type: project
---

2026-09-20 对 Sprint 14 should 层三 story 执行 QL-STORY-READY（冲刺 09-21 启动前预备，目标：Day-4 检查点 09-26 切换成本归零）。裁决均 **GAPS**：

**main-menu 004（按键绑定）**：1 BLOCKING——2026-09-19「恢复默认注册机制」裁决（GDD L190 / story 003）要求 004 落地时注册按键分类，story 004 的 AC/QA Test Cases 无对应条目与验收用例。ADVISORY：音频事件触发机制未定义（依赖 14-7）、注册机制属 003/14-4 但 14-10 blocker 仅 14-3（排期口径）、InputMap 重置机制未指定（load_from_project_settings vs 启动快照）。

**hud 006（探索 HUD 右下信息组）**：2 BLOCKING——(1) `action_points_changed` 信号 max_val 参数**恒为 0**（gsm_signal_router.gd L81-83，ADR-0014：AP 上限由 ExplorationSystem 管理，GSM 不跟踪）——「当前/最大」显示与纯函数 max 输入必须改从 `GSM.exploration.max_action_points` 取数；(2) 地图**显示名**无数据源（GSM.exploration.current_map 是 map_id 如 `qing_yun_jian_zong`，全库无 map_id→中文名映射表）——hud story 002 is_fallen 模式再现。ADVISORY：层数路径含糊（node_position.layer 0 基、总层数在 map_states.layers 数组且无公共访问器）、AP 颜色阈值为 story 自拟（GDD/UX 均未定义）。

**hud 007（场景切换过渡提示）**：2 BLOCKING——(1) 1s/0.5s 自动消失断言无时间注入方案（违反项目「不能有时间依赖的断言」标准，hud story 004 时间注入 API 先例）；(2)「坊市」AC 无验证路径——src/feature/shop 目录与 shop_scene.tscn 不存在（SCENE_PATHS 已注册路径），且探索→商店转场无发起方。ADVISORY：story 引用文件名错误（写成 hud_scene_visibility_test.gd，实为 test_hud_scene_visibility.gd）。

**Why:** 三个 story 的信号/枚举「引用存在性」均通过（pre_transition L58/post_transition L62/SceneID.SHOP=6/set_exploration_ap 均实存），但对抗性复核（is_fallen 教训）发现语义级缺口：签名存在 ≠ 参数可用（max_val 恒 0）、枚举存在 ≠ 场景可运行（shop 无文件）。

**How to apply:** story 修复后复审各自 BLOCKING 是否解决；006 的地图名映射表与 007 的坊市验证路径需要用户/设计师裁决归属。相关先例：[[hud-story002-ql-review]]（is_fallen 模式）、[[hud-story004-ql-review]]（时间注入 API）、[[hud-story005-ql-review]]（引用不存在的音频设施）、[[main-menu-story002-003-ql-review]]（注册机制裁决出处）。
