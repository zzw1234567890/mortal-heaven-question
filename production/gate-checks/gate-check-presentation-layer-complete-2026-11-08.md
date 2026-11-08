# 关卡检查：presentation-layer-complete 里程碑（Sprint 17 后）

**日期**：2026-11-08
**检查者**：gate-check 技能
**类型**：里程碑关口检查（Production 阶段内的里程碑，**非**阶段推进关卡——不涉及 `production/stage.txt` 变更）
**审查模式**：full（四位主管关卡 CD / TD / PR / AD-PHASE-GATE 全部已运行）
**上次检查**：`gate-check-presentation-layer-complete-2026-10-13.md`（裁决 FAIL）

---

## 裁决：FAIL（里程碑未达成）

**一句话依据**：核心循环链路 6 个 epic 中只有 `combat-ui-layout`（10/10）完整；`combat-ui-interaction` **0/9** 意味着战斗只能"看"不能"玩"；`SCENE_PATHS` 12 条注册路径中 **8 条指向不存在的 `.tscn`**（含 `COMBAT`），节点图弹窗点「进入战斗」会走到转场失败路径；36 项 S17 视觉走查 + 71 项 S16 走查**一条未执行**。四位主管中 **3 位 NOT READY、1 位 CONCERNS**。

**这不是质量倒退信号**：Sprint 17 的 must 4/4 全交付、自动化 3437/3436 passing、零回归（较 S16 +333 例）、双关卡审查真实拦截了「测试只重算内核值自证」这类隐蔽问题。FAIL 陈述的是「里程碑尚未完成」，不是「已交付部分是坏的」。

---

## 一、里程碑关口条件对照

**来源**：`production/milestones/presentation-layer-complete.md`

| # | 条件 | 状态 | 证据 |
|---|------|------|------|
| 1 | 7 个 Presentation epic 全部 Complete（两段式解读：核心链路 epic 为硬性） | ❌ **1/6 完整** | hud **6/8**、main-menu **4/5**、audio-manager **4/7**、combat-ui-layout **10/10 ✅**、combat-ui-interaction **0/9**、exploration-ui **5/10**、deck-editing-ui **0/7**（两段式后置）。逐 story `**Status**` 字段实测 |
| 2a | R-01 双焦点 spike 完成，OQ-02 关闭 | ✅ | `production/spikes/r01-dual-focus-spike.md` 10/10 PASS（2026-09-08）；风险册标「已关闭」 |
| 2b | R-02 Draw Call 基准：战斗满场 <200 且 60fps | ❌ **未关闭** | `r02-benchmark-evidence.md`：DC 126/132 达标（余量 68），但后端为 **Vulkan Forward+（非目标 D3D12）**、场景为 **stub 占位节点（非 002-006 真实组件）**、p95 16.92ms **超 16.6ms 预算**。组件级复测义务**双登记**（layout epic DoD + interaction story 009），自 2026-10-11 起跨 S15/S16/S17 **三次未履行** |
| 2c | R-05 节点图最坏情况基准：6 层×4 节点 60fps | ◐ **技术达标、残留未清** | D3D12 + VSync 关闭实测 p95 2.04ms（余量 8 倍）、DC 90——是本里程碑唯一在目标后端跑出的证据。但渲染基座为**程序化图集近似**，story 010 真实美术图标复测未执行；风险等级却已从 🔴 高降为 🟢 低 |
| 3 | ADR-0031 验证标准全部通过 | ❌ **3 ✅ / 3 ◐ / 1 ❌** | 见下方逐项表 |
| 4 | 6 个 UI GDD 验收标准经 QA 验证（合计约 200 项） | ❌ **实质零推进** | 本里程碑周期内无新增产品层验证：S17 四份证据文档 §2 共 **36 项全空**；S16 五份证据文档共 **71 项全空**。已验证部分基本仍为 S13 的 hud 11 项（`qa-signoff-sprint-13-2026-09-12.md`） |
| 5 | 游戏全流程可演示：主菜单→身份→地图→节点图→战斗→结算→通关 | ❌ **结构性断裂** | 见下方「§三 结构缺口实测」——不是「还没做」，是「点了会掉回主菜单」 |

### ADR-0031 §验证标准逐项

