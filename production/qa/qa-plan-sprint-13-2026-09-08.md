# QA 计划：Sprint 13（HUD 全量 + 风险 spike）

**日期**：2026-09-08
**由**：/qa-plan 生成
**范围**：Sprint 13 的 12 个 story + 3 个 spike（R-01/R-06/R-03）+ 1 个 QA 签收 story——涉及 hud / audio-manager / combat-ui-layout / qa 四个 epic
**引擎**：Godot 4.6（Forward+，D3D12 默认）
**Sprint 文件**：production/sprints/sprint-13.md
**测试基线**：Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0（零回归为硬约束）

---

## 测试摘要

| Story | 类型 | 需要自动化测试 | 需要手动验证 |
|-------|------|------------------------|------------------------------|
| S13-1 R-01 双焦点 spike | Spike | 无 | 目标硬件实测记录+OQ-02 关闭 |
| S13-2 hud 001 CanvasLayer 挂载与可见性 | Integration | `tests/integration/hud/hud_scene_visibility_test.gd` | 无 |
| S13-3 hud 002 境界+修为条 | UI+Logic 内核 | `tests/unit/hud/test_cultivation_bar_state.gd`（BLOCKING） | 截图+动画走查 |
| S13-4 hud 003 灵石+卡组计数 | UI+Logic 内核 | `tests/unit/hud/test_lingshi_deck_counter.gd`（BLOCKING） | 截图+动画走查 |
| S13-5 hud 004 通知系统 | Logic | `tests/unit/hud/notification_stack_test.gd`（BLOCKING） | 滑入滑出动画走查 |
| S13-6 hud 005 暂停菜单 | UI+Integration | `tests/integration/hud/pause_menu_test.gd` | 菜单项走查+模糊动画 |
| S13-7 QA 签收 | QA | 全量回归 2455 测试 | 冒烟检查+证据归档审阅 |
| S13-8 R-06 Ogg 循环 spike | Spike | 无 | 目标硬件听感实测+格式裁决记录 |
| S13-9 hud 006 探索 HUD 右下信息组 | UI+Logic 内核 | `tests/unit/hud/test_ap_color_threshold.gd`（BLOCKING——共享纯函数） | 截图+分段格走查 |
| S13-10 hud 007 场景切换过渡提示 | UI+Logic | `tests/unit/hud/test_transition_hint_map.gd` | 转场走查 |
| S13-11 R-02 合批方案定型 | Visual/Feel（spike） | 无（不可自动化——DC 实测须窗口模式） | 原型 DC 实测记录+规范文档 |
| S13-12 R-03 D3D12 冒烟 | Spike | 无 | 目标硬件渲染对比记录 |
| S13-13 hud 008 F1 静音图标 | UI+Integration | `tests/integration/hud/mute_icon_test.gd` | 图标视觉走查 |
| S13-14 audio 001 总线+骨架 | Integration | `tests/unit/audio_manager/test_bus_layout.gd` + `test_api_skeleton.gd` | 无 |

**分类统计**：Logic 内核 4 个（hud 002/003/004/006——hud 007 一半）、Integration 4 个（hud 001/005/008、audio 001）、Visual/Feel spike 2 个（R-02/R-06+R-03+R-01 实测类）、纯 spike 3 个、QA 签收 1 个。合计新增测试文件约 **10 个**、预估新增测试用例 **~60 个**。

---

## 需要自动化测试

### S13-2 hud 001 CanvasLayer 挂载与可见性 — Integration
**测试文件路径**：`tests/integration/hud/hud_scene_visibility_test.gd`
**测试内容**：
- 探索/地图选择/商店/事件场景加载后 HUD CanvasLayer 存在于场景树且 visible == true
- 探索→战斗转场完成后 HUD visible == false（所有子元素无一渲染）
- 战斗→探索返回后 HUD 恢复可见
- 可见性切换由 SceneManager 信号回调触发——`_process` 中无场景类型轮询（源码断言）

**需要覆盖的边界情况**：
- 转场中途（pre_transition 已发、post_transition 未发）状态确定性
- HUD 成员变量无 GSM 域赋值语句（零状态副本 grep 断言——AC-4）
- 连续两次快速转场（探索→战斗→探索）后最终可见状态正确

