# QA 计划：Sprint 17（2026-11-03 至 2026-11-12）

**日期**：2026-11-02
**由**：/qa-plan sprint 生成（qa-lead）
**范围**：9 个 story（must 4 + should 4 + nice 1）+ 4 个 QA 专项（QA-17-1 至 QA-17-4）
**权威状态源**：`production/sprint-status.yaml`（sprint: 17）
**引擎**：Godot 4.6.3 | **测试框架**：GUT
**控制清单**：Manifest Version 2026-09-07（所有 story 嵌入版本一致，无过时）

> 依据 PR-SPRINT 2026-11-02 裁决：17-3 背景模糊 40% D3D12 性能抽查**已从 must 拆出**为 ADVISORY 复测项（QA-17-4），本计划不将其列为 17-3 的阻塞测试。Day-3（11-05）17-1 未落地触发丢弃 17-3；Day-4（11-06）17-2 未落地触发丢弃 17-4——任何丢弃发生时，下表对应条目随之作废并在签收报告中记录。

---

## 1. 测试摘要

| ID | Story | Type | 优先级 | 自动化测试（关卡） | 手动验证（关卡） |
|----|-------|------|--------|--------------------|------------------|
| 17-1 | exploration-ui 005 节点移动交互 | Integration | must | `tests/integration/exploration_ui/test_node_move_interaction.gd`（BLOCKING） | 走查 + 截图签收（ADVISORY） |
| 17-2 | combat-ui-layout 007 部署面板框架 | UI（Logic 内核） | must | `tests/unit/combat_ui/test_deploy_selection_state.gd` + `test_formation_slot_layout.gd`（BLOCKING） | 五境界截图签收（ADVISORY） |
| 17-3 | exploration-ui 006 节点交互弹窗 | Integration | must | `tests/integration/exploration_ui/test_node_interaction_popups.gd`（BLOCKING） | 五类弹窗走查 + 截图（ADVISORY）；模糊帧率 → QA-17-4 |
| 17-4 | combat-ui-layout 008 结算/撤退面板 | UI（Logic 内核） | must | `tests/integration/combat_ui/test_loot_delay_clickable.gd`（BLOCKING） | 五场景截图签收（ADVISORY） |
| 17-5 | combat-ui-interaction 001 输入锁基座 | Integration | should | `tests/unit/combat_ui/test_esc_arbitration.gd` + `tests/integration/combat_ui/test_modal_freeze_stub.gd`（BLOCKING） | 双焦点视觉走查（ADVISORY） |
| 17-6 | audio 005 暂停/静音/总线控制 | Logic + Integration | should | `tests/unit/audio/test_mute_controller.gd` + `tests/integration/audio/test_pause_resume_position.gd`（BLOCKING） | 无（自动化覆盖；暂停菜单对接回归项含于集成测试） |
| 17-7 | main-menu 005 语言切换 | UI + Integration | should | `tests/integration/main_menu/test_locale_switch.gd`（BLOCKING） | 三界面双语核对 + 截图（ADVISORY） |
| 17-8 | hud 008 静音图标 F1 | UI | should | 追加至 `tests/integration/hud/test_gsm_signal_binding.gd`（BLOCKING） | 图标视觉走查（ADVISORY） |
| 17-9 | exploration-ui 004 AP 指示器 | UI（Logic 内核） | nice | `tests/unit/exploration_ui/test_ap_bar_color.gd`（BLOCKING） | 四态颜色走查（ADVISORY） |

**分类说明**：
- 17-2/17-4/17-9 头部 Type 为「UI（Logic 内核）」混合类型——Logic 内核纯函数/判定测试为 **BLOCKING** 关卡（无测试不得标 done）；视觉走查为 ADVISORY 签收项。
- 17-6+17-8 为**原子对**：17-6 滑则 17-8 级联丢弃（hud 008 的 `mute_state_changed` 信号源不存在，追加用例无法成立）。
- 17-8 的证据是**追加用例**到既有文件，非新文件——story-done 核查时以「既有文件存在 + 新增用例通过」为口径。

