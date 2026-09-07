# ADR-0031：表现层架构基线 — 场景内 Control 节点 + 零状态所有权 + 事件驱动更新

## 状态

Accepted（2026-09-07——经三轮对抗性审查后接受，4 BLOCKER + 7 HIGH 全部关闭。大小备注：166 行，超出 ≤150 目标但远低于 250 ERROR 阈值——基线 ADR 覆盖 6 系统的共同决策，额外行数用于消除歧义的边界小节 §1.1/§1.2/§2.1，接受此偏离）

## 日期

2026-09-07

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎版本** | Godot 4.6（项目锁定 2026-07-21） |
| **知识风险** | HIGH（4.6 双焦点系统、D3D12 默认渲染器均在 LLM 知识截止 2025-05 之后） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`current-best-practices.md`、ADR-0004（输入管理器）、ADR-0005（场景管理器）、ADR-0007（信号分类法） |
| **使用的截止后 API** | 4.6 双焦点系统（鼠标 ≠ 键盘焦点）；4.5 AccessKit（Control 无障碍）；4.6 D3D12 默认渲染器 |
| **需要验证** | 双焦点在自定义 Control 上的行为（OQ-02 / R-01——Sprint 13 首个 UI story 前置 spike）；Draw Call 基准（R-02）；节点图性能（R-05）；AccessKit 可用性（R-04） |

## ADR 依赖关系

- **依赖**：ADR-0001（GSM——UI 读取的状态源）、ADR-0004（输入管理器——UI 交互的锁栈判定）、ADR-0005（场景管理器——UI 场景切换唯一仲裁）、ADR-0007（信号分类法——UI 更新的触发机制）
- **被依赖**：Sprint 13+ 全部表现层 epic（combat-ui / exploration-ui / deck-editing-ui / hud / main-menu / audio-manager）

## 上下文

表现层 6 个系统（战斗 UI、探索 UI、卡组编辑 UI、HUD、主菜单与设置、音频管理）即将进入实现（Sprint 13）。architecture.md §PRESENTATION 层将整个层标记为 HIGH RISK（4.6 双焦点）。此前的层级各有专属 ADR（Feature 层 17 个、Meta 层 4 个），表现层 6 个系统面临共同的架构问题：

1. **状态所有权**——UI 显示的数据来自 GSM/各系统，若 UI 持有副本会导致显示与实际状态漂移
2. **更新机制**——UI 何时刷新：轮询（每帧读）还是信号（事件驱动）
3. **节点形态**——Autoload（跨场景常驻）还是场景内节点；Autoload 已有 25 个超 20 软上限
4. **输入处理**——4.6 双焦点下键盘焦点与鼠标焦点分离，UI 交互必须过输入锁栈
5. **性能**——Draw Call ≤200 / 60fps 预算下 16 角色卡战斗场景与节点图的渲染策略

这些问题在每个系统重复出现，且答案相同——用一个基线 ADR 统一约束，各系统 epic 不再重复决策。

## 决策

**表现层 UI 系统统一采用：场景内 Control 节点 + 零状态所有权 + 事件驱动更新 + 双焦点双视觉策略。音频系统为结构性例外（持久节点池，见 §1）。**

### 1. 节点形态——场景内节点，零新增 Autoload

- 全部 UI（含暂停菜单——见下方 §1.1）实现为场景内 Control 树（`.tscn` + GDScript），由各游戏场景挂载
- **HUD 例外**：作为 `CanvasLayer` 由 SceneManager 在场景切换时挂载/保留（ADR-0005 的 pre/post 钩子编排），不走 Autoload
- **音频系统例外**：`AudioManager` 的 AudioStreamPlayer 节点池挂在 SceneManager 持久层（见下方 §1.2），由 ADR-0005 的 `pre_transition` 信号驱动音频过渡
- Autoload 计数保持 25，不新增

#### 1.1 暂停菜单——场景内 overlay，非场景切换

- 暂停菜单（`design/ux/pause-menu.md`）是当前场景内的 overlay Control，**不经 SceneManager 转场**（ADR-0005 只管场景间切换，暂停不切换场景）
- 暂停时 `SceneTree.paused = true`；HUD 设 `process_mode = PROCESS_MODE_ALWAYS` 保持可见；音频节点池节点同样 `PROCESS_MODE_ALWAYS`，但由暂停菜单逻辑**显式暂停音频总线**（BGM 与 SFX 一并暂停，与 `design/ux/pause-menu.md` AC「音频暂停」一致）——音频恢复在暂停菜单关闭时执行
- ESC 打开暂停菜单经 ADR-0004 路径 B（`_input()` 拦截），push `modal` 级锁，关闭时 pop——遵循锁栈配对规则

#### 1.2 SceneManager 持久层——音频节点池的挂载结构