**预估测试数量**：~6 个集成测试

---

### S13-3 hud 002 境界+修为条 — UI+Logic 内核
**测试文件路径**：`tests/unit/hud/test_cultivation_bar_state.gd`
**测试内容**（纯函数 `get_cultivation_bar_state(realm_id, is_fallen, current, max_val)`）：
- 颜色阈值：p<50% → "blue"、50%≤p<90% → "purple"、p≥90% → "gold"（阈值来自数据驱动配置）
- pulsing：p≥90% 为 true
- is_fallen → label「炼气·落难」
- 化神期+修为满 → show_bar=false、label「可飞升」

**需要覆盖的边界情况**：
- p=49.9%/50%/89.9%/90%/100%；max_val=0（防除零）；负数输入；化神期未满；非化神期满；is_fallen 且修为满

**预估测试数量**：~12 个单元测试

---

### S13-4 hud 003 灵石+卡组计数 — UI+Logic 内核
**测试文件路径**：`tests/unit/hud/test_lingshi_deck_counter.gd`
**测试内容**：
- `format_lingshi(amount)`：999→"999"、1000→"1.0k"、1250→"1.2k"、9999→"9.9k"；10000+ 按临时锁定实现（4 位 k 格式）
- `get_deck_count_state(count, cap)`：count<cap normal / count==cap yellow / count>cap red+flashing+overlimit
- 灵石数据绑定：`resource_changed` 信号后显示文本更新（不含动画断言）

**需要覆盖的边界情况**：
- 0 灵石、负数输入（防御性）；卡组 0/20、28/30、30/30、32/30、cap=0；连续多次变更（最后一次生效）；战斗隐藏期间变更（恢复后显示最新值）

**预估测试数量**：~14 个单元测试

---

### S13-5 hud 004 通知系统 — Logic
**测试文件路径**：`tests/unit/hud/notification_stack_test.gd`
**测试内容**（`NotificationStack` 类，时间注入）：
- 按类型自动消失：道具/卡牌 3s、灵石/修为 2s、战斗事件 3s、系统/错误 5s
- 容量上限：3 条普通+push 第 4 条 → 最早普通通知被丢弃
- 重要通知不被挤出；全重要通知时的确定性规则（锁定）
- 手动关闭立即移除+堆叠重排

**需要覆盖的边界情况**：
- 时间推进不足时仍在队列；3 条含重要的丢弃规则；连续 2 条重要通知；关闭最早一条后重排
- *在引用的 GDD（hud-system.md）中公式不适用——本 story 无公式，测试从验收标准与类型时长表推导*

**预估测试数量**：~12 个单元测试

---

### S13-6 hud 005 暂停菜单 — UI+Integration
**测试文件路径**：`tests/integration/hud/pause_menu_test.gd`
**测试内容**：
- ESC 触发：`SceneTree.paused == true` + 菜单 visible；再按 ESC 恢复
- 战斗状态保持（AC-hud-011）：进入战斗第 3 回合→暂停→恢复，断言回合数/角色 HP/费用/牌库弃牌堆计数不变
- 音频同步暂停：暂停后总线暂停，恢复后继续；暂停中 SFX 请求不播放

**需要覆盖的边界情况**：
- 连续快速按 ESC（无状态错乱）；暂停发生在动画播放中（逻辑状态必须不变）；战斗中暂停后恢复

**预估测试数量**：~8 个集成测试

---

### S13-9 hud 006 探索 HUD 右下信息组 — UI+Logic 内核（共享纯函数）
**测试文件路径**：`tests/unit/hud/test_ap_color_threshold.gd`
**测试内容**（共享纯函数 `get_ap_color_threshold(current, max_val)`——HUD 与 exploration-ui 共用判定源）：
- 阈值判定（配置驱动）：按 exploration-ui B2 裁决标准 0.3 黄/0.1 红/0 灰（以配置常量为准）
- AP 数据绑定：`action_points_changed` 信号后显示更新

