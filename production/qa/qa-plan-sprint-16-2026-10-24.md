# QA 计划：Sprint 16

**日期**：2026-10-24
**由**：/qa-plan 生成
**范围**：9 个 story（3 must + 3 should + 3 nice），涉及 6 个系统（identity-selection-system / exploration-ui / audio-manager / combat-ui-layout / hud / main-menu）
**引擎**：Godot 4.6.3（GUT 9.6.1）
**Sprint 文件**：production/sprints/sprint-16.md

---

## 测试摘要

| Story | 类型 | 需要自动化测试 | 需要手动验证 |
|-------|------|------------------------|------------------------------|
| S16-1 身份选择 UI 场景 | UI（Logic 内核） | 单元测试（解锁判定纯函数 `is_identity_unlocked`） | 截图 + 签收 |
| S16-2 exploration-ui 002 地图选择界面 | UI（含 Integration 入口） | 无（重入流为意图转发，逻辑归探索系统） | 手动走查（三类卡片状态 + 重入确认流） |
| S16-3 exploration-ui 003 节点图数据接入 | Integration | 集成测试（`test_node_graph_render.gd`） | 截图 + 签收 |
| S16-4 audio 004 set_state 编排与过渡矩阵 | Logic + Integration | 单元（`test_state_matrix.gd`）+ 集成（`test_scene_signal_binding.gd`）+ scene_manager 回归 | 无 |
| S16-5 combat-ui-layout 004 顶部条 | UI（Integration） | 集成（`test_phase_indicator_signal.gd` + `test_log_phase2_autocollapse.gd`） | 截图 + 签收 |
| S16-6 combat-ui-layout 005 费用栏 | UI（Logic 内核） | 单元（`test_cost_color.gd`）+ 集成（`test_cost_display.gd`） | 动画截图 |
| S16-7 audio 005 暂停/静音/总线控制 | Logic + Integration | 单元（`test_mute_controller.gd`）+ 集成（`test_pause_resume_position.gd`） | 无 |
| S16-8 hud 008 静音图标 | UI | 集成（信号驱动显示，并入 `test_gsm_signal_binding.gd`） | 截图 + 签收 |
| S16-9 main-menu 005 语言切换 | UI + Integration | 集成（`test_locale_switch.gd`） | 全界面核对 |

---

## 需要自动化测试

### S16-1 身份选择 UI 场景 — UI（Logic 内核）
**测试文件路径**：`tests/unit/identity_selection_system/test_identity_unlock_gate.gd`
**测试内容**：
- 解锁判定纯函数：5 个默认身份 unlocked + 阵道双杰依赖 `cang_xuan_walker` 天赋（消费 story 001 的 `get_available_identities`，不可重复实现模板表）
- 「确认选择」按钮启用态判定：未选中 → 禁用；选中 → 启用
- 读档跳过判定：`is_identity_selected()` true → 跳过身份选择（消费 story 003）

**需要覆盖的边界情况**：
- 阵道双杰未解锁时点击 → 「轮回天赋解锁」提示路径
- 未选中任何身份时确认按钮禁用
- 6 卡 2×3 网格渲染（场景树解析断言卡片节点数 == 6）

**预估测试数量**：~4 个单元测试

**注**：本 story 无独立文件，需先按 GDD `design/gdd/identity-selection-system.md` §用户界面需求 + §验收标准创建 `production/epics/identity-selection-system/story-004-identity-select-ui.md`。DoD 锁定「按 GDD §用户界面需求实现」，focus/gamepad/a11y 三项显式 defer 登记（正式 UX 规格后续补）。

### S16-2 exploration-ui 002 地图选择界面 — UI（含 Integration 入口）
**测试文件路径**：无自动化测试文件（重入扣费逻辑归探索系统，UI 仅发意图）
**测试内容**：手动走查为主（见手动 QA 清单）。重入流「UI 发意图 → 探索系统 `map_reentry_denied` 信号 → toast」的接线可并入 S16-3 集成测试作防御断言。

**边界情况**：灵石不足按钮禁用 / 苍玄古战场不可重入 / 未解锁悬停「需X境界」/ 三路径横向滚动

