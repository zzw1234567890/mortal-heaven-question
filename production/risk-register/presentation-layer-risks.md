# 表现层风险登记册 (Presentation Layer Risk Register)

> **创建日期**：2026-09-07
> **适用范围**：Sprint 13+ 表现层（UI）开发——战斗 UI、探索 UI、卡组编辑 UI、HUD、主菜单与设置、音频管理
> **审查节奏**：每个冲刺结束时复查；风险状态变更时立即更新
> **来源**：architecture.md §PRESENTATION 层、ADR-0004、control-manifest 全局规则、combat-ui.md / exploration-ui.md UX 规范、audio-system.md GDD

---

## 风险汇总

| # | 风险 | 概率 | 影响 | 等级 | 状态 | 所有者 |
|---|------|------|------|------|------|--------|
| R-01 | Godot 4.6 双焦点系统在自定义 Control 组件上的实际行为未验证 | 高 | 高 | 🔴 高 | 已关闭（2026-09-08 spike） | ui-programmer |
| R-02 | Draw Call 超 200 预算（战斗 16 角色卡 + 手牌 + 节点图迷雾） | 中 | 高 | 🔴 高 | 开放 | ui-programmer |
| R-03 | D3D12 默认渲染器兼容性（Windows 驱动差异） | 中 | 中 | 🟡 中 | 开放 | godot-specialist |
| R-04 | AccessKit 屏幕阅读器支持的实际可用性（4.5+，未经项目验证） | 中 | 中 | 🟡 中 | 开放 | accessibility-specialist |
| R-05 | 节点图最坏情况节点数的缩放/平移帧率 | 中 | 高 | 🔴 高 | 开放 | ui-programmer |
| R-06 | Ogg Vorbis 循环间隙（BGM 无缝循环） | 高 | 中 | 🟡 中 | 开放 | audio-director |
| R-07 | Glow 在 tonemapping 之前处理（4.6 变更）——焦点环/高亮视觉效果回归 | 中 | 低 | 🟢 低 | 开放 | godot-shader-specialist |
| R-08 | 25 个 Autoload 超软上限——表现层不得新增 Autoload | 低 | 中 | 🟢 低 | 已缓解 | lead-programmer |
| R-09 | 手柄部分支持范围蔓延（虚拟光标磁性吸附实现复杂度） | 中 | 中 | 🟡 中 | 开放 | ui-programmer |
| R-10 | UI 状态与游戏状态所有权边界（UI 不得拥有游戏状态） | 低 | 高 | 🟡 中 | 已缓解 | lead-programmer |

---

## 风险详情

### R-01 双焦点系统未验证行为 🔴 高（已关闭）

> **2026-09-08 关闭**：Sprint 13 S13-1 spike（`production/spikes/r01-dual-focus-spike.md`）——10/10 PASS。
> 双视觉策略确认无需修正；ADR-0004 路径注释修正（焦点 Control 不自动消耗键盘事件，
> `_unhandled_input` 仍触发——须显式 `accept_event()`）。OQ-02 已关闭。

- **来源**：architecture.md OQ-02（High）、ADR-0004 §知识风险、architecture.md §PRESENTATION 层 HIGH RISK 标记
- **描述**：Godot 4.6 将鼠标/触摸焦点与键盘/手柄焦点分离——`grab_focus()` 只影响键盘/手柄焦点，鼠标 hover 焦点独立存在。自定义 Control 组件上 `_gui_input()` / `_unhandled_input()` 在双焦点下的响应差异未在目标硬件上测试。LLM 知识截止 2025-05，双焦点系统在截止之后——所有相关 API 建议需交叉查阅 `docs/engine-reference/godot/`。
- **影响范围**：全部 5 个 Control 类 UI 系统——焦点环（松石青 2px）vs 鼠标悬停（墨色边框加粗）的双视觉策略、Tab 导航、手柄虚拟光标、输入锁栈的设备类型判定
- **spike 结论**（2026-09-08）：
  1. `grab_focus()` 不影响鼠标 hover——双视觉并存成立，UX 规范无需修正
  2. 焦点 Control 收到键盘 `_gui_input` 但不自动消耗——`_unhandled_input` 仍触发；显式 `accept_event()` 才阻断（ADR-0004 注释修正）
  3. InputManager 设备掩码白名单判定与双焦点正交，工作正常

### R-02 Draw Call 超 200 预算 🔴 高