---

## 2. 需要自动化测试（BLOCKING——story-done 硬关卡）

### 17-1 exploration-ui 005（Integration，1.5d）

**文件**：`tests/integration/exploration_ui/test_node_move_interaction.gd`

**测试内容**（story QA Test Cases AC-1~AC-3，GDD 节点图交互 AC + A2/B4/B10 裁决）：
- **移动委托流**（AC-1）：点击可达节点 B → 断言 `move_to_node(B)` 恰好调用一次、`node_moved` 信号驱动玩家标记移动、AP 扣减与系统返回值一致。
- **到达通知**（AC-1 边缘）：战斗类节点——移动完成后弹窗触发通知恰好一次（不预弹，B4 先移动后弹窗）。
- **不可达反馈**（AC-2）：AP=0 / 路径不通 → 系统失败返回 → 无移动、无 AP 变化、反馈触发。**注意 manifest 禁令**：不可达原因必须从系统返回（断言错误码映射），不得 UI 预判可达性拦截——测试用双份用例锁定（UI 侧零预判 + 系统侧失败驱动）。
- **教程覆盖**（AC-3）：新档首次进入 → 3 步显示、任意点击跳过、`tutorial_skipped` 事件发射、二次进入不显示。

**边界情况**：
1. 动画期间二次点击——**缓冲 vs 忽略须在实现定义后锁定**（story AC-7 留白；dev 锁定行为后测试固化，两种行为其一均可，但断言必须存在）
2. 已访问节点点击（无反应）+ 悬停已探索标记（AC-4）
3. `step_reached=3` 与 `step_reached=1` 的 tutorial_skipped 载荷区分
4. 教程已完成标记从 GSM 持久设置读取（零状态所有权——断言 UI 不自建持久化）
5. AP=0 但 Boss 在当前节点（GDD 边界：Boss 仍可交互，弹确认）
6. 战败返回路径不回节点图（GDD B8 边界——战败→地图选择，非本 story 但移动流断言不得含战败回图分支）

**预估数量**：约 12-15 例。

### 17-2 combat-ui-layout 007（UI Logic 内核，2.0d）

**文件**：`tests/unit/combat_ui/test_deploy_selection_state.gd` + `tests/unit/combat_ui/test_formation_slot_layout.gd`

**测试内容**：
- **4 态判定**：`deploy_selection_state(is_dead, is_selected, selected_count, max_deploy)` —— 阵亡→不可用（优先）；已选→✓；未选+未满→☐；未选+已满+未阵亡→⊕。
- **境界→阵位映射**：`formation_slot_layout(realm_id)` —— 炼气(2,1)/筑基(2,2)/金丹(2,2)/元婴(3,2)/化神(3,3)；slots ≥ max_deploy 不变量（炼气 3≥2）。
- **确认按钮**：`confirm_button_enabled(selected_count)` —— 0 false / 1 true / 满员 true。

**边界情况**：
1. 阵亡且名额未满（仍不可用——阵亡优先级断言）
2. selected_count == max 恰好边界；max=1
3. **未知 realm → 显式报错（非静默默认）**——断言报错路径
4. **manifest 禁令**：境界→阵位映射必须数据驱动（非硬编码 if-elif 链）——测试以「新增表项不改函数体」的结构性口径覆盖（五个 realm 全枚举断言即同时锁定表驱动语义）
5. 确认按钮 0/1 边界

**预估数量**：4 态约 8 例 + 逐元素约 10 例 + 边界约 4 例 ≈ **20-22 例**（两文件合计）。

### 17-3 exploration-ui 006（Integration，1.5d）

**文件**：`tests/integration/exploration_ui/test_node_interaction_popups.gd`