| # | 标准 | 判定 | 依据 |
|---|------|:---:|------|
| 1 | 双焦点 spike 完成，OQ-02 关闭 | ✅ | `r01-dual-focus-spike.md` 10/10 PASS |
| 2 | 战斗满场 + 节点图全图：DC<200、60fps | ❌ | R-02 组件级复测三次未履行；目标后端 D3D12 上战斗满场**从未测过** |
| 3 | CI 检查 `[autoload]` 条目数 == 25 | ✅ | `project.godot` 实测 **25 条**（`grep -c` 复核） |
| 4 | UI 脚本无游戏状态缓存（零状态所有权） | ✅ | `grep -rn "func _process" src/ui/` **零命中**（189 文件）；UI 侧 GSM 赋值零命中；`_last_*` 成员均带 §2.1 瞬态注释 |
| 5 | HUD CanvasLayer 场景切换保留/隐藏 | ◐ | `test_hud_scene_visibility.gd` 覆盖矩阵存在且通过；但 **`HUD.tscn` 全库零生产实例化点**（仅测试 preload 与注释），测试证明「若挂载则正确」，未证明「已挂载」 |
| 6 | PersistentLayer 音频跨场景不中断 | ◐ | `test_bus_layout.gd` / `test_scene_signal_binding.gd` 覆盖总线与 `pre_transition` 信号链；同为测试内装配，生产启动流无 AudioManager 之外的第二类挂载验证 |
| 7 | 暂停菜单：UI 冻结、HUD 可见、音频暂停 | ✅（代码层） | `test_pause_menu.gd` / `test_pause_combat_state_preserved.gd` 全绿；同样是「测试内装配通过」，未经真人运行 |

**合计**：✅ 3 / ◐ 3 / ❌ 1。**「全部通过」不成立。**

---

## 二、质量检查

- [x] 测试套件全绿——单元 **2433 / 2432 passing / 1 pending**（存量 `test_migration_chain`）/ 1 orphan（存量）；集成 **1004/1004**（60 脚本 3847 asserts，2 orphans 存量）；合计 **3437 / 3436**
- [x] 零回归——较 S16 基线（3104 / 3103）净增 **333 例**，无新增跳过/禁用测试
- [x] QA 计划存在（`production/qa/qa-plan-sprint-17-2026-11-02.md`）
- [x] 冒烟检查存在且 PASS WITH WARNINGS（`production/qa/smoke-2026-11-08.md`）
- [x] QA 签收存在且 APPROVED WITH CONDITIONS（`production/qa/qa-signoff-sprint-17-2026-11-08.md`）
- [x] CI 上线（`.github/workflows/tests.yml`，GUT 全量 headless）
- [x] 技术债稳定——TODO 2 / FIXME 0 / HACK 0，与 S16 持平
- [x] 缺陷通道已建立（`production/qa/bugs/README.md` + 模板 + S1~S4 口径）
- [ ] **缺陷通道零使用**——`BUG-*.md` 计数 **0**。「零缺陷」是「未观测」的证据，不是质量的证据
- [ ] **视觉验证证据全缺**——见 §三
- [ ] **端到端演示从未执行**——见 §三
- [?] 试玩记录：`production/playtests/` 仅 1 份（`playtest-001-vertical-slice-2026-07-28.md`，垂直切片期）

---

## 三、结构缺口实测（本次检查新发现，任何 story 计数都不反映）

| 缺口 | 实测证据 | 影响 |
|------|---------|------|
| `SCENE_PATHS` 8/12 路径无资产 | `src/foundation/scene_manager.gd:67-79` 注册的 12 条路径中，`deck_editing` / `combat` / `tribulation` / `shop` / `event_panel` / `result_screen` / `defeat_screen` / `cultivation` 八条目标文件**不存在** | `request_scene_change()` 只校验 ID 在字典中（`scene_manager.gd:274`），不校验文件存在 → 校验通过、加载失败 → `scene_transition.gd:60` 走「目标场景缺失 → 清理 + 回退 MAIN_MENU」 |
| 节点图「进入战斗」必然掉回主菜单 | `node_interaction_popup_host.gd:214-217` `KIND_COMBAT` 分支直接 `_request_scene_change(SceneID.COMBAT, EXPLORE_TO_COMBAT)` | 玩家点战斗节点确认 → 转场失败 → 回退主菜单。**核心循环第一跳的出口是断的** |
| `CombatRoot.tscn` 零生产实例化 | 全库仅 3 处 `preload`，均在 `tests/integration/combat_ui/` | 战斗 UI 从未作为一个场景在真实 SceneTree 中出现过；「DC 126」对应的对象在运行时不存在 |
| `HUD.tscn` 零生产实例化 | 全库仅在测试中 `preload`，`src/` 内两处命中均为注释 | HUD 的全部视觉成果在真实启动路径上从未渲染过；`DEBT-EUI-005-6`（不可达点击无 toast）因此是既成事实而非待验假设 |
| 无场景串联集成测试 | `tests/integration/` 下无 `scene_flow` 目录；`main_menu` 套件只测菜单内部导航 | 「主菜单→身份→地图→节点图」的串联只有代码层调用，无一条自动化断言覆盖 |