- **来源**：technical-preferences.md §性能预算、combat-ui.md（16 角色位）、exploration-ui.md（节点图）
- **描述**：战斗场景最坏情况——16 个角色状态卡（每卡 6 层：头像/遮罩/功法法宝图标×6/HP 条/buff 境界图标/待命标记）+ 手牌 7-10 张 + 顶部条 + HUD 元素，独立 Control 各自渲染极易超 200 Draw Call。探索场景节点图（节点+路径+迷雾+HUD）同理。
- **影响范围**：战斗 UI、探索 UI、HUD——帧率跌破 60fps
- **现有缓解**：
  1. 迷雾遮罩模式已注明「合批渲染」
  2. 角色状态卡 L0-L5 分层设计已明确——实现时可采用共享 AtlasTexture
- **待办措施**：
  1. 架构阶段做渲染预算分解（每场景元素数 × 预估 Draw Call）
  2. 规定 UI 图标统一使用图集（Atlas）而非独立纹理
  3. Godot 性能分析器实测战斗满场 + 节点图全图两个基准场景
- **触发条件**：首个战斗场景 UI 组装时
- **关闭条件**：两个基准场景在 1080p 下实测 Draw Call <200 且帧率稳定 60fps

### R-03 D3D12 默认渲染器兼容性 🟡 中

- **来源**：engine-reference/godot/breaking-changes.md（4.6 变更：Windows 默认 D3D12，原为 Vulkan）
- **描述**：Godot 4.6 起 Windows 上默认使用 D3D12（目的为更好的驱动兼容性）。但 D3D12 后处理行为、截图 API、Steam 覆盖层交互在旧驱动/集显上的表现未验证。项目目标平台为 PC（Steam）。
- **影响范围**：全部渲染输出；UI 截图验证流程（coding-standards.md 要求 UI 变更用截图验证）
- **现有缓解**：无（尚未开始表现层实现）
- **待办措施**：
  1. Sprint 13 首周在目标硬件（含最低配置）跑 D3D12 vs Vulkan 渲染对比冒烟
  2. 若 D3D12 有问题，`project.godot` 可显式回退 `--rendering-driver vulkan`
  3. 验证 Steam 覆盖层（technical-preferences.md 平台说明）与截图工具链在 D3D12 下工作
- **触发条件**：Sprint 13 首个渲染输出 story
- **关闭条件**：D3D12 冒烟通过或确认回退策略并记录到 control-manifest

### R-04 AccessKit 屏幕阅读器可用性 🟡 中

- **来源**：engine-reference/godot/breaking-changes.md（4.5 AccessKit）、combat-ui.md / exploration-ui.md 无障碍章节「⚠ 待定」
- **描述**：两份 UX 规范承诺了屏幕阅读器播报（节点焦点播报、AP 变化播报），但 Godot 4.5+ 的 AccessKit 集成在 GDScript 侧的 API 可用性、NVDA/Windows 讲述人兼容性均未经项目验证。无障碍等级承诺为 WCAG-AA。
- **影响范围**：全部 UI 系统的无障碍验收标准
- **现有缓解**：UX 规范已将「屏幕阅读器具体映射」标记为「实现阶段由 accessibility-specialist 定义」——非盲承诺
- **待办措施**：
  1. accessibility-specialist 做 AccessKit 能力摸底（Control 节点 → AccessKit 暴露范围）
  2. 若 GDScript 侧支持不足，降级承诺为「焦点结构可编程访问」并在无障碍需求文档记录偏离
- **触发条件**：首个无障碍 story 实现时
- **关闭条件**：AccessKit 摸底结论写入无障碍需求文档，播报范围最终确定

### R-05 节点图最坏情况性能 🔴 高

- **来源**：exploration-ui.md Open Question #5、ADR-0014（DAG 生成 4-6 层 × 每层 2-4 节点）
- **描述**：节点图最坏情况（6 层 × 4 节点 = 24 节点 + 路径连线 + 迷雾遮罩分段 + 玩家标记 + HUD）在缩放/平移（每帧重绘变换）下的帧率未验证。缩放动画期间所有节点/连线需平滑变换。
- **影响范围**：探索 UI——缩放平移掉帧直接破坏「路线规划」核心体验
- **现有缓解**：
  1. 迷雾遮罩模式已注明合批渲染
  2. 50% 缩放时隐藏节点文字标签（减少渲染元素）
  3. 默认整图适配——多数时间无需缩放
- **待办措施**：Sprint 13 节点图 story 中含性能基准验收（最坏节点数下缩放平移 60fps）
- **触发条件**：节点图渲染实现时
- **关闭条件**：最坏情况基准通过；若不通过，优化（图集/合批/LOD）后复测

### R-06 Ogg Vorbis 循环间隙 🟡 中