**测试内容**（story AC-1/AC-2，GDD 节点弹窗 AC B5/B9 修正后 9 条 + §4c 分发表）：
- **分发表路由**（AC-1）：combat/shop/spring/rest/tribulation 五种 interaction_type 依次发射 → 各自弹窗打开且**仅一个弹窗实例**存在。
- **防双面板断言**：事件节点类型不在分发表——event_node_reached 信号不产生任何探索 UI 弹窗（GDD 显式排除规则，EventSystem 面板接管）。
- **确认/取消流**（AC-2）：战斗弹窗「先等等」→ 弹窗关闭、玩家位置/AP 不变（停留该节点——B4 裁决取消不回退移动）、无场景切换。

**边界情况**：
1. 渡劫台修为未满——信号载荷含 not_ready 标记时**无弹窗**（003 渲染联动侧）
2. 弹窗期间 ESC 等效「先等等」（UX AC）
3. **manifest 禁令**：UI 不计算回复量/商店价格——灵泉「使用灵泉」断言调用的是探索系统 API（方法调用断言）而非本地数值
4. 渡劫台走 `node_interaction_triggered` 而非独立信号（与 Boss 的 boss_node_reached 区分——后者归 007，不在本 story 测试内）
5. 商店 overlay 节点图冻结（输入锁/mouse_filter 切换断言——弹窗打开时底层缩放/平移/点击无效）
6. 传送节点无交互实现（按普通节点渲染，零弹窗断言）

**注**：背景模糊 40% D3D12 帧率抽查（A8 Guardrail）**不在本测试文件**——已拆出为 QA-17-4 ADVISORY 复测项，不阻塞 story-done。

**预估数量**：约 14-18 例。

### 17-4 combat-ui-layout 008（UI Logic 内核，2.0d）

**文件**：`tests/integration/combat_ui/test_loot_delay_clickable.gd`

**测试内容**（story AC-1/AC-2，GDD 结算 AC 6 条 + 撤退 AC 4 条）：
- **0.5s 延迟可点**（AC-1）：胜利面板弹出 → SceneTreeTimer 推进断言（**非真实等待**）：0.5s 内确认按钮 disabled、之后 enabled；未选中任何项时确认按钮灰。
- **面板触发信号**（AC-2）：胜利/战败/撤退按钮点击信号 → 对应面板 visible。

**边界情况**：
1. **恰 0.5s 边界**（实现定义固化——Timer 语义下 0.5s 整点属于禁用还是启用，dev 锁定后测试写死）
2. 卡组满时卡牌选项 disabled（灰显数据驱动，从卡组系统读取）
3. 撤退渡劫变体：is_tribulation=true 切换红框+特殊文案（断言两变体渲染字段）
4. **面板不自动关闭**（manifest 禁令——推进时间后面板仍 visible）
5. 结算三选一等宽网格（`(panel_width - margins) / 3`，GDD 边界——渲染侧数值断言或 ADVISORY 走查覆盖，集成测试断言列数/等宽属性）

**预估数量**：约 10-14 例。

### 17-5 combat-ui-interaction 001（Integration，should，1.5d）

**文件**：`tests/unit/combat_ui/test_esc_arbitration.gd` + `tests/integration/combat_ui/test_modal_freeze_stub.gd`

**测试内容**：
- **ESC 仲裁纯函数**（Logic 内核，AC-1）：`resolve_esc_target(lock_stack)` —— 空栈→pause_menu；[MODAL(loot_screen)]→loot_screen；[DIALOGUE, MODAL(retreat)]→retreat（**最上层即最后 push 者胜**）；[ANIMATION]→pause_menu（ANIMATION 不拦截 ESC）。
- **stub 弹窗冻结**（Integration，AC-2）：push MODAL 后底层 Control `_gui_input` 不触发（信号未触发断言）；pop 后恢复响应。