- SceneManager 在启动时创建一个持久节点（`root` 直挂的 `Node`，命名 `PersistentLayer`），场景切换（`change_scene_to_file()`）不销毁它
- AudioManager（RefCounted 控制类，非节点）在启动时创建并负责将 AudioStreamPlayer 节点池实例化挂入 `PersistentLayer`，生命周期与进程等长
- SceneManager 暴露挂载 API `register_persistent(node: Node)`——任何需要跨场景存活的节点都通过它注册（未来若有类似需求不再发明新结构）
- 池大小、双播放器交叉淡化等**内部细节**留给 audio epic；挂载结构本身在此定死，audio epic 不得改动此结构（如需改动须修订本 ADR）

### 2. 零状态所有权——UI 只读消费

```gdscript
# ✅ 正确：信号到达时从源系统读取（ADR-0001 第一层直接属性访问 + 载荷过滤）
func _on_batch_updated(changes: Dictionary) -> void:
    if changes.has("exploration.action_points"):
        ap_label.text = str(GSM.exploration.action_points)

# ❌ 禁止：缓存副本
var _ap_cache: int  # 绝不——显示与实际状态漂移
```

- UI 显示数据每信号周期从源系统 API 读取，不持有任何游戏状态副本
- 玩家操作（点击节点、出牌）不直接写状态——发出语义信号（如 `node_clicked(node_id)`）由对应系统执行后广播 Cat 1 信号回来，UI 再刷新
- 持久变更（`loot_selected`、`map_cleared`、`map_reentry_confirmed`）必须先经确认弹窗，再触发系统 API

#### 2.1 状态三分类——所有权边界

| 类别 | 定义 | 归属 | 示例 |
|------|------|------|------|
| **游戏状态** | 影响玩法与存档的数据 | GSM / 各系统——UI 只读 | HP、AP、灵石、卡组内容 |
| **瞬态交互状态** | 纯 UI 本地、不进存档、刷新即弃 | UI 节点自身成员变量，合法持有 | 卡组编辑的筛选器/选中项、拖拽中间态、tooltip 开关 |
| **持久设置** | 玩家配置、跨会话生效 | 主菜单系统的设置面板直接写设置文件（`save_settings()`，architecture.md 主菜单行）——不经 GSM（ADR-0001 无 settings 域），不经 SaveLoadSystem 存档链 | 音量、分辨率、减少动态、语言 |

判定规则：数据若进存档 → 游戏状态（禁副本）；若玩家改了它游戏行为变 → 持久设置（设置文件直写）；两者都不是 → 瞬态交互状态（UI 本地合法）。ADR-0005 已引用的 `GSM.session.ui_state` 标记（转场期间的 UI 中间态）属于瞬态交互状态在 GSM session 域的例外寄存——仅限转场管线使用，UI 不得扩展此模式。

### 3. 事件驱动更新——仅 Cat 1 / Cat 2b 信号

- UI 刷新仅连接 ADR-0007 分类法中的 Cat 1（GSM 状态信号，如 `batch_updated`、`player_changed`、`resource_changed`）与 Cat 2b（动作通知）
- **禁止轮询**——不在 `_process()` 中每帧读取游戏状态做 UI 刷新。限定：输入驱动的纯视觉变换（拖拽跟随、Tween 动画、节点图缩放平移）不在此列——它们不读取游戏状态，只处理输入与变换
- 性能护栏：信号响应 → 视觉更新 <1 帧（`set_deferred` 或直接赋值，不跨帧）

### 4. 双焦点双视觉策略（4.6）

- 键盘/手柄焦点：松石青 2px 外部光环（焦点环模式，已在交互模式库）
- 鼠标悬停：墨色边框加粗+微发光
- 两者同时激活时**优先显示鼠标悬停态**
- 交互入口先查 InputManager 锁栈公共判定 `is_input_allowed(action_type, device)`（ADR-0004 §公共 API）——弹窗打开时底层界面输入冻结（递归 Control 禁用：`process_mode` + `mouse_filter`）
- 实现细节遵循 ADR-0004 §设备类型——4.6 双焦点独立判定

### 5. 渲染预算——图集与合批

- UI 图标统一使用 AtlasTexture（图集），禁止独立纹理逐图标渲染
- 迷雾遮罩等大面积重复元素合批渲染
- 基准验证：战斗满场（16 角色卡）与节点图全图（最坏 6 层×4 节点）两场景实测 Draw Call <200 且 60fps
- 未达标时优化手段：图集合并 → 元素裁剪（50% 缩放隐藏文字标签）→ LOD

### 6. 交互规范来源——交互模式库

- 所有交互组件引用 `design/ux/interaction-patterns.md` 已定义模式
- 逐系统 UX 规范与模式库覆盖状态见 `interaction-patterns.md` 缺口章节与 `presentation-layer-risks.md`——**唯一前置依赖：deck-editing-ui 无 UX 规范，其 story 标记 Blocked 直到 `/ux-design` 完成入库**
- 新交互必须先 `/ux-design` 入库再实现