---

## 四、走查台账（视觉验证缺口全貌）

| 批次 | 文档 | 走查项 | 已执行 | 签收 |
|------|------|:---:|:---:|:---:|
| S17 | `node-move-interaction-evidence.md` | 10 | **0** | 未勾 |
| S17 | `deploy-panel-evidence.md` | 8 | **0** | 未勾 |
| S17 | `node-popups-evidence.md` | 8 | **0** | 未勾 |
| S17 | `settlement-retreat-evidence.md` | 10 | **0** | 未勾 |
| S16 | `identity-select-evidence.md` | 12 | **0** | 未勾 |
| S16 | `map-select-screen-evidence.md` | 12 | **0** | 未勾 |
| S16 | `node-graph-render-evidence.md` | 20 | **0** | 未勾 |
| S16 | `topbar-evidence.md` | 17 | **0** | 未勾 |
| S16 | `cost-bar-evidence.md` | 10 | **0** | 未勾 |
| **合计** | 9 份 | **107** | **0** | 0/9 |

**根因**：QA-17-1（D3D12 视觉验证路径搭建）自 S15 提出、S16 结转、S17 再次未交付——**连续三个冲刺**。

**旁证**：`character-card-evidence.md` 的 8 项虽打 `[x]`，但自述「验证基于 `_draw()` 分层序列审读」——属**代码审读冒充视觉走查**，不构成肉眼证据。

---

## 五、主管小组评估

### 创意总监：**NOT READY**

**支柱 1「自由组牌，策略为王」在体验面上完全缺席。** `combat-ui-interaction` 0/9 意味着悬停预览、拖拽出牌、目标选择、键盘路径**一个都没有**。玩家第一次接触战斗时看到的是一个完成度很高的静态战场（10/10 layout，四区域、L0-L5 角色卡、弧形手牌、费用栏、备战面板、结算面板全部就位），但手牌不能拖、目标不能选、牌打不出去——「这不是粗糙的 MVP，这是一件陈列品」。

**排期与支柱自相矛盾**：若 interaction 在核心链路上，它就不可能是 should-have；而 17-5（interaction 001）正是 S17 should 层首丢项。

**支柱 2「苟道成长，步步为营」是当前唯一被真实兑现的支柱，但只兑现了一半**：layout 007/008 的五境界阵位、4 态判定、0.5s 防误触、「畏劫而退，修为散尽」等文案确实在讲「这一步代价很重」——但 interaction 006/007 未做，备战面板不能拖阵位、战利品不能选、撤退不能确认，玩家**看到**了压力却**无法**做出决定。紧张感只存在于截图里。

**两段式裁决在创意上成立，但执行时误置了对象**：把「卡组编辑」判为可后置是对的（杀戮尖塔首局的主战场是战后三选一与商店，不是编辑器）；但连带把「出牌交互」也降级成可后置是错的——编辑离支柱 1 有两层，出牌只隔一层。按支柱接近度，出牌应属「绝对保护」档。

**「36 项走查零执行 + interaction 0/9」叠加的含义**：单独任一项都可补齐，叠加则产生最难修复的失败——**团队对「这个游戏现在看起来什么样、摸起来什么样」没有任何第一手知识**，而同时又交付了大量只在单测里存在的界面。DEBT-EUI-005-6（toast 未接线）与 DEBT-EUI-006-2（灵泉 AP/HP 恢复 0）恰是明证：已经存在的界面里就有「看起来做了但不生效」的坑——这不是 UI 缺陷，是**叙事机制不和谐**的最小样本：界面在承诺一个会回应的世界，机制不给回应。