**边界情况**：
1. 同层多 MODAL（后 push 者胜）
2. TRANSITION 锁——ESC 无效（返回值标识忽略）
3. push/pop 配对——重复 push 警告、未 push 的 pop 警告（StringName source 追踪，manifest ADR-0004 必需模式）
4. GAMEPLAY 动作排队：锁期间撤退点击**排队而非丢弃**——锁释放后执行（断言排队队列语义）
5. `is_input_allowed()` 双焦点设备类型独立判定（MOUSE/KEYBOARD 位掩码——至少各一条用例）

**预估数量**：仲裁纯函数约 8-10 例 + 集成冻结/排队约 8-10 例 ≈ **16-20 例**。

### 17-6 audio 005（Logic + Integration，should，0.5d）

**文件**：`tests/unit/audio/test_mute_controller.gd` + `tests/integration/audio/test_pause_resume_position.gd`

**测试内容**（GDD AC-PAUSE-01~02 / AC-MUTE-01~04 / AC-BUS-01~02 + 边缘 #5/#6/#9）：
- **debounce**（Logic，时间注入 clock: Callable——manifest 必需模式）：clock=0 生效 → 150ms 忽略 → 250ms 生效。
- **恢复值记忆**：Master 用户设置 -3dB → 静音 → 取消 → 恢复 -3dB（非 0dB）。
- **跨场景持久**：静音中 set_state 场景切换（BGM 换曲）→ Master 仍 -80dB；取消后新 BGM 可听。
- **暂停位置保持**（Integration）：BGM 播至 t=5.0s → `pause_all()` → 推进帧 → 位置不变 → `resume_all()` → 从 5.0s 继续。
- **总线独立性**：set_bus_volume(SFX, -40) → SFX -40dB / BGM 0dB / Ambient -10dB。

**边界情况**：
1. clock=199ms（忽略）与 200ms（生效）**分界**——精确边界双用例
2. 默认 0dB 时恢复 0dB；连续静音→取消→静音循环
3. 暂停中请求 play_sfx（音频总线显式暂停——不播放，ADR-0031 §1.1）
4. 静音中 pause_all/resume_all 往返
5. get_bus_volume ±0.5dB 精度（AC-BUS-02，GDD 边缘 #9 滑条 0% 语义同源）
6. **回归项**（story 实现注记明确要求）：暂停菜单打开→音频同步暂停/恢复——hud 侧 `PauseAudioAdapter` 桩阶段只断言 adapter 方法被调用，**总线/播放器状态断言归本 story 集成测试**（此为本 story 对接义务，须有对应用例）
7. `pause_all()/resume_all()` 幂等（manifest 护栏）

**预估数量**：Logic 约 12-15 例 + Integration 约 8-10 例 ≈ **20-25 例**。

### 17-7 main-menu 005（UI + Integration，should，1.0d）

**文件**：`tests/integration/main_menu/test_locale_switch.gd`

**测试内容**（GDD AC-main-menu-019）：
- **locale 切换即时生效**：zh→en 应用 → `TranslationServer.get_locale()` 前缀 == "en"；**探针控件文本 ≥3 处**（主菜单按钮/设置分类标签/制作人员标题各 1——manifest 必需模式，锁定可测试性）全部变为英文。
- **缺失翻译键回退**：故意缺失某 en 键 → 显示默认语言（zh）文本，无空白/键名裸露。

**边界情况**：
1. en→zh 往返一致
2. 刷新在 1 帧内完成（无中间状态可见——manifest 护栏，断言同帧文本已切换）
3. 全部键齐全（正常切换无回退误报）
4. 语言选择持久化到设置文件（文件回读断言）
5. 「恢复默认」重置为简体中文（Story 003 联动）

**预估数量**：约 8-10 例。

### 17-8 hud 008（UI，should，0.5d）——原子对第二环

**文件**：**追加用例**至 `tests/integration/hud/test_gsm_signal_binding.gd`（非新文件）

**测试内容**：
- **信号驱动显示切换**（AC-1）：emit `mute_state_changed(true)` → 图标 visible；emit `(false)` → 隐藏。
- **战斗可见性联动**（AC-2）：HUD 整体隐藏时图标随之隐藏；回探索后若仍静音恢复显示。

