# 战斗UI系统 — 审查日志

## Review — 2026-07-24 — Verdict: APPROVED（修订后）
Scope signal: L
Specialists: game-designer, systems-designer, ux-designer, ui-programmer, qa-lead, creative-director
Blocking items: 0 (6 resolved) | Recommended: 11 (all resolved)
Summary: 初审查发现 6 个阻塞项和 11 个 HIGH 级项。核心问题为战斗系统 2026-07-23 更新为 7 阶段模型后战斗UI GDD 未同步——整个文档引用已废弃的 8 阶段模型（含独立"布阵阶段"）。修订全面同步至 7 阶段（0-6），新增灵能预览模式（阶段2外手牌保留60%饱和度+悬停预览）、渡劫撤退改为高代价撤退（80%修为损失）、三选一战利品改为二次确认、6 个缺失公式补全、40 条验收标准覆盖全部功能区、战斗系统双向依赖修复、拖拽灵敏度替换为具体像素阈值。Creative-director 综合裁决：修订后所有阻塞项已清除，Approved。
Prior verdict resolved: First review

## Review — 2026-09-06 — Verdict: APPROVED（修订后——MAJOR REVISION 修复）
Scope signal: XL
Specialists: game-designer, systems-designer, ux-designer, ui-programmer, qa-lead, creative-director
Blocking items: 13 (all resolved) | HIGH: 19 (deferred to UX/implementation phase)
Summary: 第二轮对抗性审查从实现可行性与支柱对齐角度发现更深层议题。13 个 BLOCKER 分为 4 个 P0（支柱/幻想级）、6 个 P1（公式/逻辑级）、3 个 P2（验收标准级）。核心修订：1) 幻想表第4行从"知道敌人在干什么"修正为"看到敌方当前状态"（用户决策：不增加敌方意图系统）；2) 阶段进度条明确无倒计时；3) 备战面板上限从硬编码4人改为按境界引用（2-6人）；4) 视觉层级矛盾从"待验证"升级为"必须在UX阶段解决的阻塞项"；5) cost_color 补除零守卫+base_max=0 始终返回 YELLOW；6) 手牌弧形公式从 tan() V形改为圆弧 radius×(1-cos(angle))；7) 堆叠重叠公式修正9%→30%；8) 悬停延迟矛盾消除（首次触发300ms/面板间切换0ms）+ MOUSE_FILTER_IGNORE 改为 STOP；9) Draw Call 预算重估280-300并承诺 TextureAtlas+draw_rect 为必需（非"考虑"），移除 SubViewport；10) AC 从~40条扩充至~65条，新增角色状态视觉标记、动画时序、性能非功能性需求、跨境界备战等覆盖。
Prior verdict resolved: Yes — 2026-07-24 APPROVED 的 6 个 BLOCKER 已在第一轮解决，本轮发现的是更深层的实现可行性和支柱对齐议题

## Review — 2026-09-06 — Verdict: NEEDS REVISION（ui-programmer 对抗性复审）
Scope signal: L
Specialist: ui-programmer
Focus: Draw Call 预算、D3D12 渲染器影响、Control 节点树与信号、手牌弧形实现、悬停互斥策略、Tween 批量管理、响应式布局
Blocking items: 2 | High: 5 | Low: 4
Summary: 2026-07-24 审查清除的是设计一致性（7 阶段同步、公式补全等）层面的问题。本次对抗性复审从 UI 编程实现可行性角度切入，发现 2 个 BLOCKER 级技术风险：Draw Call 预算估算过于乐观且缓解策略基于对 SubViewport 的误解；悬停面板互斥策略存在逻辑矛盾（MOUSE_FILTER_IGNORE 阻止了面板自身的 mouse_exit 检测）。5 个 HIGH 级项涵盖节点树缺失、D3D12 风险评估不完整、信号架构未定义、手牌弧形公式数学错误、Tween 批量管理无量化测试基线。建议在进入实现阶段前修复 BLOCKER。

### BLOCKER 1: Draw Call 预算估算乐观 + SubViewport 缓解策略基于误解

**位置**: §Draw Call 预算（Godot 4.6），第 586-596 行