**预估测试数量**：0（纯 UI 手动验证）

### S16-3 exploration-ui 003 节点图数据接入 — Integration
**测试文件路径**：`tests/integration/exploration_ui/test_node_graph_render.gd`
**测试内容**：
- `node_type_to_icon` 纯函数：10 种节点类型映射（入口🏁/战斗⚔/精英⚡/Boss👑/事件❓/商店🏪/传送✦/灵泉💧/渡劫台🌩/回复点💚）
- 节点六态视觉映射：当前（金框+玩家标记）/可达（彩色+脉冲）/已访问（绿框✓）/不可达（灰锁）/行动力不足（灰+红斜线）/迷雾（深色❓）
- `map_generated` 信号 → 节点图构建（真实 DAG 替换 stub）

**需要覆盖的边界情况**：
- 渡劫台修为未满（可进入不可触发态）
- 传送节点按普通节点渲染（无交互）
- 迷雾节点悬停 tooltip 显示「?」不显示敌人构成

**预估测试数量**：~6 个集成测试

### S16-4 audio 004 set_state 编排与过渡矩阵 — Logic + Integration
**测试文件路径**：`tests/unit/audio/test_state_matrix.gd` + `tests/integration/audio/test_scene_signal_binding.gd`
**测试内容**：
- 矩阵完整性：12 态每态至少 1 入边或 1 出边（含 CULTIVATING）；24 行与 GDD §9 逐行对应
- 每行参数完备：fade_out_sec/fade_in_sec/ambient_delta_db 键齐全且在调优旋钮安全范围
- `map_transition_type()`：5 类 TransitionType → AudioState 转换全覆盖
- SceneManager `pre_transition` 信号 → `set_state()` 自动触发

**需要覆盖的边界情况**：
- N/A 转换（商店→战斗等 3 项）不存在于矩阵
- 未映射组合返回空（防御性）
- 同状态重复调用幂等（无重启/无重复淡化）

**预估测试数量**：~6 个单元 + ~2 个集成 + 2 个 scene_manager 回归（test_audio_transition_matrix / test_transition_type）

### S16-5 combat-ui-layout 004 顶部条 — UI（Integration）
**测试文件路径**：`tests/integration/combat_ui/test_phase_indicator_signal.gd` + `test_log_phase2_autocollapse.gd`
**测试内容**：
- 阶段指示器：phase_changed 信号 0→6 逐段更新（名称/进度格/回合编号）
- 日志行为：展开态 + phase_changed(2) → 自动折叠；条目追加后 scroll_vertical 位于最大值；战斗结束信号后清空

**需要覆盖的边界情况**：
- 同阶段重复信号（无变化）；回合号递增
- 折叠状态下新条目（仍追加，展开后可见）
- 节点树无倒计时 Timer UI 元素

**预估测试数量**：~5 个集成测试

### S16-6 combat-ui-layout 005 费用栏 — UI（Logic 内核）
**测试文件路径**：`tests/unit/combat_ui/test_cost_color.gd` + `tests/integration/combat_ui/test_cost_display.gd`
**测试内容**：
- `cost_color(available, base_max, temporary)` 纯函数：GDD 公式 4 完整覆盖（含双守卫）
- 费用信号驱动显示：扣费 → 数字更新（非轮询）

**需要覆盖的边界情况**：
- (3,0,3)→YELLOW / (0,0,0)→RED / (5,10,0)→YELLOW（ratio=0.5 恰黄）/ (4,3,3)→WHITE
- available 负值 / temporary 负值（固化决策）
- 同帧多次变更终值生效

**预估测试数量**：~8 个单元 + ~2 个集成

### S16-7 audio 005 暂停/静音/总线控制 — Logic + Integration
**测试文件路径**：`tests/unit/audio/test_mute_controller.gd` + `tests/integration/audio/test_pause_resume_position.gd`
**测试内容**：
- MuteController debounce：200ms 窗口（时间注入）
- 恢复值记忆：静音前 -3dB → 取消恢复 -3dB（非 0dB）
- 跨场景持久：静音中 set_state 换曲仍 -80dB
- 暂停位置保持：BGM t=5.0s pause → resume 从 5.0s 继续