**边界情况**：
1. HUD 挂载时已静音（初始化查询显示正确——唯一允许的主动查询）
2. 连续快速切换（最终态一致）
3. 战斗中取消静音（信号到达时 HUD 隐藏——状态更新但不可见，恢复可见后正确）
4. **manifest 禁令断言**：HUD 零静音状态缓存——不存储，仅按信号切换（结构断言）

**预估数量**：追加约 5-7 例。

### 17-9 exploration-ui 004（UI Logic 内核，nice，1.5d）

**文件**：`tests/unit/exploration_ui/test_ap_bar_color.gd`

**测试内容**（GDD 公式 2 修正版，B2 裁决语义）：
- `ap_bar_color(current, max)` 边界全表：(7,10)→BLUE；(3,10)→YELLOW（ratio=0.3 恰界属黄）；(1,10)→RED（ratio=0.1 恰界属红）；(0,10)→GRAY（守卫优先于红）；(5,5)→BLUE；(3,0)→RED（max=0 守卫）。

**边界情况**：
1. current > max 非法输入（防御性返回 BLUE 或 clamp——**实现定义后测试锁定**，同 17-1 的缓冲/忽略处理方式）
2. 化神 13 格上限：AP 13→0 逐格熄灭断言（AC-2，格数=current 同步）
3. 连续快速消耗（动画中断直接到位）；回复全部 0→13 逐格亮起
4. 数据通路必须消费 GSM `batch_updated` 的 `exploration.action_points` 路径（manifest A1 禁止第二套数据通路——与 HUD AP 同信号源断言）

**预估数量**：颜色约 8-10 例 + 指示器同步约 6-8 例 ≈ **14-18 例**。

---

## 3. 手动 QA 检查清单（ADVISORY 签收项——依托 QA-17-1 D3D12 视觉路径）

> **路径依赖**：本冲刺全部 UI 截图证据走 QA-17-1 搭建的 D3D12 窗口截图脚本 + 图像 diff（沿用 R-05/R-02 已跑通基准方法）。QA-17-1 于 S17 首周启动，产出后同步回填 S16 遗留 5 个证据文档（identity-select / map-select / node-graph-render / topbar / cost-bar）。

### 17-1 节点移动交互（走查 + 截图）
**验证方法**：窗口模式手动走查 + D3D12 截图
**签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/node-move-interaction-evidence.md`
- [ ] 可达节点点击 → 移动动画 ≤0.5s/节点 + AP 数字滚动 + 迷雾揭示
- [ ] 不可达点击：节点抖动 + toast 文案正确（行动力不足/路径不可达二分）
- [ ] 已访问节点：无反应 + 悬停已探索标记（边框绿+✓ 0.2s）
- [ ] 悬停可达节点：110% 放大 + tooltip 0.3s 内浮出
- [ ] 键盘路径：方向键空间跳转 + Enter 确认移动
- [ ] 教程 3 步显示/跳过/二次不显示

### 17-2 部署面板视觉（五境界截图）
**验证方法**：五境界分别进入备战 + D3D12 截图对比
**签收人**：ui-programmer + lead-programmer
**证据**：`production/qa/evidence/deploy-panel-evidence.md`
- [ ] 4 态视觉可区分（✓金高亮 / ☐ / ⊕ / 💀灰）——构造阵亡/满员场景
- [ ] 五个阵位布局截图与境界映射表逐张对比
- [ ] 「还可以选择X人」提示正确
- [ ] 确认按钮灰态（0 已选时）

### 17-3 五类弹窗走查
**验证方法**：依次到达五类节点 + D3D12 截图
**签收人**：ui-programmer + lead-programmer + qa-lead
**证据**：`production/qa/evidence/node-popups-evidence.md`
- [ ] 五类弹窗内容：战斗（敌人名称/数量/境界/推荐战力）、灵泉、回复（50% 文案与公式 7 一致）、渡劫（**朱砂红 80% 警示——不与 Boss 50% 混用**）、商店（overlay 冻结）
- [ ] 节点附近弹出（非全屏覆盖）+ 0.2s 放大淡入 / 0.15s 缩小淡出
- [ ] 背景模糊 40% 视觉生效、节点图可见不可操作
- [ ] 修为未满渡劫台：「修为尚未圆满」不可触发态
- [ ] **模糊开启时 60fps 抽查记录附于证据文档（QA-17-4 口径：不达标记录上报，不阻塞本 story）**

### 17-4 结算/撤退面板（五场景截图）
**验证方法**：构造胜利（含卡组满）/战败/普通撤退/渡劫撤退/渡劫进入五场景
**签收人**：ui-programmer + lead-programmer
**证据**：`production/qa/evidence/settlement-retreat-evidence.md`
- [ ] 三选一均匀等宽网格 + 垂直居中
- [ ] 0.5s 延迟体感正确；卡组满「卡组已满」灰显
- [ ] 渡劫撤退红框 +「畏劫而退，修为散尽」80% 警示文案
- [ ] 渡劫战前 warning 在备战界面弹出（时机统一裁决）
- [ ] 无自动关闭（观察 5s+）

### 17-5 双焦点视觉基建（首丢项）
**验证方法**：stub 按钮键盘 Tab 与鼠标悬停分别激活
**签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/combat-input-base-evidence.md`
- [ ] 键盘焦点→松石青 2px 焦点环；悬停→墨色边框加粗+微发光
- [ ] 同时激活→悬停态优先（与 R-01 spike 结论一致）