**问题**:

1. **235 items 估算偏低且未区分峰值**。GDD 给出静态估算：16 角色位 × 10 items = 160、7 手牌 × 7 = 49、杂项 25，合计 235。但每个角色位实际 item 数远超 10：头像（圆裁切 1）、境界标记 1、名称 Label 1、HP 条（背景 + 填充 + 数字 = 3）、状态图标区（buff/debuff 各 3-5 个）、绑定功法/法宝图标 2、待命/已行动标记 1、前后排边框样式 1——保守 13-15 items/位。16 × 13 = 208，仅角色区就超出整份估算的一半。且估算未计入峰值场景：
   - 战利品三选一面板（3 卡 + 标题 + 确认按钮 + 灵石/消耗品图标 = 10-15 items）
   - 攻击声明阶段的箭头连线（每条 1-2 items，最多 6 条）
   - 阵法光环（Light2D 或 shader，每个阵法 1-3 items）
   - 伤害/治疗飘字（Label + modulate.a 动画，峰值 5-10 个同屏）
   - 抽牌/出牌飞行中的卡牌动画过渡帧
   - 备战面板（7+ 角色卡，每张含 HP/ATK/协同信息 = 5-7 items）
   - 撤退确认/渡劫警告弹窗
   峰值场景（胜利结算 + 手牌 + 角色区 + 残留动画）可达 280-300 draw items，远超 200 预算。

2. **SubViewport 缓解策略基于对 SubViewport 渲染机制的误解**。GDD 第 595 行写"考虑 SubViewport 渲染战斗日志（独立合成）"，暗示 SubViewport 能减少 draw call。实际：SubViewport 内部的 RichTextLabel + ScrollContainer 仍会发出 draw call，它们只是在 SubViewport 的渲染目标内发出，最终作为一张纹理再画一次到主屏——总 draw call 数 = SubViewport 内部 draw calls + 1（合成纹理）。SubViewport 只在内容变化频率低（可缓存为纹理）时节省开销，而战斗日志每条行动追加一条，变化频率高，缓存收益有限。GDD 将其列为缓解策略具有误导性。

3. **缓解策略使用"考虑""以实际测量为准"等软措辞，未承诺为设计要求**。TextureAtlas 合并状态图标、HP 条改用 draw_rect()、SubViewport——均为可选项。若实现阶段测量发现超预算，GDD 没有提供 fallback 设计（如：角色位数量动态裁剪、状态图标合并为单一 TextureRect + shader 裁切、HP 条共享 _draw() 批量绘制）。缺少承诺级缓解方案和峰值预算分解。

**建议**:
- 将 235 重算为角色位 13 items/位基准，并补一份峰值场景 draw call 预算表（含胜利结算、攻击声明、备战三个峰值时刻）
- 将 SubViewport 从缓解策略中删除，或改述为"SubViewport 仅用于战斗日志的输入隔离，不作为 draw call 缓解手段"
- 将 TextureAtlas、draw_rect() HP 条从"考虑"升级为"必需"（Required），并在 ADR 中记录
- 补充 fallback：若实测仍超预算，定义优先级裁剪顺序（如：状态图标先合并、再裁剪 buff/debuff 上限、再静态化飘字）

### BLOCKER 2: 悬停面板互斥策略存在逻辑矛盾（MOUSE_FILTER_IGNORE 阻止 mouse_exit 检测）

**位置**: §12 悬浮提示规则，第 351 行；边界情况，第 499 行

**问题**:

GDD 设计：手牌放大预览面板设置 `mouse_filter = MOUSE_FILTER_IGNORE`，目的是"防止二次触发角色悬停"——即当手牌预览面板在视觉上覆盖到角色区时，鼠标移过预览区域不应触发角色详情面板。

矛盾点：