**需要覆盖的边界情况**：
- clock=199ms（忽略）与 200ms（生效）分界
- 静音中 pause_all/resume_all 往返
- 暂停中请求 play_sfx（不播放）
- set_bus_volume(SFX,-40) 总线独立性（BGM 保持 0dB）

**预估测试数量**：~5 个单元 + ~3 个集成

### S16-8 hud 008 静音图标 — UI
**测试文件路径**：追加用例至 `tests/integration/hud/test_gsm_signal_binding.gd`
**测试内容**：
- mute_state_changed(true/false) → 图标 visible/hidden
- HUD 挂载时已静音（初始化查询显示正确）
- 战斗场景 HUD 整体隐藏时图标随隐藏

**需要覆盖的边界情况**：
- 连续快速切换（最终态一致）
- 战斗中取消静音（状态更新但不可见，恢复可见后正确）

**预估测试数量**：~2 个集成（追加）

### S16-9 main-menu 005 语言切换 — UI + Integration
**测试文件路径**：`tests/integration/main_menu/test_locale_switch.gd`
**测试内容**：
- locale 切换即时生效：`TranslationServer.get_locale()` 前缀 == "en"；探针控件（主菜单按钮/设置分类标签/制作人员标题各 1 处）变英文
- 缺失翻译键回退默认语言（无空白/键名裸露）

**需要覆盖的边界情况**：
- 切回 zh 往返一致；刷新 1 帧内完成
- 全部键齐全（正常切换）

**预估测试数量**：~3 个集成

---

## 手动 QA 检查清单

### S16-1 身份选择 UI 场景 — UI
**验证方法**：D3D12 窗口截图 + 签收
**必须签收人**：ui-programmer + lead-programmer + qa-lead
**需要捕获的证据**：`production/qa/evidence/identity-select-evidence.md`

检查清单：
- [ ] 6 张身份卡片 2×3 网格渲染（5 可解锁 + 1 🔒）
- [ ] 底部选中详情区（卡组概览 / 角色属性 / 天赋描述）点击卡牌后更新
- [ ] 「确认选择」按钮：未选中禁用 → 选中启用
- [ ] 阵道双杰 🔒 遮罩 + 点击显示「轮回天赋解锁」提示
- [ ] 确认弹窗「确定选择？本局不可更改」+ [确定]/[返回重选] 两分支
- [ ] 新游戏 → 身份选择导航打通（消除冒烟留桩）

### S16-2 地图选择界面 — UI
**验证方法**：手动走查
**必须签收人**：ui-programmer + qa-lead
**需要捕获的证据**：`production/qa/evidence/map-select-screen-evidence.md`

检查清单：
- [ ] 已解锁（彩色可点击）/未通关（可进入）/已通关（重入）/未解锁（灰锁）四态卡片区分
- [ ] 重入确认弹窗内容（费用明细 + 余额）；灵石不足按钮禁用
- [ ] 苍玄古战场不可重入（无重入入口）
- [ ] 未解锁悬停「需X境界」
- [ ] 横向滚动三路径（滚轮/滚动条/手柄 LB/RB）+ 入场动画 0.3s/张
- [ ] 顶部灵石余额（资源系统只读）

### S16-3 节点图数据接入 — Integration
**验证方法**：debug 宿主截图 + 签收
**必须签收人**：ui-programmer + lead-programmer
**需要捕获的证据**：`production/qa/evidence/node-graph-render-evidence.md`

检查清单：
- [ ] 10 种节点类型图标 + 颜色 + 标签正确渲染
- [ ] 节点六态视觉（当前/可达/已访问/不可达/行动力不足/迷雾）与 GDD 视觉表逐行一致
- [ ] 连线金实线（已走）/暗虚线（未走）
- [ ] 逐层展开动画 0.8s；迷雾揭散 0.3s
- [ ] 渡劫台修为未满不可触发态视觉区分
- [ ] 悬停预览（名称 + 描述 + 战斗类敌人详情）

### S16-5 顶部条 — UI
**验证方法**：debug 宿主截图 + 签收
**必须签收人**：ui-programmer + qa-lead
**需要捕获的证据**：`production/qa/evidence/topbar-evidence.md`