- **来源**：audio-system.md GDD 待解决问题 #5（2026-09-06 状态同步审查确认仍开放）、audio-system-review-log.md
- **描述**：Godot 的 Ogg Vorbis 流式播放存在已知循环间隙——BGM 无缝循环（探索/战斗/主菜单 8 首）受影响。
- **影响范围**：音频管理系统——BGM 循环切换时可能出现可听见的间隙
- **现有缓解**：GDD 已记录 WAV 循环变通方案（WAV 支持样本级无缝循环）
- **待办措施**：架构阶段在目标硬件实测 Ogg 间隙时长；若可听见，BGM 改用 WAV（接受内存增大）或双 AudioStreamPlayer 交叉淡化（GDD 已含此架构）
- **触发条件**：音频系统实现时
- **关闭条件**：实测结论 + 选定方案记录到音频系统实现说明

### R-07 Glow 视觉回归 🟢 低

- **来源**：engine-reference/godot/breaking-changes.md（4.6：Glow 在 tonemapping 之前处理）
- **描述**：4.6 变更 Glow 处理顺序——焦点环微发光、悬停高亮、Boss 呼吸发光等依赖 Glow 的 UI 效果可能与设计预想不同。
- **影响范围**：UI 高亮类视觉效果的观感
- **现有缓解**：影响仅限观感（非功能）；UI 层多数发光效果可用 `modulate`/自绘光晕替代，不强依赖 Glow
- **待办措施**：视觉验证 story 中顺带检查；异常时调整 glow 参数或改用自绘效果
- **触发条件**：首个含发光效果的 UI story 验证时
- **关闭条件**：视觉验证通过（记录在 QA 证据）

### R-08 Autoload 超上限 🟢 低（已缓解）

- **来源**：control-manifest 全局规则（25 个 Autoload 超出 Godot 20 软上限）
- **描述**：表现层 6 个系统若按 Autoload 模式实现会继续扩容。
- **缓解措施**（已生效）：
  1. control-manifest 全局规则已规定新系统默认 RefCounted 工具类模式
  2. ADR-0027（对话系统）/ADR-0028/ADR-0029/ADR-0030 已确立先例
  3. 表现层 6 系统均为场景内 UI——天然不需要 Autoload；仅 HUD 需跨场景，由场景管理器挂载
- **残余风险**：HUD 跨场景挂载方案需在架构阶段确认（scene_manager 编排）

### R-09 手柄支持范围蔓延 🟡 中

- **来源**：technical-preferences.md（手柄=部分，可选非 MVP）、combat-ui.md / exploration-ui.md（虚拟光标+磁性吸附设计）
- **描述**：两份 UX 规范为手柄设计了完整路径（虚拟光标、磁性吸附、LB/RB 缩放、A/B/Start 映射）——「部分支持」的范围若无明确边界，实现与测试成本可能蔓延成「完整支持」。
- **影响范围**：全部 UI 系统的手柄交互 story 工作量估算
- **现有缓解**：UX 规范已明确手柄输入映射表（每组件都有）——范围已在纸面收敛
- **待办措施**：`/create-stories` 时将手柄支持拆为独立可选 story（标记 non-MVP），手柄验证 story 标记 ADVISORY 级测试证据
- **触发条件**：story 分解时
- **关闭条件**：Sprint 计划中手柄 story 明确标记范围与优先级

### R-10 UI 状态所有权边界 🟡 中（已缓解）

- **来源**：UX 规范数据需求章节、architecture.md 模块表（UI 系统只暴露 render/update 类 API）
- **描述**：UI 若持有游戏状态副本会导致状态漂移（UI 显示 ≠ 实际状态）。
- **缓解措施**（已生效）：
  1. combat-ui.md / exploration-ui.md 数据需求均声明「UI 不拥有任何游戏状态——全部只读」
  2. 更新频率均为事件驱动（`ap_changed`、`batch_updated` 等 Cat 1 信号）——无轮询无副本
  3. 持久变更事件（`loot_selected`、`map_cleared`、`map_reentry_confirmed`）均有入口二次确认 + 事件触发系统执行
- **残余风险**：实现时图省事直接在 UI 缓存状态——code review 检查项（「UI 不得持有游戏状态副本」加入表现层 control-manifest 规则，见 #5 补充）

---

## 维护记录

| 日期 | 变更 | 操作者 |
|------|------|--------|
| 2026-09-07 | 创建登记册，10 项风险（2 已缓解） | ux-design 会话 |
| 2026-09-08 | R-01 已关闭——S13-1 spike 10/10 PASS（双视觉确认+ADR-0004 注释修正） | Sprint 13 S13-1 spike |