- `MOUSE_FILTER_IGNORE` 使该 Control **及其子节点**不接收任何鼠标事件（`gui_input`、`mouse_entered`、`mouse_exited` 全部不触发）。
- 手牌放大预览面板的显示/隐藏依赖于鼠标悬停状态——GDD §12 表格中"手牌卡牌"的悬停显示是"全阶段可用"，且边界情况第 494 行写"长时间悬浮卡牌：悬浮卡牌预览保持打开直到鼠标移出卡牌区域，不自动关闭"。
- 若放大预览面板设为 IGNORE，则：
  1. 面板自身无法检测 `mouse_exited`——"鼠标移出卡牌区域"无法由面板自身判定，必须由手牌区原始卡牌的 `mouse_exited` 触发关闭。但放大预览面板可能延伸到原始卡牌区域之外（向角色区方向放大），鼠标从预览上边缘移出时仍可能在原始卡牌的 `mouse_exited` 范围内，导致面板不关闭；或鼠标从原始卡牌移到预览面板上时，原始卡牌 `mouse_exited` 触发，面板提前关闭——与"保持打开"设计冲突。
  2. 若要在预览面板上继续接收点击（如点击卡面查看详情、点击关闭按钮），IGNORE 会阻断这些交互——GDD 没有定义预览面板是否需要交互，但"全阶段可用"暗示至少悬停交互应保持。

- GDD 同时说"手牌预览面板优先渲染（z_index +1）"——z_index +1 在 2D 中已能让预览面板在视觉上覆盖角色区。若 mouse_filter 设为 IGNORE 是为了让鼠标事件"穿透"到下方的角色区触发角色悬停，那与"防止二次触发角色悬停"的目标恰好相反：IGNORE 会让事件穿透，触发角色悬停，而不是阻止它。

**结论**：当前设计对 `MOUSE_FILTER_IGNORE` 的语义理解反了。`MOUSE_FILTER_PASS` 才是"穿透到下方节点"，`MOUSE_FILTER_STOP` 才是"阻止穿透"，`MOUSE_FILTER_IGNORE` 是"本节点不接收但子节点可接收"——但 Control 无子节点交互时等同于穿透。

**建议**:
- 明确互斥策略的实际目标：是"阻止鼠标事件到达角色区"还是"让角色区不响应"？
- 若目标是前者：预览面板应使用 `MOUSE_FILTER_STOP`（阻止事件继续传播到下方 Control），而非 IGNORE
- 若目标是后者：预览面板设为 IGNORE + 在角色区的 `mouse_entered` 回调中先检查"手牌预览是否当前展开"，若展开则角色区不触发自己的详情面板（应用层互斥而非靠 mouse_filter）
- 定义预览面板的关闭触发：是原始卡牌的 `mouse_exited` 还是预览自身的 `mouse_exited`？建议用原始卡牌 + 一个稍微扩大的命中区域（Area2D 或 Control with custom point）来判定"鼠标是否仍在卡牌+预览的联合区域内"
- 在 GDD 中画出悬停互斥的事件状态机（鼠标 enter/exit 各节点的时序），消除歧义

### HIGH 1: Control 节点树结构未定义，无法审查 z_index / mouse_filter 传播 / 信号路由

**位置**: 全文——缺失

**问题**:

GDD 描述了 12+ 个 UI 区域（手牌区、敌方角色区、己方角色区、费用栏、阵法区、阶段指示器、攻击目标选择、备战、结算、撤退、日志、悬停面板），但没有给出 Control 节点树结构图。这对于 UI 编程 handoff 是严重缺失：

- **z_index 排序**：GDD 说"手牌预览面板 z_index +1 高于角色详情面板"——但 z_index 在 2D 中只在同一 CanvasLayer / 同一父节点的子节点之间有效。如果手牌预览是手牌区的子节点（位于屏幕底部），而角色详情面板是角色区的子节点（位于屏幕中部），两者的 z_index 比较取决于它们各自在树中的位置——若不在同一父节点下，z_index 比较无意义。GDD 没有定义节点树，无法验证 z_index 策略是否可行。

- **mouse_filter 递归禁用（4.5+ 特性）**：current-best-practices.md 和 ui.md 都提到 4.5+ 的递归 Control 行为——父节点设 `MOUSE_FILTER_IGNORE` 可传播到子节点。GDD 没有利用这一特性来简化阶段切换时的整片区域禁用（如阶段 4 攻击结算时禁用所有手牌+角色区的鼠标交互），而是靠状态机切换每个面板的可用性。节点树结构缺失让这一优化机会无法评估。