检查清单：
- [ ] 7 阶段名称 + 进度条 + 回合编号；阶段 0 显示「准备」
- [ ] 阶段名滑入动画 0.2s
- [ ] 阵法区 3 槽位（已部署卡 + 空位虚线框）+ 阵营色光环
- [ ] 日志默认折叠，展开半屏不遮费用栏；最新在底自动滚底

### S16-6 费用栏 — UI
**验证方法**：动画截图（连续帧）+ 签收
**必须签收人**：ui-programmer + qa-lead
**需要捕获的证据**：`production/qa/evidence/cost-bar-evidence.md`

检查清单：
- [ ] 费用颜色三态（绿/黄/红）视觉确认
- [ ] 费用消耗数字跳动 + 光粒消散 0.2s
- [ ] 临时费用用完绿色数字淡出
- [ ] 牌库/弃牌计数正确
- [ ] 「结束出牌」按钮仅阶段 2 可见
- [ ] D3D12 下粒子无 alpha 异常（009b 统一执行）

### S16-8 静音图标 — UI
**验证方法**：截图 + 签收
**必须签收人**：ui-programmer + qa-lead
**需要捕获的证据**：`production/qa/evidence/mute-icon-evidence.md`

检查清单：
- [ ] F1 进入静音 → HUD 角落扬声器+斜线图标出现
- [ ] 再按 F1 → 图标消失
- [ ] 图标位置不遮挡关键信息

### S16-9 语言切换 — UI + Integration
**验证方法**：三界面 zh/en 截图逐屏核对
**必须签收人**：ui-programmer + qa-lead
**需要捕获的证据**：`production/qa/evidence/locale-switch-evidence.md`

检查清单：
- [ ] 主菜单 / 设置 / 制作人员三界面 zh 截图 → 切 en → 所有文本更新
- [ ] 无残留中文、无空白、无需重启
- [ ] 重启后语言保持 en（持久化验证）

---

## 冒烟测试范围

在此 sprint 的任何 QA 交接前需要验证的关键路径：

1. 游戏启动到主菜单无崩溃（既有路径回归）
2. **「新游戏」→ 身份选择界面可进入**（消除上轮冒烟 FAIL 留桩）
3. 身份选择 → 地图选择 → 节点图 核心循环前三跳可演示
4. audio 004 过渡矩阵 + scene_manager 回归后 CI 连续两跑绿（TD 风格监督）
5. 存档/读档周期完成无数据丢失（既有路径回归）
6. 全量测试 2920+ 零回归

*冒烟测试由开发者通过 `/smoke-check` 验证。*

---

## 试玩要求

| Story | 试玩目标 | 最少会期数 | 目标玩家类型 |
|-------|--------------|--------------|-------------------|
| S16-1 身份选择 | 6 卡选择 + 确认流程是否直观、未解锁身份提示是否清晰 | 1（自试） | 新玩家 |
| S16-3 节点图 | 六态节点视觉是否一眼可辨、悬停预览内容是否够用 | 1（自试） | 有经验玩家 |

**签收要求**：试玩笔记写入 story Test Evidence 或证据文档，qa-lead 审查。

---

## 完成定义 — 本次 Sprint

- [ ] 所有验收标准已验证（自动化测试 + 手动证据双轨）
- [ ] S16-1：identity_select 场景落盘 + SCENE_PATHS 串联（冒烟留桩消除）
- [ ] S16-1 前置 identity story 001-003 关闭（3 测试文件全绿 + story-done 翻转）
- [ ] 核心循环前三跳可演示：主菜单→身份选择→地图选择→节点图
- [ ] 所有逻辑/集成类故事测试文件存在于指定路径且通过（S16-3/4/5/6/7/9）
- [ ] UI 类故事证据文档存在并签收（S16-1/2/3/5/6/8/9）
- [ ] S16-4：scene_manager 回归 CI 连续两跑绿（监督条件 #3）
- [ ] 冒烟检查通过（`/smoke-check sprint`）
- [ ] 未引入回归——2920 既有测试全部通过
- [ ] 代码已审查（`/code-review`）
- [ ] Story 文件已更新为 `Status: Complete`（`/story-done`）