**与 2026-10-13 的差别**：上次是「收口尚未开始」（7 epic 0 完整、仅主菜单可达）；这次进度实质前进（layout 10/10、R-01/R-05 关闭、+714 测试零回归）——**但失败模式换成了更隐蔽的一种：结构接近完成，体验零验证，且链路末端有一个不存在的场景文件**。

### 技术总监：**CONCERNS**

**技术地基更硬，但两条红色风险的关闭机制本身是坏的。** R-02 连续两次「有条件关闭」、组件级复测义务两次未履行；R-05 在无真实美术元素的情况下被降级为「🟢 低」。这不是「还没测」，是**验证机制失效**。

**DC<200 这个数字是现实的**（R-02 stub 126/132、R-05 实测 90，架构侧合批方案已经解决问题）；**但帧时间的度量方式本身是错的**——R-02 用 VSync 开启测，p50 恒 16.66ms，把「VSync 锁定」误读成「达标」；在被 VSync 限制的采样里，帧时间分布根本无法反映真实预算占用。R-05 发现了并关掉 VSync，R-02 至今没重测。

**「有条件关闭」被制度化了**：R-02 自 10-11 起状态就是「有条件关闭」，五周未变，每次只往 evidence 底部追加一行「复测义务登记」——这不是风险关闭，是风险**挂起**。

**interaction 0/9 的真实技术含义**：R-01 与 R-02 的残余验证面 **100% 落在它身上**——拖拽半透明（modulate.a 三档）、输入锁栈嵌套、双焦点在 48 个自定义 Control 上的回归，全部只能在实际交互实现后暴露（story 009 逐条对应，且明确禁止「以 stub 实测替代真实元素复测」）。

**建议路径**：不必等 9 个 interaction story 全做完——把 story 009 的 AC-1（峰值复测）+ AC-2（拖拽三档烟雾）**拆成最小切片前置**，只需「能跑的 `combat_scene.tscn` + 最小拖拽 + 16 卡满场」三样，约 1 个 must story（2-3 日）即可拿到里程碑唯一的实质性能证据。

**四件低成本硬化**（合计 < 2 日）：① CI 加 `[autoload]==25` 断言（当前 ADR 写「CI 检查」，实测 CI **无此步骤**——文档承诺了一个不存在的机制）；② `SCENE_PATHS` 启动自检 `ResourceLoader.exists()`；③ 风险册改二态 `开放/已关闭`（R-02 回开放、R-05 回 🟡 中）；④ `/story-done` 增加「证据文档 §2 无空行」检查。

### 制作人：**NOT READY**

**排期诚实性：误差从约 2 倍变为 2.5-3 倍，未收敛。**

实测交付基线（S15/S16/S17）：

| 冲刺 | 计划 must | must 完成 | should/nice 完成 | 计划内 est-day | 日历日 |
|---|---|---|---|---|---|
| S15 | 7.0d | 4/4 | 5/5 | 12.5 | 11 |
| S16 | 5.5d | 3/3 | 4 | 12.5 | 10 |
| S17 | 7.0d | 4/4 | **0/5** | 7.0 | 6 |
| 合计 | — | 11/11 | 9/14 | **32.0** | **27** |

吞吐 ≈ **1.19 est-day / 日历日** → 10 日历日冲刺的实证上限约 **11-12 est-day**。

**三个数据点给出可用的判据**：must 名义 ≤ 5.5d 时 should 层能兑现（S16）；must 名义达 7.0d 时要么全量完成（S15，story 型较轻）、要么 should 归零（S17，返工 40/60%）。**差别不在利用率（93% vs 87.5%），在返工倍数**——S17 名义 7.0d 实际消耗约 9.8d。

**剩余工作量（两段式口径 20 story）**：名义约 **25.5 est-day**；加结构性缺口（`combat_scene` 容器 + 4 个占位场景 + HUD 挂载，约 3.0d）与验证债（107 项走查 + 9 份回填，约 2.0d）→ **30.5 est-day**；UI（Logic 内核）/Integration 部分按 S17 结论 ×1.3 → **≈ 35.8 est-day**。