- **信号路由**：GDD 引用了多个信号（`hp_changed`、`phase_changed`、`action_points_changed`，来自 hud.md），但没有定义：
  - 这些信号是直接从战斗系统发出，还是经过一个中央战斗 UI 状态管理器（event bus）转发？
  - 16 个角色 HP 条是否各自订阅同一个 `hp_changed` 信号（扇出 16 次回调）？
  - 战斗结束时是否断开所有信号连接？GDD 只提"日志清空"未提信号清理——内存泄漏风险。
  - 信号连接使用 `signal.connect(callable)`（4.0+ 类型安全，deprecated-apis.md 明确要求）还是字符串 connect？未声明。

- **anchor 继承**：GDD 第 497 行说"使用 anchor_* 预设实现百分比布局"——但 anchor 是节点属性，必须在节点树中定义。节点树缺失，无法验证 anchor 策略。

**建议**:
- 在 GDD 或关联的 ADR 中补一份 Control 节点树图（至少两层深度），标注每个区域的 z_index、anchor 预设、mouse_filter 默认值
- 定义信号连接架构：推荐中央战斗 UI 状态管理器 + Callable 连接，16 个 HP 条订阅同一信号但回调中按角色 ID 过滤
- 定义战斗结束时的信号断开协议（`queue_free()` 前 `signal.disconnect()`）

### HIGH 2: D3D12 渲染器风险评估不完整（缺失 glow 对 2D 影响、缺失双焦点系统、无测试计划承诺）

**位置**: §D3D12 渲染器风险，第 598-604 行

**问题**:

1. **Glow 重做对 2D 的影响被错误排除**。GDD 第 603 行说"4.6 glow 重做主要影响 3D 渲染，2D CanvasModulate + Light2D 不受影响"。这与 rendering.md 不符：rendering.md 明确写"Glow 现在在 tonemapping 之前处理，采用屏幕混合模式"——glow 是全屏后处理，不分 2D/3D。如果游戏使用 WorldEnvironment 启用 glow（用于阵法光环、修为脉动等效果），4.6 下 glow 的视觉表现会与 4.5 不同。GDD 既说阵法光环用"自定义 shader glow"需测试，又说 CanvasModulate + Light2D 不受影响——但若光环效果依赖 WorldEnvironment 的 glow 后处理，仍会受影响。这部分风险评估自相矛盾。

2. **双焦点系统（4.6 破坏性变更）完全未提及**。breaking-changes.md 和 ui.md 都标注 4.6 的双焦点系统是 UI 破坏性变更："鼠标/触摸焦点现在与键盘/手柄焦点分离。视觉反馈因输入方式而异。"。GDD 的攻击目标选择（§7）是点击式交互，HUD design（hud.md）列出键盘快捷键 1-7 选牌、Tab 焦点循环、Space 结束回合——这些键盘焦点行为在 4.6 下与鼠标焦点分离，需要专门处理。GDD 没有提及这一变更，也没有定义键盘焦点在战斗中的视觉反馈（焦点环？高亮？）如何与鼠标悬停高亮区分。

3. **CPUParticles2D 混合模式**：GDD 提"费用消散粒子"用 CPUParticles2D + modulate.a，但没说粒子用哪种 blend mode。费用消散常见用 ADD blend（光粒发光感）。D3D12 下 ADD blend 的 sRGB 处理与 Vulkan 不同，可能出现颜色偏移或过曝。GDD 只说"可能不同"，没说将测试哪种 blend mode、fallback 是什么。

4. **"需烟雾测试"是 punt 不是设计**。GDD 列了 4 项需测试但没承诺测试计划、通过标准、fallback 设计。实现阶段若测试失败，GDD 没有提供替代方案。

5. **Forward+ 与 Mobile 渲染器选择未提及**。GDD 最低分辨率 1280×720，部分低端 PC 可能在 D3D12 + Forward+ 下性能不足。技术偏好设为 Forward+，但低分辨率场景下是否考虑 Mobile 渲染器作为 fallback 未说明。