### 17-7 语言切换全界面核对
**验证方法**：主菜单/设置/制作人员 zh 截图 → 切 en 逐屏核对 → 重启验证持久
**签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/locale-switch-evidence.md`（附探针字符串清单）
- [ ] 三界面所有文本更新（5 按钮、4 分类、按键表、制作人员列表）
- [ ] 无残留中文、无空白、无需重启
- [ ] 重启后语言保持 en

### 17-8 静音图标视觉
**验证方法**：运行中按 F1 观察图标
**签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/mute-icon-evidence.md`
- [ ] F1 图标出现/消失即时；位置不遮挡关键信息
- [ ] 跨场景持久期间保持显示

### 17-9 AP 指示器颜色态走查
**验证方法**：构造 AP>30% / 10~30% / ≤10% / =0 四态（+「减少动态」开启）
**签收人**：ui-programmer + qa-lead
**证据**：`production/qa/evidence/ap-indicator-evidence.md`
- [ ] 四态颜色/闪烁与 B2 裁决语义一致
- [ ] 黄/红阶段文字+图标提示（无障碍）
- [ ] 「减少动态」开启 → 静态红边框无闪烁
- [ ] 13 格在 1080p 基准不溢出

---

## 4. 冒烟测试范围（`/smoke-check`——QA 交接前置关卡）

**基线**：S16 全量 3104 tests / 3103 passing / 1 pending（存量 `test_migration_chain`，已知非回归）。本冲刺口径：**存量零回归 + 新增全通过**。

关键路径（新游戏→……→F1，按依赖链顺序）：
1. **启动到主菜单无崩溃**（含 CI 已上线口径）
2. **新游戏 → 身份选择 → 地图选择**（S16 已覆盖路径回归）
3. **节点图移动交互**（17-1）：点击移动 + AP 扣减 + 不可达反馈——核心循环第二跳入口
4. **节点交互弹窗**（17-3）：至少战斗确认与「先等等」取消流一往返（五类弹窗在手动走查覆盖，冒烟只锁主路径）
5. **战斗部署面板**（17-2）：进入备战 + 4 态渲染 + 确认按钮状态
6. **结算/撤退面板**（17-4）：胜利面板 0.5s 延迟 + 撤退确认普通变体
7. **语言切换**（17-7，如交付）：主菜单 zh→en 往返 + 重启持久
8. **F1 静音**（17-6+17-8 原子对，如交付）：静音开关 + 图标显示切换
9. **存档/读档回归**（S16 冒烟项保持）
10. **代码层锁定**：全部新增自动化测试文件通过 + 存量 3103 passing 不降