**需要覆盖的边界情况**：
- 0/5（GRAY——恰 0 归灰）、1/5（RED）、3/5（YELLOW）、5/5（BLUE）、max_val=0（防除零）、current>max_val（防御性）；连续变更；战斗隐藏期间变更
- **对齐提示**：exploration-ui story 004 的 `ap_bar_color` 边界用例与本测试须一致（(7,10)→BLUE/(3,10)→YELLOW/(1,10)→RED/(0,10)→GRAY/(5,5)→BLUE/(3,0)→RED）——同一共享函数、同一套锁定测试

**预估测试数量**：~10 个单元测试

---

### S13-10 hud 007 场景切换过渡提示 — UI+Logic
**测试文件路径**：`tests/unit/hud/test_transition_hint_map.gd`
**测试内容**：
- 映射表查询：(exploration, combat) → 「进入战斗」1s；(exploration, shop) → 「坊市」0.5s；(combat, exploration) → 空
- 信号驱动：pre_transition 发射后提示容器 visible+内容正确；时长后自动隐藏

**需要覆盖的边界情况**：
- 未映射组合返回空不报错；提示显示期间再次转场（旧提示替换的确定性规则）；地图加载进度指示由 post_transition 关闭

**预估测试数量**：~6 个单元测试

---

### S13-13 hud 008 F1 静音图标 — UI+Integration
**测试文件路径**：`tests/integration/hud/mute_icon_test.gd`
**测试内容**：
- `mute_state_changed(true)/(false)` 信号驱动图标显隐
- HUD 挂载时已静音（初始化查询正确显示）
- 战斗可见性联动：HUD 隐藏时图标随之隐藏；回探索后若仍静音恢复显示

**需要覆盖的边界情况**：
- 连续快速切换（最终态一致）；战斗中取消静音（状态更新但不可见，恢复后正确）

**预估测试数量**：~5 个集成测试

---

### S13-14 audio 001 总线+AudioManager 骨架 — Integration
**测试文件路径**：`tests/unit/audio_manager/test_bus_layout.gd` + `tests/unit/audio_manager/test_api_skeleton.gd`
**测试内容**：
- 总线结构存在性（按名称断言——禁整数索引）：6 总线+3 SFX 子总线+默认 dB 值+Limiter 参数
- PersistentLayer 挂载：节点池存在且 process_mode 不受场景切换影响；场景切换后仍存在
- 静默模式：注入不可用适配器 → no-op 不崩溃+日志一次
- API 骨架签名：11 个 API 与 GDD §8 一致

**需要覆盖的边界情况**：
- 重名总线不存在；效果器参数安全范围；恢复可用后 API 正常

**预估测试数量**：~10 个单元/集成测试

---

## 手动 QA 检查清单

### S13-1 R-01 双焦点 spike — Spike 实测
**验证方法**：目标硬件实测记录（spike 报告）
**必须签收人**：lead-programmer（OQ-02 关闭写入 architecture.md）
**需要捕获的证据**：`production/spikes/r01-dual-focus-spike.md`——`_gui_input()`/`_unhandled_input()` 响应差异、`grab_focus()` 对鼠标 hover 影响的实测结论+双视觉策略修正（或确认无需修正）

检查清单：
- [ ] 自定义 Control 组件上鼠标 hover 与键盘焦点可同时激活且视觉可区分
- [ ] `grab_focus()` 不改变鼠标 hover 态（或实测结论与假设不符——记录修正）
- [ ] 输入锁栈 `check_device_allowed()` 设备类型判定在双焦点下工作正常
- [ ] 结论写入 OQ-02 关闭 + presentation-layer-risks.md R-01 状态更新

### S13-3 hud 002 境界+修为条 — 动画/光效
**验证方法**：截图+录屏
**必须签收人**：designer
检查清单：
- [ ] 修为≥90% 金色脉动动画循环无卡顿
- [ ] 修为条平滑填充 0.3s 无瞬跳
- [ ] 悬停 tooltip「1800/2250」格式即时显示
- [ ] 炼气·落难破碎光效显示

### S13-6 hud 005 暂停菜单 — UI 走查
**验证方法**：手动逐步验证
**必须签收人**：designer
检查清单：
- [ ] 5 菜单项+探索进度行完整，各按钮路由正确
- [ ] 背景 0.3s 模糊流畅，恢复后计时从暂停点继续