**建议**:
- 修正 glow 影响描述：明确"4.6 glow 重做影响所有使用 WorldEnvironment glow 的效果，包括 2D"
- 新增"双焦点系统对战斗 UI 影响"小节：定义键盘焦点（1-7/Tab/Space）的视觉反馈与鼠标悬停的区分策略
- 将"需烟雾测试"升级为"测试矩阵"：列出每个效果的当前 blend mode、预期 D3D12 表现、通过标准、fallback
- 声明渲染器选择策略（Forward+ 为默认，Mobile 作为低端 fallback 的条件）

### HIGH 3: 手牌弧形排列公式数学错误（V 形而非弧形）+ 堆叠公式未保证屏幕内

**位置**: §公式 1 手牌排列弧度，第 391-399 行；§公式 2 堆叠重叠量，第 413-418 行

**问题**:

1. **弧形公式使用 tan() 产生 V 形而非弧形**。GDD 公式：
   ```
   y = base_y - abs(x - screen_center) × tan(arc_angle / 2)
   ```
   `tan()` 给出从中心向两侧的线性下降——这是 V 形（帐篷形），在中心点有尖锐折角，不是平滑弧形。真正的弧形应使用：
   - 圆弧：`y = base_y - radius × (1 - cos(angle_from_center))`，其中 `angle_from_center = (index - center) × (arc_angle / total_cards)`
   - 或二次贝塞尔：`y = base_y - k × (x - center)²`（抛物线，近似弧形）
   当前公式在 arc_angle = 30° 时，`tan(15°) ≈ 0.268`，y 从中心向两侧线性下降——视觉上明显是 V 形，与"弧形排列"的设计描述矛盾。

2. **rotation 与 position 曲线不匹配**。rotation 公式是线性分布：`rotation = (index - center) × (arc_angle / total_cards)`——这是切线角的线性近似。但 position 用的是 V 形（tan），两者曲线不一致：在中心点，position 的导数不连续（V 形尖角），而 rotation 是连续的——视觉上卡牌在中心点会"扭"一下。

3. **screen_center / screen_bottom 与 Control 本地坐标系混淆**。公式用 `screen_center` 和 `screen_bottom × 0.86`，但 Control 子节点的 `position` 是相对于父 Control 的本地坐标。如果父 Control 是手牌区（锚定在屏幕底部 25% 高度条带），则本地坐标系的原点不是屏幕左下角。公式需改为基于父 Control 的本地中心（`size.x / 2`）和本地底部（`size.y`），否则实现时坐标会错。

4. **堆叠公式（>7张）未保证全部卡牌在屏幕内**。公式：
   ```
   excess = total_cards - 7
   overlap = (card_width × 0.3) × excess
   return card_width - overlap / total_cards
   ```
   对 10 张：excess=3，overlap=0.9×card_width，返回 `card_width - 0.09×card_width = 0.91×card_width`。10 张卡总宽 = 9 × 0.91 + 1 = 9.19 × card_width。若 card_width = 100px，总宽 919px——在 1280×720 屏上勉强可放，但在手牌区可能因 margin 超出。公式没有反向求解"给定 available_width 和 total_cards，spacing 应为多少"，而是固定 30% 重叠比例——无法保证适配。

5. **重算时机未定义**。自定义 Control 布局需在 `hand_changed`（手牌数量变化）和 `resized`（窗口尺寸变化）时重算位置。GDD 只说"配合自定义脚本计算"，未提 `resized` 信号——窗口缩放时手牌位置会错。

6. **拖拽中 z-index 管理缺失**。GDD 第 425 行说"中心卡牌优先 z_index 最高"——但拖拽中的卡牌需高于所有卡（包括中心）。GDD 未定义拖拽时 z_index 的临时提升策略。

**建议**:
- 将 y 公式改为圆弧或抛物线：`y = base_y - radius * (1 - cos(angle_from_center))` 或 `y = base_y - k * (x - center_x)²`
- 确保 rotation 与 position 使用同一曲线（圆弧的切线角 = `atan2(x - center_x, radius)`）
- 将所有坐标改为父 Control 本地坐标系
- 重写堆叠公式：先求 `available_width = parent.size.x - 2 × margin`，再 `spacing = min(card_width + 10, (available_width - card_width) / (total_cards - 1))`，overlap = `max(0, card_width - spacing)`
- 补 `resized` 信号处理
- 补拖拽时 z_index 提升策略（如 `dragged_card.z_index = 100`）