**所需冲刺数**：全部容量给编码 3.3；QA 槽位独立预留 20% → 4.1；叠加 S17 实证的返工与 5 个「终验型」story → 上界 **6**。**里程碑最早关闭点：Sprint 22-23（约 2027 年 1 月上旬）**。若含 deck-editing-ui（27 story 口径，+10-12 est-day），再加 1.5-2 个冲刺。

**与文档承诺对照**：2026-10-13 公开写「5+ 冲刺」、内部实算 10-11（差 2 倍）；2026-10-24 两段式裁决隐含承诺「S16-17 两段式收口」= 2 个冲刺；实际两个冲刺用尽、可演示性零进展、剩余 5-6 冲刺——**误差 2.5-3 倍**。且 2026-11-02 的勘误只改了 deck-editing 措辞，**里程碑文档的目标日期行与「实际承载」表至今停在 2026-10-13 且标 Sprint 15「进行中」——范围仲裁做出了决定，却没有产生可被追踪的重新基线**。

**容量配比建议**（每个 10 日历日冲刺，以 11 est-day 为分母）：

| 槽位 | 份额 | 折算 |
|---|---|---|
| must（返工调整后实际消耗） | 59% | 6.5 est-day（对应名义 ≤ **5.0d**；超出即 Day-4 强制丢弃） |
| QA 验证（走查/证据回填/缺陷闭环） | 18% | **2.0 est-day**，硬槽位，不得被 must 挪用 |
| 技债/工具（D3D12 路径、拆分超限文件） | 9% | **1.0 est-day** |
| 计划外缓冲 | 14% | 1.5 est-day |
| should 层 | **0%** | 默认不写进冲刺计划；仅当 Day-4 时 must 全落地，才从 backlog 拉 ≤2.0d 并当日写入文件 |

### 美术总监：**NOT READY**

**视觉方向文档厚重（`art-bible.md` 2,967 行、9 部分全覆盖），但「单一真理来源」不存在，且缺口在扩大——不是没补，是补的方向反了。**

**已建立的部分**：视觉标识陈述（§1「黑白为骨，一色为魂」+ 三条支持原则）、造型语言（§3.3/§3.4）、灰阶层级（§4.7.1 BG-0~BG-4 / §4.7.2 T-0~T-3 附 WCAG 对比度验证）、色盲后备（§4.8）、排版/图标/组件（§7.2-§7.4）。这一层可直接用于裁决设计分歧。

**未建立的部分**：

1. **美术圣经从未签字**——`art-bible.md` 末尾 `AD-ART-BIBLE` 签收仍为「待定」，而 S16/S17 六个 story 已按它（或没按它）实现。
2. **内部色值三处互相矛盾**：§4.1 朱砂红 `#C23B3B` / §7.8 朱砂红 `#C41E1E` / 代码 `#B3424A`（4 个文件）；同一个「危险」语义有**三个红**，同一个「稀有/选中」有 `#C8A84E` / `#C9A96E` / `#E8C06A` **三个金**。
3. **主题方向矛盾**：§4.7.1 规定 UI 为深色基底（BG-0 `#141414`）；§7.5.1 规定弹窗为暖白基底 `#f5f0eb` + 墨色边框。代码如实分裂——`settlement_rules.gd` 走深色面板 + 暖白字，`lingshi_deck_bar.gd` / `exploration_info_area.gd` 走米白面板 + 墨黑字。**HUD 与战斗面板是两套主题，从未同屏被看过。**
4. **节点图调色板违背核心承诺（最严重）**：美术圣经 §6.4.1 明文「节点图**不使用任何色彩信号**」、§6.4.4 要求淡墨域 50-75%；而 `node_icon_atlas.gd:26-35` 实际使用 `#CC4444 / #FF4444 / #4488CC / #44CC88 / #9944CC / #44AAFF / #44CC66 / #FFAA00 / #FFD700 / #8B7355` **十种高饱和色**。这批色值来自 `exploration-ui-system.md:436-445`——**GDD 与美术圣经在此直接冲突，实现选了 GDD，且没有留下任何仲裁记录**。探索主界面是玩家看得最多的界面，其视觉身份在第一分钟就被推翻。
5. **无 Token 层**：`assets/ui/` 目录不存在，无 `.theme` / `.tres`；25 处以上色值以字面常量散落在 10 个文件。
6. **字体资产零入库**：`assets/**/*.{ttf,otf}` 零匹配；所有自绘文本走 `ThemeDB.fallback_font`。**所有基于字号的几何估算因此全部建立在未经验证的度量假设上**——`POPUP_SIZE` 360×220、`LOOT_CELL_HEIGHT` 210、tooltip「字符数 × 12px」三处固定尺寸边界。