## 解决的 GDD 需求

无专用 GDD 章节对应本 ADR 全文——它是 6 个 UI GDD（combat-ui-system / exploration-ui-system / deck-editing-ui-system / hud-system / main-menu-system / audio-system）§用户界面需求的共同架构基线。

| 来源 | 需求 | 本 ADR 如何解决 |
|------|------|--------------------------|
| architecture.md §PRESENTATION 层 | 全部 UI 系统标记 `Control` (4.6 双焦点) HIGH RISK | §4 双焦点双视觉策略 + 引用 ADR-0004 锁栈判定 |
| 6 个 UI GDD §用户界面需求 | 各界面数据展示与操作转化 | §2 零状态所有权 + §3 事件驱动更新 |
| control-manifest §Presentation 层规则（2026-09-07） | 8 必需 + 7 禁止 + 5 护栏 | 本 ADR 为该规则的架构决策确认——内容一致，ADR 为权威源 |
| technical-preferences.md §性能预算 | 60fps / Draw Call <200 / 2GB | §5 渲染预算 |
| presentation-layer-risks.md | R-01/02/05/08/10 | §4/§5/§1/§2 分别对应缓解 |
| combat-ui.md / exploration-ui.md 数据需求章节 | 「UI 不拥有任何游戏状态——全部只读」 | §2 零状态所有权 |

## 考虑的替代方案

1. **每 UI 系统独立 ADR（6 个）**——拒绝：6 个系统答案完全相同，重复 6 遍违反 DRY；后续修改需同步 6 处
2. **UI 层引入 1-2 个 Autoload（UIManager）**——拒绝：Autoload 已 25 个超上限；UI 天然是场景内的，SceneManager 的 CanvasLayer 挂载已解决 HUD 跨场景需求
3. **MVVM/MVP 数据绑定框架**——拒绝：信号驱动已达到同等效果且是 Godot 惯用法（引擎参考 `current-best-practices.md` 的信号架构建议）；引入外部绑定框架与 GDScript 惯用法冲突
4. **轮询更新（每帧读 GSM）**——拒绝：16 角色卡 + HUD + 节点图每帧全量读取浪费帧预算；信号驱动按需刷新

## 后果

**正面**：
- 表现层 6 个 epic 共享同一套已决策的架构模式——story 创建时无需重复架构决策
- R-08（Autoload）、R-10（所有权）两个风险直接关闭
- control-manifest 的 Presentation 层规则获得 ADR 权威源背书

**负面/风险**：
- 双焦点 spike（R-01）失败可能迫使 §4 策略调整——spike 前置在 Sprint 13 首个 UI story
- Draw Call 基准（R-02）未达标需要图集重构——风险已登记，基准测试前置
- 音频节点池的内部细节（池大小、交叉淡化）未在本 ADR 展开——挂载结构已定死（§1.2），内部细节留给 audio epic
- deck-editing-ui 无 UX 规范——其 story 将标记 Blocked 直到 `/ux-design` 完成（§6）

## 验证标准

- [ ] 双焦点 spike 完成，OQ-02 关闭（Sprint 13 首周）
- [ ] 战斗满场 + 节点图全图基准：Draw Call <200，60fps
- [ ] CI 检查 `project.godot` 的 `[autoload]` 段条目数 == 25（新增 Autoload 使 CI 失败）
- [ ] 代码审查检查项：UI 脚本无游戏状态缓存——可 grep 启发式：UI 脚本禁止对 GSM 域赋值；`_cache`/`_last` 前缀成员需注释说明为瞬态交互状态（§2.1 分类）
- [ ] HUD CanvasLayer 挂载在场景切换时正确保留/隐藏（探索可见/战斗隐藏）
- [ ] `PersistentLayer` 在场景切换后音频不中断（连续播放验证）
- [ ] 暂停菜单打开时游戏 UI 冻结、HUD 可见、音频暂停（BGM 总线显式暂停，与 pause-menu.md AC 一致；关闭时恢复）

## 相关决策

- ADR-0001（GSM 三层 API——UI 消费侧）
- ADR-0004（输入管理器——锁栈与设备判定；本 ADR 引用其公共 API `is_input_allowed`）
- ADR-0005（场景管理器——HUD 挂载与音频过渡编排；本 ADR §1.2 扩展其持久层机制，属正常契约细化）
- ADR-0007（信号分类法——Cat 1/Cat 2b 更新源）
- control-manifest §Presentation 层规则（本 ADR 的清单映射；翻转 Accepted 时需再生成清单并更新版本戳）
- `design/ux/pause-menu.md`（§1.1 暂停菜单规格来源）
- production/risk-register/presentation-layer-risks.md（R-01/02/04/05/08/10）