### HIGH 4: Tween 批量管理无量化基线，"12+ 掉帧"阈值缺乏依据

**位置**: §公式 3 HP 条颜色阈值，第 440 行

**问题**:

GDD 说："若性能分析显示 12+ 同时 Tween 掉帧，改用共享 lerp 管理器（`_physics_process()` 中批量插值）。"

1. **"12+"阈值无依据**。Godot 的 `SceneTreeTween` 在 `_process` 中逐帧更新每个 Tween 的回调。12 个 Tween 对 60fps 几乎不可能造成掉帧（每个 Tween 仅一次属性写入 + ease 计算，微秒级）。真正会掉帧的是：
   - 16 个角色同时 HP 变化（阶段 4 攻击结算，按速度顺序，但视觉上可能 3-5 个同帧受伤）
   - 16 个角色 HP 条 + 飘字 + 受击闪白同时播放
   - 备战阶段 7 个角色选择动画同时触发（0.3s/角色 × 7 = 名义 2.1s，但若批量触发则瞬间 7 Tween）
   "12+"这个数字像是凭空取的，没有性能分析数据支撑。

2. **没有定义何时测量、用什么场景测量**。GDD 说"若性能分析显示"但没定义性能分析的执行场景（如：16 角色全攻击阶段 4 + 5 个 buff 图标同时落入 + 飘字 5 个——这是峰值 Tween 场景）。没有可重复的 benchmark，"12+"无法被验证。

3. **Tween vs 共享 lerp 管理器的切换策略未定义**。GDD 提了 fallback 但没说：
   - 切换条件具体是什么？（帧时间 > 16.6ms 持续 N 帧？还是 Tween 数量 > X？）
   - 切换是全局还是局部？（所有 HP 条切到 lerp，还是只切超载的部分？）
   - 切换后 Tween 代码是否保留？（双路径维护成本）
   - 共享 lerp 管理器的接口是什么？（`_physics_process` 中遍历活跃插值列表）

4. **Tween 生命周期管理缺失**。GDD 说"批量伤害时直接计算最终 HP 执行一次 0.3s 过渡"——但如果在过渡中角色又受伤（连续攻击），新的 Tween 要 kill 旧的还是叠加？GDD 没定义。Godot 的 `create_tween()` 不自动 kill 前一个，若不手动 `kill()` 会出现多个 Tween 争抢同一 HP 条 value 属性，视觉抖动。

**建议**:
- 删除"12+"硬阈值，改为"在峰值场景（16 角色攻击结算 + 飘字 + 状态图标落入）下用 profiler 测量帧时间，若 > 16.6ms 则切换"
- 定义峰值 benchmark 场景（具体到角色数量、同时受伤数量、动画类型）
- 定义 Tween 生命周期：新 Tween 启动前 `if existing_tween: existing_tween.kill()`
- 定义共享 lerp 管理器接口：`HPBarLerpManager.register(bar, from, to, duration)`，在 `_physics_process` 中批量插值
- 在 ADR 中记录 Tween vs lerp 的决策与切换条件

### HIGH 5: 响应式布局策略仅提及 anchor_* 预设，未覆盖关键场景

**位置**: §边界情况，第 497-498 行

**问题**:

GDD 仅说"使用 anchor_* 预设实现百分比布局"，这是响应式的最低要求，但未覆盖：

1. **手牌区弧形在宽屏/超宽屏下的行为**。弧形公式用 `screen_width / total_cards` 限制 spacing，但超宽屏（如 3440×1440）下 screen_width 很大，spacing 被 `card_width + 10px` 上限锁住，手牌区只占屏幕中央一小段，两侧大量留白——这是可接受的，但 GDD 没说留白用什么填充（背景？装饰？）。第 497 行说"两侧以游戏背景填充（非纯黑边）"——但手牌区是 Control 节点，其本身的背景透明，留白实际由父节点决定。未定义父节点的背景处理。