**代价可量化**：现在每新增一个 UI story 就多 2-4 处字面色值；到核心循环完成时预计还有 20+ 个 UI story，将产生 40-80 个额外色值散点，届时统一需要逐文件 diff + 逐屏重走查——**成本约为现在建立的 5-8 倍**。

**与 2026-10-13 的差别**：当时只指出「缺一份文档」；现在能指出更硬的证据——**缺的是 Token 层与仲裁裁决**。文档已有 2,967 行，问题不在篇幅，在于同一概念有多套值且 GDD 与美术圣经直接冲突。

---

## 六、阻塞项清单（合并四位主管）

| # | 阻塞项 | 主管 | 「必须改变什么」 | 责任 |
|---|--------|------|-----------------|------|
| **B1** | 战斗场景壳不存在，核心循环第一跳出口断路 | TD/CD/PR | 为 `combat_scene.tscn`（薄容器 + 挂载 `CombatRoot` + HUD 挂载点）、`result_screen` / `defeat_screen` / `event_panel` / `shop` 四个占位场景、HUD 的 `register_persistent` 启动挂载建立显式承载 story（建议新建 `presentation-wiring` epic 或并入 combat-wiring 006），约 3.0 est-day，Sprint 18 must；并新增关口条件「`SCENE_PATHS` 零占位」 | technical-director（定归属）+ lead-programmer（实现）+ producer（排期） |
| **B2** | 出牌交互被误置于 should 层 | CD | `combat-ui-interaction` 001/003/005 从 should 提升为 Sprint 18 **must**，并写入里程碑条件 1 的解锁定义：「核心链路上的 epic 不得置于 should/nice 层」 | producer + creative-director |
| **B3** | R-02 组件级 D3D12 复测三次未履行 | TD/AD/PR | 拆 interaction story 009 的 AC-1+AC-2 为最小切片前置执行（1 个 must story，2-3 日）；产出「真实组件 + D3D12 + **VSync 关闭**」的 DC 与 p50/p95/p99 证据；**禁止用 VSync 开启的 p50=60fps 作为达标证据** | technical-director + qa-lead |
| **B4** | 107 项走查零执行 + QA-17-1 三冲刺未交付 | CD/TD/AD/PR | QA-17-1 **Sprint 18 Day-0 显式裁决**（给出交付日 或 正式放弃改人工）；P0 九项（1.5-2 人时）Sprint 18 首周闭环；把「视觉走查」写进冲刺 DoD 阻断条款（≥2 份未签收证据文档 ⇒ 冲刺不得关闭） | qa-lead + producer |
| **B5** | 视觉 Token 单一来源缺失 + 三处仲裁未做 | AD | ① 出 `design/art/style-guide.md`（或 `assets/ui/themes/palette.tres` + 说明），给唯一权威色值表与**禁用色白名单**；② 明文裁决：语义红取哪一个（并同步 GDD）、UI 主题深/浅（或明确分区规则）、节点图取「纯墨白」还是「10 类彩色」；③ 补 `AD-ART-BIBLE` 签字；④ 逐文件替换 25 处字面常量 + 加源码级断言（`src/ui/` 出现 `Color("#...")` 字面量即失败，白名单除外） | art-director（仲裁与起草）+ technical-artist（落 Theme） |
| **B6** | 字体资产零入库，三处尺寸边界建立在未验证的字宽度量上 | AD | `assets/ui/fonts/` 入库思源宋体 + 行书族子集化；建立 Theme 并替换全部 `ThemeDB.fallback_font`；把 `POPUP_SIZE` / `LOOT_CELL_HEIGHT` / tooltip 字符估算改为 `get_string_size()` / `get_line_count()` 驱动 | 资产管线 + ui-programmer |
| **B7** | 「看起来做了但不生效」未清零 | CD | DEBT-EUI-005-6（toast 未接线）与 DEBT-EUI-006-2（灵泉/回复 AP·HP 不恢复）在 Sprint 18 接线；无法接线的**必须在界面上显式降级**（按钮置灰 +「尚未开放」），不允许「点了没反应」。这是叙事机制不和谐，不是技术债 | lead-programmer |
| **B8** | ADR-0031 §验证标准 #3（CI autoload==25）无实现 | TD | CI 目前只有 GUT 一步，实测无任何 autoload 计数断言；补 CI 步骤（约 15 行 yml）或改 ADR 措辞为「人工检查」。当前是「文档承诺了一个不存在的机制」，比没有标准更危险 | devops-engineer |
| **B9** | 「有条件关闭」让风险可无限挂起 | TD | 风险册改二态 `开放 / 已关闭`；R-02 恢复**开放**；R-05 回 🟡 中（保留 D3D12 实测数据，注明残留真实元素复测） | producer |
| **B10** | 里程碑文档目标日期与承载表失效 | PR | 重写目标日期行与「实际承载」表（当前仍标 Sprint 15「进行中」），删除隐含的「S16-17 两段式收口」承诺，写入 5-6 冲刺区间与最早关闭点（Sprint 22-23） | producer |
| **B11** | 关口条件 5 在当前定义下不可达 | PR/CD | 裁决改写为分段式（见 §七 R1），需 creative-director 起草、producer 级联，不得由制作人单方面改写创意标准 | creative-director + producer |
| **B12** | 条件 4（约 200 项 GDD AC）无验收口径 | PR/AD | 选 1 个 epic（建议 combat-ui-layout，10/10 且组件最多）做一次完整 AC 对表，产出「哪些可自动化、哪些必须人工走查」的模板；否则收口时面对一个 189 项的、无法估算的验收尾巴 | qa-lead |
| **B13** | 检查点规则失效 | PR | Day-4 检查点改为「到期日必须写入判定」（执行丢弃 / 或写入「本冲刺放弃该检查点，理由 X」），写入位置固定为冲刺计划表格 + `sprint-status.yaml` 注释 | producer |