### S13-11 R-02 合批方案定型 — 原型实测
**验证方法**：DC 实测记录+规范文档审阅
**必须签收人**：lead-programmer
**需要捕获的证据**：`production/qa/evidence/r02-batching-spec.md`
检查清单：
- [ ] 16 角色卡原型每位 ≤4 DC（连续 60 帧稳定采样）
- [ ] 合批规范五节齐备（图集结构/HP 条/DC 分组/fallback 优先级/测量方法）——002-006 开发者无需再做渲染决策

### S13-8 R-06 Ogg 循环 spike — 听感实测
**验证方法**：目标硬件听感实测记录
**必须签收人**：designer（格式裁决）+audio-director
**需要捕获的证据**：`production/spikes/r06-ogg-loop-spike.md`——间隙时长实测+WAV/Ogg 裁决+R-06 关闭

### S13-12 R-03 D3D12 冒烟 — 渲染对比
**验证方法**：目标硬件 D3D12 vs Vulkan 对比冒烟+截图工具链验证
**必须签收人**：lead-programmer
**需要捕获的证据**：spike 记录——异常清单或回退策略确认（`--rendering-driver vulkan`）

### S13-7 QA 签收 — 汇总
**验证方法**：全量回归+证据归档审阅+冒烟检查
**必须签收人**：qa-lead
检查清单：
- [ ] 2455 既有测试零回归+新增 ~60 测试全通过
- [ ] 全部手动证据文档归档（上述各 spike/evidence 文件）
- [ ] 冒烟检查通过（`/smoke-check sprint`）
- [ ] OQ-02/R-01/R-02/R-03/R-06 风险状态在 presentation-layer-risks.md 更新

---

## 冒烟测试范围

在此 sprint 的任何 QA 交接前需要验证的关键路径：

1. 游戏启动到主菜单无崩溃
2. 可以开始新游戏/新会话（身份选择→初始地图）
3. HUD 在探索场景正确显示（境界条/灵石/卡组计数/AP 信息组）——本 sprint 主要新增机制
4. 战斗场景 HUD 隐藏且暂停菜单可用（战斗状态保持）
5. 通知系统：获得灵石/道具时顶部通知滑入消失
6. 存档/读档周期完成无数据丢失（hud 001 转场+hud 005 保存并退出路径）
7. 性能在目标硬件上符合预算：HUD 各组件渲染不新增帧尖峰（D3D12 冒烟联动 R-03）

---

## 试玩要求

| Story | 试玩目标 | 最少会期数 | 目标玩家类型 |
|-------|--------------|--------------|-------------------|
| hud 005 暂停菜单 | 暂停/恢复流程是否直觉（ESC 进入/退出）？菜单项是否可发现？ | 1 | 有经验玩家 |
| hud 004 通知系统 | 通知 2-5s 时长是否够读？堆叠 3 条是否造成困扰？ | 1（可与上一项合并会期） | 新玩家 |

**签收要求**：试玩笔记写入 `production/session-logs/playtest-sprint13-hud.md`，由 designer 审查后方可标记 hud 004/005 完成。

*其余 story 无需试玩验证（组件级验证以截图+走查覆盖）。*

---

## 完成定义 — 本次 Sprint

当以下所有条件都满足时，story 才算完成：

- [ ] 所有验收标准已验证——通过自动化测试结果或记录的手动证据（spike 报告/截图/录屏/带签收的试玩笔记）
- [ ] 所有逻辑和集成类 story 的测试文件存在于指定路径（4 个 Logic 内核+4 个 Integration 测试文件）
- [ ] 所有视觉/手感和 UI 类 story 的手动证据文档存在
- [ ] 3 个 spike 报告存在且结论写入对应风险登记册/OQ 条目
- [ ] 冒烟检查通过（在 QA 交接前运行 `/smoke-check sprint`）
- [ ] 未引入回归问题——2455 既有测试全部通过
- [ ] 代码已审查（通过 `/code-review` 或记录的同行评审）
- [ ] Story 文件已更新为 `Status: Complete`（通过 `/story-done`）