2. **角色区在超宽屏下的居中策略**。GDD 说"角色区居中不拉伸"——但 16 个角色位（6 敌方 + 6 己方，或按境界 3+3 等）在宽屏下若保持固定尺寸居中，两侧留白很大；若按比例拉伸间距，角色位之间的距离在宽屏上过远，视觉割裂。未定义选择哪种。

3. **1280×720 最低分辨率的验证**。GDD 说"低于 1280×720 不支持"——但 1280×720 下：
   - 16 角色位（每张角色卡若 100×140px，6 个一排 = 600px + 间距，勉强可放）
   - 手牌区弧形 7 张卡 × 100px = 700px + 弧形溢出，在 1280 宽下 OK，但 10 张堆叠后 = 919px，在 1280 下超出屏幕（减去 margin 后可用宽约 1200px，919px OK 但很紧）
   - 字号缩放公式（§6）只覆盖 Label，未覆盖 TextureRect 图标尺寸——图标在小屏下是否缩放？
   GDD 没有在 1280×720 下的完整布局验证。

4. **窗口缩放过程中的动态行为未定义**。`anchor_*` 预设在窗口缩放时自动调整 Control 的矩形，但手牌弧形位置需重算（见 HIGH 3），攻击箭头连线需重绘，备战面板的角色卡网格需重排。GDD 只说用 anchor 预设，没说这些动态内容如何响应 `resized` 信号。

5. **anchor 预设的具体选择未声明**。Godot 有 `PRESET_TOP_LEFT`、`PRESET_CENTER`、`PRESET_FULL_RECT` 等。GDD 没说手牌区用 `PRESET_BOTTOM_WIDE` 还是 `PRESET_FULL_RECT` + 自定义 anchor，角色区用 `PRESET_CENTER` 还是自定义。不同预设对响应式行为影响很大。

**建议**:
- 为每个 UI 区域声明 anchor 预设（如：手牌区 `PRESET_BOTTOM_WIDE` + 高度固定 25%；角色区 `PRESET_CENTER` + 固定尺寸；费用栏 `PRESET_BOTTOM_WIDE` + 高度固定）
- 在 1280×720 下做一次完整布局验证（ASCII 或 mock），列出每个区域的实际像素尺寸
- 定义窗口 `resized` 时的重算顺序：手牌弧形 → 攻击箭头 → 备战网格
- 声明超宽屏下角色区是居中固定还是间距拉伸

### LOW 1: FoldableContainer（4.5 新增）未用于战斗日志，错过引擎惯用法

**位置**: §11 战斗日志，第 329-336 行

**问题**: 战斗日志是"可收起的滚动文本日志（默认折叠为小标签）"——这正是 Godot 4.5 新增 `FoldableContainer` 的设计场景（ui.md 和 current-best-practices.md 都推荐）。GDD 说用 RichTextLabel + ScrollContainer，但没提 FoldableContainer。若用自定义折叠方案，需自己实现折叠/展开动画、状态持久化——而 FoldableContainer 内置这些。错过引擎惯用法，增加实现成本。

**建议**: 评估 FoldableContainer 作为战斗日志容器；若不采用，在 ADR 中记录原因（如：需要自定义折叠时的最新日志预览，FoldableContainer 不支持）。

### LOW 2: 备战面板阵位布局预览的拖拽交互未定义实现方式

**位置**: §8 备战阶段UI，第 257 行

**问题**: GDD 说"阵位布局预览实时更新（拖拽角色到头像区自动排位，或直接在预览区拖拽调整前后排）"——但备战面板内拖拽在 Control 节点上的实现方式未定义：是用 Godot 内置 `_get_drag_data`/`_can_drop_data`/`_drop_data` 接口（Control 的拖拽 API），还是自定义 `_gui_input` + 鼠标位置判定？前者是 Godot 惯用法（与手牌出牌拖拽统一），后者更灵活但重复造轮子。GDD 的出牌拖拽（§2）和备战拖拽（§8）应统一拖拽架构。