---

## 七、四位主管的共同最小路径

**R1｜把条件 5 换成四条可证伪断言，取代模糊的「全流程可演示」**
建议写法：(a) 从主菜单启动，经身份选择进入节点图，点击战斗节点后**进入战斗场景而非回退主菜单**；(b) 在战斗中**用默认卡组成功打出一张牌并造成可见伤害**（支柱 1 的最小可演示单元）；(c) 战斗结束进入结算面板并**完成一次战利品选择与一次撤退确认**，状态被真实写入；(d) 上述全程由**一位未参与开发的人在 15 分钟内独立完成**，不看开发者提示。四条全中即达成；任一条不中，无论 epic 完成度多高都不算收口。原「通关链路」（Boss 战→通关结算）拆为 5b，明确**不在本里程碑关闭条件内**，归下一里程碑（Sprint 21-22）。

**R2｜Sprint 18 的 must 只放三件事，其余全部显式丢弃**
① `combat-ui-interaction` 001/003/005（出牌链路，支柱 1 的命门）；② `combat_scene.tscn` 薄容器 + HUD 挂载 + 战斗→结算去向（补断链，含 `SCENE_PATHS` 自检）；③ P0/P1 走查 + 一次全程人工走查（补证据）。把 audio 005、main-menu 005、hud 007/008、exploration 004 与 deck-editing-ui 全部**显式丢弃并写明理由**——S17 已证明 must 吃满容量、should 永远做不完，那就在计划阶段诚实地只写 must。

**R3｜四项 < 2 日的低成本硬化（不改任何玩法代码，但把三条纸面规则变成真护栏）**
CI 加 `[autoload]==25` 断言；`SCENE_PATHS` 启动自检；风险册二态化；`/story-done` 增加「证据文档 §2 无空行」检查。**本次评估暴露的根因不是能力不足，是规则不执行且无人察觉。**

**R4｜由创意总监做一次不读代码的 15 分钟纯体验走查**
产出「已实现的体验 vs `game-pillars.md` 四条支柱」的偏差清单，作为 concept→实现的偏差基线。理由：本项目所有质量判断目前都长在自动化测试上，而支柱是体验命题，不能由测试断言。

---

## 八、验证链（Chain-of-Verification）