**失败即阻断**：任一关键路径崩溃/S1 → 构建不进入手动 QA。

---

## 5. 试玩要求

本冲刺无需正式试玩会期（核心循环第二跳的「手感」验证与背景模糊体感由 QA-17-4 ADVISORY 复测及视觉走查覆盖；设计侧 polish 阶段试玩后置）。**建议项（非阻塞）**：若 17-1~17-4 全部交付，安排 30 分钟内部快速试玩——新游戏到第一场战斗结算的完整第二段循环，观察教程流/弹窗节奏/结算延迟体感，反馈以 S3/S4 缺陷或 polish 备忘记录。

---

## 6. QA 专项任务（非编码容量，并行执行）

| ID | 任务 | 负责人 | 验收 |
|----|------|--------|------|
| QA-17-1 | D3D12 视觉验证路径搭建（窗口截图脚本 + 图像 diff） | qa-lead | 脚本产出 + 首批截图样例；**S16 五个遗留证据文档回填闭环** |
| QA-17-2 | S16-3 三条缺陷风险走查确认（串行依赖 QA-17-1 路径） | qa-tester | 三条逐一裁决；不符则开缺陷报告 |
| QA-17-3 | tech-debt-register 补登（S15-9 四项 + audio 004 四项 S 建议） | qa-lead | 留痕闭环 |
| QA-17-4 | ADVISORY 复测项登记：17-3 背景模糊 40% D3D12 帧率抽查 | qa-lead | 抽查记录落盘（≥60fps 通过；不达标上报，不在 story 内优化） |

---

## 7. 完成定义（本冲刺 QA 关卡）

- [ ] 所有 must story 完成（或经 Day-3/Day-4 硬化检查点**显式丢弃并记录**——丢弃时对应测试条目作废，签收报告载明）
- [ ] 所有 Logic/Integration story 的测试文件存在于 story 指定路径且通过（BLOCKING 关卡，story-done 前核查）：
  - `tests/integration/exploration_ui/test_node_move_interaction.gd` / `test_node_interaction_popups.gd`
  - `tests/unit/combat_ui/test_deploy_selection_state.gd` / `test_formation_slot_layout.gd` / `test_esc_arbitration.gd`（should）
  - `tests/integration/combat_ui/test_loot_delay_clickable.gd` / `test_modal_freeze_stub.gd`（should）
  - `tests/unit/audio/test_mute_controller.gd` + `tests/integration/audio/test_pause_resume_position.gd`（should）
  - `tests/integration/main_menu/test_locale_switch.gd`（should）
  - `tests/integration/hud/test_gsm_signal_binding.gd` 追加用例（should，原子对）
  - `tests/unit/exploration_ui/test_ap_bar_color.gd`（nice）
- [ ] 存量回归：S16 基线 3103 passing 不降（1 pending 存量豁免）
- [ ] 冒烟检查通过（`/smoke-check sprint`，关键路径 10 项）
- [ ] UI 证据文档落盘 + 签收（17 个新证据项，依托 QA-17-1 路径）+ **S16 遗留 5 个证据文档回填闭环**
- [ ] 17-6 交付则原子对回归项（PauseAudioAdapter 真实实现的同步断言）已覆盖；17-6 丢弃则 17-8 一并作废记录
- [ ] 交付特性中无 S1/S2 缺陷
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 偏差已更新设计文档（如 B4/B5/B9 裁决在实现中偏移）
- [ ] story-done 关闭前 git 工作区无本 story 文件残留（S16 流程改进）
- [ ] QA-17-4 抽查记录落盘（ADVISORY，不构成 17-3 阻塞）

**预估新增自动化测试总量**：约 120-150 例（9 story 合计，must 4 项约 56-69 例）。