**建议**: 声明全 UI 统一使用 Control 内置拖拽 API（`_get_drag_data` 等），在 ADR 中记录。

### LOW 3: 字号响应式公式未覆盖 4K（2160p）场景

**位置**: §公式 6 低分辨率文字缩放，第 472-477 行

**问题**: 公式只定义 `screen_height >= 1080` 返回 base_font_size，未处理 > 1080（如 1440p、2160p）。在 4K 下若 base_font_size 为 22px，实际显示过小（4K 像素密度高，22px 字在物理屏幕上极小）。公式应支持更大分辨率放大字号，或声明依赖 Godot 的 `content_scale_factor` 自动缩放（不手动调字号）。

**建议**: 声明 4K 下依赖 `content_scale_factor` 自动缩放，或扩展公式：`if screen_height >= 2160: return base_font_size × 1.5`。

### LOW 4: 战斗日志条目格式未定义颜色/图标编码

**位置**: §11 战斗日志，第 334 行

**问题**: GDD 定义日志条目格式为 `[回合·阶段] 行动者 → 动作 → 目标 → 数值`，但未定义：
- 不同动作类型（伤害/治疗/buff/阵亡）是否有颜色区分（如伤害红、治疗绿）
- 是否带行动者阵营前缀（己方/敌方）
- RichTextLabel 的 BBCode 标签使用方式（`[color=red]...[/color]`）
HUD design（hud.md）的元素 15 定义了战斗日志的视觉形式（暖白基底 + 墨色边框），但条目内容样式未对齐。

**建议**: 补充日志条目 BBCode 模板，对齐 hud.md 的色彩编码（朱砂红=伤害、松石青=治疗、琉璃金=稀有事件）。

## 优先级矩阵

| ID | 级别 | 主题 | 影响面 | 建议解决时机 |
|----|------|------|--------|------------|
| B1 | BLOCKER | Draw Call 预算乐观 + SubViewport 误解 | 性能、实现可行性 | 进入实现前 |
| B2 | BLOCKER | 悬停互斥 mouse_filter 语义矛盾 | 交互正确性 | 进入实现前 |
| H1 | HIGH | Control 节点树未定义 | 实现架构、z_index、信号 | 进入实现前 |
| H2 | HIGH | D3D12 风险评估不完整 | 渲染正确性、无障碍 | 进入实现前 |
| H3 | HIGH | 手牌弧形公式数学错误 | 视觉实现、响应式 | 进入实现前 |
| H4 | HIGH | Tween 批量管理无量化基线 | 性能、动画正确性 | 实现阶段 + profiler |
| H5 | HIGH | 响应式布局策略不完整 | 多分辨率适配 | 进入实现前 |
| L1 | LOW | FoldableContainer 未评估 | 实现成本 | 实现阶段 |
| L2 | LOW | 备战拖拽架构未定义 | 代码统一 | 实现阶段 |
| L3 | LOW | 字号公式未覆盖 4K | 4K 显示 | 实现阶段 |
| L4 | LOW | 日志条目编码未定义 | 视觉一致 | 实现阶段 |

## 引用的关键文件路径

- GDD: `E:\mortal-heaven-question\design\gdd\combat-ui-system.md`
- 战斗系统 GDD: `E:\mortal-heaven-question\design\gdd\combat-system.md`
- HUD 设计: `E:\mortal-heaven-question\design\ux\hud.md`
- 引擎参考 UI: `E:\mortal-heaven-question\docs\engine-reference\godot\modules\ui.md`
- 引擎参考渲染: `E:\mortal-heaven-question\docs\engine-reference\godot\modules\rendering.md`
- 破坏性变更: `E:\mortal-heaven-question\docs\engine-reference\godot\breaking-changes.md`
- 当前最佳实践: `E:\mortal-heaven-question\docs\engine-reference\godot\current-best-practices.md`
- 已弃用 API: `E:\mortal-heaven-question\docs\engine-reference\godot\deprecated-apis.md`
- 技术偏好: `E:\mortal-heaven-question\.claude\docs\technical-preferences.md`
- 编码标准: `E:\mortal-heaven-question\.claude\docs\coding-standards.md`