5 个挑战问题已检查——**裁决未变**：

1. **【TOOL ACTION】是否将 FAIL 条件过度软化？** 重跑 `grep -l "\*\*Status\*\*: Complete"` 逐 epic 计数——hud 6/8、main-menu 4/5、audio 4/7、layout 10/10、interaction 0/9、exploration 5/10、deck 0/7，与草案一致。条件 1 与条件 5 各自独立即足以 FAIL。
2. **【TOOL ACTION】结构缺口是否夸大？** 逐条 `[ -f ]` 检查 `SCENE_PATHS` 的 12 个目标——**实测 8 个缺失**（deck_editing / combat / tribulation / shop / event_panel / result_screen / defeat_screen / cultivation）；`HUD.tscn` 在 `src/` 内的两处命中**均为注释**，零实例化确认。
3. **【TOOL ACTION】走查台账是否准确？** S17 四份文档 §2 逐行统计 = 10/8/8/10 = **36 项全空**；S16 五份按走查行数 = 12/12/20/17/10 = **71 项**。合计 107 项。
4. **主管分歧如何处理？** TD 给 CONCERNS、CD/PR/AD 给 NOT READY——无矛盾：TD 是对「技术地基」的评价（地基确实更硬），CD/PR/AD 是对「里程碑是否达成」的评价（未达成）。按 gate-check 规则，任一 NOT READY ⇒ 裁决至少 FAIL。
5. **通往 PASS 的最小路径？** Sprint 18：B1（场景壳 + HUD 挂载）+ B3 最小切片（性能证据）+ B4 P0 走查；Sprint 19-20：interaction 001/003/005 出牌链路 + 007 结算/撤退流转；SPRINT 20 末跑条件 5a 四条断言。

---

## 九、结论文档修正（本检查提出，**未自动执行**）

| 文件 | 建议修正 |
|------|---------|
| `production/milestones/presentation-layer-complete.md` | ① 目标日期行改写为「两段式 S18-S22/23，最早关闭 2027-01 上旬」；② 「实际承载」表补 S15/S16/S17 三行并改 Sprint 15 状态为 ✅ Done；③ 关口条件 5 拆 5a/5b；④ 新增条件 6「`SCENE_PATHS` 零占位」；⑤ 条件 1 改为「4 个核心链路 epic + interaction 全部 Complete，且关键预制件在真实启动流程中被挂载」 |
| `production/risk-register/presentation-layer-risks.md` | 口径二态化（移除「有条件关闭」）；R-02 回「开放」；R-05 回 🟡 中并注明残留 story 010 |
| `docs/decisions/ADR-0031-presentation-layer-architecture-baseline.md` | §验证标准 #3 措辞与 CI 实际不符，须补 CI 步骤或改为人工检查 |
| `.github/workflows/tests.yml` | 补 `[autoload]` 条目数 == 25 断言 |
| `src/foundation/scene_manager.gd` | `SCENE_PATHS` 启动自检 `ResourceLoader.exists()`，缺失即 `push_error` |
| `design/art/` | 新建 `style-guide.md`（唯一色值表 + 禁用色白名单）；补 `AD-ART-BIBLE` 签字；裁决节点图配色（§6.4.1 纯墨白 vs GDD 10 色） |
| `design/gdd/game-concept.md` | §MVP 定义第 5 条「基础卡组构建功能」被两段式移出 MVP——须加注「MVP 定义修正（2026-10-24）：以默认卡组 + 战后掉牌三选一替代编辑界面」，否则两份已批准文档互相否证 |

---

## 十、下一步

**不推进阶段**（`production/stage.txt` 保持 `Production`）——本检查是里程碑内部关口，不涉及阶段变更。

**按顺序：**

1. `/sprint-plan new` — 按 PR 建议的容量配比（must 名义 ≤ 5.0d、QA 槽位 2.0d、技债 1.0d）规划 Sprint 18，must 只放三件事（R2）。
2. **Sprint 18 Day-0 必须先做的三项裁决**：QA-17-1 交付 or 放弃（B4）；里程碑条件 5 改写（B11）；`combat_scene.tscn` 承接归属（B1）。
3. 并行执行四项低成本硬化（R3，< 2 日）。
4. 首周内闭环 P0 九项走查 + A8 帧率实测。
