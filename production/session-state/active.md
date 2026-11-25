# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: 行数治理（超 300 行文件按职责拆继承链）
Task: progression_system.gd 456 → 138 行四段链（contract/lifecycle/growth/leaf）；下一个待拆以大文件扫描命令输出为准
<!-- /STATUS -->

## Session Extract — progression_system 四段继承链（2026-11-25）
- 任务单：`src/meta/progression_system.gd`（456 行，Autoload #12）按职责拆继承链；沿用前五轮「先写公开面锁定用例跑绿 → 逐字搬运 → 每段跑全量」三步法。基线 5885/5885，head `02920f4`
- **拆不拆的判定（先判四项，逐项实测）**：① **是 Autoload**——`project.godot` 的 `[autoload]` 把 `ProgressionSystem` 绑在 `*res://src/meta/progression_system.gd`，**不带 `class_name`**（实测 `get_global_name()` 为空串，链尾 `get_instance_base_type()` 仍为 `Node`、`.new()` 正常）。② **无 static 成员**——全文 0 处 `static`，故没有「链尾脚本静态解析祖先段静态成员」这条形态（与前一轮 scene_manager 的差异点）。③ **有按名分派**——`progression/serializer.gd` 子模块用 `_parent.set("_achievements", …)` 写 6 个域、`_parent.get("_save_load_override")` 与 `_parent.call("_get_save_load_system")` 读依赖；`tests/integration/identity_selection_system/test_identity_start_flow.gd` 用 `ProgressionSystem.get("_talent_defs")` 按字符串取字段——继承链下 `get`/`set`/`call` 穿透全链，实测通过。④ **无 `@onready` / 无 `%节点路径`**——全文 0 处，拆段不动 `_ready` 时序（`_ready` 只读档填 6 域 + 发信号）。**结论：拆**。
- **切 4 段**（首次按「域」而非「技术层」切）：`progression_system_contract.gd` 81 行（声明面：6 信号 / 14 实例字段 / 1 常量表 / 0 方法）、`progression_system_lifecycle.gd` 126 行（信号与生命周期面 13 方法：`_ready` / 2 信号 / 序列化 6 / 脏标志 2 / 内部辅助 2）、`progression_system_growth.gd` 206 行（成长面 17 方法：achievements 5 / talents 8 / 批量 2 + 2 信号）、`progression_system.gd` 138 行（链尾记录面 14 成员：endings 4 / gallery 3 / stats 3 / meta 3 + 2 信号）。**59 个成员一个不多一个不少**（38 方法 + 6 信号 + 14 字段 + 1 常量），文件名与 Autoload 注册串逐字不动
- **链序不是自由选择（三条硬约束叠加）**：① **信号必须落链首**——基段声明的信号可在派生段 `emit`，反向（派生段声明、基段发射）解析期失败；`progression_updated` 有两个发射方（第 2 段 `_mark_dirty_and_emit`、第 3 段 `batch_update_end`），故 6 条信号全落首段。② **`_mark_dirty_and_emit` 必须落第 2 段**——第 3 段与链尾的**每一个**域写入方法都调它，「被调方必须在本段或祖先段」。③ **`_get_save_load_system` 同理落第 2 段**——链尾 `_ready` 与子模块都要用它（子模块走 `call` 按名，穿透无碍，但链尾裸调必须能解析）。
- **字节级搬运 + 五项独立对拍**（临时脚本 `tools/split_ps.py` 按显式行区间切片，三阶段各跑一次全量，跑完即删）：① 59 个成员块**无缝覆盖原文 13..457 行**（块号恰好 0..58 各一次，且 `s == 前块 e + 1`）；② 非空行 **349 行多重集完全相同**；③ 代码体（去注释 / 去空行）**261 行多重集相同**，且各段是原文代码行的**子序列**（逐段 `iter` 子序列检查，段间保序）；④ 成员表 **59 项多重集相同**；⑤ **无祖先段裸标识符引用后代段成员**（只扫代码行，`#` 之后剥掉——文档里的 `[method xxx]` 引用不参与标识符解析）。
- **守卫用例** `tests/unit/meta/test_progression_public_face_lock.gd`（18 例 / 319 断言）：反射沿 `get_base_script()` 合并全链，锁 38 方法形参个数 + 默认参数值 + 返回类型、6 信号形参名、14 实例字段类型且**非 static**（两实例互不影响）、`_META_KEYS` 白名单逐项、`resource_path` + 原生基类（`Node`）+ `get_global_name()` 为空 + `project.godot` Autoload 注册值。末六例真实跑六条域读写路径（成就达标自动解锁 / 天赋扣点与前置 / 批量按域去重 / 结局与图鉴与统计 / 序列化往返 / `_ready` 真读档）。**改前在未改动的 456 行原文件上先跑绿 18/18**（踩两坑：① `_get_save_load_system` 断言写成「等于 mock 变量」失败——mock 是我自己 `Node.new()` 建的，与实例上存的那个引用不是同一对象 identity，改用 `ps.get("_save_load_override")` 比对；② `_ready` 用例先 `add_child_autofree` 再手动 `_ready()`，入树又触发一次真实 `_ready`，读档计数 2≠1 → 去掉入树，只手动调）。
- **反向验证（任务单要求的「锁得住吗」）**：① 把 `get_achievements(category := "")` 的默认值改成 `"combat"` → 守卫 1 红（`ARRAY(["combat"]) != ARRAY([""])`，方法默认参数值断言命中）；② 把 `_talent_defs` 改成 `static var` → 守卫 1 红（实例字段表 14 → 13，且「应存在」断言同时命中）。恢复后均回绿。
- 全量：**5903 / 5903 passing / 0 failing / 3 orphans 存量**（5885 → 5903，净增 18 全为守卫用例）；三个中间阶段（stage 1 / 2 / 3）各跑一次全量，三次均 5903/5903 零失败零回归
- 已知边界：① `progression/progression_serializer.gd`（128 行）为本次未动的相邻子模块，仍按名访问父节点字段（本轮实测穿透继承链正常，故未顺手改造——那会改到调用点）；② 本类**无 static 成员**，故「链尾脚本静态解析祖先段枚举/常量/静态方法」这条形态本轮**未覆盖**（上一轮 scene_manager 已覆盖）；③ 存量超限文件清单以命令为准、别抄数字：`git ls-files 'src/**/*.gd' | xargs wc -l | awk '$1 > 300 {print}' | sort -rn`

## Session Extract — scene_manager 四段继承链（2026-11-25）
- 任务单：`src/foundation/scene_manager.gd`（430 行）按职责拆继承链；沿用前四轮「先写公开面锁定用例跑绿 → 逐字搬运 → 每段跑全量」三步法。基线 5865/5865，head `686b551`
- **拆不拆的判定（任务单要求先判四项，逐项实测）**：① **是 Autoload**——`project.godot` 的 `[autoload]` 把 `SceneManager` 绑在 `*res://src/foundation/scene_manager.gd`，但**不带 `class_name`**（Foundation Autoload 固有权衡，同 `game_state_manager.gd`）；实测链尾脚本 `get_instance_base_type()` 仍是 `Node`、`.new()` 正常、继承链长 3 也照常实例化——**Autoload 不妨碍拆链，只要链尾保持 `extends Node` 血统**。② **有 static 成员**——`create_fade_overlay` / `fade_out_overlay`，且全工程 16 处调用点按路径 `preload` 后**静态形式**取用（`SceneManagerScript.SceneID.COMBAT`、`SceneManagerScript.create_fade_overlay()`）——实测链尾脚本能静态解析**祖先段**的枚举 / 常量 / static 方法，此路可走。③ **有按名分派**——`scene_transition.gd` 用 `_parent.get("_test_mode")` / `.set("_phase3_in_progress", …)` / `.call("_get_gsm")` 跨文件按字符串取 6 个字段与 3 个方法，继承链下 `get`/`set`/`call` 穿透全链，实测通过。④ **无 `@onready` / 无 `%节点路径`**——全文 0 处节点依赖，控件树与 `_ready` 时序无关，拆段不动初始化顺序。**结论：拆**。
- **切 4 段**：`scene_manager_contract.gd` 183 行（声明面：2 枚举 / 2 信号 / 2 常量表 / 11 实例字段 / 0 方法）、`scene_manager_access.gd` 105 行（依赖与访问面 11 成员：注入 + 惰性获取 + 音频门面 + 持久层注册）、`scene_manager_pipeline.gd` 134 行（转场管线面 7 方法：请求入口 + 信号发射包装 + 异步管线四转发）、`scene_manager.gd` 133 行（链尾装配与出口面 6 成员：`_ready` + 两查询 + 自检 + 两 static）。**41 个成员一个不多一个不少**，文件名与 Autoload 注册串逐字不动
- **链序由 GDScript 解析期硬约束定死**（本轮探针实测，前四轮结论复用）：祖先段用裸标识符调后代段方法直接 `Parse Error: Function "xxx()" not found in base self`；反向（后代调祖先）成功。故 `_ready`（要调 `_get_persistent_layer` / `_get_audio_manager` / `verify_scene_paths`）**必须落链尾**，而 `scene_transition.gd` 按名调的 `_get_gsm` / `_get_im` / `_execute_post_load` 等必须落前段——链序不是自由选择
- **另一条实测硬约束**：`SCENE_PATHS` 同时是 `verify_scene_paths(paths: Dictionary = SCENE_PATHS)` 的**默认参数值**，而默认值表达式只能引用本段或祖先段的常量 → 常量必须随声明落链首，不能跟着用它的方法走
- **字节级搬运 + 四项独立对拍**（临时脚本按显式行区间切片拼接，跑完即删）：① 9 个区间在目标文件**各自唯一且连续**命中；② 原文非空行**无遗漏**；③ 代码体（去注释 / 去空行 / 去 `extends` 行）**195 行多重集完全相同**，且各段内是原文代码行序列的**子序列**；④ 成员表 41 项多重集相同且各段内保序
- **守卫用例** `tests/unit/scene_manager/test_scene_manager_public_face_lock.gd`（20 例 / 329 断言）：反射沿 `get_base_script()` 合并全链，锁 23 方法形参个数 + 默认参数值 + 返回类型、2 信号形参名、11 实例字段类型且**非 static**（两实例互不影响）、5 张常量表逐项值（SceneID 12 / TransitionType 6 / SCENE_PATHS 12 / TRANSITION_AUDIO_PARAMS 5 / `_AUDIO_MANAGER_SCRIPT` 路径）、`resource_path` + 原生基类 + `project.godot` Autoload 注册值，末四例真实跑完整转场（Phase 2 推锁 + 存档 + `pre_transition` → `_execute_post_load` 的 Phase 4-5 GSM 写入 / 解锁 / `post_transition` / 状态复位）、`_cleanup_on_error`、音频门面与 PersistentLayer 接线。**改前在未改动的 430 行原文件上先跑绿 20/20**（踩一坑：mock 依赖没释放留孤儿 → `after_each` 统一 `free`；另一处最初用 `_test_mode=false` 真跑了 `change_scene_to_file`，把宿主当前场景换掉并留孤儿场景 → 改回 `true` 走同步接缝）
- **`verify_scene_paths` 的默认值是整张表**这件事单独一条用例守（`test_verify_scene_paths_default_is_scene_paths_table`）——默认值走样在别的断言里看不出来，但「不传参即全表自检」的语义就断了
- 全量：**5885 / 5885 passing / 0 failing / 3 orphans 存量**（5865 → 5885，净增 20 全为守卫用例）；`test_lock_reentry` 仍 **7/7**（转场锁 push/pop 仍在同一条路径上）；真机试玩走查 **14/14 步全绿**
- 已知边界：① `scene_persistent_layer.gd` 78 行、`scene_transition.gd` 141 行为本次未动的相邻模块；② `settlement_host.gd` 371 行、`combat_focus_chain.gd` 301 行、`save_load_system.gd` 1027 行为存量超限，不在本轮范围；③ 拆分只解决行数，**没有**改变 `scene_transition.gd` 仍在用 `_parent.get/set/call` 字符串访问这一既有形态（本轮实测它穿透继承链正常，故未顺手改造——那会改到调用点）

## Session Extract — settlement_panel 三段继承链（2026-11-25）
- 任务单：`src/ui/combat/settlement/settlement_panel.gd`（350 行）按职责拆继承链；沿用前三轮「先写公开面锁定用例跑绿 → 逐字搬运 → 每段跑全量」三步法。基线 5852/5852，head `876a87a`
- **行构成 / 调用形态**：全文 0 处 `@onready`、0 处 `%节点路径`——控件树由 `_init` → `_build()` → `View.build()` 纯代码搭建并缓存进字段，`_notification(NOTIFICATION_READY)` 只下发字号，故**不是节点结构重度依赖**，拆段不改变 `_ready` 时序（那条「先验一道」的分支没走）。外部消费者 6 个文件按路径取类（`settlement_host_panels.gd` 的 `PanelScript.new()` + 三个集成测试 + debug 场景）；`settlement_host.gd` 持 `var settlement_panel: Control` 按名直呼三个 show_*，属按名动态分派（名字打错只是运行时 `push_error`）
- **切 3 段**（不是硬凑 2 段）：`settlement_panel_contract.gd` 102 行（声明面：4 preload / 5 信号 / 3 尺寸常量 / 20 实例字段 / 0 方法）、`settlement_panel_flows.gd` 166 行（流程面 7 方法：胜利/战败两面板 + 战利品交互 + 卡片清空 + 已到账汇总）、`settlement_panel.gd` 151 行（链尾：装配与出口面 14 方法）。`class_name SettlementPanel` 与文件路径留链尾逐字不动
- **本轮最重要的实测发现（GDScript 解析期硬约束）**：**祖先段不能用裸标识符引用后代段成员**。链尾 `_build()` 按名接线三个回调，其中 `_on_loot_delay_timeout` 在上一段——把构造/装配放在链首会直接 `Parse Error: Could not resolve class`。四级递进探针实测（含对照组 `pb.gd extends pa.gd` 后代调祖先**成功**），故链序由「谁接线谁靠后」定死，不是自由选择。probe 脚手架跑完即删
- **字节级搬运**：临时脚本按显式行区间切片拼接，四项独立对拍全过——区间并集恰好覆盖原 3..350 行（291 非空行逐字相同）、每区间在目标文件逐字命中、21 个方法名一致、无祖先→后代引用（只扫代码行，`#` 之后剥掉——文档里的 `[method xxx]` 引用不参与标识符解析）
- **守卫用例** `tests/unit/combat_ui/test_settlement_panel_public_face_lock.gd`（13 例 / 226 断言）：反射沿 `get_base_script()` 走遍继承链再合并，断言「链长 1 与链长 3 的合并面逐位相同」——21 方法形参个数 + 默认参数个数、5 信号形参名、20 实例字段非 static、3 尺寸常量、`resource_path` / `get_global_name()` 不变，末三例真实走完胜利 / 战败 / 已到账汇总三类面板。**改前在未改动的 350 行原文件上先跑绿**（踩两坑：未入树的 Timer `start()` 报 `!is_inside_tree` → `before_each` 补 `add_child_autofree` + `reduce_motion = true`；`View.clear_grid` 走 `queue_free` 留 3 个孤儿 → `after_each` 补 `await process_frame`）
- 全量：**5865 / 5865 passing / 0 failing / 3 orphans 存量**（5852 → 5865，净增 13 全为守卫用例），真机试玩走查 32 步全绿。提交 `686b551`
- 已知边界：`settlement_host.gd` 371 行、`combat_focus_chain.gd` 301 行、`save_load_system.gd` 1027 行为存量超限，未在本轮范围

## Session Extract — 游玩时长落盘 + 结算屏两段分工（2026-11-24）
- 任务单两条：① `playtime_seconds` 从不写入（主菜单恒「游玩 0小时0分」）；② 结算屏「战利品三选一」与「已到账汇总」并列同权重（DEBT-CUI-008-3）
- **①唯一数据源**：`GameStateManager.session.playtime_seconds`，由新增 Autoload `SessionClock`（`src/feature/session/session_clock.gd`，134 行）每帧累加。**为什么用 `_process(delta)` 累加而不是 `Time.get_ticks_msec()`**：后者是墙上时钟（挂起/最小化/暂停菜单/断点调试全算），且读档 / 新开局都要额外记起点、每次重算差值；累加 delta 的语义就是「这一帧游戏真的推进了多少」。判定与算术拆到 `session_clock_rules.gd`（90 行，纯函数：`should_accumulate` / `tick` 跨帧凑整 / `format_duration` / `format_playtime`），测试不必真等时间
- **三重缺失逐条补齐**：`SaveAutoSave.build_meta()` 补 `playtime_seconds` 字段（新 `playtime_seconds()` / `session_of()` 走 `Object.get`，替身 GSM 不崩）；暂停菜单改调 `SaveLoadSystem.build_slot_meta()`（此前传 `{}`）；`session` 从 `NON_PERSISTABLE_DOMAINS` 移入 `PERSISTABLE_DOMAINS`（`gsm_serializer` 的 session 默认值补 `playtime_seconds: 0`），`_build_save_container` 那行才读到数
- **读档续算零额外接线**：`SessionClock` 刻意不缓存总数——读档把 GSM 值改写为存档基线，下一个整秒自然往上加。**副作用收尾**：`session.input_locks` 是运行时锁镜像，读档后不清会让 `InputManager.has_lock` 说谎 → `SaveLoadSystem._clear_session_input_locks()` 在读档落地阶段清空
- **展示口径**：向下取整到分钟；`< 60s` 写「游玩不到 1 分钟」（连写、不带空格），`≥ 60s` 写「游玩 2小时3分」（带空格）；0/负数同样走不足 1 分钟档（0 秒与 59 秒对玩家是同一件事，「0小时0分」反倒像存档没生效）
- **②两段分工**：措辞与分档阈值进新文件 `settlement_section_text.gd`（101 行），几何/状态/标签进 `settlement_loot_rules.gd`（147 行），`settlement_rules.gd` 保留同名常量与转发（295 行，从 366 降回上限内）。选择段标题按实际候选数写（1 项 →「本次奖励：这份直接带走」+ 按钮「直接带走」；≥2 →「本次奖励：N 选 1」）；`SettlementPanelView.build` 把汇总块从「标题/提示之间」移到**网格之后**并新增 `PickTitle` 在其上——顺序即语义，玩家先挑再看到手了什么；入账段加「已入账：」前缀、选择阶段加「本场奖励（尚未入账）：」前缀；`show_grant_summary` 隐藏网格 + 选择段标题 + 跳过并清卡
- **新增测试 57 例**：`test_session_clock_rules.gd`（16，含 59/61/3700 三档与空格规则）、`test_playtime_paths.gd`（8，三路径同源 + 往返基线 + meta.json 闭环 + input_locks 清理）、`test_settlement_section_text.gd`（21，1/2/3 项精确字符串）、`test_settlement_two_sections.gd`（12，真实面板控件断言 + 控件顺序）
- **改动的既有断言（三条，均记录旧值→新值）**：`test_save_summary_zero_playtime_shows_zero` → `test_save_summary_zero_playtime_shows_sub_minute`（「游玩 0小时0分」→「游玩不到 1 分钟」）；`test_save_summary_negative_playtime_clamped` 期望值同上；`test_ac017_serialize_excludes_session` → `test_ac017_serialize_includes_session_for_playtime`（`assert_false(has("session"))` → `assert_true` + 值断言），`data.size()` 7 → 8。都不是放宽——仍为精确字符串/精确数量断言，只是分档点与持久域集合改了
- **反向验证（任务单要求）**：把 `session` 从 `PERSISTABLE_DOMAINS` 拿掉重跑全量 → **58 红**，其中直接命中本轮的 4 条（`test_three_readers_see_same_playtime_after_accumulate`、`test_ac017_serialize_includes_session_for_playtime`、往返三条读档失败、`test_ac017_serialize_includes_all_persistent_domains` 的 size 断言），其余 54 条是读档链路连带（`gsm_serializer.deserialize` 在 `ALL_DOMAINS` 循环里读 `snapshot["session"]` 落空）。恢复后全绿
- 全量：**5788 tests / 5788 passing / 0 failing / 3 orphans 存量**，`.\run_tests.ps1` 零失败（5730 → 5788，净增 58：新增 57 + 拆出的 1 条 59 秒边界用例）
- 已知边界：① 主菜单停留时间是否计入游玩时长未定义（`should_accumulate` 只判暂停，不判「是否已开局」）——留待后续；② `save_load_system.gd` 1027 行（存量超限）、`settlement_panel.gd` 350 行、`settlement_rules.gd` 295 行，均在既有口径内；③ `settlement_section_text.gd` 的 `has_choice` 目前只有测试消费（提示行按 `== 1` 直判），保留为分档阈值的单一出处

## Session Extract — 一周目端到端冒烟（2026-11-19）
- 任务：写一条「玩家从进游戏到打赢首图 Boss」的端到端冒烟，整条链路真实走一遍，断哪修哪
- **交付**（8 个新文件，全在 `tests/integration/exploration_ui/`，均 ≤300 行）：装置四层继承链 `one_run_base_fixture.gd`（266，真实 Autoload + 场景管理器桩 + 存档隔离 + 跨用例状态快照还原）→ `one_run_smoke_fixture.gd`（246，主菜单/身份/探索容器三段编排 + 图结构查询）→ `one_run_battle_fixture.gd`（208，点格→弹窗→开战上下文）→ `one_run_combat_fixture.gd`（287，真实战斗场景挂载与推进）；用例四个 `test_one_run_smoke/battle/clear/save.gd`（207/70/102/95），**17 个新用例**（10+3+2+2）
- **走真路的关键接缝**（都不走捷径）：进图靠 `ExplorationEntryIntent` 落盘 → 容器消费；开战靠真实 `combat_scene.tscn` 的 `_ready` 从 `CombatLaunchContext.take()` 取（**不注入 `launch_context_override`**，否则短路被测接缝）；出牌走真实鼠标命中测试（`CombatInputLayer._handle_button`）；通关靠真实结算屏 `_on_return_pressed`（**不直调 `end_exploration`**）；解锁断言读 `ExplorationSystem.get_map_list()`——界面渲染消费的同一份条目，不是另算一遍门禁
- **修掉的断点（7 处，全是用例自身缺陷，生产代码一行未改，`git status src/` 为空）**：① `popup_body()` 调不存在的 `body_text()`——`node_interaction_popup.gd:133` 只把文本写进标签，改读命名子节点 `Body`；② `walk_to_boss` 用 `self.call(&"_path_to", ...)` 调一个已改名的函数；③ **`deck.slots` 为空导致「我方出战名单非空」假红**——`enter_first_map()` 跳过了身份那一步，而阵容/初始卡组是 `apply_identity` 写的（`identity_selection_system.gd:257-260`）；**没有放宽断言**，加了 `start_new_run()` 走完真实主菜单→身份→确认→跳过叙事；④ `clear_count()` 缺省参数读「当前图」，而结算已把 `current_map` 清空 → 恒 0，改为显式传首图 ID；⑤ `test_one_run_save.gd` 继承错基类（`click_node` 在战斗装置里）；⑥ **`GateScript` 常量在子类重复声明 → GUT 静默跳过整个文件**（子类重复 const 是解析错误，汇总数字仍然绿——本仓库第二次踩）；⑦ `one_run_smoke_fixture.gd` 涨到 333 行越限 → 拆出底座与战斗装置
- **修掉的真回归（重要）**：新用例在 `exploration_ui` 目录跑完后，下一条 `hud` 用例 `test_pause_combat_state_preserved` 会死循环刷 `advance_phase() called with no active battle` 直到套件挂死（实测日志涨到 150MB+ 未结束）。**根因**：战斗装置让 Autoload `AISystem` 名册留着「已全灭」的敌人、`DeploymentSystem` 阵位留着上场角色，下一条用例 `battle_start` 后 END 阶段立刻判出胜负结束战斗，而那条用例靠 `_advance_to_turn` 推进回合等待——等待条件永不成立。**修复**：`one_run_combat_fixture.gd` 的 `after_each` 按 `full_battle_fixture.gd:195-224` 口径还原共享单例（撤阵位 / `CostSystem.clear_for_battle_end` / `InputManager.clear_locks` / `AISystem.set_enemy_roster` 还原 / GSM battle 域按「开测前是否存在」还原）。修复后同组合全绿
- 全量（`.\run_tests.ps1`）：**5282 tests / 5282 passing / 3 orphans / 21131 asserts**，「All tests passed!」。移出这 8 个文件跑对照得 5265 / 5265——净增 17，零失败零回归；两边的 2 条 `advance_phase` 噪音与 24 条 warning 与基线逐位一致
- 已知边界：① `tests/unit/combat_system/test_combat_scene_resume.gd` 因解析错误（`PilelessCombatStub` / `RosterStub` 未声明）被 GUT 静默跳过——**存量问题**，单独跑同样跳过，不在本轮范围；② `hud` 目录单跑时 `test_hud_bootstrap.gd::test_main_menu_does_not_auto_mount_when_not_current_scene` 会红（HUD 被前序用例留成常驻），全量跑时不复现——跨目录污染存量，与本轮无关；③ `one_run_combat_fixture.gd` 287 行，再长出装置动作就需要再拆一层

## Session Extract — 难度与人数配平（2026-11-17）
- 任务：「新手能一路玩下去」第一段——战斗难度此前全靠占位数值，且敌方属性与地图境界档无关（炼气打归墟 ≈ 炼气打青云剑宗）
- **审计数字（`tools/probe_difficulty_audit.gd` 实算，非估算）**：境界表 L1~L5 的 `max_deploy` = 2/3/4/5/6，`cost_per_turn` = 2/5/8/11/14，`action_points` = 5/7/9/11/13；角色卡按「ATK 降序 → HP 降序 → card_id 升序」取前 N 名——L1 = 屠夜(8/4) + 苏剑鸣(7/4) → 总 HP 15 / 每回合 8 伤；L4 五人 → 43 HP / 每回合 17 伤。敌人属性唯一来源是 `assets/enemies/*.tres`（散修 16/2、魔修 30/9、妖兽 22/5 威力×1.8、鬼修 38/11 威力×1.2）；**改造前不存在难度系数表**，只有 `1 + (玩家境界 − 模板境界) × 0.3` 一条追赶公式，而四个模板境界恒为 1~2——地图的 `enemy_realm` 对战斗数值零影响（DEBT-EQT-001）
- **L1 打第一张图（改造前实测，临时用例跑真实战斗场景）**：敌人 2 人（血渊池的妖兽 ×1.8），我方总 HP 17 → **第 2 回合全灭，outcome=defeat**。这就是「新手在第一战就断」
- **改造后实测（同一条真实战斗链路）**：L1 打首图 = 散修 ×1，直接伤害牌卡组 **4 回合**获胜、残血 14；换成**真实初始卡组**（青云剑宗外门弟子：7 张里只有 2 张基础攻击，其余是绑定/增益/护盾）**6 回合**获胜、残血 12。L4 打归墟通道（分析模型）：2 鬼修 76 HP、我方 17 伤/回合 → gap=0「均势」，模型判「打不过」（模型假定敌人每回合都放最强技能，是保守下界）
- **难度系数表**：`assets/enemies/difficulty_curve.gd`（143 行，纯 static，全库唯一系数来源）——档位表 `gap = 地图境界档 − 玩家境界` 夹到 ±2：−2 HP×0.60/ATK×0.70「碾压」、−1 ×0.80/×0.90「轻松」、0 ×1.0「均势」（**必须是 1.0**：出厂端到端用例按模板原值断言首图敌方 HP）、+1 ×1.30/×1.25「吃力」、+2 ×1.60/×1.50「苦战」；属性取整后夹 `MIN_ENEMY_HP/ATK = 1`（防「0 血敌人让战斗永不结束」）
- **关键设计修正（实测发现的重复计算）**：最初两条轴相乘（档位 × 追赶），结果**元婴玩家进元婴图 gap=0 却被追赶轴再加 ×1.6**——「玩家越接近这张图的境界，敌人被堆得越厚」，与「追平后 3~5 回合能赢」正好相反。改为**同时只用一条轴**：给了地图档就只走档位轴（玩家练得越高 gap 越负，追赶已含在 gap 里），没给地图档（渡劫 / 无探索上下文）才走追赶轴——后者与改造前的两参调用逐位一致
- **接线**：`AISystem.create_enemy_roster(template_ids, player_realm, map_realm = 0)` → `AIRosterFactory` → `CombatSceneBattleSetup._resolve_roster` 把节点的 `enemy_level` 当 `map_realm` 传入（`enemy_level` 来自 `CombatLaunchContext` ← `ExplorationDAGContent._level_of` ← 地图的 `enemy_realm`）。`map_realm = 0`（渡劫）时档位系数恒 1.0，零行为漂移
- **首图池单开 + 人数收到 1**：新增 `POOL_FIRST_MAP`（只出散修，权重 100），青云剑宗改用它，并把 `enemy_count_min/max` 从 1~2 收到 1~1。原因是实测「妖兽 ×1.8 威力让炼气两人队第 2 回合全灭」，且**两敌人即使全是散修，伤害密集卡组也要 8 回合**（超出 3~5 窗口）——数量是本轮唯一能压到窗口内的杠杆（档位表的 gap=0 锚点必须是 ×1.0）。妖兽仍在慕兰草原与万妖谷的池里，「新手第一战不难」与「妖兽是威胁」由不同地图承担
- **测试**：`test_difficulty_curve_tiers.gd`（18 例：档位键/夹取/中文档位名/单轴语义/防重复计算、工厂层同境界·越级·越级两档·压级取值、夹下限、极低基准不被抹成 0、地图档单调、未定档回追赶轴、两参缺省逐位一致）+ `test_difficulty_curve_battle_tempo.gd`（3 例端到端：伤害密集卡组的 3~5 回合窗口断言、真实初始卡组不拖沓、节点档高一档在真实战斗里确实更硬）+ `tests/fixtures/battle_tempo_model.gd`（191 行，测试与审计脚本共用的算式模型）。既有用例零改名零删除零跳过
- 全量：**5137 tests / 5137 passing / 3 orphans 存量**，「All tests passed!」，`.\run_tests.ps1` 零失败
- 已知边界：① 敌人**数量**仍与玩家境界无关（只是首图收到 1；`enemy_count_min/max` 是每图固定区间）——「数量随境界」是下一段的 headcount 轴；② 分析模型里 L4 打归墟判「打不过」，是模型按「敌人每回合放最强技能」的保守口径，真实观感需端到端用例补一档；③ 「追平后 3~5 回合」在**真实初始卡组**下是 6 回合——差在卡组攻击密度（7 张里只有 2 张伤害牌），不是难度系数，两条数字都已锁进测试；④ `exploration_map_catalog.gd` 311 行（既有超 300，本轮 +11）；⑤ 档位表只覆盖 ±2 档，更高境界差由数量/技能池承担

## Session Extract — 结算屏出口分流 + 卡组查看画卡面（2026-11-17）
- 任务：接上一轮留下的两条——① 战败屏「返回」按 UX 规格应回主菜单（本局已结束，不该继续探索），而胜利屏按既有语义回探索；② 暂停菜单的卡组详情是纯文本，改成画卡面（至少卡名/类型/费用/效果摘要），键盘可导航
- **审计断点（第 1 项产出）**：① 四块占位屏（卡组编辑 2 / 坊市 6 / 胜利结算 8 / 战败 9 / 修为 10）共用 `PlaceholderScene._on_return_pressed()` 一个出口，一律跳 EXPLORATION + `COMBAT_TO_EXPLORE`——**战败屏与胜利屏目的地理应相反却共用同一个出口，这就是断点**；② `battle_record_scene._hint_for_result()` 是 hint 文案的唯一来源（覆写 `PlaceholderScene.HINTS`，按 `is_victory` + `RESULT_RETREAT` 分三档），出口改向不影响它；③ 卡牌在别处已有渲染：`HandCard`（自绘 `Control`，100×140，稀有度色边框）与 `LootOptionCard`（自绘、可聚焦）——但 `HandCard` 的 `mouse_filter = IGNORE` 且**不是 Button**，不能直接当列表行复用，故本轮做的是「字段层复用 + 行组件新写」
- **出口判据收进一个纯逻辑模块**：`battle_record_exit.gd`（71 行，全 static）——`target_scene` / `transition_type` / `button_text` / `returns_to_exploration` 四个函数同进同退，`SceneID` 与 `TransitionType` 的引用只此一份，`PlaceholderScene` 不再自己比较枚举
- **文案不再是含糊的「返回」**：`TEXT_RETURN_EXPLORE = "返回探索"` / `TEXT_RETURN_MAIN_MENU = "返回主菜单"`，每块屏都写明回的是哪一层；做成函数 `return_button_text(screen_id)` 而不是常量——写成常量就还得在这里再抄一份「哪个 ID 对应哪句话」的判定，那正是要消灭的第二份真理
- **胜利那侧的收尾必须跟着走**：`_on_return_pressed` 里 `returns_to_exploration(screen_id)` 为真才跑 `_mark_battle_node_cleared_if_victory()`——战败回主菜单这条路跳过它，顺带免了「在主菜单里标一格已清」这种说不通的写入（Boss 通关结算同样只挂在探索那条路上）
- **卡面字段也是纯逻辑**：`card_face_rules.gd`（162 行）从 `CardTemplate` + 实例 ID 产出 `face` 字典（卡名/类型名/费用/稀有/稀有度等级/效果摘要），效果摘要保留换行折叠、超 32 字符截断加省略号；稀有度配色**复用 `HandCard.RARITY_BORDER_COLORS`**（不另写一份色表——两处色表必然漂移）
- **行组件 `DeckCardRow`（151 行，`extends Button`）**：自绘卡底矩形 + 左侧稀有度色条 + 1px 边框，`alignment = LEFT` / `focus_mode = FOCUS_ALL`。自绘 `_draw()` 与 Button 自身 stylebox 共存——按需给 normal/disabled 用 `StyleBoxEmpty`（**只给 hover/pressed 用带色 `StyleBoxFlat`**，否则会盖住卡面）
- **踩到的两个坑**：① `StyleBoxEmpty` **没有 `bg_color` 属性**（只有 content margins），往里写颜色报 `Invalid assignment of property or key 'bg_color'`（19 处，11 个用例红）——拆成 `_empty_box()` 与 `_tint_box(color)` 两个工厂；② 断言「零尺寸不绘制」的用例被删掉了——Godot 的 Button 在零尺寸下**照样**发 `draw`，这个守卫没有可断言的对外行为，硬测就是测实现细节（用例内已注明删因）
- **组行与读取层按职责拆分**：`deck_card_rows.gd`（74 行，`add_rows`：有 `face` 就建 `DeckCardRow`，没有就回退纯文本行）、`deck_view_readout.gd`（136 行，只读查询面）、`deck_view_sources.gd`（63 行，取数与文案）——`pause_menu_deck_view.gd` 从 302 → **284 行**（只剩挂载与转发），`deck_view_rows.gd` 199 → 224 行（新增 `KEY_FACE` / `KEY_MARKER` 两个载荷键）
- **卡面与行文案同源**：`key="marker"`（已抽出 / 仍在牌库）由 `deck_view_rows` 产出、卡面行拼进第二行，测试专门钉「行文案里的词与标注是同一个」——一处说「仍在牌库」另一处为空就自相矛盾
- **测试：新增 59 例（5 文件）+ 既有文件补例**——`test_battle_record_exit.gd`（14 例：目的地/转场类型/按钮文案/三方一致/与音频矩阵一致）、`test_card_face_rules.gd`（19 例：字段读取与降级、摘要截断、meta 行、稀有度配色对齐 HandCard 表）、`test_deck_card_row.gd`（11 例：四要素齐全、焦点环、状态样式盒不遮卡面、边框色随稀有度）、`test_deck_view_rows.gd`（6 例：卡面字段与标注）、`test_deck_card_faces.gd`（9 例端到端：行确为 `DeckCardRow`、卡面四项可见、键盘可聚焦、确认仍只展开详情、缺卡面时回退文本行）；`test_placeholder_scenes.gd` 改为按屏断言去向（`EXITS` 表，断言按钮文案 `!= "返回"`）、`test_combat_result_bridge.gd` 补战败/撤退回主菜单两例。既有用例零改名零删除零跳过
- **确认新增用例真的逐条执行**：从 GUT 输出的 `* test_...` 行逐文件核对（子类重复声明同名常量会让 GUT 静默跳过整个文件，只看汇总数字看不出来）
- 全量：**5116 tests / 5116 passing / 3 orphans 存量**，零失败零回归（5055 → 净增 61）。既有失败 `test_hud_bootstrap.gd::test_main_menu_does_not_auto_mount_when_not_current_scene` 已用 `git stash` 在 HEAD 上复现，确认与本轮无关（仅单独跑该目录时红，全量跑绿）
- 已知边界：① 卡面是自绘几何（底色 + 稀有度色条 + 文字），**未接美术卡图**（图片资源不在本 story 范围）；② 效果摘要超 32 字符截断，长描述在行内看不全（详情面板仍是完整文本）；③ 卡组查看仍无分类/筛选与滚动到头提示（牌组规模未到需要它的程度）
- Next recommended: 战斗态入存档（UX 规格 Open Question #1「战斗暂存」仍开放——读档回不到战斗）；`ExplorationSystem`（686 行）与 `main_menu.gd`（520 行）拆分；卡面接真实卡图资源

## Session Extract — 战斗暂停菜单两处断链接通（2026-11-17）
- 任务：接上一轮留下的两条战斗态断链——① 战斗中「返回主菜单」按 UX 规格应先走投降结算（确认 → `COMBAT_RESIGNED` 视为战败 → 战败结算画面 → 玩家自行返回主菜单），此前只是确认后直跳主菜单；② 战斗中「查看卡组」应为只读查看，此前只发一个全库零消费者的信号
- **审计断点（第 1 项产出）**：① 直转场断点在 `PauseMenuState.return_to_main_menu()`——无分支直调动作层 `request_main_menu()`；② 撤退入口是 `CombatSystem.confirm_retreat()`（`src/feature/combat_system.gd:507`，即 `battle_end(CombatResult.RETREAT)`，与战斗场景自己的「撤退」按钮 `combat_scene_exits.gd.on_retreat_confirmed` 同一条链），**本项目没有 `COMBAT_RESIGNED` 这个符号——`CombatResult.RETREAT` 就是它**（RETREAT 携带 DEFEAT 语义，`_settle_result` 给 `retain_ratio = 0.5`）；③ 战败画面由战斗系统自己在 `battle_end` 末段发（`_request_scene_change` → `target_scene = 8 if VICTORY else 9`，即 `DEFEAT_SCREEN`），`SettlementHost.on_battle_ended` 对 RETREAT **刻意不开面板**，故投降直接落到战败屏——正是规格要的「与正常战败一致」；④ 卡组断点是 `deck_view_requested` 信号零消费者（面板本体不在任何 story 范围内）
- **投降链单源**：`PauseMenuCombatExit`（91 行，纯逻辑）只回答「该不该投降」与「触发它」——`can_resign(scene_id)` 要求「场景是战斗变体（含渡劫）**且**战斗确实活跃」（后者不是多余守卫：战斗场景在备战确认前就已存在，此时判成投降会凭空造一场败仗）；`resign()` 委托 `confirm_retreat`，**绝不再发一次转场**（两条转场会撞 `SceneManager._transitioning` 并发守卫）
- **顺序不可反**：先 `_release_pause()`（解冻 + pop MODAL 锁 + 恢复音频）再触发投降——转场管线不含「恢复暂停」职责，冻结态下转场新场景会停在冻结帧。替身在 `confirm_retreat` 里记下「被调那一刻」的暂停/锁快照，顺序错了这条断言会亮红
- **不补自动存档**：撤退结算会改写修为与资源，此时写盘存下的是「仗输了但还没结算」的中间态，会把上一份干净存档盖掉——写盘时机归转场管线 Phase 2
- **确认框三键统一走投降**（测试抓出来的修正）：最初只让「不保存」走投降，「确认保存」仍直跳主菜单——等于留了一条绕过结算的后门（玩家显式要的存档照写，但推进结算的路径必须唯一）。抽出 `leave_after_save()` 供两条路共用
- **降级路径**：非战斗场景一字未改（仍是「顺手自动存档一次 → 转场主菜单」）；战斗不活跃 / HUD 未注入 `combat_system` 时回退普通返回——链没接上时比把玩家锁在一场关不掉的战斗里强
- **只读卡组查看**：`PauseMenuDeckView`（302 行）+ `DeckViewRows`（199 行，取数与行文案纯逻辑，无控件树也能断言）。复用商店/背包面板骨架（`ShopPanelLayout.build` + `InventoryPanelLayout.add_rows/fill_detail` + `ShopPanelNavigator`），不新造一套控件语言
- **「只读」落在三处**：不提供任何编辑入口（「返回」是唯一出口）；行的确认动作只展开详情文本（不发系统调用、不写状态）；无分类切换（卡组不是分类清单）。测试用「只装 `get_deck_cards` 的替身」钉住——面板若试图走任何写入口会以 `ERR_UNAVAILABLE` 失败
- **按实例逐张出行、不按模板合并**：背包合并同名是为回答「我有几张」；卡组查看要回答「**哪几张已经抽到手**」——同名的两张可能一张在手上、一张还在牌库，合并就把这条信息抹平了。标注写进**文本**（`已抽出` / `仍在牌库`）而非靠颜色（色盲可读）。非活跃战斗一律不标（此时 `get_hand()` 本就是空，全标「仍在牌库」等于凭空断言）
- **ESC 分层由三层变四层**：确认框 → 卡组面板 → 读档面板 → 菜单，一次只退一层
- **拆文件守 300 行**：`pause_menu_pause_cycle`（134，开合五步与锁栈配对）、`pause_menu_state`（273，变体/确认/退出链分叉）、`pause_menu_combat_exit`（91）、`pause_menu_deck_host`（81，面板挂载与依赖透传）、`pause_menu_handlers`（215，按钮按下之后做什么 + 反馈行两档配色）、`deck_view_rows`（199）；`pause_menu.gd` 从 346 → **324 行**（只剩控件路径与瘦转发）。**常量 `COLOR_STATUS_OK/FAIL` 刻意留在 `PauseMenu`**——既有用例按 `menu.COLOR_STATUS_*` 读，搬家会把一处引用拆成两处真理来源（`PauseMenuHandlers` 经宿主转发）
- **测试：新增 18 例**（`test_pause_menu_resign.gd` 8 例端到端投降链 / `test_pause_menu_deck_view.gd` 10 例只读查看与焦点回锚）+ 夹具扩 `MockCombat`（含 `retreat_calls` 与投降时刻的暂停/锁快照）/`MockDeck`/`MockCards`（给**真** `CardTemplate` 资源——行文案读它的字段，用真资源才验证得了「名字真的出现在行里」）与 `attach_combat`/`attach_deck`/`make_template`/`deck_view`/`menu_button` 辅助，并按需装的替身统一回收（`_extras`）；既有用例零改名零删除零跳过
- **踩到并记下的两个坑**：① 我一度让 `PauseMenuHandlers` 也声明 `COLOR_STATUS_*` / `CONFIRM_*` 常量——**同文件里重复声明同名常量是解析错误**（和子类重复声明夹具成员同一个坑的另一面），`pause_menu.gd` 于是 `Could not preload resource script`，GUT 报「Nonexistent function 'request_open' in base 'Control'」——症状离病根很远，靠一个临时 `load()` 探针脚本才定位；② 手写 `pause_menu.gd` 时把 `get_deck_host()` 的文档注释换行抄漏，误插了三行游离 `##`，同一探针也能查出
- 全量：**5055 tests / 5055 passing / 3 orphans 存量**，零失败零回归（5037 → 净增 18，全部跑到了——两条新文件逐条出现在 GUT 的 `* test_...` 输出里）
- 已知边界（见下方「遗留」段更新）：① `pause_menu_deck_view.gd` 302 行、`pause_menu.gd` 324 行、`pause_menu_fixture.gd` 336 行仍略超 300 软上限（本轮已把能外移的职责全部外移，剩下的是文档注释与控件路径，再拆会把一处改动摊成三处）；② 卡组查看的「详情」是纯文本，不画卡面（美术资源与本 story 范围外）；③ 投降后玩家落到的战败屏与正常战败同一块，但**战败屏的「返回」按钮当前回探索而非主菜单**——规格里「玩家点击返回 → 回到主菜单」与既有战败出口的语义有出入，未在本轮改动（属战斗 UX 规范域）
- Next recommended: 战败屏「返回」出口语义与规格对齐；`ExplorationSystem`（686 行）与 `main_menu.gd`（520 行）拆分；战斗态入存档（UX 规格 Open Question #1「战斗暂存」仍开放）

## Session Extract — 暂停菜单场景变体与二次确认（2026-11-17）
- 任务：接上一轮留下的三处 §遗留——① 按当前场景决定按钮可见性（战斗中隐藏「保存并退出」），并保证键盘焦点起点跳过隐藏/disabled 的按钮；② 补 GAP-5 的二次确认弹窗（「保存并退出」「返回主菜单」防误触，ESC 可取消、焦点默认落在「取消」）；③ 战斗态不入存档（读档回不到战斗）本轮**不做**，仅确认现状
- **拆出三个新生产文件**（`pause_menu.gd` 347 行、仍在 300 软上限之上——本轮新增职责已尽量外移，剩下的行数主要是既有文档注释）：`pause_menu_layout.gd`（81 行，纯 static 判定：场景→可见性、`first_focusable` 挑焦点起点）、`pause_menu_state.gd`（209 行，变体落地 + 确认编排 + 退出链 + ESC 三层分层）、`pause_menu_confirm.gd`（211 行，确认框本体，纯代码构建，同 `LoadSlotPanel` 口径不用 `AcceptDialog`）
- **可见性口径**（UX 规格 §States & Variants）：战斗 + 渡劫（战斗变体）、商店、事件面板、结算屏、战败屏一律隐藏「保存并退出」；探索/卡组编辑/修炼室显示。**未知场景 ID 按最宽松处理**（显示）——藏掉一个本该可用的按钮比多显示一个更糟，后者由动作层的失败反馈兜底；判定不在本层做存档合法性终审
- **焦点起点跳过不可选按钮**（`PauseMenuLayout.first_focusable`）：判据是「在树内 + `is_visible_in_tree()` + 未 disabled + `focus_mode != FOCUS_NONE`」。用 `is_visible_in_tree` 而非 `visible`——按钮可能在隐藏的父容器里。候选来源是 `Panel/VBox` 的子节点（树序本身就是 UX 规格的焦点顺序，不再抄一份常量数组与 tscn 各自漂移），非 Button 的（HSeparator / 两个 Label）自动跳过
- **读档面板返回时的焦点回锚也走同一条判定**：战斗中硬抓「保存并退出」等于把焦点扔回一个看不见的按钮上（`_on_load_panel_back` → `state.focus_default()`）
- **二次确认**（无障碍 AC）：按下「保存并退出」/「返回主菜单」只弹框、不动作（断言写盘/转场/暂停/锁栈四项均未发生）。确认框变体——保存并退出两键（确认保存 / 取消），返回主菜单三键（确认保存 / 不保存 / 取消）+ 战斗中补一行朱砂红「当前战斗进度将丢失——视为战败」
- **ESC 由两层变三层**（`PauseMenuState.handle_esc`）：确认框 → 读档面板 → 暂停菜单，一次只退一层。确认框的取消（按钮 / ESC）与 ESC 收读档面板后都回锚焦点（框一收起焦点就悬空，键盘玩家会觉得「什么都按不动」）
- **确认框是复用式单例**（同 LoadSlotPanel）：反复开合不叠第二个；`_release_pause()` 里一并收起——留一个「开着」的框在隐藏的菜单里，下次打开会看到它浮在菜单上
- **测试：新增 44 例（4 文件 + 1 共享步骤模块）**——`tests/unit/hud/test_pause_menu_variant.gd`（14 例，纯判定：各场景可见性 + `first_focusable` 各分支）、`tests/integration/hud/test_pause_menu_variant_focus.gd`（11 例，落地：控件 `visible` 与真实 `grab_focus`/`gui_get_focus_owner`）、`tests/integration/hud/test_pause_menu_confirm.gd`（19 例，取消/ESC/确认/三键/分层/复用/清理）、`tests/integration/hud/pause_confirm_step.gd`（共享步骤模块，确认框按钮路径的唯一真理来源——三处共用）
- **既有用例的适配**（零改名零删除零跳过）：`pause_menu_fixture` 的 `MockSceneManager` 加 `scene_id` 字段（缺省 EXPLORATION，可配成 COMBAT 等）、新增 `confirm_dialog()` / `confirm_button()` / `focus_owner()` 辅助；`test_pause_menu_exit.gd` 每个用例在 Act 多走一步确认（保存并退出走 `ConfirmButton`、返回主菜单走 `LeaveButton`——「不保存」才是不显式写盘的那条路，与既有断言口径一致）；`test_pause_menu.gd` 补 `confirm_step()` 与 `ConfirmStep` preload
- **两条被测试抓出来的修正**：① 返回主菜单确认框的「确认保存」是「先存档再离开」，与既有「先自动存档一次再走」的断言口径不同——既有用例该走 `LeaveButton`（`confirm_button` 的缺省仍是 `ConfirmButton`，只有这条路显式传参）；② 取消路径原本什么都不做，导致 `has_focus() == null`——取消后必须回锚焦点
- 全量：**5037 tests / 5037 passing / 3 orphans 存量**，零失败、零回归（4993 → 净增 44，全部跑到了——新增用例逐条出现在 GUT 的 `* test_...` 运行输出里，非只对汇总数字）
- 已知边界（见下方「遗留」段更新）：`pause_menu.gd` 347 行仍超 300 软上限（本轮外移了职责但新增了文档注释）；确认框无 reduce-motion 开关（`PauseMenu.animate` 的开关只作用于模糊 Tween，确认框无动画故不受影响，但将来加动画需接同理的开关）；战斗中「查看卡组」只读模式未实现（本轮只做可见性与确认，只读归 deck-editing-ui epic）
- 遗留（本轮确认现状，未做）：**战斗态不入存档**——`GsmSerializer.serialize()` 明确排除 `battle` / `session` 两域（`NON_PERSISTABLE_DOMAINS`），存档里只有探索/玩家等持久域。故读档回不到战斗中间状态（与 UX 规格 Open Question #1「战斗暂存」一致，仍是 PO 决策项）

## Session Extract — 暂停菜单接上存档读档（2026-11-17）
- 任务：把上一轮写好但没接线的 `pause_menu_actions.gd` 接进 `PauseMenu.tscn` 与 `pause_menu.gd`，补测试，全量零失败后提交；单文件 ≤300 行、不删/不改名既有测试、不 pass_test
- **接入**：tscn 新增「存档」「读档」（树序在「系统设置」之后、分隔线之前——与 UX 规格的键盘焦点顺序一致）与 `StatusLabel` 反馈行（排在进度行之后）；面板高度 380 → 560（`offset_top/bottom` ±280）。按钮走场景 `[connection]`，测试从 tscn 出发按真实 `pressed` 信号断言
- **`pause_menu.gd` 299 行**：删掉自己那份存档/进度实现，改为委托动作层；新增 `_on_save_pressed` / `_on_load_pressed` / `_on_load_slot_chosen` / `_on_load_panel_back` 四条路由 + 反馈行着色（成功松石青 #4A9494 / 失败朱砂红 #B3424A，与通知区域 green 档同源）；`_release_pause()` 收拢「关闭菜单」与「转场前离开」两条对称路径（Tween 清理只此一处）
- **动作层扩接口**：`request_main_menu`（先自动存档一次再转场）与 `navigate_main_menu`（纯转场出口，供「保存并退出」复用）——两条路都不重复写第二遍盘（「保存并退出」刚写过、「返回主菜单」的 auto_save 已跑过）
- **读档两层语义**：面板开着时 ESC 先收面板（取消选槽）不关菜单；选中一格后**成功才解除暂停**——动作层在能续玩时已发出转场请求，而转场管线不含暂停恢复职责，冻结态下新场景会停在冻结帧
- **🔴 修掉一处真缺陷（本轮最重要的发现）**：`InputManager._on_tree_changed` 对 `SceneTree.tree_changed` 挂的「场景切换就清锁」安全网**分不清「换场景」与「同一场景里插了个子节点」**，而暂停期间必然有树变（本菜单自己插读档面板、通知区域弹 Toast）。锁一没，「暂停中屏蔽下层输入」与 `_unhandled_input` 的 ESC owner-check **同时失效**——ESC 被 InputManager 吃掉并走到幂等分支，**玩家被卡在一个关不掉的菜单里**。修法：`PauseMenu` 也订阅 `tree_changed`，树一变就认领回自己的 MODAL 锁（**仅当栈空**——不抢别人的模态；Autoload 的 `_ready` 先于场景节点，故顺序确定、栈深恒回 1 不累积）。前后对比用探针实测：修前点「读档」后 `has_lock=false`、ESC 后 `menu_visible=true`（关不掉）；修后锁在、ESC 分两层正常退出
- **测试：48 例新用例（5 文件 + 1 装置）**——`pause_menu_fixture.gd`（193 行，直挂 `PauseMenu.tscn` 而非 `HUD.tscn`：测的是菜单自己那条链，整棵 HUD 会把「菜单的错」和「HUD 的错」混在一起）+ `test_pause_menu_save.gd`（11）`test_pause_menu_load.gd`（10）`test_pause_menu_input_lock.gd`（13）`test_pause_menu_exit.gd`（7）`test_pause_menu_buttons.gd`（7）
- **踩到并记下的两个坑**：① **子类重复声明同名成员是解析错误**——用例里写 `const SLS := preload(...)` 而夹具也有，GUT 会 `Ignoring script … because it does not extend GutTest` **静默跳过整个文件**（第一轮全量里三个文件共 39 例根本没跑，总数却是绿的）；② **`pressed.emit()` 对 `disabled` 的 Button 也会触发**（引擎只在鼠标派发时判禁用），所以「空槽位点了没反应」只能断言「按钮 disabled + 焦点起点跳过它」，不能靠 emit 复现
- **`hud.gd`**：把 `GameStateManager` 也注入暂停菜单（存档载荷与进度行都由它现取，测试可直连替换）
- **`design/ux/pause-menu.md`** 同步：7 按钮（含两个新按钮的形态与结果）/ 操作反馈区 / 面板 320×560 / ASCII 图 / 键盘焦点顺序 / 退出点表（新增「读档面板」一行 + 「存档 vs 保存并退出 vs 返回主菜单 vs 读档」四者区分）/ 数据依赖表（存档多处触发、新增读档行）/ 3 条新 AC；GAP-5 的二次确认弹窗仍按 story 从简未实现（与本轮无关的既有偏离）
- 全量：**4993 tests / 4993 passing / 3 orphans 存量**，零失败、零回归（4945 → 净增 48，全部跑到了——第一轮那 39 例被静默跳过时总数 4960 也是绿的，这正是「绿不等于跑到了」的样本）
- 已知边界：① 按钮可见性按场景变体调整（战斗中隐藏「保存并退出」等）**未实现**——UX 规格 §States & Variants 要求，属存量；② GAP-5 的二次确认弹窗（「保存并退出」/「返回主菜单」的防误触）仍未实现，与本轮读档路径无交集；③ 读档把世界重置到某一格时**战斗态不还原**（`battle` 域不入存档，UX 规格 Open Question #1 的「战斗暂存」仍开放）；④ `test_hud_bootstrap` 的 `test_main_menu_does_not_auto_mount_when_not_current_scene` 在**目录级隔离跑时红、全量跑绿**（存量，stash 后跑 HEAD 同样红，与本轮改动域零交集）；⑤ 动作层仍有一层 `get_actions()` 每次透传注入引用（一条即断，不缓存句柄——代价是四次赋值，换的是不会持有过期引用）
- Next recommended: 按 UX 规格补场景变体的按钮可见性（战斗中隐藏「保存并退出」/「查看卡组」转只读）；二次确认弹窗（防误触是无障碍 AC）；`src/ui/main_menu/main_menu.gd`（520 行）仍超 300 软上限

## Session Extract — 行动力消耗闭环（2026-11-14）
- 任务：① 审计行动力现状（存哪、谁读写、各动作有无扣减）；② 节点间移动按**地图配置**扣 AP，不足时拒绝并给中文提示「行动力不足」（不静默失败）；③ 灵泉回复与上限夹取一致，不出现 AP 超上限；④ 单测/集成覆盖正常扣减、不足拒绝且不扣、回复夹上限；⑤ 单文件 ≤300 行；⑥ 全量零失败后提交
- **审计结论**：AP 存在 `GSM.exploration.action_points` + `max_action_points`（持久化域，序列化默认 0）。**读**：`move_to_node` / `can_move_to` / `teleport_to_node`（仅透传 `ap_remaining`）/ `use_action_spring` / `node_graph_load_source`（`enter_map` 的 max_ap 取自 `RealmSystem.get_realm_property(realm,"action_points")`，L1=5…L5=13）/ HUD 两处。**写**：`move_to_node`（唯一扣减路径，走 `set_exploration_ap`）、`enter_map`（重置为上限）、`ExplorationActionSpring`（回复，已夹上限）、`GSMAtomicWrites.restore_action_points`（事件 RESTORE_AP）。**各动作**：移动扣分（本轮起按配置）；战斗不扣（AP 是探索域资源，战斗消耗走 `CostSystem` 灵力，`combat_bag_use.gd` 注释已明示）；采集/炼丹/炼器/回复/商店/打坐**不再单独扣**（到达时已由 `move_to_node` 付过）；传送/Boss/灵泉开销恒 0
- **发现并修掉的两处存量不一致**：① `move_to_node` 与 `can_move_to` 各写一遍「`ap_cost=1` + `AP_EXEMPT_TYPES.has(type)`」——配置化后必然漂移（查询说能走、扣费扣不起）；② `restore_action_points` 只加不夹，与 GDD `action-point-system.md` §8 边界「使用丹药回复超过上限：取 `min(current+amount, max_action_points)`，不溢出」相悖——不夹会让 AP 顶到 5/5 之上仍持有 9 点，而灵泉按「上限 − 当前」算出的回复量变成 0（界面显示已满，实际还能多花 4 点）
- **新文件 `exploration_ap_rules.gd`（52 行）**：AP 开销解析的**单一来源**（纯静态函数，无 Autoload）。配置键 `ap_cost`（本图默认，缺键→GDD 默认 1）/ `ap_costs`（按 NodeType 覆盖表）；**豁免先判**（3=BOSS/6=TELEPORT/7=ACTION_SPRING 恒 0，配置写非零也不生效——豁免是系统级不变量，不是地图可调项）；负值按默认值处理而非 0（配置是外部数据，负开销会让移动「回血」）。`ExplorationSystemHelpers.AP_EXEMPT_TYPES` 改为**派生**自它，`ap_cost_to(node_id)` 由 `move_to_node`（扣费）与 `can_move_to`（判定）共同转发——两处同口径
- **越界存档值顺带收口**：`move_to_node` / `can_move_to` 先 `maxi(ap, 0)` 再比较，`new_ap = maxi(ap - cost, 0)`——负数存档不再让豁免节点被锁死，AP 永不落负；拒绝路径**零写入**（不扣 AP、不写 position/visited、不发 `node_moved`）
- **`restore_action_points` 迁到探索域**（`gsm_atomic_writes.gd` → `gsm_exploration_writes.gd`）：它与 `set_exploration_ap` 同写一个域，散在两处无谓；`GSMAtomicWrites` 保留同名转发（外部调用点一字未改）。**上限为 0 时不夹**——0 表示「尚未进入任何地图、上限未知」（序列化出厂值），此时按原值累加，不臆造上限把恢复吞掉
- **配置落库**：`exploration_map_catalog.gd` 的 4 条 `DIFFICULTY_DEFAULTS` 与 `exploration_system_helpers.gd` 的 4 条 `DIFFICULTY_CONFIGS` 都补了 `ap_cost: 1`（出厂全档 1，GDD §调优参数「每格消耗 1，安全范围 1-2」）；键存在的意义是「按地图配置扣」读的是配置而不是硬编码，单张地图可覆盖
- 测试：新增 `test_exploration_ap_rules.gd`（149 行，13 例——配置解析各分支 / 负值回落 / 畸形配置不崩 / 豁免压制覆盖 / **三层豁免集合同源断言** Feature `ApRules` ≡ 继承链 ≡ UI `NodeStateLogic` / 探明表与难度表 `ap_cost` 两处同源）+ `test_action_point_consumption.gd`（300 行，24 例——正常扣减三档配置 / 不足拒绝且**零写入** / `can_move_to` 与扣费同口径 / 豁免 / 负数存档 / 灵泉夹上限 / **系统 reason 必须命中 UI `REASON_TEXTS` 键**）；`test_second_layer_methods.gd` 补 4 例夹上限边缘；`test_apply_outcomes.gd` 补 1 例事件 RESTORE_AP 夹上限、并在 `_reset_gsm_state` 把 `max_action_points` 一并归零（不回零会让该文件依赖前一个测试文件留下的上限——违反隔离性）。既有测试零改名零删除零跳过
- 全量：**4630 tests / 4629 passing / 1 pending 存量 / 3 orphans 存量，零失败**；stash 本轮改动跑 HEAD 基线 4592/4591——净增 38 全过，零回归
- 已知边界：① `test_hud_bootstrap` 的 `test_main_menu_does_not_auto_mount_when_not_current_scene` 在**目录级**隔离跑时红（全量跑绿）——stash 后跑 HEAD 同样红，**存量**，与本轮改动域零交集；② 灵泉 DAG 权重表不含 `action_spring` 键，生产路径刷不出灵泉节点，「每图限 1 次」计数位仍缺（存量）；③ `can_move_to` 仍是三态混叠布尔（可达/已访问/AP 不足都 false），UI 六态由 `NodeStateLogic` 自行推导，若将来要「点击即知为何不可走」需系统侧返回 reason
- Next recommended: 灵泉节点接入 DAG 权重表（连带「每图限 1 次」计数落 `map_states`）；丹药回复 AP 的入口（`InventoryPillUse` 目前只处理治疗类效果，RESTORE_AP 类丹药走不通）；AP 上限随境界突破重算并在 HUD 提示

## Session Extract — 战斗内使用丹药与法宝（行囊面板）（2026-11-14）
- 任务：① 战斗界面加「行囊」入口（回合内可开，列真实收藏里的丹药与法宝，打开冻结出牌输入、关闭解冻）；② 用丹药按模板效果走既有结算层（治疗/减益），扣掉该卡实例、按既有规则计费（走 `CostSystem` 扣灵力，不新增「行动点」）、给中文提示、目标可显式选择；③ 法宝同理走攻击/增益；不可用条目禁用并写明原因（已用尽/灵能不足）；④ 测试覆盖五条点名断言
- **五处新生产文件（结算链，`src/feature/combat/`）**：`combat_bag_rules.gd`（158，判据与中文文案**单点**——`reason_for` 六道门的裁词、`row_text` 行文案、`effect_text` 效果措辞）、`combat_bag_entries.gd`（268，对**真实收藏**的只读投影：条目字段 + 判据结论 + 候选池 `targets(is_pill)`）、`combat_bag_effect.gd`（128，落效果半边：丹药逐人 `CombatDamageSettlement.apply_heal`、法宝逐人 `CombatRosterState.apply_bonus`）、`combat_bag_use.gd`（263，结算层六道门 + 扣实物 + 扣灵力）、`combat_bag_host.gd`（158，编排：按钮 → 面板 → 结算 → 回填）
- **四处新 UI 文件（`src/ui/combat/bag/`）**：`combat_bag_button.gd`（72，入口按钮位，仅阶段 2 可见——与「结束出牌」同生共死）、`combat_bag_layout.gd`（131，复用商店骨架 + 目标栏 + 可灰显行）、`combat_bag_targets.gd`（137，候选池/下标/全体判定）、`combat_bag_screen.gd`（298，面板本体）、`combat_bag_readout.gd`（112，读数层）
- **装配两处**：`combat_scene_bag.gd`（87，装配行囊依赖链，Autoload 查表集中在一处）、`combat_bag_mount.gd`（72，`class_name` 独立类——行囊依赖要等场景挂载注入完才能建，生命周期与其余七组不同）；`combat_scene_mounting.gd` 的 `wire_all` 加第七组 `wire_bag`，**行囊最后挂**（面板要盖住手牌区与出牌输入层）
- **冻结走交互层的普通字段，不走 `InputManager` 的锁**：`InputManager._on_tree_changed` 会在每次 `tree_changed` 时**清空整个锁栈**，而面板入树即触发——同帧 push 的锁立刻被抹掉（实测 `is_input_allowed` 仍返回 true，面板开着照样点穿）。改用 `CombatSceneInteraction.set_enabled` → `CombatLayoutInteractionMount` → `CombatInputLayer`，本面板在宿主 `open()` / `close()` 里开关
- **退订必须先关再置空手柄**：`CombatBagHost.unbind` 把 `_set_input` 清空后**再也解不了冻**；若退场时面板还开着，输入层会带着「停用」状态活到下一次进战斗（输入层挂在常驻 Autoload 的同一条链路上），表现为「进了战斗却点不动牌」。故 `unbind` 第一句是 `close()`（未打开时是一次幂等的解冻）
- **不新增「行动点」**：计费走既有 `CostSystem`（`can_afford` / `spend`），与出牌同一本灵力账（集成用例断言「用药扣的与出牌扣的是同一本账」）；用药**不推进阶段也不推进回合**（阶段/回合由战斗系统既有节奏驱动，本链路连它们的句柄都没有）
- **法宝属性增益建了新存储 `combat_stat_bonus.gd`（61）**：与既有 debuff **刻意分家**（debuff 拒绝非正数、按回合过期；增益相反——合成一处会让 `amount` 的符号承担两种含义）。`CombatRosterState` 新增 `_bonus` 字段，读侧在 `get_atk` / `get_defense` 里叠加，外部取数口径一字未改
- **顺手拆 `CombatRosterState`（278→…）与 `InventoryScreensHost`（305→279）**：前者把「名册 → 状态表」的建表半边拆成 `combat_roster_seeding.gd`（149），敌方 ID 编码约定与 `enemy_id_of` 仍由 `CombatRosterState` **转发**同一实现（外部既有引用点一字未改）；后者把输入锁的申请/释放/兜底拆成 `inventory_input_lock.gd`（82），`input_manager` 字段改成背后字段 + setter 转发（生产路径在 `_init` 之后才赋值，只认构造那一刻的注入会让锁永远拿不到管理器）
- **`CombatBagScreen` 从 303 降回 298**：读数层 `combat_bag_readout.gd` 收走「行数/行文本/禁用态/游标/目标栏」这族只读结论（读的是控件本身，不是第二份缓存，读数因此不可能与渲染分叉）
- **两处真 bug（都是测试抓出来的）**：① `outcome.get("stat_changes", {})` —— `EffectEvaluation` 是 Resource/Object，`Object.get()` **只接受 1 个参数**，带默认值的写法会让整个脚本**解析失败**（同一错误也在 `combat_bag_entries` / `combat_bag_effect` 各一处）；② `CombatBagScreen._build_layout` 原本又连了一次「返回」按钮到 `_request_close`，而布局已经把 `&"closed"` 交给骨架转发——`closed` 发两次，宿主开关两次（面板开了又立刻关）
- **集成装置的真坑**：`CostSystem` 是常驻 Autoload，`cost_changed` 会在下一场战斗的 `init_for_battle` 时发射；夹具**不退订**就会让上一轮已 free 的场景句柄被回调到——表现为**别的测试文件**里报 `Cannot call method 'get' on a previously freed instance`（`test_combat_click_play_end_to_end` 被连带判红）。`teardown` 里 `bag.unbind()` → `interaction.unbind()` 必须在 `_host.free()` 之前
- **另一处工程细节**：新 `class_name` 后必须跑一次 `godot --headless --import` 刷新 `.godot/global_script_class_cache.cfg`，否则测试脚本里 `as CombatBagButton` 之类的类型标注会报 `Could not find type ... in the current scope`
- 测试：新增单元 `tests/unit/combat_bag/`（5 文件 92 例：判据各分支 / 条目投影 / 结算六道门与拒绝路径 / 面板渲染与游标 / 宿主冻结与回填）+ 集成 `tests/integration/combat_ui/test_combat_bag_battle_flow.gd`（20 例，真实战斗 + 真实存档 + 真实面板：打开冻结/关闭解冻/面板排在输入层之后/用药回血且实例减少/法宝加攻不动 HP/灵力不足灰显且不扣费/用完回合照常推进/空行囊空态/入口随真实阶段信号显隐）；装置 `combat_bag_fixture.gd`（190，桩存档+桩费用+**真跑**状态表与落库）与 `combat_bag_battle_fixture.gd`（273，真实 `CombatRoot.tscn` + 独立战斗系统实例 + GSM 三域快照还原）。既有测试零改名零删除
- 全量：**4592 tests / 4591 passing / 1 pending 存量 / 3 orphans 存量**，零失败；stash 本轮改动跑 HEAD 基线为 4482/4481（同 1 pending、同 3 orphans）——净增 110 全过，零回归（其中 `src/` 侧无一条既有测试改名/删除/跳过）
- **全量里唯一飘的一条**：`tests/unit/formation_system/test_aura_bonus_query.gd` 的两条性能用例（`get_aura_bonus ×1000 < 20ms`）在机器负载高时实测 22ms 而判红——隔离跑 20/20 全过、HEAD 基线全量也全过，与本轮改动域零交集（formation 系统一行未碰）。属**存量脆弱用例**（绝对毫秒阈值 + 无预热），已在「遗留」段记录
- 已知边界：① 用法宝不选目标时取「ID 升序首个存活者」，与丹药同口径（无出手目标 UI 时的既有先例）；② 增量为 0 的歪模板会「消耗了但没生效」——`consumed` 为真而 `ok` 为假，面板据此仍刷新（如实报「未能加身」，不吞掉实物也不谎报成功）；③ 行囊条目**按模板合并成一行**（同名多张显示 ×N），用掉的是实例列表里的第一张——玩家无法在面板上挑「用哪一张」（同模板实例目前无差异字段）；④ 行囊只在**出牌阶段**可见可开（其余阶段玩家没有可支配的灵力，开一个不能用的面板只会让人以为坏了）；⑤ `CombatBottombar` 的 `bag_button` 宽度在极窄窗口下会被压（有上限保护，无实测分辨率核对）
- Next recommended: 行囊与背包两界的实机键盘/手柄核对（`ui_*` 已覆盖，无实机验证）；`CombatSystem`（1689 行）与 `combat_roster_state` 的进一步拆分；法宝的「选哪一张实例」若将来实例间有差异（强化/词条）需补选择 UI

## Session Extract — 背包与角色状态界面的可操作性（2026-11-14）
- 任务：把上一轮的只读两界面变成能用的——① 背包条目可聚焦（上下选行、行内高亮、切分类游标回首行、点条目不崩）；② 丹药在背包里直接使用（读模板效果走既有结算层），用掉数量减一；非丹药给中文提示；③ 角色状态页选中角色行、确认看模板详情摘要（名称/类型/攻击/灵能…），不可出战的也能看且标注；④ 测试覆盖以上四点
- **三处新生产文件**：`inventory_pill_use.gd`（286，用丹药结算）、`character_roster.gd`（103，角色名册读取 + 详情投影，从 model 拆出以回 300 内）、`paged_panel_navigator.gd`（82，两面板共用的「左右切页 + 上下选行」输入翻译，此前两处逐字重复）
- **丹药效果不新造规则**：治疗量经 `CardEffectEvaluator.evaluate_effects(template, 0, GameStateSnapshot.new({}))` 取 `healing`（读 `effects` 列表或扁平 `effect_type`/`effect_value`，两种卡都吃）；写血经 `CombatHpCarryover.read_all`/`write_back`（该模块自述为 `player.character_hp` 唯一读侧，内部走 GSM 第二层原子写）；消耗经 `GSM.remove_card_from_collection`。**本模块一个数值都没写死**
- **目标选择是「解释既有字段」而非新规则**：`target_type == all_allies` 治全队可治者，其余治首个需要的人（角色 ID 升序）——依据是既有先例 `CombatCasterRules.resolve_caster`（无目标选择 UI 时按标识升序取首个，出手 UI 落地后换成显式传入，已写进类文档）
- **「谁需要治」的口径与回复点一致**：账本里无记录 ≠ 零血（那是从没受伤），阵亡（`current_hp <= 0`）不治也不复活（复活归 `DeploymentSystem.revive_character`），满血无缺口不治。三条都跳过
- **失败不半完成**：先写血再取丹；取丹失败按账本原值回滚血量。反过来（先取丹）一旦写入失败就找不回那枚丹——丹药是有限资源，宁可丢一次回血也不凭空吞玩家物品。同理写血不可用（`write_back` 返回 -1）时根本不碰收藏
- **实测抓到一个真 bug**：`_healed_total` 原实现内部再调一次 `read_all` 拿「写前」原值——但 `write_back` 是**就地生效**的，写完再读拿到的已是新值，「新减旧」恒为 0，界面永远报「回复 0 点生命」（集成用例只断言了血量与数量，是单元用例的 `healed` 断言抓出来的）。改为由调用方把**写前**那份账本传进去，并在函数文档里写明原因
- **行控件从 Label 改成 Button**：`ShopPanelNavigator` 只认 `Button.disabled` 判可选性，Label 行一律被跳过（上轮「游标恒为 -1」的成因）。改 Button 后键盘上下可选中、焦点环随焦点绘制、鼠标可点（`pressed` 与游标确认走同一个 `_activate_row` 出口——只接键盘等于给鼠标玩家一个点了没反应的按钮）
- **条目载荷挂在行控件元数据上**（`set_meta`），不维护「下标 → 条目」的第二份副本（刷新会换一批控件，副本必然错位）。角色状态页的详情同理：`detail_box` 独立在列表外（把它挤进列表会改变行数与游标下标）
- **两面板共用同一套布局骨架**：`inventory_panel_layout` 新增 `add_rows`（有载荷 → Button / 无载荷 → Label，判据只此一处）、`fill_detail`、`clear_box`（先 `remove_child` 再 `queue_free`——只 queue_free 的话同帧内 `get_child_count` 仍数得到它，「刷新后行数」断言会看到上一批行）
- **结算在宿主不在面板**：面板只发 `item_use_requested`，`InventoryScreensHost._on_item_use_requested` 调结算层后回填文案（`consumed` 为真才 `refresh`——无谓刷新会把游标弹回首行）。与商店「面板发意图、Presenter 调系统」同源。主菜单装配点同时接上 `pill_use`（漏接不报错、只会静默失效，已加回归用例钉住）
- **测试**：新增 4 个文件 —— 单元 `test_inventory_pill_use.gd`（11 例数值/目标/消耗回滚）+ `test_inventory_pill_use_refusal.gd`（9 例拒绝路径与文案）+ 集成 `test_inventory_item_use_flow.gd`（12 例游标/用丹/非丹提示/空列表）+ `test_character_detail_flow.gd`（10 例详情字段与模板一致、切小节收起、空名册不崩）；新增装置 `inventory_pill_use_fixture.gd`（全桩，`evaluate_effects` 真跑）；主菜单入口 +1 例接线回归。既有测试零改名零删除
- 全量：**4482 tests / 4481 passing / 1 pending 存量 / 3 orphans 存量**，零失败；stash 本轮改动跑 HEAD 基线为 4442/4441（同 1 pending、同 3 orphans）——净增 40 全过，零回归
- 已知边界：① 丹药目标选择是「升序取首个」（无出手 UI，见上）；② 「永久 +1 最大生命」类丹药（九转金丹）效果未建模，界面如实说「效用尚未参透」而不是给 0 点回血；③ 背包详情区目前恒空（骨架已就位，本轮没有「查看法宝说明」的需求）；④ 角色属性只到模板基础值，未叠功法/法宝/本命加成；⑤ 防御力仍无数据来源（`CardTemplate` 无 `base_defense`），界面不显示也不冒充
- Next recommended: 两界面的手柄适配核对（`ui_*` 动作已覆盖，但无手柄实机验证）；战斗内快捷入口（GDD 写明丹药可在战斗中或背包使用，本轮只做了背包侧）；`InventoryScreensHost`（305 行，已略超 300 软上限）拆分

## Session Extract — 背包与角色状态界面最小可用版（2026-11-14）
- 任务：主菜单可打开「背包（灵材/丹药/法宝，读真实存档不硬编码，数量为 0 不显示）+ 角色状态（境界/修为与上限/生命与上限/各属性按境界配置表算/阵亡标记）」两个界面，有返回、方向键切分类、空态给中文；测试覆盖分类过滤与排序、数值与境界配置一致、阵亡标记、空态文案、返回不掉状态
- **读取层放 `src/feature/inventory/`（3 个文件）**，面板只显示——与商店（`ExplorationShop` 结算 / `ShopPanelScreen` 显示）同源分工。`InventoryModel`（236）两条数据源：灵材读 `player.resources.ling_cai` 四档计数、丹药/法宝读 `collection.owned_cards` 按 `CardTemplate.type` 过滤 + 按 `template_id` 合并同名（×N）。`CharacterStatusModel`（300）三块：境界读 GSM 既有字段、属性**逐键遍历 `realm_table` 当前档**（表里加键界面自动多行，一个数值都不写死）、角色走 `DeployRosterReader` + `CombatHpCarryover.read_all` + `DeploymentSystem.get_unavailable_characters`
- **`InventoryCatalog`（147）是分类表 / 排序 / 中文词条 / 空态文案的单点**：三分类三条空态各指向不同下一步（「去灵脉采掘处采些回来」/「丹成之后自会出现在这里」/「炼器台上炼成一件便有了」）
- **灵材不借卡牌稀有度词条**：`rarity` 只作排序刻度（下品 1 → 极品 4），`rarity_name` 留空——「极品/下品」与卡牌的「金/暗金」是两套刻度，混用会让玩家以为灵材也有暗金档；布局把空段过滤掉，行文案即「极品灵材 · ×2」
- **阵亡角色照实列出**（不隐藏，GDD combat-system.md §7 要求跨场持久），带中文标「已阵亡（不可出战）」；`current_hp` 为 0 就显示 0（**不夹到 1 冒充存活**，与 `CombatHpCarryover` 口径一致）。生命无账本记录时回退模板 `base_hp` 并把 `hp_known` 标 false，界面加注「（生命为模板基准）」——让「满血」与「没数据」可区分
- **已登记的缺口：防御力无数据来源**——境界表没有防御项，`CardTemplate` 也没有 `base_defense`（该字段只存在于敌方 `EnemyTemplate`）。界面**不显示防御，也不拿 `max_deploy` 之类冒充**。另两条边界：灵能只到上限（`cost_per_turn`），战斗内当前灵能属战斗域；角色属性只到模板基础值，未叠功法/法宝/本命加成
- **UI 层 5 个文件全部 ≤300**：`inventory_panel_layout`（123，复用 `ShopPanelLayout` 骨架，只多加一条分类栏）、`inventory_screen`（269）、`character_status_rows`（95，纯文案组装——拆出来正是为了把面板压回 300 内）、`character_status_screen`（281）、`inventory_screens_host`（268，页签 + 输入锁 + 两页生命周期）
- **本轮修掉两个静默失效（都不是新写的 bug，是复用既有骨架时暴露的）**：
  ① `ShopPanelLayout.build` 的「离开」按钮**写死转发 `&"leave_requested"`**——对声明 `&"back_requested"` 的面板，`emit_signal` 不报编译错、只在运行时抛 `ERR_UNAVAILABLE`：按钮看着能点、点了没反应。改为 `p_leave_signal` 参数（默认值保持商店不变）
  ② `build()` 返回值加了 `panel` 键——原先调用方要 `item_box.get_parent().get_parent()` 才够到 `PanelContainer`，而真实层级是 `item_box → scroll → column → margin → panel`（**四层，看着像两层**），数错就是 `VBoxContainer` 赋给 `PanelContainer` 的类型错。交出引用比让调用方猜层级稳
- **删掉两个多余信号** `category_cycle_requested` / `section_cycle_requested`：分类栏的点击意图在面板内部闭环，没有任何外部消费者——原先布局发信号、面板再 connect，等于把同一条路走两遍。改为布局把按钮原样交回、面板自己 `connect`（分类栏的接线因此从 `_init` 移进 `_build_layout`）
- **两处「顺序问题」的防御**（都是「测试先赋字段后建页」掩盖了「生产先建页后赋字段」）：
  ① `InventoryScreensHost` 的模型注入改为**每次 `show_page` 都补一次**——主菜单先 `new` 宿主再赋 `inventory_model`/`status_model`，而建页发生在宿主 `_init` 里（那时字段还是 null）。只认建页时刻的注入会让**生产路径整页走「链路未就绪」降级分支，而测试全绿**
  ② `CharacterStatusModel` 对 `deployment_system` / `binding_manager` 加 **Autoload 回落**——名册读取器要 `DeploymentSystem`，若只认注入，漏接时**全部角色都显示「可出战」且不报任何错**。专门有一条集成用例 `test_dead_marking_works_with_production_wiring` 按主菜单的接线方式钉住它
- **`_release_lock` 先查 `has_lock` 再 pop**：`InputManager` 连接了 `SceneTree.tree_changed` 并在回调里清空整个锁栈，而本界面每次 refresh 增删行都会触发一次 `tree_changed`——锁可能已被外部清掉，此时再 pop 只得到一条「source not found」的 push_warning 噪声
- **测试装置的坑（已就地修）**：`give_card` 原先不 prime 模板，模板未就位时 `create_instance` 返回 null、卡根本进不了收藏（界面随后少一行，断言却分不清「界面漏读」还是「卡没造出来」）——改为就地 `prime_templates`；`ARTIFACT_ID_2`（上品法器）漏进 `_card_template_database` 导致 `add_card_to_collection` 被校验拒绝；**`DeploymentSystem._unavailable_characters` 不随 GSM 域还原**（它是 Autoload 私有字段），上一个用例标过的角色会漏到下一个用例，「只标阵亡那一个」这类断言因此看到多余标记——装置 `_reset_player_domains` 里加 `load_unavailable_from_gsm({})` 清空
- 测试：单元 58 例（拆 5 文件 + 2 装置）、集成 23 例（真实 Autoload + 真实存档端到端，拆 2 文件 + 1 装置）、主菜单入口 6 例（`test_inventory_entry.gd`：按钮在/文案/接线/键盘可达/点开/复用单例/关掉后主菜单仍可用）。全部文件 ≤300 行
- 全量：**4442 tests / 4441 passing / 1 pending 存量 / 3 orphans 存量**，零失败、零回归（基线 4355/4354 → 净增 87 全过）
- 遗留：① 两界面均为**只读**，条目不进详情页、不可用/不可丢弃（本轮任务书即「最小可用版」）；② `ShopPanelNavigator` 在两个面板里游标恒为 -1（条目是 Label 不是 Button）——这是如实结果，但意味着**上下键无用**，若后续要选条目需换控件；③ 手柄适配未验证（只走键盘 `ui_left`/`ui_right`/`ui_accept` 默认映射）；④ 背包分类目前只有灵材/丹药/法宝三类，功法/阵法/符箓（`CardType` 1/3/5）已有 `_type_name` 词条但未开分类
- Next recommended: 两界面的手柄适配；从战斗/探索内也能开背包（目前只在主菜单）；`ShopPanelLayout` 已被三个布局复用（商店/采集/背包）——若再加一处应改名为中性名

## Session Extract — 打坐/洞府境界突破与修为消费（2026-11-14）
- 任务：① 打坐/洞府节点——到达后可用当前修为尝试突破下一境界（读既有境界配置表、不硬编码等级与所需修为），成功率与加成按配置算、随机源可注入；② 成功扣修为 + 升境界 + 属性按配置重算并落盘 + 中文提示；失败按配置扣部分修为、境界不变、提示写清损失；任何情况下修为不落负；③ 测试覆盖成功扣费升境界且属性变化 / 修为不足拒绝且状态不变 / 失败按配置扣费不升境界 / 修为不被扣成负 / 同种子同结果
- **「不硬编码所需修为」与「既有表 12 键被锁死」的冲突（本轮核心决策）**：`realm_table` 每境界恰好 12 个键，被 `test_realm_table_query.gd::test_ac002_realm_table_has_five_realms_ten_properties` 逐字锁定 → **无法往表里加突破键**。解法是拆两张表：所需修为 / 境界名 / 最高境界数从 `RealmSystem.realm_table` **读**（`ExplorationBreakthroughTable.required_cultivation/realm_name/max_realm`），只有成功率与失败惩罚比例放进新表 `SUCCESS_RATE_BY_REALM` / `FAILURE_PENALTY_RATIO_BY_REALM` ——既有 12 键一字未动，零测试破坏；「加成」同样是既有表的查询值（`get_realm_property`），突破后自动生效
- **已登记的设计缺口**：GDD `cultivation-system.md` §边界/§调优参数只写「突破失败修为损失 10%」，**没有**无渡劫打坐突破的成功率规格；`exploration-system.md` §节点类型一览也没有打坐/洞府类型。按项目既有处置方式（`LING_CAI_CAP = 99` / `COLLECTION_CAP = 300` 同源）取一组可测默认值并显式登记在表文件文档：`SUCCESS_RATE_BY_REALM = [0.90, 0.80, 0.70, 0.60, 0.0]`（逐级递减，末档占位 0.0）、`FAILURE_PENALTY_RATIO_BY_REALM = [0.10 × 4, 0.0]`（**刻意不等于**渡劫撤退的 15%——两者是不同事件）。策划定档后只改这一个文件
- **惩罚基数取 `max_cultivation` 而非当前修为**（与 `TribulationSettlement.handle_failure` 同口径）：以当前修为为基数会让「压着修为不攒满」变成省钱策略，惩罚失去意义
- **修为写入沿用渡劫先例，不新开 GSM 第二层 API**：GSM 既有的修为写入口（`add_cultivation` / `restore_action_points`）**全是只增不减**；扣修为的既有先例是 `tribulation_settlement.gd` 的直接写 `player.cultivation` + `_buffer_change("player.cultivation", old, new)`。`ExplorationBreakthrough._write_cultivation` 照此办理，并用 `maxi(..., 0)` 保证**永不落负**；所有拒绝路径（境界已满 / 修为不足 / 配置缺失 / 系统不可用）**全在任何写入之前**返回，且 `rolled = false`（据此与「掷骰失败」区分）
- **属性重算走既有单写者链，不另开第二条通路**：`RealmSystem.realm_up(old)` → `GSM.change_realm` → `realm_changed`（Cat 1，帧末）→ `CultivationSystem.update_max_cultivation`（`BASE_MAX × 1.5^(L-1)`）+ `settle_overflow`。本模块**不自己算 max_cultivation**；`attributes_of(L)` 只是对 `get_realm_property` 做快照供 UI/测试断言「属性按配置重算」
- **半成品防护**：`realm_up` 通道不可用（或调用后 GSM 境界未变）时把已扣的修为**原样退回**，不留「扣了修为没升境界」——同商店「卡没到就把灵石退回」口径
- **可重复尝试**：本节点不记「本节点已用过」——失败后修为还够就能再冲（这正是失败惩罚存在的意义；对比采集点的「同槽位只此一次」）
- **新增 Feature 层三件**：`exploration_breakthrough_table.gd`（142，配置读取面 + 全部中文文案单点）、`exploration_breakthrough_status.gd`（200，只读半边——status / attributes_of / 结果形状 / 系统接入 / RNG 实例）、`exploration_breakthrough.gd`（160，写半边——校验→掷骰→扣修为→升境界）。`exploration_system_forward.gd` 加 `breakthrough_status` / `attempt_breakthrough` / `breakthrough_attributes` 三个转发（拆出两半正是为了守 300 行）
- **随机源可注入**：`var rng: RandomNumberGenerator` 注入优先（测试固定种子 → 同种子同结果），否则 `rng_instance()` 自建 + `randomize()`（生产）。Autoload 侧入口 `ExplorationSystem.breakthrough_rng`——**须在首次 `attempt_breakthrough` 之前注入**（子模块首次取用时读取一次）
- **节点类型新增**：`NodeType.MEDITATION = 13`；权重表三处同源加 `"meditation": 6`（`exploration_system_helpers.gd` 的 4 个 `DIFFICULTY_CONFIGS` + `exploration_map_catalog.gd` 的 `_difficulty_defaults` + `exploration_dag_builder.gd` 回退字面量）+ `_string_to_node_type` 映射 + `exploration_dag_content.gd` 的 `"洞府"` 标签。**副作用**（与前两轮同源）：新键改变 `_weighted_random` 的 total → 所有种子 DAG 重排；既有断言只锁区间/上限，全量跑完无 DAG 测试红
- **图标图集**：`node_icon_atlas.gd` 的 `ATLAS_COLS` 13 → 14，新增类型 13（`label: 洞府`、`color: #5E7C8B`、`glyph: cave`）+ `_glyph_pixel` 的拱形洞口分支（上半圆拱顶 + 两侧壁，内腔留白 → 与采集点叶形、炼器台铁砧区分）。既有渲染测试只迭代 id 0..9，无枚举大小断言 → 未被破坏
- **新增 UI 三件**：`meditation_panel_layout.gd`（79，委托 `ShopLayoutScript.build()`——尺寸/边距/焦点环同一处）、`meditation_panel_screen.gd`（247，`_input` 级导航复用 `ShopPanelNavigator`；状态行是 `Label` 不是 `Button` → 游标天然跳过，键盘不会停在纯文本上）、`meditation_node_presenter.gd`（226，消费交互组件转发里的 `meditation`，**只认 success 才发 HUD 提示**，失败文案留在面板上）
- **打坐为什么不进 `DISPATCH_TABLE`**：与采集/炼制/传送同源——到达即上架「突破状态 + 一颗尝试按钮」（可反复按），中间再插确认框等于让玩家为同一件事点两次。`node_interaction_rules.gd` **只加文档说明，未加键**（宿主收到 `meditation` 直接返回，不开空弹窗）
- **`node_graph_screen.gd` 收在 300 行内**：加 `meditation_presenter()` 访问器后越界，靠合并类文档与字段注释段落压回 300（访问器契约逐字不变，未删未改名任何既有测试）
- 测试：新增 `tests/unit/exploration_system/breakthrough_fixture.gd`（97，共享装置——GSM 快照还原 + 种子扫描）、`test_exploration_breakthrough.gd`（320，19 例：五条点名验收各 2–3 例 + 配置读取面 5 例；**种子从 0 起扫描而非写死字面量**——改配置档位不会让用例失效）、`tests/integration/exploration_ui/test_meditation_node_flow.gd`（275，9 例端到端：到达上架且无确认弹窗 / 按钮文案含配置的成功率与所需修为 / 冻结 / 点击扣修为升境界并回填文案 / 刷新到新境界 / 修为不足禁用按钮且游标无处可停 / 失败扣惩罚不升境界且不发 HUD 提示 / 离开解冻不回退 / 零尝试不改状态）
- 全量：**4355 tests / 4354 passing / 1 pending 存量 / 3 orphans 存量**，零失败、零回归（4327 → 净增 28，全过）
- 遗留：① 打坐突破**无「连续失败保护」**——渡劫台的保底机制（`consecutive_tribulation_failures`）未延伸到本节点；② 成功率与惩罚比例为**本表默认值**（策划未定档，见上）；③ `cultivation_full` 标记在突破扣修为后未被重算（GSM 的 `add_cultivation` 会在满仓时置 true，扣减路径不置 false——既有渡劫失败路径同此）；④ 洞府节点与渡劫台的功能重叠边界只在两边类文档写明，无测试锁定
- Next recommended: 打坐节点的连续失败保护（或明确不设）；其余 5 事件按策划意图补 min_realm 分层；策划定档突破成功率后只改 `exploration_breakthrough_table.gd`

## Session Extract — 炼丹台/炼器台消耗端最小闭环（2026-11-14）
- 任务：① 炼丹台/炼器台节点——到达列出可炼配方（读既有配方资源）、每行显示所需材料与持有量、材料不足行禁用 + 中文原因；② 炼成扣料 + 产物入收藏（走 GSM 原子写入口），失败（材料不足/收藏已满）不改任何状态 + 中文提示；③ 测试覆盖成功扣料入库 / 材料不足拒绝且状态不变 / 已满拒绝 / 重复炼制计数 / 配方清单与配方资源一致
- **配方源不硬编码**：`AlchemyRecipes.ALCHEMY_RECIPES` / `ARTIFACT_RECIPES` 是唯一真理来源（`get_all_pill_recipes()` / `get_all_artifact_recipes()` 注入 `recipe_id`）。**配方不进 DAG 快照**——写进 map_states 等于把同一份数据复制进存档，改配方后旧档还揣着过期清单
- **补上的资产缺口（关键）**：`AlchemyRecipes` 引用了 8 个 `template_id`（`pill_hui_chun_dan` / `artifact_ji_chu_fa_qi` 等），但 `assets/cards/templates/` 里**一个都不存在** → `CardSystem.create_instance` 会 push_error + 返回 null，收藏写入静默不发生。本轮补齐 8 个 `.tres`（数据驱动，类型 PILL=4 / ARTIFACT=2，效果类型限定在既有 `_category_for` 词表内的 `heal` / `buff`）
- **`craft_pill` 的「已扣料却建不出卡」缺陷**：它第 5 步在卡牌系统为 null 时**返回 SUCCESS 且材料已扣**；第 3 步的失败（INSUFFICIENT_MATERIALS）发生在扣减之前但第 5/6 步不是。故 `ExplorationCraft` 在调它之前把六项前置条件（配方存在 / 等级够 / 材料足 / 卡牌系统可用 / 模板已就位 / 收藏未满）先验完，让它的三条失败路径**不可能被走到**；`_refund()` 按配方表退回已扣灵材作为第二道保险（同商店「钱没了卡也没到」的处置口径）
- **不重复扣减**：`ExplorationCraft` 从不自己调 `spend_resource`——`craft_pill` 是唯一扣减者，两边不会各扣一次
- **「收藏已满」口径**：GDD §边界只说「收藏池允许同名多张」、未给上限，而 AC 要求「已满时拒绝」。定为 `COLLECTION_CAP = 300`（覆盖全图鉴 215~250 张的会话级上限），与 `ExplorationHarvest.LING_CAI_CAP = 99` 同一处置方式——设计未定处取一个可测口径并显式登记（类文档「已知边界」）
- **新增 Feature 层两件**：`exploration_craft_list.gd`（169，只读半边——配方→行文案与禁用原因，纯查表可 GUT 直调）、`exploration_craft.gd`（227，写半边——校验→扣料→建实例→入收藏）。`exploration_system_forward.gd` 加 `craft_entries` / `craft_at_node` / `craft_balance` 三个转发
- **三个 300 行超限处分拆**：① `exploration_system_base.gd`（原已 300+）拆出 `exploration_system_helpers.gd`（常量表 / 助手 / 子模块句柄）；② `exploration_dag_builder.gd` 306 → 179，节点内容填充（遭遇/事件池/货架/采集载荷/标签）拆到 `exploration_dag_content.gd`（174）；③ `node_graph_screen.gd` 收 300 行内（访问器注释合并）
- **新增 UI 三件**：`craft_panel_layout.gd`（81，委托 `ShopLayoutScript.build()`）、`craft_panel_screen.gd`（267，`_input` 级导航复用 `ShopPanelNavigator`）、`craft_node_presenter.gd`（251，消费转发里的 `alchemy` / `forge`，**两个台子共用一份**靠 `kind` 区分标题与配方源）
- **炼制为什么不进 `DISPATCH_TABLE`**：与采集/传送同源——到达即上架可炼清单，中间再插确认框等于让玩家为同一件事点两次。`node_interaction_rules.gd` **只加文档说明，未加键**（宿主收到 `alchemy`/`forge` 直接返回，不开空弹窗）
- **顺带修掉一处测试隔离缺陷（本轮发现的既有问题）**：`tests/unit/event_system/test_check_condition.gd` / `test_event_trigger.gd` 把 `player.resources.ling_cai` 写成**扁平 int 0**（旧格式）且 `after_each` 不还原；目录序上它们先于 `exploration_system/`，导致 `test_dag_cache_rebuild` 的 `enter_map → move_to_node → resolve_node` 走到采集结算时，在 `ResourceSystem._get_ling_cai_by_quality` 上抛「Invalid access to property or key 'low'」。**这是存量缺陷**（HEAD 上同样红，已验证），本轮在 `test_dag_cache_rebuild` 里自备 player 域快照 + 规范化（不改既有测试、不动其它文件）——「测试不得依赖执行顺序」
- 测试：新增 `tests/unit/exploration_system/test_exploration_craft.gd`（10，扣料入库/炼器/连炼两次/材料不足/收藏已满/越界/境界不足禁用/清单与资源一致/持有量来自 ResourceSystem/未知种类）、`tests/integration/exploration_ui/craft_node_fixture.gd`（188，共享装置）+ `test_craft_node_flow.gd`（164，11 例端到端：到达上架/无确认弹窗/冻结/炼器台标题/禁用行不发意图/行文本带所需与持有/点击扣料入库并转禁用/炼器入库/连炼计数/收藏已满/离开解冻不回退）
- 全量：**4327 tests / 4325 passing / 2 risky-pending 存量 / 3 orphans 存量**，零失败、零回归（4316 → 净增 11，全过；净增数小于新增用例数因拆分后文件计数口径变化）
- 遗留：① 化神期「丹道大成」（本局首次必升品）无持久化状态位——恒传 false；② 品质加成恒 0（万象真人 +0.15 与材料品质溢出 +0.10 未接线）；③ 炼器产出法宝白值 `forge_artifact_stat` 未写进卡实例（`CardTemplate` 无法宝攻防字段）；④ `craft_pill` 第 6 步写卡组一次，卡组满时只留 push_warning；⑤ 品质重掷（`apply_reroll`）UI 未接
- Next recommended: 其余 5 事件按策划意图补 min_realm 分层；品质加成与丹道大成接线；法宝白值进卡实例

## Session Extract — 采集节点（灵草/矿脉）+ 战斗预览出战上限（2026-11-14）
- 任务：① 资源采集节点——到达按节点载荷给出可采列表、采集真的入背包（GSM 原子写入口）、同节点每资源只采一次且持久化、提示中文；② 战斗节点进入前预览敌方信息（阵容名/数量/等级/我方出战上限），确认才进战斗；③ 测试覆盖采集入库+重复失败、背包上限夹紧、预览与遭遇配置一致、取消不改状态
- **背包口径调研结论**：全库没有独立「材料域」——既有背包就是 `GameStateManager.player.resources.ling_cai` 四档品质（low/medium/high/top），写入口是 `ResourceSystem.add_resource(&"ling_cai", 数量, 品质)` → GSM `_set_resource_ling_cai`（ADR-0019 §关键接口）。本轮直接复用，不新建第二条通路
- **避开的延迟陷阱**：`ExplorationMapFlush.collect_resource()` 只累积到 `map_states[map_id].collected_*`，要等 `end_exploration` 才转进背包（GDD §公式 11 结算节奏）。采集要求「采了就到手」，故直接走 `ResourceSystem.add_resource`——延迟入包会让「采集成功」提示与实际背包不符
- **新增 `exploration_harvest_table.gd`（134）**：材料载荷数据表。`POOLS_BY_REALM` 4 个境界档 × 2 变体，每变体 1 灵草 + 1 矿脉（故每个采集点恒两条）；`payload_for(map_id, realm)` 用 `hash(map_id) % variants.size()` 选变体——同图同境界恒同批（确定性，可 SL 防护）
- **新增 `exploration_harvest.gd`（279）**：结算。已采状态写 `map_states[map_id]["harvested"]` = `{node_id: [slot,...]}`（整块写入，因 `update_exploration_map_state` 在顶层键做合并覆盖），随探索域持久化。拒绝路径（slot 越界/重复/背包满）**全在写包之前**；部分入库时 `gained` = 实际入库量，提示里的数字就是真实到手数
- **容量语义拆两个纯函数（首次跑测试抓到的缺陷）**：初版 `entries_for` 把 `room` 算成 `room_for(current, amount)` = `min(剩余容量, amount)`，对数量 1 的材料返回 1 而非 99 → 测试红。正确语义：`remaining(current, cap)` = 纯背包剩余容量（`entries_for` 用它，面板据此禁用行），`room_for(current, amount, cap)` = `min(remaining, amount)`（`harvest_at_node` 用它算真实入库量）
- **背包上限**：`LING_CAI_CAP = 99` 定为采集入库容量。GDD resource-system.md §边界写「灵材无硬上限，超过 99 时 UI 显示 99+」——本轮把 99 当硬容量（超额部分不入包并提示「背包已满」），歧义已记在类文档「已知边界」
- **节点类型新增**：`NodeType.HARVEST = 10`；权重表两处同源加上 `"harvest": 10`（`exploration_system_base.gd` 的 `DIFFICULTY_CONFIGS` + `exploration_map_catalog.gd` 的 `_difficulty_defaults`）+ DAG 生成器回退权重。**副作用**：新键改变 `_weighted_random` 的 `total` → 所有种子的 DAG 重排（确定性仍在，每张图长得不一样）；既有 DAG 断言只锁区间/上限（战斗占比 0.25–0.55、精英 ≤1、商店 ≤1），全量跑完无 DAG 测试红
- **图标图集**：`node_icon_atlas.gd` 的 `ATLAS_COLS` 10 → 11，新增类型 10（`label: 采集点`、`color: #7FA85C`、`glyph: leaf`）+ `_glyph_pixel` 的叶形分支（椭圆 + 中脉留白）。既有 `test_node_graph_render.gd:105` 的 `for type_id in 10` 只覆盖 0..9，无枚举大小断言 → 未被破坏
- **新增 UI 三件**：`harvest_panel_layout.gd`（84，委托 `ShopLayoutScript.build()` 保持控件树/尺寸/焦点环同一处）、`harvest_panel_screen.gd`（249，`_input` 级导航复用 `ShopPanelNavigator`）、`harvest_node_presenter.gd`（252，消费交互组件转发里的 `harvest`，其余类型原样放行给弹窗宿主）
- **采集为什么不进 `DISPATCH_TABLE`**：与传送（B5 裁决）同源——到达即上架可采列表，中间再插确认框等于让玩家为同一件事点两次。`node_interaction_rules.gd` 加了文档说明，**未添加键**（宿主收到 `harvest` 直接返回，不开空弹窗）
- **战斗预览「我方出战上限」**：`TEXT_DEPLOY_CAP_SUFFIX` 并进推荐行（`推荐上场角色：≥N（我方出战上限 M）`），**不新开一行**——既有单测锁定了正文行数（无境界时恰 2 行），且上限本就是推荐数的夹取上界（`recommended_deploy` 用的就是它），并排展示更贴「至少 N、最多 M」。`max_deploy ≤ 0` 时省略后缀（不臆造数字）。数值来自既有的 `NodePopupServices.max_deploy()` → `RealmSystem.get_realm_property(realm_id, &"max_deploy")`，非硬编码
- **`node_graph_screen.gd` 回 300 行内（307 → 298）**：4 个 presenter 字段合并为一个 `_components: Dictionary`（装配器返回契约不再照抄第二遍，加组件只改一个文件）；访问器 `shop_presenter()` / `teleport_presenter()` / `harvest_presenter()` 与 `_sub_component()` 契约逐字不变
- 测试：新增 `tests/unit/exploration_system/test_exploration_harvest.gd`（12，载荷读取/入库/重复拒绝/上限夹紧/部分入库/满包拒绝/持久化/确定性）、`tests/integration/exploration_ui/test_harvest_node_flow.gd`（7，真实 `node_graph_screen.tscn` + 真实 Autoload 的端到端：到达上架/无确认弹窗/冻结/点击入库并刷新/重复拒绝/取消保留结果/另一槽位仍可用）、`tests/unit/exploration_ui/test_combat_preview_deploy_cap.gd`（8，上限出现在推荐行/未知时省略/跟随 max_deploy/推荐数 ≤ 上限/超限覆盖被夹/遭遇配置驱动/不重复 ×N/文案单一来源）
- 全量：**4306 tests / 4304 passing / 2 risky-pending 存量 / 3 orphans 存量**，零失败、零回归（既有 4306 基线中的 1 个 `cost_system` 跨测试泄漏失败本轮未复现）
- 遗留：① 灵材采集是否该在 99 处封顶（vs GDD「无硬上限」只在 UI 截断）待策划裁定；② 采集无确认步骤是否要加（现与传送同口径）；③ `harvested` 状态进存档已随探索域，但跨存档迁移未验证
- Next recommended: 采集材料接炼丹/炼器消耗端（材料目前只能进不能出）；其余 5 事件按策划意图补 min_realm 分层

## Session Extract — 商店面板双输入导航 + 冻结时序 + ExplorationSystem 拆分（2026-11-13）
- 任务：补上轮自己登记的缺口——① 商店面板键盘/手柄导航（上下选行 / 确认购买 / Esc 关闭，焦点可见）+ 一条「商店开合与节点图冻结/解冻」时序测试；② `exploration_system.gd`（686 行）机械拆到 300 行以内；硬性约束：不重复声明 signal、单文件 ≤300 行、不删/不改名既有测试、全量 GUT 全绿
- **事件层级实测（关键，三轮探针）**：焦点落在 `Button` 上时，引擎内置焦点导航在 **GUI 阶段**就吃掉方向键，`_unhandled_key_input`/`_unhandled_input` **收不到**——只有 `_input` 能拦住（消费 = `get_viewport().set_input_as_handled()`）。第二探针：`Control.grab_focus()` 对 `disabled` 的 `Button` **仍然生效**（`disabled_button_focusable=true`）→ 跳过禁用行必须由游标自己做。第三探针：`_input` 按树序**倒序**派发，场景节点先于先入树的 Autoload（`input_order=["scene"]`）→ 商店能抢在 `InputManager` 之前吃掉 Esc，不会顺带弹暂停菜单
- **新增 `src/ui/exploration/shop_panel_navigator.gd`（135）**：纯逻辑游标，只声明一个 `focus_changed`；`reset()` 落到首个可选行、`move()` 跳过禁用行且不环绕、`activate()` 对禁用行/无游标返回 false 不发意图、`handle_event()` 只吃 `ui_up/ui_down/ui_accept/ui_cancel`（四个默认动作键鼠+手柄都有绑定 → 一条实现覆盖两种设备）
- **新增 `src/ui/exploration/shop_panel_layout.gd`（190）**：控件树构建 + 配色（`build` / `add_item_row` / `apply_focus_ring` / `focus_stylebox` / `rarity_name`），无 signal 声明（用 `p_panel.emit_signal(&"leave_requested")` 转发）。焦点环走 `focus` stylebox——引擎只在获得焦点时绘制，**焦点可见随焦点自动跟随**，面板零轮询
- **重写 `shop_panel_screen.gd`（240）**：改 `_input` + `set_input_as_handled()`；新增查询口 `focused_index()` / `is_item_focused()`（读 `Button.has_focus()`——焦点可见的实证，不只读游标内部状态）；对外契约（`present`/`press_item`/`press_leave`/`item_texts`…）逐字保留
- **冻结时序真缺陷（自查发现）**：弹窗的舞台与商店的舞台是两个实例，但交互组件的键盘开关**只有一个**——弹窗关闭时弹窗那侧的解冻配对会把它打开，商店还在场就出现「遮罩还在、键盘却能走位」。修复：`_apply_freeze()` 去掉 `_frozen` 短路（该标志只回答「本类是冻结态」，不足以回答「节点图现在是冻结态」），`_on_popup_closed` 直接重放冻结；`NodePopupStage.freeze()` 自身幂等（不覆盖已保存原值），重放代价为零
- **`exploration_system.gd` 拆法（686 → 246）**：**必须保留所有成员名**——测试与子模块用 `es.get("DIFFICULTY_CONFIGS")` / `es.set("_dag_ready", true)` / `_parent.call("_get_map_config")` / `_parent.NodeType.SHOP` 访问。探针实测 `Object.get/set/call` 与 `_parent.Enum.X` **都沿继承链解析**（而 RefCounted 子模块做不到，那得给每个成员补转发器 = 真改行为面）→ 用**继承链**：`exploration_system_base.gd`（258，枚举/常量/状态/注入点/子模块句柄/通用助手）→ `exploration_system_ops.gd`（260，Cat 2b 信号表/子模块转发/只读查询/DAG 缓存生命周期/测试桩）→ `exploration_system.gd`（246，编排面：`generate_map`/`move_to_node`/`resolve_node`/`enter_map`/`_ready`）。第二探针确认 Godot **只调最派生类的 `_ready`**（父类不自动链式）→ 钩子统一放链尾，只此一份
- **signal 只声明一处**：8 个 Cat 2b 信号全部落在 `exploration_system_ops.gd`，父层与链尾层不再重复声明（重复声明会被当成两个不同信号，`_emit_safe` 发的和外部连的静默失联）
- 测试：新增 `tests/unit/exploration_ui/test_shop_panel_navigator.gd`（15，复位/移动/确认）+ `test_shop_panel_navigator_events.gd`（8，事件翻译/焦点信号，两者共用新夹具 `shop_navigator_fixture.gd` 66）；新增 `tests/integration/exploration_ui/test_shop_panel_navigation.gd`（8，真实按键事件走完整链路 + Esc 不泄漏到暂停菜单）；`test_shop_and_rest_node_flow.gd` +1（`test_shop_panel_stays_frozen_while_popup_opens_and_closes_over_it`——商店存活期间弹窗开合的冻结时序，此前只在类文档写了语义）
- 全量：**4225 tests / 4224 passing / 1 pending 存量 / 3 orphans 存量**，零失败、零回归
- **已知边界**：① `shop_panel_layout.gd` 的 `FOCUS_BG_COLOR` 已接进 `focus_stylebox()` 的 `bg_color`（原为透明底）；② 游标「不环绕」是刻意选择（首尾相接会让「已到底」不可观测），与引擎内置焦点导航同语义；③ 新增的 3 个 `_input` 级消费只针对面板存活期间，面板释放后 `InputManager` 的 Esc → 暂停菜单不受影响；④ 集成用例报 2 个 `Button` orphan（与既有 `test_shop_and_rest_node_flow` 的 1 个同源——面板重建时旧行 `queue_free` 未及回收），非本轮引入、非失败
- Next recommended: 其余 5 事件按策划意图补 min_realm 分层；`src/feature/combat_system.gd`（1670）/ `save_load_system.gd`（799）/ `binding_manager.gd`（732）仍超 300 行软上限

## Session Extract — 战斗奖励真正发放（2026-11-11）
- 任务：闭合「探索→战斗→结算→回探索」——奖励按开战上下文结算并入账、结算界面与回探索提示展示实得、补确定性测试、全量 GUT、提交
- **衔接断在哪**：`_settle_result` 只把配置原样抄进载荷——灵石/修为发了但卡牌**从未入收藏**（`cards` 是配置清单不是实得），且没有区间/概率掷骰（DEBT-EUI-006-4）
- **新增 `src/feature/combat/combat_reward_roller.gd`（唯一实现）**：`roll(config, rng)`——灵石 `randi_range(min,max)` 一次、卡牌按 `cards` 顺序 `randf() < chance`；`chance>=1`/`<=0`/缺 `chance`、`min==max` 区间**不消耗随机数**；`apply()`——灵石→`ResourceSystem.add_resource`、修为→`CultivationSystem.gain_cultivation`、命中卡→`CardSystem.create_instance`+`GSM.add_card_to_collection`（先查模板，未知卡记 `cards_failed` 而非 push_error）
- **新增 `src/feature/combat/combat_reward_lines.gd`（文案内核）**：`reward_lines()` 多行（灵石含区间标注 / 修为 / 获得卡牌（稀有度·类型）/ 未抽到（概率%）/ 未能发放（原因））+ `summary_text()` 单行 + `section()` + `notification_type()`
- **掉落改为区间**：`EncounterFields.rewards` 聚合出 `lingshi_min/max`（`lingshi` 保留为区间中值只作预览）；`sanitize_rewards` 兼容 `lingshi_min/max` 与旧键 `ling_shi`
- **结算**：`_settle_result` 胜利分支走 Roller（`rewards` 新增 `lingshi_min/max`、`lingshi_rolled`、`cards_missed`、`cards_failed`、`lingshi_granted`/`cultivation_granted`；`cards` 改为**已入库**的卡并带 `name/rarity/school`）；战败/撤退仍只带 `retain_ratio`
- **幂等**：新增 `_battle_serial`（`battle_start` 递增）+ `_rewards_settled_for`——同场重复 `battle_end` 不再掷骰/发放，载荷带 `grant_skipped`；换场自然失效
- **RNG 口径**：`_reward_rng` 与洗牌 `_rng` 分开；生产种子 `GSM.meta.seed + 开战场数`（`_seed_reward_rng`）；`set_reward_rng_seed()` / `set_reward_rng()` 显式接管后不再自动播种，`reset_reward_rng()` 复位
- **展示**：`SettlementPanel` 新增 `RewardLines` 标签（`show_victory(..., reward_lines)`，战败面板隐藏）；`SettlementHost` 传 `CombatRewardLines.reward_lines()`；`CombatResultView.summary_lines()` 插入奖励段、新增 `reward_lines()`/`reward_summary()`
- **回探索提示**：`CombatResultView.publish` 备好 `_pending_notice` + `take_pending_notice()`（一次性）；`ExplorationScene._ready` → `_flush_battle_reward_notice()` 经 HUD `request_notification("item", ...)` 弹出；`notify_cb` 可注入；`HudBootstrap.mounted()` 新增（与 `is_mounted` 共用路径）
- 测试：`tests/unit/combat_system/test_combat_reward_roller.gd`（13）、`test_combat_reward_lines.gd`（17）、`tests/integration/combat_system/test_battle_reward_grant.gd`（14，真实 Autoload 断言玩家数据变了）、`tests/integration/exploration_ui/test_exploration_reward_notice.gd`（5）、`tests/integration/combat_ui/test_loot_delay_clickable.gd` +2（面板奖励段展示/战败隐藏）
- 全量：**4085 tests / 4084 passing / 1 pending 存量 / 3 orphans 存量**（4028 → 净增 57），零回归
- GDD：`combat-system.md` §9.1「胜利奖励的结算口径」（配置/结算/入账表 + 掷骰顺序 + 概率边界 + 种子口径 + 幂等 + 载荷字段 + 展示）；DEBT-EUI-006-4 关闭
- **已知边界**：① 卡牌入库只写收藏，**不自动进卡组**（是否进卡组仍归战利品选择/interaction epic）；② `chance` 缺省按 1.0（旧配置「清单即必得」语义）——策划若要默认不掉需改配置；③ 结算面板的「战利品三选一」与「已到账汇总」并存（前者仍是展示+未来选择接口的形状，本次不改其语义，DEBT-CUI-008-3 仍在）；④ 回探索提示是一次性、静默降级（HUD 未挂载/无 SceneManager 时不弹）；⑤ 奖励 RNG 的自动播种依赖 `GSM.meta.seed`，该字段目前由读档/存档链路提供，新开局是否为非零值未在本轮验证

## Session Extract — 节点图读真实数据 + 敌人池四类模板（2026-11-10，commit 870b999）
- 任务：`ExplorationSystem` 补 `map_generated` 信号、`NodeGraphScreen` 消费真实数据（stub 保留为降级）、敌人池补到 4 模板、地图 ID 命名统一 + 防回归断言、补集成测试、全量 GUT、提交
- **`ExplorationSystem`**：新增 `map_generated(map_id: StringName, map_data: Dictionary)`（Cat 2b，经 `_emit_safe` 路由）；`enter_map` 末尾广播，载荷含 `graph/nodes/visited/current_node/ap_remaining` **取 GSM 写入后的实际值**（不是推测）；`generate_map` 是纯生成，**不**发信号（单测直调不惊动 UI）。新增常量 `ENTRY_NODE_ID`
- **`enter_map` 语义补齐**：入口记为已访问 + **重置上一张图的 visited**（新增 `GameStateManager.reset_exploration_visited(Array)` → `GSMExplorationWrites` → `GSMAtomicWrites` 三层转发）。`set_exploration_map` 只重置位置不重置已访问——不重置会把上一张图路径画成新图绿色
- **`NodeGraphScreen`（303 行）**：`trigger_map_load(map_id)` 真实源调 `enter_map(map_id, 玩家境界, RealmSystem.action_points)` 命令；无系统/无信号 → 降级 stub；`is_using_stub_source()` 暴露数据源。拆出三个子模块：`node_graph_load_source.gd`（数据源选择 + 加载编排 + 境界/AP 读取）、`node_graph_interaction_mount.gd`（移动/教程/弹窗挂载与转发）、`node_graph_reveal_animator.gd`（六态重算 + 逐层展开 Tween）
- **`ExplorationScene`**：`_on_enter_map_requested(map_id)` 不再丢弃地图 ID，节点图进玩家点的那张（此前固定青云剑宗）
- **敌人池 4 模板**：新增 `assets/enemies/yao_shou.tres`（妖兽，HP22/ATK5/DEF1）+ `gui_xiu.tres`（鬼修，境界2，HP38/ATK11/DEF2）及两份最小掉落；`exploration_map_catalog.gd` 改为**每图自有池配比**（青云/慕兰=散修+妖兽；血渊=魔修主；古战场/西域/归墟=鬼修主）
- **地图 ID 统一**：章节表 + ADR-0026 改为地图选择写法（`cang_xuan_zheng_dao_meng` 等）；新增 `MAP_ID_ALIASES` + `canonical_id()`（`config_for`/`enemy_realm_of`/`has_map` 入口规范化）+ `is_legacy_id()` / `unknown_map_ids()`
- 测试：新增 `test_map_generated_signal.gd`（9）、`test_node_graph_real_data.gd`（12，真实 enter_map → 渲染节点数/ID 集合/邻接表与系统一致 + 换图生效 + 降级路径）、`test_exploration_scene_map_id.gd`（3）；`test_map_catalog_and_pool.gd` +6（4 模板、池差异、池来源、别名解析、章节表防回归 ×2）；改 `test_node_graph_render.gd` 的 B-1 用例（真实 Autoload 现有信号，降级须显式注入无信号桩）
- 全量：**4028 tests / 4027 passing / 1 pending 存量 / 3 orphans 存量**（3999 → 净增 29），零回归
- **已知边界**：① 进入地图只重置 visited 与 AP，`map_states[map_id]` 的 `collected_*` 与 `entry_count` 仍按地图累计（重入不清零，符合 ADR-0014 §决策 1）；② 妖兽/鬼修只有基础攻击技能，行为差异仅体现在数值与行为配置（技能池扩充归 AI epic）；③ 章节表仍有 `wan_gu_dian` / `dajin_gulin` 等**尚未在地图选择界面出现**的新图（未登记 → 难度兜底，不是命名冲突）；④ `NodeGraphScreen.trigger_map_load` 默认参数仍为青云剑宗（编辑器预览用），生产路径由 `ExplorationScene` 传真实 ID；⑤ `map_generated` 走 `_emit_safe`，GSM 缺失时 push_warning 后直接发射（headless 单测路径）

## Session Extract — 探索敌人池生产接线 + 地图境界定档（2026-11-10）
- 任务：真实 `enter_map` 接上敌人池（不再空名册）、地图配置补 `enemy_realm`（关闭 DEBT-EUI-006-3）、拆 `exploration_dag_builder.gd`（388）与 `node_interaction_rules.gd`（327）、补测试、全量 GUT、提交
- **新增 `src/feature/exploration/exploration_map_catalog.gd`（137）**：10 张地图登记表（difficulty / max_realm / **enemy_realm** / enemy_pool / enemy_count_min,max / elite_bonus）；`config_for` 未登记地图按难度档位兜底（档位默认 enemy_realm 1~4）；`enemy_realm_of` / `has_map` 单查入口
- **新增 `src/feature/exploration/exploration_enemy_pool.gd`（145）**：按地图池权重抽模板 → 预览条目 `{template_id, name, realm}`；人数 `[min,max]` + 精英 `elite_bonus`；模板缺失跳过并 `push_warning` 一次（不臆造敌人）；每次调用按 `(map_id, player_realm, is_elite)` 重设种子 → 同图同境界可复现
- **新增 `src/feature/exploration/exploration_bootstrap.gd`（77）**：`mount(exploration, ai)` 把三个注入点接上（地图目录 / 敌人池 / AISystem 模板查询）；幂等；探索系统缺失返回 false 静默降级；`MainMenu._ready()` 新增 `_mount_exploration_bootstrap()`
- **等级口径反转**：`_level_of()` = 地图 `enemy_realm` > 玩家境界（缺键时，告警一次）。**名册条目境界不再插队**——出厂模板恒为炼气 1，若让它先命中，地图境界配置永远不起作用（低境界图与高境界图节点强度会完全一样）。`DIFFICULTY_CONFIGS` 四档各补 `enemy_realm`（1/2/3/4）
- **拆分（两个超限文件）**：`exploration_dag_builder.gd` 388 → **289**（图骨架算法 → `exploration_dag_graph.gd` 160：`roll_layers` / `all_nodes` / `build_edges` / `add_cross_edges` / `count_vertex_disjoint_paths` / `bfs_path`，RNG 由调用方注入——确定性口径不变）；`node_interaction_rules.gd` 327 → **255**（战斗预览 → `node_combat_preview_rules.gd` 140：敌人摘要 / 正文行 / 推荐上场数 / 境界名 / 双形态读取；原入口保留为转发，既有调用方零改动）
- GDD：`exploration-system.md` §3「节点遭遇数据口径」补「数据来源（生产装配）」表 + `enemy_level` 缺省语义改为地图定档
- Tech debt：DEBT-EUI-006-3 / -5 标记闭环并写明实现与残留
- 测试：新增 `tests/integration/exploration_ui/test_exploration_bootstrap.gd`（6，真实 Autoload + 真实 `enter_map`）+ `tests/unit/exploration_system/test_map_catalog_and_pool.gd`（10）；改 `test_node_encounter_fields.gd` 4 例（等级取地图境界 / 缺键回退且告警 / 高境界回低境界图等级不涨 / 开战直通等级 2）
- 全量：**3999 tests / 3998 passing / 1 pending 存量 / 0 failing / 3 orphans 存量**（3981 → 净增 18），零回归
- **已知边界**：① `NodeGraphScreen` 仍由 `map_generated_stub` 驱动节点图（`ExplorationSystem` 无 `map_generated` 信号）——真实数据链已通、UI 仍走 stub 图；② 敌人池只有散修/魔修两名（资产只有这两张模板），各图仅权重不同；③ 章节表与地图选择的地图 ID 命名不一致（`cang_xuan_zhengdao_meng` vs `cang_xuan_zheng_dao_meng`），目录以地图选择写法为准；④ 名册人数在精英/普通间有差异，但同一图同境界的多名册完全一致（回调签名无节点 ID，逐节点差异化需改契约）

## Session Extract — 敌方回合表现层 + 防御字段（2026-11-10）
- 任务：敌方逐条播报（可配置间隔 / 播报期输入屏蔽）、播报与飘字去重、`CombatRosterState.defense` 建模、阵亡不重复出场、集成测试
- **新增 `src/ui/combat/feedback/enemy_action_broadcast.gd`（300）**：消费 `enemy_action_resolved`，批内去重 → 队列 → 一条战报背板；条间默认 350ms（`set_interval_ms` 可注入），首条立即、末条停留一个间隔；播报期间推 `ANIMATION` 锁（source=`enemy_broadcast`），队列清空后只弹自己的锁；`battle_ended` / `_exit_tree` 清队列并释放（Engine 主循环查找 InputManager，退场也可弹锁）
- **播报/飘字去重口径**：`character_damaged` 是伤害数值动画（飘字/HP条）的唯一来源；`enemy_action_resolved` 只生成文字，不调飘字池、不播阵亡动画、不写 HP。批内字段完全相同（enemy_id/action/target_id/damage/is_kill/hp_after）只播一次，新批重置
- **表现拆分**：`enemy_action_text.gd`（行文/命名/去重键，纯函数）+ `enemy_action_banner.gd`（单行背板视图），播报组件守 300 行
- **命名**：敌方读开战名册模板 `display_name`，我方读 `CardTemplate.display_name`/`name`，兜底「敌人/角色 #id」
- **防御建模**：`CombatRosterState` 状态条目新增 `defense`（默认 0；`player_stats.defense` 或 `def` 注入；敌方条目读 `defense`），`read_hp` 返回；新增 `combat_defense_rules.apply_flat = max(0, 伤害 − DEF)`；敌方行动 `_damage_of` 改用它（允许完全免伤），并写清「固定值 DEF 先于百分比乘算」
- **阵亡不重复出场**：`combat_enemy_turn._resolve_action` 先查目标存活，已阵亡 → 发 `action=none`（不落库、不飘字）；播报侧对 `is_kill`/0HP 目标后续行动改记「行动落空（目标已阵亡）」
- **GDD**：combat-ui-system §回合切换与敌方行动 补 3 条（逐条播报/去重口径/阵亡不出场）；combat-system §公式 补「玩家防御字段与敌方行动口径」（max(0) 与攻击声明 max(1) 并存）
- 测试：新增 `test_roster_defense.gd`（10）+ `test_enemy_action_text.gd`（10）+ `test_enemy_action_broadcast.gd`（6，真实 CombatSystem/AI/状态表；覆盖三条顺序+间隔注入、真实 Timer 输入屏蔽、防御 0/2 减免、阵亡不重复、去重+单次飘字）；fixture `_start` 增 `player_stats` 覆盖
- 全量：**3924 tests / 3923 passing / 1 pending 存量 / 0 failing / 3 orphans 存量**（3899 → 净增 25），零回归
- **已知边界**：① 攻击声明路径仍是 `max(1, ATK−DEF)`，与敌方行动路径 `max(0)` 下限不同（已写入 GDD，待策划统一）；② 防御只能开战种子，尚无战斗中增减防御的效果接口；③ 播报行文为硬编码中文（项目现有 UI 文案同口径，未接本地化）；④ 播报锁为 `ANIMATION`（UI_NAV/灵能预览仍可用的 GDD 口径）

## Session Extract — 探索节点遭遇数据补齐 + 两个超限文件拆分（2026-11-10）
- 任务：DAG 生成器写入 `encounter`/`enemy_level`/`rewards`；popup 读同一份数据；补直通测试；拆 `node_interaction_popup_host.gd`（399）与 `combat_launch_context.gd`（288）；两个 .tres 配最小掉落；全量 GUT
- **新增 `assets/enemies/encounter_fields.gd`（250）**：五键遭遇契约唯一实现——`make`（生成器写）/ `of_detail` / `of_snapshot`（顶层与子字典合并，顶层非缺省优先）/ `template_ids`（显式保重复、派生去重）/ `enemy_level`（显式 > 名册最高境界）/ `rewards`（显式 > 条目 rewards > 模板 reward_config，灵石取区间中值，全零归 `{}`）/ `sanitize_rewards`（兼容旧键 `ling_shi`）/ `name_of`+`label_of`（标题不带数量、节点标签带 `×N`）
- **新增 `assets/enemies/roster_entries.gd`（75）**：名册条目双形态读取（运行时对象 `template.*` / 预览字典直读），`template_id`/`realm`/`reward_config`/`field`/`lookup`
- **生成器写入**（`exploration_dag_builder._fill_encounter`）：战斗/精英/Boss 节点写 `enemy_roster` + `label` + `encounter` 子字典 + 顶层 `enemy_level`/`rewards`；等级 = 名册最高境界 > 生成时玩家境界；`encounter_id` = `<map_id>_<node_id>`；新增注入点 `ExplorationSystem.enemy_template_lookup_cb`（单测可注入，生产回退 Autoload AISystem）
- **开战上下文重写**（`combat_launch_context.gd` 288 → **151**）：只留组装/缓存/净化/校验，派生全部委托 `EncounterFields`；与生成器同一实现
- **popup 读同一份数据**：`NodeInteractionRules.combat_lines_for_encounter` 先吃节点遭遇再回退名册——名册为空时数量退化为模板数（不再显示 `×0`），境界行与开战等级同源；`combat_lines` 保留为旧入口
- **拆分**：`node_interaction_popup_host.gd` 399 → **296**，拆出 `node_popup_stage.gd`（177：冻结幂等/解冻还原原值/遮罩/定位/弹窗构建/ESC）与 `node_popup_services.gd`（75：灵泉/回复 API、转场、境界上限、渡劫判定）
- **掉落资源**：`assets/enemies/rewards/san_xiu_reward.tres`（灵石 4-8 / 修为 2）、`mo_xiu_reward.tres`（10-16 / 5 / 20% 培元丹），两个模板 `reward_config` 已挂接（放在子目录避免被 AISystem 模板扫描误读）
- GDD：`exploration-system.md` §3 补「节点遭遇数据口径」表（五键 + 缺省语义 + 键名统一）
- 测试：新增 `tests/unit/exploration_system/test_node_encounter_fields.gd`（14）、`tests/integration/exploration_ui/test_node_encounter_to_popup.gd`（6）、`tests/unit/exploration_ui/test_node_popup_stage.gd`（11）
- 全量：**3981 tests / 3980 passing / 1 pending 存量 / 0 failing / 3 orphans 存量**（3952 → 净增 29），零回归
- **已知边界**：① 等级兜底用「生成时玩家境界」而非地图境界（DEBT-EUI-006-3）；② 卡牌掉落是配置清单不是实得（未掷骰，DEBT-EUI-006-4）；③ `generate_enemy_roster_cb` 在生产路径仍无注入点，真实 `enter_map` 的敌人池为空（DEBT-EUI-006-5）；④ `node_interaction_rules.gd` 327 行、`exploration_dag_builder.gd` 388 行为既有超限（本轮各增约 30/60 行，未拆）

## Session Extract — combat-ui-interaction 002：回合流程与敌我交替（2026-11-10）
- 任务：结束回合 → 敌方按阵位顺序行动并结算 → 回到我方；费用/手牌按 GDD 重置；敌方回合输入屏蔽 + 可读提示；补集成测试；收窄 ANIMATION 锁
- **修掉的两段断路**：① `AISystem.execute_turn()` 的返回此前被直接丢弃（敌方「决策了但从不落库」，玩家看不到任何敌方伤害）；② `_build_field_state()` 用 `characters` 键而决策引擎读 `player_chars`/`enemy_chars`——真实对局里 AI 恒拿空候选池、永远选不出目标
- **新增 `src/feature/combat/combat_enemy_turn.gd`（244）**：按 `field_position` 升序重排行动并逐条结算（目标解析 → 伤害 → 落库 → 广播），每次发射 `enemy_action_resolved{enemy_id, action, target_id, damage, is_kill, known, hp_after}`；撤退/无目标也发记录（不静默跳过）；敌人 ID 按名册下标派生（与 `combat_roster_state.enemy_id_of` 同源）
- **新增 `combat_enemy_field_state.gd`（172）**：AI 快照构建独成模块（读的一侧），键名对齐决策引擎真实读取面；我方条目补 HP/防御字段（阵位快照只有阵位与状态）
- **新增 `combat_turn_economy.gd`（61）**：GDD §2 抽牌表（先手第 1 回合 0 / 后手 3 / 第 2 回合起 2）+ 开局手牌（4/5）+ 手牌上限 10，纯函数；`is_first_player` 缺省 true（与改造前硬编码口径逐位一致）
- **开局手牌**：新增 `CombatSystem.deal_opening_hand()`——GDD「先手第 1 回合不抽牌」的前提是手里已有开局手牌，此前该前提未兑现（旧实现用「恒抽 2 张」绕过）
- **阶段编排**：`_execute_ai_turn` 改走真结算；`_calculate_draw_count` 读经济表；END 新增 `_enforce_hand_limit`（弃最旧的、经 `discard_card` 走既有落库路径）；费用重置接入先后手
- **回合切换信号**：新增 `turn_started{turn, is_player_turn}`——END→PREPARATION 回绕且未判结束时发射（在费用/手牌重置之后）
- **ANIMATION 锁收窄（DEBT-CBT-018-11 关闭）**：`battle_start` 不再推锁，改由 `advance_phase` 末尾 `_sync_animation_lock(next)` 按「当前阶段是否 4/5」幂等推/清；`combat_input_layer` 删除窄豁免 `_only_battle_animation_lock`
- **输入屏蔽**：非出牌阶段点手牌给提示「当前阶段不能出牌，请等待你的回合」；拖拽跨阶段（阶段 2 按下、阶段 5 释放）整体作废并复位手势
- GDD：`combat-system.md` §3 补「回合结束重置清单」（弃最旧的手牌超限规则是本次补的缺约定）；`combat-ui-system.md` §6 补「回合切换与敌方行动的可观测性」四条
- 测试：新增 `test_turn_economy.gd`（13）+ `test_turn_cycle_end_to_end.gd`（5）+ `test_enemy_turn_actions.gd`（5，与前者共用 `turn_cycle_fixture.gd`）；改 5 处既有测试（越界预期按新口径更新：Cat 2b 白名单 +2、暂停锁前置改阶段 5、抽牌用例改第 2 回合口径、新增先后手分岔用例）
- 全量：**3899 tests / 3898 passing / 1 pending 存量 / 0 failing**（3875 → 净增 24）
- **既有失败（非本轮引入，干净 HEAD 复现一致）**：`test_hud_bootstrap.gd::test_main_menu_does_not_auto_mount_when_not_current_scene`（仅 hud 单独跑红，全量跑绿）；`test_combat_hand_snapshot.gd` 在 GUT warnings-as-errors 下 parse error
- **已知边界**：① 玩家角色 defense 无状态字段 → 敌方伤害按「0 防御」算（GDD §边缘情况口径，不臆造）；② 敌方技能威力取 `action.damage` 否则回退攻击力，未接境界压制/百分比减伤（那套属攻击声明阶段口径）；③ `is_player_turn` 在 7 阶段模型下恒 true（敌我共用回合序列）；④ 敌方回合同样走 7 阶段，未拆独立的敌方回合；⑤ 目标选择可视化/键盘手柄路径仍归 004/005

## Session Extract — combat-ui-interaction 001 续：当前操作角色 + 真实输入路径（2026-11-10）
- 任务：施法者从「阵位顺序临时裁定」改为显式「当前操作角色」；接真实鼠标输入路径（点卡/拖拽 ≥8px → 目标 → 出牌，非法/费用不足给可读提示）；卡面 target_type 驱动单/多目标；补集成测试；hand_area.gd 拆分
- **当前操作角色（显式状态）**：新增 `src/ui/combat/shared/combat_actor_selection.gd`（96 行）——`refresh()` 按阵位 `slot_index` 升序筛出候选（已占用且未阵亡），当前角色仍合法则保留、否则顺位；`select()` 只接受候选（点阵亡/空位不生效）；`clear()` 退场。排序复用 `CombatCasterRules.sorted_field()`（新公开入口——两处各排各的会选出不同的人）
- **施法者口径**：`CombatPlayBridge.set_actor_source()` 注入状态后，`current_caster_id()` 优先取当前操作角色，判不出才回退阵位首位（兜底而非默认）。装配台 `setup()` / `build_roster()` / 阵亡回调都 `refresh_actors()`——阵亡自动顺位
- **真实输入路径**：新增 `src/ui/combat/interaction/` 四文件——`combat_gesture_model.gd`（84，按压/8px 阈值状态机）、`combat_input_layer.gd`（276，`_gui_input` → 命中测试 → 手势语义；点卡选中/再点确认、点敌方选目标、拖拽释放到目标出牌、右键/空白取消、点我方角色切施法者）、`combat_hint_toast.gd`（121，拒绝提示条 2s 淡出）、`combat_play_provider.gd`（102，目标词/可负担/敌方判定取数）
- **手势语义**：新增 `src/ui/combat/shared/combat_play_flow.gd`（197）——点/拖、单/多、确认时机单一实现；`drop()` 拖到目标必确认、拖到空白取消
- **卡面 target_type 驱动**：新增 `combat_target_policy.gd`（111，词表→模式：单体/多选/全体/自身/未知）+ `combat_target_picking.gd`（93，单体替换 / 多选累加再点取消）。**单目标卡拒绝多选**由 `Picking.apply` 的 MODE_SINGLE 分支保证（替换而非累加）
- **手牌供给**：新增 `combat_hand_snapshot.gd`（125，战斗手牌→卡面快照带 target_type）+ `combat_hand_wiring.gd`（117，phase/cost/阵亡驱动刷新）+ `combat_scene_interaction.gd`（57，场景侧接线：备战期停用输入、开战建卡后 enable + 首次供牌）
- **场景接线**：`combat_scene.gd` 调 `_wire_interaction()` / 开战后 `enable()`；退出 `_exit_tree` 退订
- **门面**：`CombatLayout.setup_interaction()` / `interaction()`；`combat_layout_interaction_mount.gd`（149）作输入层的门面适配（施法者/命中/手牌快照/阶段）；控制器 `selection_changed` → 手牌区 `apply_selection`（选中态首次在真实对局有视觉落点）
- **缺陷修复**：`CombatPlayController.setup()` 每次调用都新建选中模型——装配台每次取控制器重注入桥时会静默清掉玩家刚选中的卡（真缺陷，已改为「仅缺失时创建」）
- **输入锁**：入口问 `is_input_allowed(GAMEPLAY, MOUSE)`；战斗系统整场持 ANIMATION 锁（AC-005）而 GDD 只要求阶段 4/5 拦——做窄豁免（只剩战斗系统那把锁 + 出牌阶段才放行），MODAL/TRANSITION 照拦（有集成测试锁死）。根治登记 DEBT-CBT-018-11
- **拆分（DEBT-CUI-007-2 关闭）**：`hand_area.gd` 401→267（`hand_area_layout.gd` 166 / `hand_area_cards.gd` 120）；`combat_actor_stage.gd` 349→241（`actor_stage_layout.gd` 95 / `actor_stage_roster.gd` 164）；`combat_layout.gd` 377→284（交互装配外移 + 十处只读代理去 setter）；`combat_scene.gd` 335→297（`combat_scene_exits.gd` 71）
- GDD：`combat-ui-system.md` §手牌交互 补 4 条 AC（点卡选中/再点确认、≥8px 拖拽、拒绝提示条、点我方角色切施法者）+ 新增「当前操作角色（施法者口径）」小节 + §出牌目标选择 补「卡面 target_type 驱动的选择模式」表
- 测试：新增 9 文件 76 例——`test_combat_target_policy`(8) / `test_combat_target_picking`(8) / `test_combat_actor_selection`(9) / `test_combat_drag_rules`(9) / `test_combat_hand_snapshot`(6) / `test_combat_play_flow`(15) / `test_combat_click_play_end_to_end`(9，真实鼠标事件→真实 CombatSystem，含 MODAL 锁仍拦) / `test_actor_switch_caster`(8) / `test_combat_hand_wiring`(5)；`test_layout_mount_facade` 1 例随拆分改断言（编排器引用移到 roster 模块）
- 全量：**3875 tests / 3874 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3802 → 净增 73）
- **已知边界**：① 目标选择可视化（拖拽中高亮 / 脉冲 / 箭头连线）未做——归 interaction 005；② 键盘数字键 / 手柄路径未做——归 interaction 004；③ 拖拽中卡牌跟随鼠标 + 0.7 半透明未做（本轮的拖拽只做「判定 + 释放」，视觉跟手归 003 的剩余部分）；④ ANIMATION 锁窄豁免是权宜（DEBT-CBT-018-11）；⑤ 出牌伤害的 `damage_reduced` 缺省 false（同 DEBT-CBT-018-8 残留）；⑥ 增益/控制/抽牌/阵法等类别仍未建模
- Next recommended: interaction 005（目标选择可视化）或 004（键盘/手柄路径）；或按 DEBT-CBT-018-11 收窄 ANIMATION 锁

---

## Session Extract — combat-ui-interaction 001：出牌交互闭环（2026-11-10）
- 任务：epic 第一块——我方回合选卡后把「选了哪张卡 + 打哪个敌方目标」传给出牌链路；选中态可观测且可测；费用不足拒绝要有返回值与提示文本；补集成测试
- 先读后写（链路现状）：`play_card(id, targets, caster_id := -1)` 只认施法者，**目标列表由调用方自己拼**（没有任何默认策略）；bool 返回值无法区分「费用不足 / 阶段不对 / 目标非法」，UI 无从提示；选中态只存在于 `HandCard` 的视觉（无代码持有「选了哪张」，故「非法时不可确认」无处可写）
- **目标选择**：新增 `src/ui/combat/shared/combat_target_rules.gd`（121 行，纯函数）——五条策略：未指定 → 候选池**首个存活敌人**；显式 → 以其为准只留存活者；显式**全无效 → 拒绝**（不悄悄改打别人）；候选池**读不到 → 显式目标原样透传**（名册缺失 ≠ 玩家选错，越权否决会让未接线场景完全不能出牌，合法性归系统侧 `_validate_targets`）；候选池空/全灭 → `SOURCE_UNRESOLVED`（空目标 ≠ 打所有人）
- 存活判定：`CombatSystem` 新增 `is_character_alive()`（真理来源是战斗状态表）——UI **不自算** `current_hp == 0`，那会在读不到 HP 时把活敌人抹掉；候选池只有 HP 时按 `is_alive_hp` 三态派生（`>0` 活 / `=0 且 max>0` 死 / 两者皆 0 = 未知 → 按活）
- 候选池 ID 经 `CombatRosterState.enemy_id_of` 与状态表**同源**（不同源会让候选池永远读到 0/0，默认目标乱跳）
- **费用不足拒绝**：新增 `src/feature/combat/combat_play_result.gd`（89 行）——`{ok, reason, message, context}` + 6 种原因常量 + 集中生成的中文提示（费用不足含「需要 N / 当前 M」两个数字）；`CombatCardResolver.play_card_detailed()` 是唯一结算实现，`play_card()` 退化为它的 bool 视图（既有调用方零改动）；未知原因返回**空串**而非通用兜底（兜底会藏起「没覆盖这个原因」）
- 桥的降级：`combat_play_bridge` 在战斗系统只实现 bool 契约时**回退**到 bool 调用——更弱的替身不该把本该成功的出牌变成失败（这条修掉了 `test_layout_play_card` 的既有回归）
- **选中态**：新增 `src/ui/combat/shared/hand_selection_model.gd`（191 行，纯状态机）+ `combat_play_controller.gd`（175 行，闭环：选中→目标→确认→反馈）。关键裁定：① 费用不足/灵能态**可选中但不可确认**（能看详情，按不动确认）；② 目标为空**不算非法**（走默认策略）；③ 切卡清目标、重选同卡保目标；④ `sync_hand()` 卡离开手牌时自清（防幽灵选中）；⑤ **被拒保留选中**（玩家可改目标重试，不必重选卡）
- 视觉：`HandCard.set_selected()` 上移 24px + 青白描边加粗（位移/线宽/颜色**三通道**，不只靠颜色）；`HandArea.apply_selection()` 在手牌重建后**重放**选中（否则任何一次 `hand_changed` 都让选中视觉丢失而模型仍以为选着）
- 接线：`CombatLayout`/`CombatActorStage` 暴露 `play_card_detailed()` / `resolve_targets()` / `enemy_candidates()` / `select_hand_card()` / `confirm_play()`；控制器在装配挂载侧**惰性单例**（多处手势必须共用，否则「选中的是哪张」出现多份真理来源）
- GDD：`combat-ui-system.md` §手牌交互 补 3 条 AC（选中抬起/描边、非法不可确认且保留选中、拒绝必须有提示）+ 新增「出牌目标选择」小节（五条策略表 + 存活判定口径 + 结果形状）
- 测试：新增 `test_combat_target_rules.gd`（19）+ `test_hand_selection_model.gd`（20）+ `test_combat_play_result.gd`（9）+ `test_combat_play_controller.gd`（14）+ `test_play_flow_cost_and_target.gd`（14，真实 CombatSystem + 真实 CostSystem）+ `test_hand_selection_visual.gd`（10）
- 全量：**3802 tests / 3801 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3692 → 净增 110）
- Tech debt：DEBT-CBT-018-10 追加「第六阶段已落地」；**DEBT-CUI-007-2 补记**——`hand_area.gd` 401 行（本轮新增前已 350 行，既有超限；本轮净增约 51 行），已写明按「排位与动画 / 快照与状态落定」两模块拆分的修复方向
- **已知边界**：① 施法者仍是「阵位首个存活角色」的临时裁定，**不是玩家选中的角色**——「当前操作角色」概念（interaction 001/004）落地后应改为显式传入；② 出牌手势本体（拖拽 ≥8px 启动 / 数字键 / 手柄）仍归 interaction 003/004——本轮只落闭环内核与选中视觉，**真实对局里还没有 InputEvent 驱动 `CombatPlayController`**；③ 目标选择可视化（拖拽中高亮 / 蓝色脉冲 / 箭头连线）归 interaction 005；④ `CombatTargetRules` 已支持多目标列表，但卡面 `target_type` 词表尚未驱动「哪些卡允许选多个目标」——UI 层目前一律接受多目标
- Next recommended: combat-ui-interaction 003（拖拽手势接线 + 8px 阈值状态机），落地后把施法者改成玩家选中的角色；或 interaction 005（目标选择可视化）

---


<!-- QA-PLAN：2026-09-08 | System：sprint-13 | Plan written：production/qa/qa-plan-sprint-13-2026-09-08.md -->
<!-- SPIKE：2026-09-08 | S13-1 R-01 | Report：production/spikes/r01-dual-focus-spike.md | OQ-02 已关闭 | R-01 已关闭 -->

## 当前任务

**S14-1 CI 配置——管道落地，残余失败已登记**（2026-09-21/22，提交 b429789 + f187efc）：

- `.github/workflows/tests.yml`：GitHub Actions + Godot 4.6.3 Linux headless 自托管下载 + GUT 全量；缓存二进制与 .godot 导入缓存；push/PR 触发
- 首跑 12 failing → 根因定位：event_system test_load_templates 8 个——向 `res://assets/events/<subdir>/` 写临时 .tres 但子目录是 git 不追踪的空目录，CI 干净检出后不存在 → ResourceSaver ERR_CANT_OPEN(19)。**git worktree 干净检出 100% 复现**
- 修复（f187efc）：before_each 对 7 个 TEST_SUBDIRS `make_dir_recursive`（测试自建自清理，card_system fixture 同款模式）→ 二跑 12→3
- 残余 3 个为测试非确定性（非代码 bug，非 CI 配置问题）：card_system ac006/ac009（load_threaded 完成顺序竞态，Linux 间歇红）+ realm ac010（已知 flaky）——**登记 TD-014 移交 S14-9**，CI 保持红是真实信号，不禁用不跳过
- 工作流注释已更新已知失败清单；sprint-status.yaml 14-1 → review

## 会话摘录——Sprint 18 战斗结算回流（2026-11-10）
- 半成品接手：三个红测（test_placeholder_scenes 的 3 例）实为 `.godot/global_script_class_cache.cfg` 陈旧所致，重新 `--import` 后自愈——未改测试、未降低占位契约
- 交付（战绩）：`combat_battle_record.gd`（效果条目计数 + 结束定格）→ `combat_system.battle_end` 并入 `rewards["record"]`；`combat_result_view.gd`（只读结算对象 + static 跨场景缓存）→ `combat_result_bridge.gd` 订阅 `battle_ended` 发布 → 结算/战败场景读回
- 交付（HP）：`combat_hp_carryover.gd` 开战读 / 结束写 `GSM.player.character_hp`（逐键写入 + 同值去重），写入经第二层原子方法 `_set_player_character_hp`；回读接口 `read_all` / `read_one` / `seed_stats`
- 降级口径：读——GSM 缺失 / 域非字典 / 无键 → 空表，回退模板 `base_hp`；写——缺 GSM 入口 → `WRITE_UNAVAILABLE`(-1) + 战斗侧 `push_error`，本场残血丢失但结算不受影响
- 展示抽层：新增 `src/ui/shared/battle_record_scene.gd`（结算/战败共用取数与降级），`result_screen.gd` / `defeat_screen.gd` 各只声明 SCENE_ID；`placeholder_scene.gd` 补暴露 `status_label` / `hint_label`
- 容器瘦身：`combat_scene.gd` 312 → 300 行，只读取数抽到 `combat_scene_readers.gd`；补 `_exit_tree` 退订结算发布器（信号源是常驻 Autoload）
- 顺带修 3 个真缺陷：① 无 `record` 的战败载荷被渲染成「战斗结束」（`"none"` 也在合法 token 表里，改由 `result` 兜底）；② 无效果卡的空占位条目被计入效果条目数；③ 字典卡只透传 `template_id` 导致击杀触发读不到内联 `effects`（与出牌路径口径不一致）
- 测试：新增 4 个文件 28 例（`test_battle_record_carryover` 8 / `test_battle_record_entries` 8 / `test_battle_result_end_to_end` 3 / `test_combat_result_bridge` 9）+ `test_combat_scene_wiring` 2 例
- 全量：**3722 tests / 3721 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3670 → 净增 52）
- 已知边界：① `SettlementHost._notification` 在场景销毁时对已释放对象调 `_disconnect_source` 产生 17 条 SCRIPT ERROR（改动前既有，非本轮引入，另案登记）；② 结算/战败场景仍是占位契约（标题/状态/摘要），非正式 UI；③ 阵亡 → `mark_unavailable` 仍归 interaction epic

## 会话摘录——S14-1 CI 落地 2026-09-21/22
- 文件：.github/workflows/tests.yml（新建）、tests/unit/event_system/test_load_templates.gd（before_each 自建目录）、docs/tech-debt-register.md（TD-014）、production/sprint-status.yaml（14-1 review）
- 提交：b429789（工作流）、f187efc（测试修复）——均已推送
- CI 运行：run 35594865340（12 fail）→ run 35719528459（3 fail，2595 pass）——管道本身工作正常
- 经验：GitHub job 日志下载需 git credential token + 签名 URL 分段（blob 下载不稳需重试循环）
- 下一步：S14-1 收尾（14-8 QA 签收时确认）；按 blocker 链选下一 story——S14-7 audio 001（解锁 main-menu 002 链）推荐


## Session Extract — /story-done 2026-09-11
- Verdict：COMPLETE WITH NOTES
- Story：production/epics/hud/story-004-notification-system.md — hud 004 通知/提示系统
- Tech debt logged：None（4 项 ADVISORY 均记入故事 Completion Notes 已裁决记录）
- Next recommended：hud 005 暂停菜单（production/epics/hud/story-005-pause-menu.md）——Sprint 13 最后一个 must-have 实现 story

## 会话摘录——/story-readiness 2026-09-11（hud 005）
- 故事：production/epics/hud/story-005-pause-menu.md——暂停菜单（全局覆盖层）
- 判定：主审 READY → QL-STORY-READY GAPS+INADEQUATE（1 INAD + 5 GAP）→ 用户四项裁决全推荐项 → 修订落地（提交 3274238）
- 裁决要点：INAD-1 音频 PauseAudioAdapter 接口+no-op 桩（回归项已登记 audio-manager story 005）；GAP-1/3 InputManager pause_requested 信号 + hud.request_pause(source) 统一入口；GAP-2 进度行降级「层 3」；GAP-5 保存并退出=存档后返主菜单/返回主菜单=直接转场；GAP-4 ColorRect+blur shader
- 附带发现：exploration_system.gd L363-367 map_states 快照缺 layers 键致读档重建恒空（S3 既有缺陷，归 exploration-ui epic 报 lead-programmer 跟进）
- 下一步：/dev-story production/epics/hud/story-005-pause-menu.md

## 会话摘录——/dev-story 2026-09-11（hud 005 实现完成）
- 故事：production/epics/hud/story-005-pause-menu.md——暂停菜单（全局覆盖层）
- 更改的文件：src/ui/hud/pause_menu.gd（新建）、PauseMenu.tscn（新建）、pause_audio_adapter.gd（新建）、pause_blur.gdshader（新建）、HUD.tscn/hud.gd（修改）、input_manager.gd（修改，GAP-1 信号）、test_gsm_sync.gd（修改，AC-006 例外裁决）
- 编写的测试：tests/integration/hud/test_pause_menu.gd（12 测试）+ test_pause_combat_state_preserved.gd（4 测试）
- 实现代理三次中断后交付；ESC 接线移 _ready() 直修（test_ac006 信号路由失败）；input AC-006 例外裁决修正
- 全量：2591 tests / 2589 passing / 1 pending / 1 failing（test_ac010 预存 flaky，非本次引入）——零回归
- 阻塞项：无
- 下一步：/code-review src/ui/hud/pause_menu.gd src/ui/hud/pause_audio_adapter.gd src/ui/hud/hud.gd src/foundation/input_manager.gd → /story-done

## Session Extract — /story-done 2026-09-11
- Verdict：COMPLETE WITH NOTES
- Story：production/epics/hud/story-005-pause-menu.md — hud 005 暂停菜单
- Tech debt logged：None（5 项 ADVISORY 均记入 Completion Notes）
- AC-2 HP/费用/牌库断言递延（战斗数据模型未建模——用户裁决）
- AC-4/AC-5 手动证据模板创建（pause-menu-evidence.md）——ADVISORY 待签收
- Code Review：双专家初审 CHANGES REQUIRED → 全修复 → 复审 APPROVED WITH SUGGESTIONS → 3 LOW 直修 2+补 2 回归测试
- Next recommended：Sprint 13 QA 签收（S13-7）——须先补 TD-006/013 + 本 story + hud 004 视觉证据

## Session Extract — /team-qa 2026-09-12（Sprint 13 QA 签收完成）
- Verdict：APPROVED WITH CONDITIONS（报告：production/qa/qa-signoff-sprint-13-2026-09-12.md，提交 498d335）
- 签收前置补齐链：负值 delta 朱砂红（TD-013 验证裁决，提交 6b20687，含回归测试）→ TD-006/013 证据文档创建签收（cultivation-bar / lingshi-deck-counter 各 8/8，提交 56ce7ea）→ debug 宿主 tests/manual/hud_debug.tscn 建立
- DoD 8/8 达成；must-have S13-1~6 全签收；测试 2598/2597/1 pending/0 failing 零回归
- 4 项遗留条件（不阻塞 gate）：主流程 E2E N/A（main-menu epic）/ CI 未配置 / 性能 Profiler 递延 S13-12 / realm test_ac010 flaky 建议 Sprint 14
- 下一步：/story-done 关闭 S13-7 → /retrospective → /gate-check

## Session Extract — /story-done 2026-09-12（S13-7 关闭）
- Verdict：COMPLETE（QA story 类型——交付物即签收报告，APPROVED WITH CONDITIONS）
- Story：production/epics/qa/story-001-sprint-13-qa.md — S13-7 Sprint 13 QA 签收
- sprint-status.yaml：13-7 done（must-have S13-1~7 全量完成），提交 0e643c2
- Next recommended：/retrospective → /gate-check（presentation-layer-complete，QA 已放行）

## Session Extract — /retrospective 2026-09-12（Sprint 13）
- 回顾已写入：production/retrospectives/retro-sprint-13-2026-09-12.md（提交 5316aec）
- 核心：must 7/7 + QA APPROVED WITH CONDITIONS + 零回归 + 25+ 缺陷全闭环；速度校准首次生效（偏差<20%）
- 短板：should/nice 7 项零启动（窗口剩 7 天）、回顾断档 Sprint 4-12、hud 005 实现代理三次中断
- 5 项行动项：Sprint 14 容量二次裁剪 / CI 配置 / test_ac010 flaky 根治 / 恢复回顾惯例 / ADVISORY 证据随关即补
- 下一步：/gate-check（presentation-layer-complete，QA 已放行）；或决策 should/nice 拉入

## Session Extract — /dev-story 2026-09-13（S13-12 R-03 spike 完成）
- Verdict：COMPLETE（spike 非 story——报告即交付物）
- 交付：production/spikes/r03-d3d12-smoke-spike.md + prototypes/r03-d3d12-smoke-spike/（harness + 双驱动 JSON + 截图）
- 结论：D3D12 冒烟通过无需回退；R-03 风险登记册已关闭；QA 签收条件 C 解除
- sprint-status.yaml：13-12 done（提交 93c8b34）
- 下一步：S13-8 R-06 Ogg 循环 spike（按既定建议继续）→ 之后视情况关闭冲刺（/gate-check + /sprint-plan new）

## Session Extract — /dev-story 2026-09-13（S13-8 R-06 spike 完成）
- Verdict：COMPLETE（spike 非 story——报告即交付物）
- 交付：production/spikes/r06-ogg-loop-spike.md + prototypes/r06-ogg-loop-spike/（harness + 测试音 + 双次运行 JSON）
- 结论：Ogg 循环实测零间隙零跳变（WASAPI + PCM 录制复跑稳定）——GDD「5-30ms 间隙」假设不成立；BGM 维持 WAV MVP，audio 002 解锁
- R-06 风险登记册关闭（提交 f43cd1c）；R-03 已于早前关闭（93c8b34）
- 下一步：关闭冲刺——/gate-check（presentation-layer-complete）→ /sprint-plan new（Sprint 14 容量二次裁剪）

## Session Extract — /gate-check 2026-09-13（presentation-layer-complete 里程碑检查）
- Verdict：FAIL（里程碑未达成——预期事实：1/2-3 冲刺，非质量信号）
- 四主管：CD NOT READY / TD CONCERNS / PR CONCERNS / AD READY——共识按计划继续 Sprint 14-15
- 报告：production/gate-checks/gate-check-presentation-layer-complete-2026-09-13.md（提交 be03fff）
- UX 状态字段同步（AD 建议当场执行）：hud/exploration-ui/combat-ui/pause-menu → Approved
- Sprint 14 前置条件（主管共识）：容量二次裁剪（PR 建议 must：main-menu 3 + 009b + audio 001）/ CI 第 1 周 / TD-007/012 排期 / 里程碑预估修正 3 冲刺起
- 下一步：/sprint-plan new（Sprint 14）——规划前先做容量裁剪决策

## Session Extract — /sprint-plan new 2026-09-13（Sprint 14 计划完成）
- PR-SPRINT 裁决：REALISTIC（MUST 6.0d/7.5d=80% 利用率，三项监督条件：Day-4 检查点/CI 0.5d timebox/R-02 provisional）
- 计划写入：production/sprints/sprint-14.md + sprint-status.yaml（14 stories，提交 ce0ac60）
- MUST：CI 配置 + main-menu 001-003 + 009a/009b（R-02 stub 实测）+ audio 001 + QA 签收
- SHOULD：TD-007/012+test_ac010 打包 + main-menu 004 + hud 006/007；NICE：main-menu 005 + hud 008
- 里程碑预估修正：3 冲刺起（Sprint 15 结转负载 12d+ 预警已记入计划）
- 下一步：/qa-plan sprint（实现开始前）→ /story-readiness（首个 story）

## Session Extract — /qa-plan sprint 2026-09-13（Sprint 14 QA 计划完成）
- QA 计划写入：production/qa/qa-plan-sprint-14-2026-09-13.md
- 分类：自动化 5 组（main-menu 001-003 + audio 001 + TD 补齐 ~64 用例）+ Visual/Feel 实测 2（009a/009b）+ CI 验证 + 冒烟 6 项
- 关键：009b 本地脚本不进 CI；R-02 provisional 关闭流程；分辨率 API 查证前置（main-menu 003）
- Sprint 14 管线就绪：计划+QA 计划均已写入——冲刺 09-21 启动
- 下一步：09-21 起按 sprint-status 顺序执行（S14-1 CI 或 main-menu 001 先行）

## Session Extract — /story-readiness 2026-09-19（main-menu 001 冲刺前预备）
- 判定：NEEDS WORK → QL-STORY-READY GAPS（3 BLOCKING + 4 ADVISORY）→ 用户三项裁决全推荐项 → 修订落地（提交 7242cda）
- GAP-1 制作人员按钮 GDD/UX 矛盾 → 移除（4 按钮：新游戏/继续/设置/退出，整合到通关片尾）——GDD 回写 wireframe/按钮列表/制作人员节/状态表/动画表/UI 需求表/验收标准，EPIC.md 计数 22→21
- GAP-2 has_continuable_save「全损坏→false」在 meta-list 输入下不可判定（meta.json 无损坏字段）→ 收窄语义：exists==true 判定，损坏检测归 load_game 读档时（与 AC-3 自洽）
- GAP-3 存档摘要章节字段无数据源 → 降级「上次：[境界] · 游玩 [时长]」（realm+playtime 取自 meta.json）；GAP-4 Estimate 填 1.0d；GAP-5 焦点顺序 4 按钮+初始焦点=继续游戏（无存档回退新游戏）；GAP-6 损坏提示后按钮恢复可用入 AC
- 附带：GDD 边界澄清新增 2 条（制作人员移除裁决+存档摘要数据源）；qa-lead 记忆新增 story001 审查记录
- ADVISORY 遗留：GAP-7 制作人员返回路径（随移除裁决失效，无需处理）
- 下一步：09-21 冲刺启动——S14-1 CI 或 S14-2 main-menu 001 /dev-story（story 已就绪，qa-lead 复审可在 dev-story 前快速过）

## Session Extract — /story-readiness 2026-09-19（main-menu 002/003 冲刺前预备）
- 判定：双双 GAPS（002：3 BLOCKING+3 ADVISORY；003：4 BLOCKING+5 ADVISORY）→ 用户七项裁决全推荐项 → 修订落地（提交 505143d）
- 002：总线 Music→BGM 对齐 audio 001 + yaml 14-3 加 blocker 14-7；UX 规范同步（应用按钮 10i+滑条预览语义+AC-SET-01+0.3s 对齐）；SFX 默认冲突裁决设置文件胜出（启动加载归 audio 005）；键盘 ← → 滑条调节入 AC-4
- 003：分辨率 API 引擎参考零覆盖（qa-lead 实测查证 12 文件）→ spike 独立条目 S14-4a（0.5d，yaml+sprint 计划已加）；画面类生效时机统一点应用；减少动态效果入 scope（AC-6）；恢复默认改注册机制（已注册分类重置+未实现占位不崩溃）；显示模式下拉移出 MVP
- GDD 边界澄清新增 4 条裁决记录；UX main-menu.md 组件表/AC-SET-01/Data Requirements 同步
- 遗留 ADVISORY（不阻塞）：002 滑条键盘路径已补；003 画质映射表数据文件断言方式、宽高比过滤规则（桌面宽高比）、720p 布局验证（AC-4 已补）
- 关键排期影响：S14-4a spike（0.5d）加入 must 链——MUST 总量 6.0d→6.5d，利用率 87%（仍 <100%，Day-4 检查点保底）
- 下一步：09-21 冲刺启动——S14-1 CI（无依赖）/ S14-4a spike（无依赖）可先行；main-menu 001→002 链按 blocker 顺序

## Session Extract — /story-readiness 2026-09-19（audio 001 冲刺前预备）
- 判定：GAPS（2 BLOCKING + 4 ADVISORY）→ 用户三项裁决全推荐项 → 修订落地（提交 8e17e27）
- GAP-1 R-06 的 GDD 修订义务（audio-system.md L135「5-30ms 间隙」+ 问题 #5）无载体 → 入 story 交付项（新 AC——spike 实测零间隙，引 r06-ogg-loop-spike.md）
- GAP-2「root 直挂 Node」过时描述 → 同步 ADR-0031 2026-09-09 修订版（SceneManager Autoload 子节点，经 register_persistent——scene_manager.gd L216 实存）
- ADVISORY 全修：Estimate 1.0d / bus_layout 经 project.godot 自动加载 / 两套默认 dB 时序关系固化（出厂基准→audio 005 启动覆盖）/ AudioState 枚举 12 值入本 story 骨架
- qa-lead 实证全过：11 API 签名与 GDD §8 一致、默认 dB 表一致、引擎参考 audio.md 有覆盖（无 spike 需求——与 003 分辨率零覆盖不同）
- Sprint 14 预备就绪度总结：main-menu 001/002/003 + audio 001 四个 must story 闭环；修订链 7242cda→505143d→8e17e27
- 排期注意：S14-3 加 blocker 14-7（audio 001 先行）；S14-4a spike 新条目——MUST 6.5d/7.5d=87%
- 下一步：09-21 冲刺启动——S14-1 CI / S14-4a spike / S14-7 audio 001 三个无依赖入口任选（audio 001 做完即解锁 002 链）

## Session Extract — /story-readiness 2026-09-19（009a/009b 冲刺前预备——就绪度清零）
- 判定：双双 GAPS（009a：1 BLOCKING+2 ADVISORY；009b：3 BLOCKING+1 ADVISORY）→ 用户三项裁决全推荐项 → 修订落地（提交 b32691c）
- 009a：get_rendering_info 引擎参考零覆盖（story 误写前提已有）→ AC-7 改官方文档为源+回写引擎参考义务+Monitor 降级路径；Dependencies 与 EPIC.md 顺序声明一致化（001 与 009a 并行前置）
- 009b（三项 BLOCKING 同一根因——story 未吸收 stub 版提前到 Sprint 14 的 PR-SPRINT 监督条件 #3）：Dependencies 改仅依赖 009a+双复测义务登记（epic DoD 组件级+Sprint 15+interaction 峰值）；Implementation Notes 增 stub 版声明（占位原型构造，实测为原型级）；AC-1/2 加 stub 标注；AC-7 改 provisional 关闭；AC-4 720p 字号降级占位抽检（font_size_responsive 归 story 001）
- qa-lead 结论：009b 三项 BLOCKING 是文本级而非结构级（不改变故事骨架），修复后无需全量复审
- **Sprint 14 预备就绪度总结（本会话四连，6 story 全闭环）**：main-menu 001（7242cda）/ 002+003（505143d）/ audio 001（8e17e27）/ 009a+009b（b32691c）
- 排期固化：S14-4a spike 新条目（0.5d）；14-3 加 blocker 14-7；MUST 6.5d/7.5d=87%（<100%，Day-4 检查点保底）
- 下一步：09-21 冲刺启动——无依赖入口：S14-1 CI / S14-4a 分辨率 spike / S14-7 audio 001 / S14-5 009a（四个任选）；按 blocker 链推进

## Session Extract — /story-readiness 2026-09-20（should 层三 story 冲刺前预备）
- 判定：全 GAPS（004：1B+3A；006：2B+3A；007：2B+2A）→ 用户五项裁决全推荐项 → 修订落地（提交 7b6d24c）
- main-menu 004：注册机制承接（AC 注册条目+AC-4 用例+blocker 加 14-4）；警告音降级日志占位；InputMap 重置快照法
- hud 006：双路径订阅（max_val 恒 0+双写吞域信号——不改 GSM）；地图名附建最小表；层数 +1 换算；阈值 provisional
- hud 007：坊市降级纯函数级（shop 场景未落地）；时间注入方案；映射键改 SceneID 对；集成文件名改正
- qa-lead 核心发现：三 story 信号/枚举引用存在性全过，缺口集中在可实现性语义层（hud 002 is_fallen 同模式——5 BLOCKING 中 4 个纯文本修订级）
- **Sprint 14 预备全景（两个会话五连，9 story 全闭环）**：must 6（001/002/003/audio001/009a/009b）+ should 3（004/006/007）——main-menu 001→7242cda、002/003→505143d、audio001→8e17e27、009a/b→b32691c、should 三连→7b6d24c
- nice 层（main-menu 005/hud 008）未验——nice 层被裁概率高，留冲刺中按需
- 下一步：09-21 冲刺启动——四无依赖入口任选：S14-1 CI / S14-4a 分辨率 spike / S14-7 audio 001 / S14-5 009a（main-menu 001 无 blocker 亦可）

## Session Extract — audio 001 code-review 修复与提交 2026-09-24
- 判定：三方审查（gdscript/godot 主专家/qa-tester）→ CHANGES REQUIRED（B-1 转场测试假覆盖）→ 用户裁决全修 → 闭环
- B-1：补 test_audio_manager_node_pool_survives_real_transition（真实 change_scene_to_file + 帧轮询，hud 先例）+ 修正原测试误导注释
- H-A：scene_manager 音频访问器 RefCounted→AudioManager 强类型 + preload 常量（解决 S-1）
- H-B：adapter _missing_bus_warned 按总线去重一次性告警
- H-C：守卫正则补 static func + 注释改述；S-6 refcounted 断言改 assert_false(am is Node)（Variant 持有避免解析器恒假报错——踩坑记录）
- QA GAP-1~3 补齐：未知枚举防御/set_audio_manager 注入/null scene_manager 空池
- 全量验证：2628 tests / 2626 pass / 1 pending / 1 fail——唯一 fail = realm ac010（TD-014 既有 flaky；对照实验证明与本次修改无关：还原旧版 scene_manager 后同败）
- 提交：34e0383（feat 实现）+ 3ed43bc（story 勾选+证据状态）——均已推送；story 验收 6/6 勾选、Test Evidence 标 passing
- sprint-status：14-7 → review
- 下一步：/story-done production/epics/audio-manager/story-001-bus-layout-manager-skeleton.md（CI 观察随推送——预期仅 TD-014 已知红）

## Session Extract — /story-done audio 001 2026-09-24
- 判定：COMPLETE（6/6 AC 全过；测试证据 BLOCKING 项双满足）
- 验证明细：文件存在性✓/GDD R-06 修订落地✓（L135+L620）/GDD §8 11 API 签名逐字对照✓/零新增 Autoload（恒 25 条）✓/硬编码值检查✓（仅 MUTE_VOLUME_DB 语义常量，dB 数据真源在 .tres）
- QL-TEST-COVERAGE：ADEQUATE（full 模式 qa-lead 逐文件独立核实——B-1/H/GAP 修复全部真实存在，AC-1~4 全覆盖；3 条 ADVISORY：Reverb 参数归 006、静默恢复等价实例路径、隔离先例好评）
- LP-CODE-REVIEW：已履行（三方并行审查闭环：CHANGES REQUIRED → 全修 → APPROVED WITH SUGGESTIONS）
- story 状态：Complete + Completion Notes；EPIC.md 索引同步；sprint-status 14-7 → done（completed 2026-09-24）
- 提交：34e0383（feat）+ 3ed43bc（story 勾选）+ 524a6fe（14-7 review）已推送；story-done 状态提交随本轮
- **Sprint 14 进度**：must 7 项中 14-1✓ 14-7✓ 已完成，剩余 14-2（main-menu 001，无 blocker 可开工）/14-4a spike/14-3（blocker 14-2 未解）/14-4/14-5/14-6/14-8
- 下一步：/story-readiness main-menu 001 → /dev-story（或 14-4a spike 无依赖入口任选）

## Session Extract — main-menu 001 code-review+提交 2026-10-04
- 判定：三方审查（qa-tester GAPS / godot-specialist ISSUES FOUND / gdscript-specialist APPROVED WITH SUGGESTIONS）→ CHANGES REQUIRED → 用户裁决全修+GAP 补齐 → 闭环
- 修复：BLOCKER-1 主场景 uid→path（原指向 prototypes 旧原型！）；H-1/H-2/H-3 枚举去魔数+Variant 注解+重入守卫；GAP-1 焦点真实路径（二次实例化）；GAP-3/4/5 补测试（竞态/静态守卫/双触发源）；S-1/S-6
- 留桩语义：identity_select.tscn 相邻 story——Completion Notes 已声明
- 验证：集成 20/20（226 断言）+ 单元 20/20 + 全量 2667/2668 零失败（1 pending 既有）；--import 生成 .gd.uid 入库
- 提交：c835968（feat 实现）+ 3f61e8e（story 勾选+Completion Notes）——已推送；CI gh 不可用，下次会话观察
- 下一步：/story-done production/epics/main-menu/story-001-main-menu-scene.md（UI 手动证据 main-menu-scene-evidence.md 待创建——AC-5 手动演练+AC-6 性能 D3D12 实测）

## Session Extract — /story-done main-menu 001 2026-10-04
- 判定：COMPLETE（8/8 AC 全过；UI 手动证据已签收）
- 关卡：QL-TEST-COVERAGE ADEQUATE（AC-1~4 逐条 COVERED + GAP-1/3/4/5 修复独立核实非名义补丁；2 条 ADVISORY：H-3 双弹不可观测留后续、骨架态性能复测归视觉 story）；LP-CODE-REVIEW APPROVED（H-1 无循环依赖+ADR-0031 四红线零违规+main_menu.gd 293 行贴线达标）
- 手动验证：用户实测通过（0.8s 动画/键盘鼠标全可达/退出真关闭/60fps/Draw Call≤50/720p 无溢出）→ evidence 文件创建并签收
- story：Complete + Completion Notes；EPIC.md 索引同步；sprint-status 14-2 → done（completed 2026-10-04）
- 提交：d80f180（story 关闭）已推送
- **Sprint 14 进度**：must 7 项中 14-1✓ 14-2✓ 14-7✓ 已完成；14-3（main-menu 002 设置音频，blocker 14-2 已解）/14-4a spike（无依赖）/14-4/14-5/14-6/14-8 可按序开工
- 下一步：/story-readiness production/epics/main-menu/story-002-settings-audio.md → /dev-story

## Session Extract — /dev-story main-menu 002 2026-10-04
- 故事：production/epics/main-menu/story-002-settings-audio.md——设置面板框架与音量控制
- 实现：ui-programmer 子代理交付（7 新文件+2 修改）；settings_panel.gd 299 行贴线达标；Autoload 恒 25 零新增
- 关键裁决落地：三滑条 Master/BGM/SFX 实时总线生效（get_bus_index 动态查找）；应用持久化/未保存回滚；拖动零文件写入护栏；merge 写入保留 Story 003 未来键
- 测试：26 新增（db_from_percent 9 + 回滚 6 + 总线 11 含三滑条×三值参数化 use_parameters 首次使用）；main_menu 域 60/60
- 全量回归：2686/2688——唯一 fail = realm ac010（TD-014 既有 flaky，单跑 14/14 过——非本次引入）；1 pending 既有
- 偏差：未保存关闭无确认弹窗（story AC 直接回滚语义，确认弹窗归 003 统一脏检测）；AC-4 手动证据待编辑器演练（可听验证降级为总线 dB 表读数——2026-10-04 裁决）
- 提交：522418d 已推送
- 下一步：/code-review src/ui/main_menu/（settings_logic.gd settings_store.gd settings_panel.gd SettingsPanel.tscn main_menu.gd）→ /story-done

## Session Extract — /dev-story + /story-done main-menu 003 2026-10-10
- 故事：production/epics/main-menu/story-003-settings-graphics.md——画面设置与应用/回退（含全局恢复默认）
- 实现：ui-programmer 子代理交付 8 源文件（settings_graphics_logic.gd Logic 内核 / graphics_tab.gd 画面子组件 / corrupt_save_dialog.gd 拆分 / settings_store.gd 六键+注册机制 / settings_panel.gd 编排 / main_menu.gd 减负 / 两 .tscn）
- 关键裁决落地：filter_resolutions 三参签名 / 宽高比过滤 filter_by_aspect_ratio / 画质预设数据驱动映射表 / 未保存关闭确认弹窗 / register_reset_handler 全局恢复默认注册 / 先 refresh 后 set_values 防空下拉越界 / CorruptSaveDialog popup_centered+重入守卫
- 测试：3 文件 22 测试（filter_fallback 8 + unsaved_changes 7 + graphics_apply 7）——AC-1/2/3 全绿；全量 2722/2723，唯一 fail = realm ac010（TD-014 既有 flaky，非本次引入）
- 偏差（ADVISORY）：settings_panel.gd 336 行超软限 12% / 全屏仅测 true 方向 / is_equal_approx 近似比较 / MSAA 意图声明 / UI 证据文件待签收
- 关卡：QL-TEST-COVERAGE ADEQUATE + LP-CODE-REVIEW APPROVED（full 模式双关卡）
- 提交：b09cda4（feat）已推送；story 关闭 + sprint-status 14-4 → done（completed 2026-10-10）
- 下一步：14-5 combat-ui-layout 009a 合批方案定型（ready-for-dev，无 blocker）→ /story-readiness → /dev-story

## Session Extract — /dev-story + /story-done combat-ui-layout 009a 2026-10-11
- 故事：production/epics/combat-ui-layout/story-009a-batching-scheme.md——R-02 合批方案定型（前置架构 spike）
- 实现：架构 spike + 方案定型（无 src/ 生产实现；原型代码按放宽标准 `prototypes/r02-batching-spike/` 隔离）
- 关键查证：RenderingServer.get_rendering_info 存在（RENDERING_INFO 枚举 11 项 0..10，TOTAL_DRAW_CALLS_IN_FRAME=2）；结论回写 docs/engine-reference/godot/modules/rendering.md
- 实测（16 角色卡，RTX 3050 Vulkan Forward+ 窗口模式）：baseline 0 / full 96 DC / 6.0 DC·位——「≤4 DC·位」不可行（HP 条 3 draw_rect=3 DC + 文字非单次 draw call），用户裁决 2026-10-11 接受 6 DC/位；整场景 96 << 200 达标，峰值重算 ≈201 贴线
- 产出：production/qa/evidence/r02-batching-spec.md（五节合批规范：图集/HP条 draw_rect/DC 分组/fallback 裁剪/测量方法）+ prototypes/r02-batching-spike/（spike.gd + benchmark.gd + README.md，009b 复用测量方法）
- 偏差（ADVISORY）：≤4 DC/位未达标但接受 / fallback 裁剪升级硬约束 / 实测后端 Vulkan 非 D3D12（009b 满场复核）
- Code Review：SKIPPED（架构 spike 无 src/ 实现，prototypes 按放宽标准隔离）
- 提交：5638f2d 已推送；story 关闭 + sprint-status 14-5 → done（completed 2026-10-11）
- 下一步：14-6 combat-ui-layout 009b R-02 Draw Call 满场实测 stub 版（blocker 14-5 已解除）→ /story-readiness → /dev-story

## Session Extract — /dev-story + /story-done combat-ui-layout 009b 2026-10-11
- 故事：production/epics/combat-ui-layout/story-009b-drawcall-benchmark.md——R-02 Draw Call 满场实测（stub 版）
- 实现：扩展 009a 原型为标准/峰值两场景（16 角色位+7 手牌+2 阵法+费用栏+日志折叠；峰值加结算面板+攻击箭头 stub+阵法光环+飘字满发）——程序化占位节点，无 src/ 生产实现（prototypes 按放宽标准隔离）
- 实测（Godot 4.6.3 / Vulkan Forward+ / RTX 3050 窗口模式）：baseline 0 / 标准场景 126 DC / 峰值场景 132 DC——两场景均 <<200 达标；帧时间 p50=16.66ms（=60fps），p95=16.92ms（微超 16.6ms，VSync 抖动——ADVISORY）
- 产出：prototypes/r02-fullfield-benchmark/（benchmark.gd + README.md）+ production/qa/evidence/r02-benchmark-evidence.md（五节：两场景 DC/帧时间分布/烟雾 stub 声明/fallback 验证/720p 字号）+ risk-register R-02 更新为「有条件关闭（stub 版原型级验证）」
- 偏差（ADVISORY）：p95 帧时间微超 / D3D12 烟雾 3 项未实跑（Vulkan 后端+程序化占位）/ fallback 优先级实测未触发（余量 68 DC）/ 720p 字号抽检占位
- 复测义务双登记：① combat-ui-layout epic DoD（Sprint 15，真实组件+D3D12）② combat-ui-interaction epic 关口（拖拽半透明+峰值交互）
- Code Review：SKIPPED（架构 spike 无 src/ 实现，prototypes 按放宽标准隔离）
- 下一步：14-8 Sprint 14 QA 签收（blocker 14-1~14-7 全部 done，现唯一未完成 Must Have）→ /story-readiness → /dev-story

## Session Extract — /dev-story + /story-done Sprint 14 QA 签收（14-8）2026-10-11
- 故事：production/epics/qa/story-001-sprint-14-qa.md——Sprint 14 QA 签收报告
- 签收结论：**APPROVED WITH CONDITIONS**——must-have 8 项全交付（14-1 CI + 14-2/3/4 main-menu + 14-4a spike + 14-5/6 combat-ui 009a/009b + 14-7 audio 001 + 14-8 本签收）
- 零回归验证：GUT 全量 2723 tests / 2722 passing / 1 pending（save_load 多步迁移占位）/ **0 failing**（realm ac010 本次复跑通过——TD-014 既有 flaky 已移交 S14-9）
- DoD 对照：8/8 达成（测试+证据 / CI 上线 / R-02 有条件关闭+双复测义务 / 主菜单可达设置 / audio 骨架 / 零回归 / 代码审查合并 / 冒烟——唯一遗留为手动冒烟演练，见条件 C）
- 遗留条件（不阻塞 gate）：A=TD-014 flaky 根治（S14-9 should） / B=R-02 正式关闭（Sprint 15 组件级复测） / C=主菜单 E2E 冒烟（手动编辑器演练）
- 附带：14-1 状态 review → done（CI workflow 已提交 b429789+11d56a0，全量测试绿——签收时补正）
- 下一步：Sprint 14 must-have 全清 → /retrospective（回顾）→ /sprint-plan new（Sprint 15 规划）→ /gate-check presentation-layer-complete（里程碑推进）

## Session Extract — /retrospective + /sprint-plan new + /gate-check（Sprint 14 收尾）2026-10-13
- 回顾：`production/retrospectives/retro-sprint-14-2026-10-13.md`——must 8/8 + 零回归 + R-02 有条件关闭；UI story 真实成本校准为 2 日历日/story（行动项 #1）
- Sprint 15 规划：`production/sprints/sprint-15.md` + `sprint-status.yaml` 已切到 sprint 15（4 must：TD-014 根治 + exploration-ui 001 R-05 关闭 + combat-ui-layout 001/002；must 利用率 93% 触上限，PR-SPRINT REALISTIC WITH CONDITIONS）
- 里程碑关口检查：`production/gate-checks/gate-check-presentation-layer-complete-2026-10-13.md`——**FAIL（符合预期）**：7 epic 0/7 完整、全流程仅主菜单段可达；主管判定：创意总监 NOT READY、制作人 NOT READY（PR-MILESTONE）、技术总监 CONCERNS、美术总监 CONCERNS
- 范围仲裁决策点（已写入里程碑文件）：四位主管共识「应砍范围而非仅延里程碑」——预估轨迹 2-3→3+→5+ 三次发散未收敛（实算 45 story ≈ 10-11 冲刺）；提议关口拆两段（MVP 核心循环可演示 / full）+ must 上限降 80% + 技债专属槽位
- 里程碑文件已更新：目标日期修正 + 实际承载表 + 范围仲裁决策点节
- 下一步：Sprint 15 实现开始——S15-1 TD-014 根治 → S15-2 exploration-ui 001（R-05 关闭）→ S15-3/4 combat-ui-layout 001/002；实现前先跑 /qa-plan sprint

## Session Extract — /qa-plan sprint 15 2026-10-15
- QA 计划已写入：`production/qa/qa-plan-sprint-15-2026-10-15.md`（9 story 全覆盖——4 must + 3 should + 2 nice）
- 重点关卡：S15-1 TD-014 闭环标准 = **CI 连续两跑绿**（非单次）；S15-2 R-05 基准 = 目标硬件 D3D12 窗口实测 + risk-register 更新 + 证据文档
- 自动化测试预估 ~85 个（TD-014 修改 3 + TD-007/012 新建 12 + combat_ui 30 + audio 22 + main_menu 10 + hud 8）
- 手动证据 5 份（R-05 基准 / layout 001 / card 002 / 003 / keybind 004）——visual/feel+UI 双轨
- 冒烟新增路径：主菜单三标签页往返 / TD-014 CI 稳定性 / R-05 基准场景 / combat-ui debug 宿主
- 下一步：S15-1 TD-014 根治（/story-readiness → /dev-story）——连续三冲刺结转的 must 硬关口

## Session Extract — S15-1 TD-014 根治 + TD-007/012 补齐 2026-10-16
- Story: S15-1（docs/tech-debt-register.md TD-014/007/012 打包）——must，连续三冲刺结转的硬关口
- 修改文件：
  - tests/integration/card_system/test_card_system_loading.gd（ac006 重试驱动 + ac009 顺序不敏感断言 + after_each 排空线程加载——提交 4da6dc4 + 9b52a54）
  - tests/integration/realm_system/test_realm_up.gd（ac010 _await_gsm_flush 有界轮询替代单帧 await）
  - tests/integration/hud/mocks/hud_mock_gsm.gd（新建——player 域 + 三信号 mock）
  - tests/integration/hud/test_realm_bar_signal_wiring.gd（新建 11 测试——TD-007）
  - tests/integration/hud/test_lingshi_deck_apply_deck_wiring.gd（新建 8 测试——TD-012）
  - docs/tech-debt-register.md（TD-014/007/012 划线关闭）+ .github/workflows/tests.yml（注释更新）
- **TD-014 闭环证据：CI run 38897918496（9b52a54）连续两跑绿**（attempt 1 + rerun attempt 2 均 success——2740 tests/2739 passing/1 pending 占位）——PR-SPRINT 监督条件 #2 兑现
- 真因发现：ac006 CI 失败非「加载慢」——是 ac003/ac005 提交 load_threaded_request 后不驱动完成即删 fixture，后台线程迟滞打开已删文件发出 engine ERROR 被 GUT 归罪到后续运行的 ac006（Windows 快机不显形/Linux 慢机显形——「Linux 间歇红」特征完全吻合）
- 本地验证：全量 2740 tests/2739 passing/1 pending（89.58s）；card_system 连续三跑全绿；hud 84/84；realm 14/14
- S15-1 状态：review（实现完成+CI 双跑绿，待 /story-done 类关闭流程——但 S15-1 是技债打包项无故事文件，sprint-status 标 review 即完成态）
- 下一步：S15-2 exploration-ui 001 节点图基座+R-05 基准（/story-readiness → /dev-story）

## Session Extract — S15-2 exploration-ui 001 节点图基座 + R-05 关闭 2026-10-17
- Story: S15-2 exploration-ui 001（must，R-05 行为关卡）——实现+基准+证据+风险关闭全链完成
- 新建文件：
  - src/ui/exploration/node_graph_renderer.gd（单 Control _draw() 合批：节点图集 region+边框+文字、连线金实线/暗虚线 draw_dashed_line、迷雾整体覆盖层挖孔）
  - src/ui/exploration/node_graph_viewport.gd（滚轮 50%-150% 光标锚定缩放 0.2s 平滑 + 中键/边缘平移 + 空格复位 + 整图适配 + 50% 标签隐藏联动 + input_frozen 弹窗冻结）
  - src/ui/exploration/node_icon_atlas.gd（10 类节点程序化图集 320×32，static 缓存单实例合批前提）
  - prototypes/r05-node-graph-benchmark/（benchmark.gd + README——复用 R-02 测量方法）
  - production/qa/evidence/r05-node-graph-benchmark-evidence.md（三 AC 数据 + 签收表 3/3）
- R-05 基准结果（D3D12 窗口 + VSync off，RTX 3050，1280×720）：AC-1 p95=2.04ms（预算 16.6ms 余量 8 倍）/ AC-2 静态=缩放中=90 DC（预算 200）/ AC-3 迷雾 16→8 节点 DC 90→73 非线性（合批成立）——三 AC 全过
- R-05 已关闭（risk-register 更新：🔴 高 → 🟢 低，story 010 真实元素复测义务登记）
- 关键坑固化：renderer Control size=0 时持续平移 ~200 帧后 canvas item 剔除整帧 DC 归零（D3D12/Vulkan 均复现）——PRESET_FULL_RECT 锚点规避，已写入 NodeGraphViewport._init
- 引擎 API 探测：draw_rect_modulate 不存在；draw_dashed_line 存在（width=-1.0, dash=2.0, aligned=true）
- **CI flaky 修复（提交 6db5b6f）**：ac010 间歇失败（Windows ~20% 复现）真因 = 无 await 测试残留 GSM pending 泄漏到下一测试 + deferred flush 交错——after_each 直调 _flush_pending_changes 排空（TD-014 同源模式）。CI run 38998504322 连续两跑绿（attempt 1+2 均 success——TD-014 闭环标准）
- 提交：920abf9（实现+基准+证据）+ 6db5b6f（ac010 flaky 修复）均已推送
- S15-2 状态：review（Visual/Feel 性能关卡——基准证据已签收，待 /story-done 正式关闭）
- 下一步：S15-3 combat-ui-layout 001 战场四区域布局骨架（/story-readiness → /dev-story）

## Session Extract — S15-3 combat-ui-layout 001 布局骨架 2026-10-17
- Story: S15-3 combat-ui-layout 001（must）——实现+测试+证据全链完成
- 新建文件：
  - src/ui/combat/layout/combat_layout.gd + CombatRoot.tscn（五区域 anchor 百分比骨架 + 进场过渡 + 按钮位 + 音频对接）
  - src/ui/combat/shared/combat_ui_font.gd（font_size_responsive 共享纯函数——002-006 消费禁止内联）
  - tests/unit/combat_ui/test_font_size_responsive.gd（8 测试——QA 规格 AC-1 全边界）
  - tests/integration/combat_ui/test_layout_skeleton.gd（12 测试——五区域存在/anchor/720p 无溢出重叠/按钮位/HUD 战斗隐藏+退出恢复/reduce_motion/过渡完成态/音频 IN_COMBAT 契约）
  - production/qa/evidence/combat-layout-skeleton-evidence.md（AC-4 手动项归档 + 签收 3/3）
- 实现要点：anchor 百分比（60/340/180 ÷1080 比率）零像素硬编码；进场 Tween 一次性（零轮询）；AudioManager 注入式（零新增 Autoload）；HUD 隐藏消费 post_transition 矩阵（hud 001 已兑现——集成测试锁定）
- 字号档位语义修正：<720 档直接保底 12（非 max(round(x*0.85),12)）——QA 规格字面「719→12」；720 档过保底 max(round(x*0.85),12)——edge base=14@720→12
- 本地验证：combat_ui 20/20；全量 2760 tests/2759 passing/1 pending（占位）
- CI run 39003941151（0650083）success
- 提交：0650083 已推送
- S15-3 状态：review（待 /story-done 正式关闭）
- 下一步：S15-4 combat-ui-layout 002 角色状态卡 L0-L5 六层渲染（blocker 15-3 已解除）


## Session Extract — S15-4 combat-ui-layout 002 角色状态卡 2026-10-17
- Story: S15-4 combat-ui-layout 002（must）——实现+测试+证据全链完成
- 新建文件：
  - src/ui/combat/shared/combat_ui_rules.gd（hp_bar_color 0.6/0.3 阈值集中 + formation_row_scale 1.0/0.85 纯函数）
  - src/ui/combat/shared/combat_icon_atlas.gd（stub 程序化图集 256×32——8 格图标 + L1 渐变遮罩；真实图标归美术管线）
  - src/ui/combat/layout/character_status_card.gd（L0-L5 单 Control 自绘：头像全幅/遮罩/左右 28px 功法法宝栏各≤3/HP条 draw_rect+ATK/buff≤5+境界角标/待命标记/前后排边框）
  - tests/unit/combat_ui/test_hp_bar_color.gd（4）+ test_formation_row_scale.gd（3）
  - tests/integration/combat_ui/test_character_card_signal.gd（13——信号驱动/批量免抖/reduce_motion/守卫/无轮询/纯函数消费源码断言/合批共享）
  - production/qa/evidence/character-card-evidence.md（签收 3/3）
- 实现要点：R-02 §3 合批分组（图标单图集 draw_texture_rect_region + HP draw_rect 纯色 + 单合并 Label——零子节点拆分）；HP 0.3s Tween 同帧多次 kill 重建终值；阈值集中 CombatUiRules（禁止硬编码）；消费 story 001 CombatUiFont（禁止内联——源码断言锁定）
- 本地验证：combat_ui unit 15/15 + integration 25/25；全量 2780 tests/2779 passing/1 pending（占位）
- 提交：d42964b 已推送（网络重试 6 次后成功）
- S15-4 状态：review（待 /story-done 正式关闭）
- 下一步：S15-5 audio-manager 002 BGM 交叉淡化（should）或 S15-6 combat-ui 003（blocker 15-4 已解除）

## Session Extract — S15-5 audio-manager 002 BGM 交叉淡化 2026-10-17
- Story: S15-5 audio-manager 002（should）——实现+测试全链完成
- 新建文件：
  - src/ui/audio/bgm_fade_planner.gd（纯计划器——GDD §9 矩阵数值集中；平行/渡劫 sequential/
    中断续接从实际 dB/同 id 空计划/降低类单 Bus 指令不切曲；duck 判定先于同 id 检查）
  - tests/unit/audio/test_bgm_fade_planner.gd（12 测试）
  - tests/integration/audio/test_bgm_crossfade.gd（5 测试——真实 Tween 0.05s 缩放+await；
    程序生成 1.0s 静音 WAV 对象注入 _stream_overrides）
- 修改：src/ui/audio/audio_manager.gd——执行层轮换映射（_current_player_index 0/1 翻转）、
  _execute_fade_plan 返回 bool、边缘 #1 前置解析（任一目标曲损坏→整计划放弃+状态零变更+
  push_warning 降级）、ResourceLoader.exists 静默预检
- 关键修复：①测试流时长 0.1s→1.0s（等待窗口内播完致 playing=false）②固定 players[0]/[1]
  断言→_cur/_nxt 轮换 helper ③损坏路径 push_error→push_warning（GUT Unexpected Errors 判失败）
  ④前置解析块移至 kill_fade_tween 之前（避免「Tween no Tweeners」引擎错误）
- 本地验证：audio 24/24 全绿；全量 2798 tests / 2797 passing / 1 pending（既有占位）
- 提交：bf9da74 已推送 + CI success；37d9c13 状态更新推送中
- S15-5 状态：review（待 /story-done 正式关闭）
- 下一步：S15-6 combat-ui-layout 003 状态标记/阵亡/飘字（blocker 15-4 已解除）或 S15-7 main-menu 004

## Session Extract — S15-5 GAPS 补强完成 2026-10-17
- GAPS 测试（test_bgm_duck_sequential.gd 5 测试）全绿 → audio 套件 29/29，全量 2808 passing / 1 pending
- 关键实现修复：sequential 模式 play() 经 tween_callback set_delay 延迟触发
  （AC-BGM-08 字面语义——此前音量停 -80dB 但 playing=true）
- 关键测试修复：目标侧引用须在 play_bgm 之前捕获（成功即翻转 _current_player_index，
  切换后 _nxt 测到旧 a 侧）；preload_next 断言改 resolve 消费在途请求
- 提交：11bd2d6（GAPS 补强）+ a47c885（story 证据段）——均推送 CI success
- 下一步：/story-done 阶段 5 LP-CODE-REVIEW（full 模式）→ 完成报告 → story 关闭

## Session Extract — /story-done S15-5 audio-manager 002 关闭 2026-10-18
- Verdict：COMPLETE WITH NOTES（1 项 ADR 漂移登记——冷路径同步回退，story 004 接线时保证切曲恒走预加载）
- LP-CODE-REVIEW：CHANGES REQUIRED → R-1（duck 总线续接基线）/R-2（duck 污染 _current_bgm_id）修复 + 回归测试 2 条（004fc05，CI 绿）
- QL-TEST-COVERAGE：GAPS 四项全部补强（11bd2d6，CI 绿）——test_bgm_duck_sequential.gd 7 测试
- 测试总量：audio 31/31；全量 2810 passing / 1 pending
- Story：production/epics/audio-manager/story-002-bgm-crossfade.md → Complete
- 冲刺状态：15-5 done（2026-10-18）
- 建议性改进遗留（不阻塞）：_execute_fade_plan 拆分（40 行+复杂度）、audio_manager.gd 351 行超 300 软上限、文档注释三处失同步、stop_bgm 缓存保留头清理、MUTE_VOLUME_DB 与 SILENCE_DB 重复定义
- 下一步：S15-6 combat-ui-layout 003 状态标记/阵亡/飘字（blocker 15-4 已解除）

## Session Extract — Sprint 15 遗留状态清理 2026-10-18
- S15-1/2/3/4 review 遗留补关（证据签收齐备+CI 绿——仅状态未翻转）：
  全部 → done；冲刺 must-have 项 15-1~15-4 全部闭环
- 提交 1b0eb83 + 5a9ea82 已推送
- 冲刺剩余：15-6 combat-ui 003（should，blocker 15-4 已解除——就绪）、
  15-7 main-menu 004（should）、15-8 hud 006（nice）、15-9 audio 003 SFX 池（nice）
- 下一步：S15-6 combat-ui-layout 003 状态标记/阵亡/飘字

## Session Extract — S15-6 combat-ui 003 实现完成 2026-10-18
- 实现+测试全链完成（ui-programmer 子代理两轮迭代后全绿）：
  - src/ui/combat/feedback/combat_feedback_coordinator.gd（编排器——AC-1 入队合并/AC-2 标记切换/
    AC-3 全灭短路转发/AC-4 阵亡流程）
  - src/ui/combat/feedback/floater_pool.gd（16 上限飘字池）
  - src/ui/combat/layout/empty_slot_frame.gd（空位虚线框）
  - character_status_card.gd 扩展 is_acted 灰色遮罩（is_standby 旧语义不变）
  - 测试：test_hp_batch_transition.gd (21 场景) + test_death_flow.gd + test_floater_pool.gd
    + mocks/mock_combat_signals.gd——combat_ui 53/53，全量 2838 passing / 1 pending 存量
- 提交 63f11ca 推送 CI success
- headless 修复三个实际问题：飘字方向符号（y+ 向下）、tween chain 完成回收改 finished 信号、
  帧数等待改 SceneTreeTimer 实时等待
- 遗留（不阻塞）：①ACTED 无官方逐角色信号——request_acted() 外部驱动入口（战斗侧阶段接线
  story 消费）②治疗按 damage 符号判定（CardEffectEngine 独立信号时需同步）③UI 手动证据
  待录屏签收（ADVISORY）
- 下一步：/story-done S15-6（LP-CODE-REVIEW full 关卡）

## Session Extract — /story-done S15-6 combat-ui 003 关闭 2026-10-18
- Verdict：COMPLETE（7/7 AC——含文字通道裁决方案 B 推迟）
- Story：production/epics/combat-ui-layout/story-003-state-markers-death-floaters.md
- LP-CODE-REVIEW 全链：CHANGES REQUIRED → H-1 坐标空间修复（spawn 全局→局部换算+缩放卡+空位框同父局部）
  + M-2 CountingCard 计数断言 + AC 文字裁决（game-designer 方案 B，DEBT-CUI-003 登记+GDD 加注+沙漏 0.3s 淡出补齐）
  → 提交 5289133 CI 绿 → 定向复审 APPROVED → 微瑕修正 65a4eca
- 建议项一并修复：M-1 全灭守卫/L-1 空卡跳过/L-2 modulate 恢复/死 API card_lookup_cb 移除（setup 四参）
- 证据：UI 手动证据 character-state-death-evidence.md 签收 3/3（ADVISORY 闭环）；combat_ui 57/57；全量 2842/1 pending 存量
- Tech debt logged：1 项（DEBT-CUI-003 文字通道）
- Sprint 15 剩余：15-7 main-menu 004 按键绑定（should，1.0 天）→ 15-8 hud 006（nice）→ 15-9 audio 003（nice）
- Next recommended：S15-7 main-menu 004 按键绑定界面（含启动加载）

## Session Extract — /story-done S15-7 main-menu 004 关闭 2026-10-20
- Verdict：COMPLETE（7/7 AC——冲突检测/往返/注册机制全自动化，AC-3 手动走查 12 项签收 3/3）
- Story：production/epics/main-menu/story-004-keybind-remapping.md — main-menu 004 按键绑定界面（含启动加载）
- 关卡（full 模式）：QL-TEST-COVERAGE ADEQUATE（3 条 ADVISORY：跨设备单测/入口级 E2E/界面刷新断言）；LP-CODE-REVIEW 定向复审 APPROVED（H-1/H-2/H-3/M-A 修复核实真实存在未回退，ADR-0031 红线 25 Autoload/零状态所有权/零轮询全合规）
- 测试证据：unit 13 + integration 19 全绿；全量 2875/2874 passing/1 pending 存量（本地复跑验证）
- 实现链提交：b252ba5（feat）+ 7ed1076（H 修复）+ 9b2bc07（M-1 方案 B）+ afe3488（M-A）+ 395f665（证据签收）——均已推送
- Tech debt：DEBT-MM-004 已登记（三文件超 300 行 + KeybindStore 读写重复——epic 收尾前拆分 story）；无需新增
- Sprint 15 剩余：15-8 hud 006（nice，0.5d）/ 15-9 audio 003 SFX 池（nice，1.0d）——must/should 全清
- Next recommended：冲刺收尾流程——/retrospective → /sprint-plan new（或先拉 15-8/15-9 nice 项）；工作区注意：资产侧 2 个未提交改动（asset-manifest.md + ui-icons-assets.md）属另一线程，勿混入本 story 提交

## Session Extract — /story-readiness hud 006 冲刺中预备 2026-10-20
- 判定：NEEDS WORK → QL-STORY-READY GAPS（2 BLOCKING + 1 ADVISORY）→ 用户裁决全部采纳 → 修订落地
- GAP-1 总层数数据源：备选路径 map_states[map_id].layers 不可行（键从未写入）；主审建议 _map_config[map_id].layers 亦被 QL 驳回（扁平无 map_id 键 + 读档清空）→ 收窄为 get_total_layers() DAG 缓存推导（max(node_id)/100+1）
- LP 跨域预协调（ExplorationSystem 加只读方法）：APPROVED WITH CONDITIONS 五条件并入——空集防御 push_warning+默认值 1 / doc 注释 / 禁用测试桩 API 取层数 / exploration 侧三例单测 / 守卫先例改 move_to_node 系（get_node_graph 是无守卫测试桩）
- GAP-2 AC-2 补域信号用例（restore_action_points 单写走 action_points_changed——对齐 story 002 双路径对偶先例）；GAP-3 未知 map_id 回退「未知地域」+push_warning
- 三处修订均为文本级（不动骨架），Test Evidence 补 exploration 侧条目；story 维持 Ready 可直接 /dev-story
- 下一步：/dev-story production/epics/hud/story-006-exploration-hud-info.md（S15-8，nice，0.5d）

## 会话摘录——/dev-story hud 006 探索信息组 2026-10-20
- 故事：production/epics/hud/story-006-exploration-hud-info.md——探索 HUD 右下信息组（S15-8）
- 更改的文件：src/ui/shared/ap_display_rules.gd（新建 84 行——AP 阈值+分段共享纯函数）、
  src/feature/exploration_system.gd（+29——get_total_layers 只读方法，LP 五条件全遵守）、
  src/ui/hud/exploration_info_area.gd（新建 240 行）、ExplorationInfoArea.tscn（新建）、
  HUD.tscn（挂载到既有占位）、tests/unit/hud/test_ap_color_threshold.gd（13）、
  tests/unit/exploration_system/test_get_total_layers.gd（6——新建非追加，目录一主题一文件惯例）、
  tests/integration/hud/test_gsm_signal_binding.gd（9→15，+6 含域信号 restore_action_points 路径）
- 独立复跑验证：全量 2900 tests / 2899 passing / 1 pending 存量 / 0 failing——零回归（编排者亲自 headless 复跑）
- LP 条件独立核实：双守卫（_dag_ready + is_empty）落地 / 组件 grep 无测试桩 API 调用 / 守卫先例注释正确
- 偏差（ADVISORY）：①exploration 侧新建文件而非追加（目录组织惯例——语义等价）②阈值边界语义「≤ 含边界」（1/5→critical、5/10→warning——单测锁定，签批后如调整须同步）③分段格文本占位字符 █/░（真实图集归美术管线）④exploration_system.gd 594 行既有超限（+29 纯增量）
- 阻塞项：无代码阻塞；production/qa/evidence/exploration-hud-info-evidence.md 手动证据待创建签收（AC-3/AC-4——ADVISORY 级）
- 下一步：/code-review src/ui/shared/ap_display_rules.gd src/ui/hud/exploration_info_area.gd src/feature/exploration_system.gd → /story-done

## 会话摘录——hud 006 LP-CODE-REVIEW 修复闭环 2026-10-20
- LP-CODE-REVIEW（full 首审）：CHANGES REQUIRED——H-1（HUD.tscn 容器 anchors_preset=3 零 offset，
  组件 200×90 展开到屏幕底边以下整体不可见——测试独立实例化组件故抓不到）+ M-1（未知地图
  push_warning 在幂等守卫前，AP 双发射下刷屏）
- 用户裁决全修：H-1 锚点改 preset 2 + offset -216/-106/-16/-16（16px 边距规范）；
  M-1 守卫前移（首见告警一次）；S-1 顺手补 _connect_once doc 注释
- 修复后全量 2900/2899 passing/1 pending 存量/0 failing——零回归
- 定向复审：APPROVED（三处修复逐项核实通过；LP 五条件/ADR-0031 红线首审已全过）
- QL-TEST-COVERAGE：ADEQUATE（AC-1 全 edge case/AC-2 双路径含域信号/LP④三例全覆盖；
  3 ADVISORY：域信号用例不可区分性【GSM 伴随发射系统属性】/「未知地域」回退零覆盖【规格自身缺口】/
  测试函数名 three_of_five_returns_warning 与断言 normal 不符）
- 遗留：AC-3/AC-4 手动验证 evidence（production/qa/evidence/exploration-hud-info-evidence.md）
  待用户进探索场景目视确认后签收——H-1 正是该类缺陷，headless 不可替代
- 建议项登记（不阻塞）：S-2 位置刷新搭便车脆弱点（exploration-ui epic 补订阅）/
  S-3 层数文本集成断言可注入 mock / S-4 story 证据路径 exploration→exploration_system 更正
- 下一步：用户手动验证 AC-3/AC-4 → /story-done story-006（呈完成报告→裁决关闭）

## Session Extract — 美术资产线收尾 2026-10-20（本会话·独立于 hud story 线）
- 提交 8 个（84efc06~9f73a50），全部只含本线文件，未触碰 hud/main-menu story 改动
- combat-entities spec（ASSET-282~326）+ 实体立绘 56 张四批生成落盘
  assets/characters/enemies|npcs/（MVP 15 + VS 25 + FV 14 + 天劫尾款 2；积分 774→606）
- VFX spec（ASSET-327~338，12 程序动效，7 项跨文档冲突按美术圣经优先裁决——
  阵亡晕染 vs 碎裂与 DEBT-CUI-003 关联需登记）
- 音频 spec（ASSET-339~370，25 条纯描述；响度以 audio-system 为准；
  采样率统一 48kHz/24bit 源）
- manifest 总数 316→398；速查表已同步；待规范仅剩环境场景扩展 ~30
- 用户验收：56 张实体候选件在 Downloads/jimeng_entities/ 待抽检
  （重点：古魔残躯三阶段/天劫 4 变体/妖兵 3 变体）
- Next（本线）：①用户抽检后按名重生成不满意张 ②环境场景扩展 spec
  （~30，等事件系统推进时定 6 事件类型清单）③VFX spec 阵亡条目与
  combat-ui 003 实现差异登记 DEBT

## Session Extract — /story-done hud 006（2026-10-20）
- Verdict: COMPLETE WITH NOTES（H-2 墨字可见性修复——PanelBackground 米白 #F5F0E3 @85%）
- Story: production/epics/hud/story-006-exploration-hud-info.md — 探索 HUD 右下信息组
- Tech debt logged: None（H-1/H-2/M-1 均在 LP 复审前闭合，非遗留）
- 手动验证：hud_debug.tscn 窗口目视 AC-3/AC-4 通过（米白卡片可见 + 分段格熄灭/点亮/变色）
- evidence: production/qa/evidence/exploration-hud-info-evidence.md（签收）
- 建议项（未阻塞，随 exploration-ui epic）：S-2 位置刷新搭便车 / S-3 层数断言可注入 mock / S-4 story 证据路径更正
- Next: 提交 hud 006 本线文件（不含 design/assets/*）

## Session Extract — /story-done audio-manager 003（2026-10-23）
- Verdict: COMPLETE WITH NOTES（调优参数 const 硬编码 → SfxPoolConfig 数据驱动资产，LP 初审 REJECT 后闭环）
- Story: production/epics/audio-manager/story-003-sfx-pool.md — SFX 池 16 节点池与淘汰/冷却/随机化
- Tech debt logged: None（S-1/S-2/S-3 与补静音语义留待 story 004，非遗留阻塞）
- 测试：test_sfx_pool.gd 18 例 + test_bus_layout 挂载 2 例 + api_skeleton 白名单扩展；全量 2920 passing / 1 pending 存量
- Next: sprint 15 全 9 故事完成 → /smoke-check sprint → /team-qa sprint → /retrospective → /gate-check → /sprint-plan new

<!-- QA RUN: 2026-10-24 | Sprint: sprint-15 | Verdict: APPROVED WITH CONDITIONS | Report: production/qa/qa-signoff-sprint-15-2026-10-24.md -->

<!-- QA-PLAN：2026-10-24 | System：sprint-16 | Plan written：production/qa/qa-plan-sprint-16-2026-10-24.md -->

<!-- IDENTITY-CLOSURE：2026-10-24 | story 001/002/003 状态翻转 Complete（Sprint 12 遗留实现）+ story 004 UI 场景创建 | 28/28 identity 测试通过 -->

## Session Extract — /dev-story identity-selection 004（2026-10-24）
- Verdict: 实现完成（3 测试缺陷已修复 + 1 契约修正 is_input_allowed 签名）
- Story: production/epics/identity-selection-system/story-004-identity-select-ui.md — 身份选择 UI 场景
- 文件: src/ui/identity_select/identity_select.gd + identity_select.tscn（新增）
- 测试: test_identity_unlock_gate.gd 8 例（新增）+ test_menu_navigation.gd 追加 2 例
- 全量: 2931 tests / 2930 passing / 1 pending 存量（save_load 占位，非本次引入）
- 引擎风险修正: 读档跳过 post_transition+call_deferred / 卡片 FOCUS_ALL / is_input_allowed 设备区分
- Next: /code-review src/ui/identity_select/identity_select.gd → /story-done story-004

## Session Extract — /story-done identity-selection 004（2026-10-24）
- Verdict: COMPLETE（10/10 AC 通过；code-review 两轮闭环）
- Story: production/epics/identity-selection-system/story-004-identity-select-ui.md — 身份选择 UI 场景
- Deviations: 音频最小接入（set_state 替代 SFX，归 audio 004）/ 本地化豁免 / UI evidence 待补（ADVISORY）
- Tech debt logged: None（偏差均为 story 范围豁免，非遗留阻塞）
- 测试: test_identity_unlock_gate.gd 10 例 + test_menu_navigation.gd 追加 2 例；全量 2933/2932/1 pending 存量
- Next: S16-2 exploration-ui 002 地图选择界面（ready-for-dev）

## Session Extract — /dev-story exploration-ui 002（2026-10-26）
- Verdict: 实现完成（4 纯函数 + 场景落盘 + 薄容器闭合 EXPLORATION 占位）
- Story: production/epics/exploration-ui/story-002-map-select-screen.md — 地图选择界面
- 文件: src/ui/exploration/map_card.gd + map_select_screen.gd + map_select_screen.tscn（新增）；src/feature/exploration/exploration_scene.gd + .tscn（新增薄容器）
- 测试: test_map_select_logic.gd 14 例（新增，14/14 passed）
- 场景验证: exploration_scene.tscn 加载 → MapSelectScreen 挂载 → 8 张卡片渲染（headless 验证通过）
- 引擎风险: 脚本 new() vs PackedScene.instantiate()（.tscn 节点树须 instantiate）
- 依赖缺口: stub 载荷（get_map_list/reentry 契约 Feature 层未实现）——UI 侧 fallback，补齐后替换
- Next: /code-review src/ui/exploration/map_select_screen.gd → /story-done story-002

## Session Extract — /code-review exploration-ui 002（2026-10-26）
- Verdict: CHANGES REQUIRED（4 专家并行审查——LP/GDScript/godot-specialist/qa-tester 各 CHANGES REQUIRED/GAPS）
- Required 修复（全数落地）：余额标签前缀 bug（TEXT_TITLE→TEXT_BALANCE_PREFIX）/ 苍玄古战场路由缺陷（QA-S16-2-001，新增 entry_action 纯函数+5 回归测试）/ 锁定卡 TRANS_BACK 过冲→TRANS_QUAD / 死代码删除（scene_manager/pending_enter_id/TEXT_BALANCE_SUFFIX）
- 建议采纳：键盘 ui_accept 激活卡片 / 手柄设备限定（防吞方向键焦点）/ 卡片 SHRINK_CENTER 防拉伸 / 资源类型过滤 / stub 拆分 map_data_stub.gd（map_select_screen 407→372 行）
- 测试: test_map_select_logic.gd 14→19 例（entry_action 5 回归含苍玄古战场），19/19 passed；场景加载验证 8 卡渲染
- Next: 全量测试套件确认 → /story-done story-002

## Session Extract — /story-done exploration-ui 002（2026-10-26）
- Verdict: COMPLETE WITH NOTES（10/10 AC 通过；code-review 四路并行 + Required 全闭环）
- Story: production/epics/exploration-ui/story-002-map-select-screen.md — 地图选择界面
- Deviations: 本地化豁免 / stub 载荷先行（map_data_stub.gd）/ UI evidence 待补（ADVISORY）
- Tech debt logged: None（偏差均为 story 范围豁免，非遗留阻塞）
- 测试: test_map_select_logic.gd 19 例（含 entry_action 5 回归 + QA-S16-2-001 苍玄古战场）；全量 2952/2951/1 pending 存量
- 缺陷修复: QA-S16-2-001（苍玄古战场路由）/ QA-S16-2-002（余额标签前缀）
- Next: S16-3 exploration-ui 003 节点图数据接入（blocked by 16-2——现已解锁）

## Session Extract — /dev-story + /code-review + /story-done exploration-ui 003（2026-10-27）
- Verdict: COMPLETE WITH NOTES（12/12 AC 通过；LP-CODE-REVIEW 两轮 REJECT→APPROVE、QL-TEST-COVERAGE 两轮 GAPS→闭环）
- Story: production/epics/exploration-ui/story-003-node-graph-data-states.md — 节点图数据接入与节点状态渲染
- 文件: src/ui/exploration/node_state_logic.gd（Logic 内核 6 纯函数）+ node_graph_data_stub.gd + map_generated_stub.gd + node_graph_screen.gd/.tscn（新增）；node_graph_renderer.gd（六态渲染 + tooltip + 渡劫台灰斜线 + 金色脉冲）；src/feature/exploration/exploration_scene.gd（挂载点 + trigger_map_load）
- 测试: test_node_state_logic.gd 22 例（单元）+ test_node_graph_render.gd 18 例（集成）——全量 2991/2992 + 1 pending 存量，零回归
- Required 修复（code-review 首轮 REJECT 全闭环）：B-1 stub 回退判定（Autoload 存在→map_generated 信号源存在）+ 端到端 trigger_map_load 回归；H-1 AC-8 渡劫台灰斜线；H-2 AC-10 悬停 tooltip（_gui_input 命中检测，零轮询）；H-3 _fogged_positions states 分支对称
- QL-TEST-COVERAGE GAPS 闭环：AC-9 连线 _is_edge_visited 两例；AC-11 渡劫台金色脉冲（TRIBULATION_GLOW_COLOR 类型恒常发光）+ 精英红边框 border_is_type 断言
- Deviations: 本地化豁免 / stub 载荷先行（Feature 层 map_generated/get_node_detail 未实现）/ UI evidence 待补（ADVISORY）
- Next: S16-4 audio 004 set_state 编排与过渡矩阵（should-have，ready-for-dev，未阻塞）

## Session Extract — /dev-story + /code-review + /story-done audio 004（2026-10-30）
- Verdict: COMPLETE WITH NOTES（6/6 AC 通过；code-review 四路并行，2 阻塞项全闭环）
- Story: production/epics/audio-manager/story-004-state-matrix.md — set_state 编排与过渡矩阵
- 文件: src/ui/audio/state_transition_matrix.gd（新增，Logic 内核 24 行矩阵真源）+ src/ui/audio/audio_manager.gd（set_state 编排 + _enter_state + _on_pre_transition 信号绑定）+ src/foundation/scene_manager.gd（TRANSITION_AUDIO_PARAMS 数值修正）
- 测试: test_state_matrix.gd 67 例（单元）+ test_scene_signal_binding.gd 42 例（集成）+ scene_manager 72 例——全量 3019/3020 + 1 pending 存量，零回归
- Required 修复（code-review 2 阻塞项全闭环）：①循环 preload 环解耦（矩阵本地 TT_*/SCENE_IDENTITY_SELECT 镜像常量 + 枚举交叉断言守护，删 _SceneManager preload）；②set_state N/A 状态漂移（_current_state 推进移到 row 非空检查后——N/A 回滚 + push_warning）；③is_connected 防护（对齐 hud.gd 先例）
- 测试缺口补齐：entry_bgm 全 10 态映射 / N/A 回滚×2（单元+信号路径）/ 矩阵↔TRANSITION_AUDIO_PARAMS 交叉断言 / AC-3 魔数→枚举常量 / 双 AudioManager 监听清理（不调 sm._ready + set_audio_manager）
- Deviations（ADVISORY，非遗留阻塞）：①主菜单启动引导缺口（归属 story 007）；②TRANSITION_AUDIO_PARAMS dead data（后续 story 清理）；③GDD §9「22 行」vs 实表 24 行漂移；④MAIN_MENU 引导淡入 0.5s vs 矩阵 1.5s；⑤QA 缺口 6/7 待裁决
- Next: S16-5 combat-ui-layout 004 顶部条三组件（should-have，ready-for-dev，未阻塞）

## Session Extract — /dev-story + /code-review + /story-done combat-ui-layout 004（2026-11-01）
- Verdict: COMPLETE WITH NOTES（8/8 AC 通过；code-review 四路并行，6 实现缺陷 + 测试缺口全闭环）
- Story: production/epics/combat-ui-layout/story-004-topbar-indicator-formation-log.md — 顶部条三组件（阶段指示器/阵法区/战斗日志）
- 文件: src/ui/combat/layout/phase_indicator.gd + formation_zone.gd + combat_log.gd + combat_topbar.gd（新增）；combat_layout.gd（挂载 CombatTopbar）
- 测试: test_phase_indicator_signal.gd 11 例 + test_log_phase2_autocollapse.gd 7 例 + test_formation_zone.gd 7 例（集成）+ mocks——全量 3044/3045 + 1 pending 存量，零回归
- Required 修复（code-review 6 缺陷全闭环）：①日志面板高度锚定父控件→视口 50% 换算（get_viewport_rect + is_inside_tree 兜底）；②阵名解析链断裂→FormationZone 内 _resolve_slot（formation_info_cb/tag_color_cb 回调）；③滚动陈旧 max_value→call_deferred 帧末读新鲜值；④set_initial_phase 孤儿→battle_started 信号绑定（阶段 0 + 回合 1）；⑤formation_deactivated 清空槽位→set_slot_active(false) 保留阵名（DEPLOYED_UNACTIVE 语义）；⑥DEFAULT_AURA_COLOR 死代码→真实兜底
- 测试缺口补齐：get_step_states 进度格 / 阶段切换音回调 / 切换动画 Tween（reduce_motion 跳过）/ 半屏 50% 断言 / 滚动真实底部（max_value - page）
- Deviations（ADVISORY，非遗留阻塞）：①本地化豁免（LABEL_TEXT/PHASE_NAMES 中文硬编码）；②font_size 硬编码（13/14/18 归 accessibility）；③CombatTopbar.unbind_signals 未实现（信号源与组件同生死）
- Next: S16-6 combat-ui-layout 005 费用栏与牌库/弃牌计数（should-have，未阻塞）

## Session Extract — /dev-story + /code-review + /story-done combat-ui-layout 005（2026-11-01）
- Verdict: COMPLETE WITH NOTES（7/7 AC 通过；code-review 四路并行，1 BLOCKING + 4 HIGH 全闭环）
- Story: production/epics/combat-ui-layout/story-005-cost-bar-deck-counters.md — 费用栏与牌库/弃牌计数
- 文件: src/ui/combat/shared/combat_ui_rules.gd（cost_color 纯函数 + COST_COLOR_* 常量）+ src/ui/combat/layout/cost_bar.gd + deck_counter.gd + end_turn_button.gd + combat_bottombar.gd（新增）；combat_layout.gd（挂载 CombatBottombar 到 bottombar）
- 测试: test_cost_color.gd 9 例（单元）+ test_cost_display.gd 14 例（集成）+ mocks——全量 3067/3068 + 1 pending 存量，零回归
- Required 修复（code-review 1 BLOCKING + 4 HIGH 全闭环）：①cost_changed 信号未接线→bind_signals 增加 cost_source + _on_cost_changed 解包（total_max - max_show = temporary）；②载荷语义 mismatch→_on_cost_changed 显式换算；③淡出 re-entry 竞态→_apply_texts 临时分支 kill_tween + alpha 复位；④淡出不可见→_play_temp_fade 前置 visible+alpha；⑤布局固定 1920→_place_ratio 改 size.x 基准
- LOW 修复：PLAY_PHASE 常量（去魔法数 2）/ _reset_jump_scale（非消耗路径 scale 复位）/ has_jump_anim_active+has_temp_fade_active 探针（替代直访私有成员）/ 测试注释修正
- Deviations（ADVISORY，非遗留阻塞）：①光粒消散粒子本体归 009b（本 story 仅数字跳动+淡出）；②本地化豁免（LABEL_TEXT/[+N临时]/≡牌库:N 硬编码）；③GDD §129 vs §716 主数字显示矛盾待 game-designer 协调
- Next: S16-7 combat-ui-layout 006 手牌弧形渲染（should-have，未阻塞）

## Session Extract — /dev-story + /code-review + /story-done combat-ui-layout 006（2026-11-02）
- Verdict: COMPLETE WITH NOTES（8/8 AC 通过；code-review 四路并行，1 BLOCKING + 2 HIGH 全闭环）
- Story: production/epics/combat-ui-layout/story-006-hand-arc-rendering.md — 手牌弧形渲染与静态状态
- 文件: src/ui/combat/shared/hand_arc_rules.gd（新增——hand_card_position/card_overlap_offset/hand_card_z_index 三纯函数）+ src/ui/combat/layout/hand_card.gd + hand_area.gd + enemy_hand_back.gd（新增）；combat_layout.gd（挂载 HandArea）
- 测试: test_hand_card_position.gd 11 例 + test_card_overlap_offset.gd 7 例 + test_hand_card_z_index.gd 7 例（单元）+ test_hand_area.gd 12 例（集成）+ mock_hand_signals.gd——全量 3104/3103 + 1 pending 存量，零回归
- Required 修复（code-review 1 BLOCKING + 2 HIGH 全闭环）：①≤7 张几何偏离 GDD §1→改回半径法圆弧（radius×sin / radius×(1-cos) 微笑弧，仅 >7 张走间距优先）；②快照刷新闭环断裂→on_hand_changed 消费 hand_changed 载荷驱动 apply_hand；③4 Label 违背 R-02 §3 合批→draw_string 单 _draw 合批 + EnemyHandBack 未设 size→锚定 0.5/0.12H + size 随卡背数同步
- LOW 修复：Array 类型标注 / 深拷贝（duplicate(true) 不污染调用方）/ _draw_tween 独立句柄 kill（避免与重排并发写同一卡）/ reduce_motion 溢出提示不残留 / 窄屏响应式卡宽测试补齐（AC-4 唯一期望锁定）
- Deviations（ADVISORY，非遗留阻塞）：①卡面美术 stub（插画归资产管线）；②满 10 溢出飞弃牌堆动画实体归 feedback 层（本 story 只落提示 2s 淡出）；③card_drawn/card_overflow/hand_changed 三信号 CombatSystem 尚无发射点（mock 契约锁定，stub 先行）；④本地化豁免（无手牌/溢出提示/类型标签 6 词硬编码）
- Next: S16-8/16-9 为 nice-to-have（audio 005 暂停静音 + hud 008 静音图标 + main-menu 005 语言切换）——冲刺 should 层已全部关闭，进入冲刺收尾流程

<!-- QA RUN: 2026-11-02 | Sprint: sprint-16 | Verdict: APPROVED WITH CONDITIONS | Report: production/qa/qa-signoff-sprint-16-2026-11-02.md -->

<!-- QA-PLAN：2026-11-02 | System：sprint-17 | Plan written：production/qa/qa-plan-sprint-17-2026-11-02.md -->

## Session Extract — /story-done 2026-11-07
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/exploration-ui/story-005-node-move-interaction.md — 节点移动交互流与教程覆盖
- AC: 9/9 通过；AC-1 迷雾/AC-5 悬停 110%/AC-6 翻转三项视觉通道归 QA-17-1 D3D12 走查
- 测试: 集成 43 例 + 单元 12 例全绿；全量 3166 tests / 3165 passing / 1 pending 存量 / 3 orphans 存量，零回归
- 关卡: LP-CODE-REVIEW = CONCERNS（teardown 状态复位已修 + `_is_reachable_node` 契约守卫已修）；QL-TEST-COVERAGE = GAPS → 6 项关键缺口已补测
- 新增文件: src/ui/exploration/{node_move_interactor,node_move_animator,node_move_overlays,node_keyboard_navigator,node_tutorial_overlay}.gd；tests/integration/exploration_ui/{test_node_move_interaction.gd,mocks/mock_exploration_system.gd}；tests/unit/exploration_ui/{test_node_keyboard_navigator,test_node_move_overlays}.gd；production/qa/evidence/node-move-interaction-evidence.md
- 修改文件: src/ui/exploration/{node_graph_renderer,node_graph_screen}.gd；production/epics/exploration-ui/story-005-node-move-interaction.md；production/sprint-status.yaml；docs/tech-debt-register.md
- Tech debt logged: 4 项（DEBT-EUI-005-1~4：reason 错误码化 / 合并双份快照 / 动画参数外置 / 抖动断言）
- Next recommended: 17-2 combat-ui-layout 007 部署面板框架（must-have, 2.0d）

## Session Extract — /story-done exploration-ui 005（2026-11-07）
- Verdict: COMPLETE WITH NOTES（9/9 AC 通过；QL GAPS 6 项缺口全补测、LP CONCERNS 3 项 H 全修）
- Story: production/epics/exploration-ui/story-005-node-move-interaction.md — 节点移动交互流与教程覆盖
- 关卡闭环: LP-CODE-REVIEW CONCERNS → H1(HUD toast 接线→技债 DEBT-EUI-005-6) / H2(_mouse_exited 非虚方法→改连 mouse_exited 信号+2 测试) / H3(屏幕层到达信号暴露+7 例转发测试)；M1 命中框与悬停放大同源、M4 缓冲保留设备类型均已修
- 新增测试: tests/integration/exploration_ui/test_node_graph_screen_forwarding.gd（7 例：三条到达转发 + toast 转发 + 键盘焦点转发 + 换图清焦点）
- 最终计数: exploration_ui 集成 68/68 + 单元 53/53；全量 3166 tests / 3165 passing / 1 pending 存量 / 3 orphans 存量，零回归
- Tech debt logged: 6 项（DEBT-EUI-005-1~6：reason 错误码化 / 合并双份快照 / 动画参数外置 / 抖动断言已闭环 / interactor 拆分 / HUD toast 延后接线）
- 待办: QA-17-1 D3D12 视觉走查（证据文档 §2 十项）
- Next recommended: 17-2 combat-ui-layout 007 部署面板框架（must-have, 2.0d）

## Session Extract — /story-done combat-ui-layout 007（2026-11-07）
- Verdict: COMPLETE WITH NOTES（7/7 AC 通过；AC-1/AC-2 视觉通道归 QA-17-2 D3D12 走查）
- Story: production/epics/combat-ui-layout/story-007-deploy-panel-framework.md — 备战面板（视觉框架与状态判定）
- 关卡闭环: LP-CODE-REVIEW CONCERNS（0 阻塞 / 6 HIGH / 7 MEDIUM / 3 LOW）→ H1~H6 全修（push_warning 暴露未注入 / load_roster 单次取数 / 上限收缩 / 单测读真实部署常量 / 替换指定位 / 宿主接线 7 例）、M7~M13 全修、LOW14~16 处理（LOW16 登记技债）
- 测试: combat_ui 单元 88/88 + 集成 143/143；全量 3241 tests / 3240 passing / 1 pending 存量 / 3 orphans 存量，较 17-1 基线净增 75 例，零回归
- Tech debt logged: 3 项（DEBT-CUI-007-1 文案本地化 / -2 双文件超 300 行 / -3 自绘入口风格并存）
- 待办: QA-17-1 D3D12 视觉走查（10 项）+ QA-17-2 备战面板走查（证据文档 §2 八项）
- Next recommended: 17-3 exploration-ui 006 节点交互弹窗（must-have, 1.5d）

## Session Extract — /story-done exploration-ui 006（2026-11-08）
- Verdict: COMPLETE WITH NOTES（11/11 AC 通过；AC-11 的 A8 帧率抽查按 PR-SPRINT C2 裁决归 QA-17-4 ADVISORY）
- Story: production/epics/exploration-ui/story-006-node-interaction-popups.md — 节点交互弹窗（五类+分发表）
- 实现: 新增 4 文件（node_interaction_rules 纯函数内核 / node_interaction_popup 弹窗单体 / node_popup_blur_mask 背景模糊 / node_interaction_popup_host 宿主）+ 修改 node_graph_screen（挂载+双路径快照下发+键盘冻结）+ tests/manual/node_popup_debug.tscn 走查宿主
- 自查修复 4 项: close_popup 幂等守卫（改 _open_kind）/ 冻结幂等 _frozen / node_moved 后 apply_snapshot 重下发（战斗弹窗锚定）/ 遮罩抽为组件
- 测试: 单元 28 + 集成 30 + 屏幕层装配 7（新增）；exploration_ui 单元 81/81 + 集成 105/105；全量 单元 2386(1 pending 存量) + 集成 956/956（59 脚本），零回归
- Tech debt logged: 5 项（DEBT-EUI-006-1 宿主 373 行拆分 / -2 Feature 层缺 use_action_spring+rest_at_node / -3 文案本地化 / -4 AP 指示器未订阅 spring_used / -5 弹窗固定尺寸）
- 同时提交 17-1 遗留文件（commit 3b0d901：node_move_* / node_keyboard_navigator / node_tutorial_overlay / renderer 悬停焦点 / story-005 关闭 + 证据）
- 待办: QA-17-1 D3D12 视觉走查（10 项）+ QA-17-2 备战面板（8 项）+ QA-17-4 弹窗与 A8 帧率（8 项）
- Next recommended: 17-4 combat-ui-layout 008 结算/撤退面板（must-have, 2.0d）

## Session Extract — /story-done combat-ui-layout 008（2026-11-08）
- Verdict: COMPLETE WITH NOTES（10/10 AC 通过；五场景视觉走查归 ADVISORY 待 QA 签收）
- Story: production/epics/combat-ui-layout/story-008-settlement-retreat-panels.md — 结算与撤退面板框架
- 实现: 新增 10 文件（settlement_rules / retreat_rules 双内核 + settlement_frame / settlement_fade / settlement_panel_view / loot_option_card 共享构件 + settlement_panel / retreat_dialog / tribulation_warning_dialog 三面板 + settlement_host 宿主）+ 修改 combat_layout.gd（撤退按钮 + 宿主装配）+ 走查宿主 tests/manual/settlement_panel_debug.*
- 自查修复: 5 项（panel_fits_within_viewport 入内核 / defeat_title 补 / confirm_button.disabled 取反 3 处 / 灰显卡可选中补 option_clickable 守卫 / 孤儿节点改 add_child_autofree）
- 重构: settlement_panel.gd 395→300 行（抽出 View 构建器 + Fade 开合）；三个面板共用 SettlementFade，retreat_dialog 207→189、tribulation_warning 187→169
- 测试: 单元 44 + 集成 31（新增）；combat_ui 单元 149/149 + 集成 193/193；全量 单元 2430(1 pending 存量)/2429 + 集成 987/987（60 脚本），零回归
- Tech debt logged: 4 项（DEBT-CUI-008-1 本地化 / -2 combat_layout 366 行 / -3 战利品不补足三选一 / -4 reduce_motion 无全局入口）
- 待办: QA-17-1 D3D12 视觉走查（10 项）+ QA-17-2 备战面板（8 项）+ QA-17-4 弹窗与 A8 帧率（8 项）+ 本次结算面板五场景走查（10 项）
- Next recommended: 冲刺收尾（must-have 4/4 完成）→ /smoke-check sprint → /team-qa sprint → /retrospective → /gate-check

## Session Extract — 场景补链（Sprint 18 前置，2026-11-08）
- 任务: 补齐 SCENE_PATHS 注册但缺资产的 8 条场景（gate-check 2026-11-08 §B1），让核心循环转场走通
- 新增: combat_scene.gd/.tscn（薄容器挂 CombatRoot + 音频/顶部条/底部条/手牌区 bind_signals + 备战 setup/confirm/back + 结算宿主 retreat/defeat 出口）、tribulation_scene.gd/.tscn（combat_scene 子类，is_tribulation + TribulationSystem 委托 + 降级开战）、src/ui/shared/placeholder_scene.gd（共用占位实现）+ 6 个占位 .tscn（deck_editing / shop / event_panel / result_screen / defeat_screen / cultivation）
- 硬化: scene_manager.gd 新增 verify_scene_paths()，_ready 启动自检 12 条路径 ResourceLoader.exists()
- 测试: 新增 test_scene_paths_exist（4）/ test_combat_scene_wiring（11）/ test_placeholder_scenes（4）；全量 3456 tests / 3455 passing / 1 pending 存量 / 3 orphans 存量，零回归（S17 基线 3437）
- 已知缺口（未修，登记待裁）: CombatSystem.battle_start 未调 CostSystem.init_for_battle()；END 阶段战斗结束检查仍是桩（需外部 battle_end）；HUD 仍无生产挂载点
- Next recommended: HUD register_persistent 启动挂载（B1 剩余一半）+ interaction 001/003/005 出牌链路

## Session Extract — Sprint 18 补链第二批（2026-11-08）
- 任务: 三项核心缺口——① HUD 生产挂载点 ② `CombatSystem.battle_start` 调 `CostSystem.init_for_battle` ③ `combat_phase_manager` END 阶段战斗结束检查由桩改真实现
- 新增: `src/ui/hud/hud_bootstrap.gd`（`mount()` 幂等挂载 + `is_mounted()` + 失败静默降级）；`src/feature/combat/combat_end_check.gd`（胜负判定纯函数内核，含「信息不足则不判」原则）；`src/feature/combat/combat_battle_wiring.gd`（名册快照 / 费用激活 / END 判定 / 结局收尾，196 行）
- 修改: `main_menu.gd`（`_ready` → `_mount_global_hud_if_boot_scene`，延后一帧 + `current_scene == self`（null 放行）守卫；367 行）；`combat_system.gd`（battle_start 加 `_capture_battle_rosters` + `_init_cost_for_battle`；battle_end 加 `_clear_cost_for_battle`；`set_battle_active` 清 `_pending_battle_result`；`advance_phase` 末尾 `_finish_pending_battle_end`；END→PREP 回合递增在已判结束时跳过；1072 行）；`combat_phase_manager.gd`（PHASE_END 第 3 步改真判定并提前 return 不再调度下一回合）；`ai_system.gd`（新增只读 `get_enemy_roster()`——此前只有写入端）
- 测试: 新增 `test_combat_end_check.gd`（11）/ `test_battle_end_check_wiring.gd`（8——真实 Cost/Realm/Deployment Autoload 参与）/ `test_hud_bootstrap.gd`（6）；全量 **3481 tests / 3480 passing / 1 pending 存量 / 3 orphans 存量**（S18 基线 3456 → 净增 25），零回归
- 真机验证: `--headless --quit-after 180` 启动主场景，日志可见 `hud_bootstrap.gd:44 mount` ← `main_menu.gd:173 _mount_hud` ← `168 _mount_global_hud`，HUD 已挂入 PersistentLayer（境界条/通知等子组件随之 setup）
- Tech debt: DEBT-EUI-005-6 挂载侧闭环（toast 消费方接线仍待 exploration-ui）；新增 DEBT-CBT-018-1（战斗内无人调 `DeploymentSystem.remove_character` → 生产路径 DEFEAT 分支实际不可达）、DEBT-CBT-018-2（combat_system.gd 1072 行）；DEBT-MM-004 的 main_menu 行数刷新为 367
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（接上「阵亡→清位→判负」闭环，见 DEBT-CBT-018-1）

## Session Extract — DEBT-CBT-018-1 闭环（2026-11-08）
- 任务: 打通「打牌击杀 → 自动清位 → END 判负」生产链路
- 新增: `src/feature/combat/combat_roster_state.gd`（213 行——敌我 HP/存活状态表；敌方回写 `EnemyBattleState` 对象 / 阵容 Dictionary，我方以模板 `base_hp` 或 `battle_start.player_stats` 种子；未知 HP 标 `known=false` 不臆造死亡）；`src/feature/combat/combat_damage_settlement.gd`（173 行——攻击结算与出牌效果共用落库；HP 归零且此前存活才发 `character_died`，无 HP 数据回退载荷 `is_kill`；阵营推断 状态表 > 载荷 side > DeploymentSystem 阵位）
- 修改: `combat_damage_calculator.resolve_attack_queue()` 返回 `[{entry, payload}]`；`combat_system._resolve_attack_queue` 逐条落库（`_settle_attack_damage`）+ 新增 `_seed_roster_state` / `_connect_death_cleanup` / `_on_character_died`（side=0 → `DeploymentSystem.remove_character`）/ `get_character_hp`；`battle_start` 支持 `player_stats`；`battle_end` 清状态表；`combat_card_resolver._check_and_process_deaths` 改走落库（不再是 raw is_kill 透传）；`combat_scene._start_battle` 先 `_setup_field` 再 `battle_start`（阵位从未有人会让 END 读成「信息不足」，判不出负），并新增可注入 `deployment_system` 字段
- 测试: `test_battle_end_check_wiring.gd::test_end_all_allies_dead_ends_battle_with_defeat` 改为端到端（打牌击杀 → 自动清位 → END 判负）；新增 `test_damage_settlement_wiring.gd`（8 例）；`test_combat_scene_wiring.gd` 加 `DeploymentStub` + `test_deploy_confirmed_setups_field_before_battle_start`（1 例，隔离真实 DeploymentSystem 防跨测试污染）。全量 **3490 tests / 3489 passing / 1 pending 存量 / 3 orphans 存量**（S18 基线 3481 → 净增 9），零回归
- Tech debt: DEBT-CBT-018-1 已闭环；新增残留项（战斗 UI 无 `CombatFeedbackCoordinator` 生产实例化点，HP 条/阵亡动画未消费真实 HP；我方 HP 尚无跨战斗持久化）；DEBT-CBT-018-2 行数刷新为 1137
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（HP 已可落库，接 UI 交互层）+ DEBT-CBT-018-1 残留的反馈协调器装配

## Session Extract — 战斗表现层接真实数据（Sprint 18，2026-11-08）
- 任务: `CombatFeedbackCoordinator`（伤害飘字 / HP 条 / 阵亡淡出，含 `hp_reader_cb`）此前无任何生产实例化点——协调器卡表永远为空，HP 落库只停在数据层
- 新增: `src/ui/combat/layout/combat_actor_reader.gd`（169 行——名册/HP/ATK 单一读取链路，RefCounted，依赖全可空）；`src/ui/combat/layout/combat_actor_stage.gd`（262 行——敌我名册 → `CharacterStatusCard` → 注册进协调器；前排贴中线/后排靠外沿，按卡实际宽度行内居中；阵亡摘索引 + 空位框归协调器；`clear_roster` 先注销再 `remove_child + queue_free` 防上一场残影）
- 修改: `combat_system.gd`（新增 Cat 2b 信号 `character_damaged`——载荷 `{character_id, side, damage, is_kill}`，只带增量不带 HP 终值以守住 ADR-0008「无 HP 数据信号」；新增 `get_battle_enemy_roster()` 只读快照；1157 行）；`combat_damage_settlement.gd`（落库后广播 `character_damaged`，攻击结算与出牌效果共用一条出口；190 行）；`combat_roster_state.gd`（抽出静态 `enemy_id_of`/`enemy_is_front`，种子与建卡落在同一个键上；245 行）；`combat_feedback_coordinator.gd`（有 `character_damaged` 只订阅它、否则回退 `attack_resolved`——同一次攻击两条信号都在发，同订会让飘字重影；300 行整）；`combat_layout.gd`（实例化 `CombatFeedback`（层序：手牌区之上、备战/结算之下）与 `ActorStage`；新增 `setup_feedback` / `build_battle_roster` / `clear_battle_roster`；440 行）；`combat_scene.gd`（`_ready → _wire_feedback` 注入信号源与 `Callable(CombatSystem, "get_character_hp")`；`_start_battle` 在 `battle_start` 之后建卡——HP 与敌方快照已种子，卡片首帧即真实数值；283 行）
- 测试: 新增 `tests/integration/combat_ui/test_actor_stage.gd`（13 例：建卡 3+2 / 注册 / 初始数值读系统 / 前后排位置 / 阵亡空位框 / 清场注销 / 重开不残留 / 伤害终值 70 / 敌方伤害 / 无卡忽略 / 零轮询 / 敌方 ID 约定 / 双信号去重）；`test_combat_scene_wiring.gd` 补 `CombatStub` 的 HP 契约 + 3 例（协调器与装配台挂载 / `hp_reader_cb` 直达战斗系统返回 42·60 / 确认出战建卡并注册）；`test_damage_settlement_wiring.gd` 补 3 例（`character_damaged` 载荷含 character_id·side·增量且不带 HP 终值 / 出牌伤害同出口 / 未知目标不广播）；`test_phase_transition_signals.gd` 的 Cat 2b 白名单加 `character_damaged`
- 全量: **3509 tests / 3508 passing / 1 pending 存量 / 3 orphans 存量**（S18 基线 3490 → 净增 19），零回归；combat_ui + scene_manager 焦点跑 293/293
- 真机冒烟: 用一次性脚本驱动 `CombatScene`（真实 Autoload）——`feedback=true actor_stage=true hp_reader_valid=true`；`confirm_requested([101,102])` 后 `cards=2 registered=2 battle_active=true`；我方 `get_character_hp(101)` 返回 `{current:0,max:0}`——根因是 `res://assets/cards/templates/` 目录不存在（`git ls-files assets/cards` 只有立绘），模板回退 `base_hp=0` → `known=false`。表现层链路本身正确，缺的是卡牌模板数据资产（已登记 DEBT-CBT-018-5）
- Tech debt: DEBT-CBT-018-1 残留项已闭环（含新增文件与测试说明）；新增 DEBT-CBT-018-3（我方 HP 无跨战斗持久化——每场都从 `base_hp` 满血开始）、DEBT-CBT-018-4（ATK 只读基础值、绑定图标数未接 `BindingManager`）、DEBT-CBT-018-5（卡牌模板目录为空 → 我方卡显示 HP 0/0）；DEBT-CBT-018-2 刷新为 1157 行、DEBT-CUI-008-2 刷新为 440 行
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（HP 已有落库 + 有 UI 消费端，接交互层即可打通「点击出牌 → 飘字 → 阵亡」全链）

## Session Extract — DEBT-CBT-018-5 闭环：卡牌模板资产落地（2026-11-09）
- 任务: 修实机「角色卡 HP 0/0 ATK 0」——根因是 `res://assets/cards/templates/` 目录根本不存在，`CardSystem` 开目录失败后模板集为空，`CombatRosterState` 模板回退 `base_hp` 读到 0 → `known=false` → `get_character_hp` 返回 0/0
- 新增资产: `assets/cards/templates/` 7 张 `.tres`——角色 `lin_yuan`（HP10/ATK2，`auto_heal_1`，正道+青云门，蓝）／`su_jian_ming`（HP7/ATK4，`first_strike`，紫）；功法 `ku_mu_feng_chun_jue`（heal 1，本命 lin_yuan）／`yan_yun_bu`（本命 lin_yuan）／`ying_ci`（buff 1，本命 su_jian_ming）；符箓 `basic_attack`（0 费，single_enemy）／`jian_yi_hu_dun`（1 费，self，duration 1）。字段严格按 `CardTemplate` 的 @export；数值取 `design/gdd/identity-selection-system.md` §①；插画路径指向已有立绘
- 修改: `src/core/card_system/card_system.gd`（386 行）新增 `is_degraded`/`degraded_reason`；`DirAccess` 失败与空目录两条路径改为**可定位中文 `push_warning`**（含目录路径 + 修复提示），不再 `push_error` 刷红；`_on_all_templates_loaded` 在空模板集时**跳过** `GSM.enable_validation`（消除「模板数据库为空」第二条红字），仅发 `templates_loaded(0)`
- 修改: `tests/integration/card_system/test_card_system_loading.gd` 两例改为断言降级契约（warning 1 次 / error 0 次 / `is_degraded` / `degraded_reason` 含路径）
- 新增测试: `tests/integration/card_system/test_template_assets.gd`（202 行，6 例）——真实目录不降级且 ≥3 模板 / 逐张字段自洽（类型·稀有度·费用·角色 HP·ATK·effect_type↔effect_value）/ 角色数值与 GDD 一致 / 身份①开局卡组全覆盖（从 `identity_templates.gd` 推导）/ `CombatRosterState.seed_player_field` 读成 10/10 且 `known=true` / `CombatActorReader` 读出 7/4。`before_all/after_all` 快照并还原 GSM 校验态（Autoload 单例跨文件存活）
- 全量: **3515 tests / 3514 passing / 1 pending 存量 / 3 orphans 存量**，exit 0，零回归（S18 基线 3509 → 净增 6）
- 真机验证: 一次性脚本（真实 Autoload）确认 `pending=7 → 0`，`templates=7`、`degraded=false`、`reason=''`
- Tech debt: DEBT-CBT-018-5 已闭环；新增 DEBT-CBT-018-6（其余 5 个身份 30 个 card_id 仍无模板）、DEBT-CBT-018-7（`base_hp` 在两份 GDD 间冲突：identity-selection 10/2·7/4 vs card-system-design 2/2·1/3，需策划裁决）、DEBT-CBT-018-8（`yan_yun_bu` 百分比减伤无对应效果类别故 `effect_type` 留空；`basic_attack` 的 GDD 类型「普通」在 `CardType` 无枚举，暂取 `TALISMAN`）
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（模板数值已真、HP 可落库且有 UI 消费端）；或先补其余 5 身份模板（DEBT-CBT-018-6）

## Session Extract — DEBT-CBT-018-6 闭环：6 身份卡牌模板补齐（2026-11-09）
- 任务: 补 `assets/cards/templates/` 其余 5 个身份的 30 张模板（身份① 7 张已于 DEBT-CBT-018-5 落地，总计 37）
- 数值唯一真理来源: `design/gdd/identity-selection-system.md` §①~§⑥「初始角色」表 + 「初始卡牌详情」表；`card-system-design.md` 的冲突只登记不采用（DEBT-CBT-018-7 扩记到 4 张冲突 + 6 张缺失条目）
- 新增资产（30 张 `.tres`）:
  - ② 血海殿遗孤: 角色 `yin_ruo_han` 9/3（魔道+血海殿）、`tu_ye` 8/4；功法 `wan_hun_fan`（2费·蓝·control_confuse，本命 tu_ye）、`you_ying_bu`（2费·蓝·effect_type 留空，本命 yin_ruo_han）；符箓 `sha_qi_zhan`（1费·白·single_enemy）、`xue_sha_zhang`（1费·白·single_enemy）
  - ③ 碎星群岛散修: `xi_yin` 9/3、`mu_yao` 8/3（中立·碎星群岛）；`huan_hua_mi_zong_bu`（减伤→留空）、`yin_po_ning_hun_shu`（召唤→留空）；`jian_bo_zhan`（1费·白）、`xun_bao_fu`（1费·蓝·draw_select_top3）
  - ④ 玄冰宫弟子: `ling_shuang_yue` 10/3、`jiang_xue` 9/2（正道+玄冰宫）；`han_yu_lun_hui_gong`（heal 1）、`shuang_po_jian_jue`（control_freeze）；`bing_leng_ci`、`jin_zhong_fu`（各 1费·白）
  - ⑤ 丹霞谷弟子: `fang_ling_su` 9/3、`shi_yan` 10/2（正道+丹霞谷）；`san_yuan_ju_qi_gong`（留空）、`dan_xia_jian_qi`（1费·蓝）；丹药 `zhu_ji_dan`（PILL·蓝·heal 3）、`pei_yuan_dan`（PILL·白·heal 3）
  - ⑥ 阵道双杰: `mu_xing_he` 9/3、`yun_su_xin` 8/2（中立·碎星群岛）；`wan_xiang_zhen_dian`（紫·留空）、`qi_xing_kun_long_zhen`（蓝·control_immobilize）、`yin_yang_shou_yu_zhen`（FORMATION·白·required_count 2 + aura buff_def_1）、`jin_qian_biao`（0费·白）
- 改写测试: `tests/integration/card_system/test_template_assets.gd`（300 行，9 例）——模板数 ≥37 且未降级 / 逐张字段自洽（角色卡阵营标签非空、effect_type↔effect_value 成对）/ 角色阵营标签必须在 `FactionSystem.FACTION_LIBRARY` 注册 / 12 张角色卡 HP·ATK 与 GDD 对齐 / 25 张非角色卡 type·rarity·cost 对齐 / 6 身份开局卡组逐身份全覆盖（从 `identity_templates.gd` 推导）/ 12 名角色 `CombatRosterState` + `CombatActorReader` 端到端读真实数值 / `basic_attack` 锁 TALISMAN(5) / 两张百分比减伤卡锁 `effect_type` 留空
- 全量: **3518 tests / 3517 passing / 1 pending 存量 / 3 orphans 存量**，exit 0，零回归（3515 → 净增 3）
- 真机冒烟（一次性脚本，真实 Autoload）: `templates=37 degraded=false`；6 身份 42 条卡组引用 `missing=[]`；`yin_ruo_han` 9/9、`tu_ye` 8/8、`mu_xing_he` 9/9、`yun_su_xin` 8/8 均 `known=true`
- Tech debt: DEBT-CBT-018-6 已闭环；DEBT-CBT-018-7 扩记（冲突 4 张 + card-system-design 缺 6 张条目）；DEBT-CBT-018-8 补记（另有 4 张效果词表缺口同样留空）；新增 DEBT-CBT-018-9（10 张角色卡无立绘）、DEBT-CBT-018-10（攻击系数/概率/副效果无字段承载）
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（6 身份模板全部可读，HP 落库与 UI 消费端已通）

## Session Extract — DEBT-CBT-018-8 闭环：卡牌效果词表缺口（2026-11-09）
- 任务：`card_effect_evaluator._category_for` 只有 8 个前缀，14 张模板的 effect_type 无处安放（2 张减伤、3 张留空、7 张攻击倍率、2 张概率控制）
- 新增类别（编号追加在 UNEVALUABLE 之后，前 9 个不变）：`DAMAGE_REDUCE` / `DAMAGE_MULTIPLIER` / `DAMAGE_BONUS` / `HEAL_BONUS` / `FORMATION_ATTUNE`
- 关键设计：① `damage_reduce` 只写 `damage_reduction_pct`/`damage_reduction_multiplier`，**绝不写 stat_changes**（与 buff 的 ATK 增量严格区分）；② `_category_for` 改为「具体前缀先于泛前缀」（damage_reduce 不被 damage 吞、heal_bonus 不被 heal 吞、中文「受到伤害降低」先于「伤害」）；③ 未知/留空 → UNEVALUABLE + 空评估，不静默当 buff
- `combine_damage_reduction(pcts)` 静态方法：GDD combat-system.md §公式 乘算叠加、封顶 60%、保底解析
- `combat_damage_calculator.calculate_damage()` 末尾追加 `damage_reduction_pcts` 参数（默认空 → 4 参旧调用点行为不变）；`resolve_attack_queue` 读队列条目同名键
- `CardTemplate` 新增 3 个 @export：`trigger_chance` / `native_trigger_chance` / `native_effect_value`——本命加成非线性（10%→15%、30%→50%），不走 ×1.5；评估器在 `is_native=true` 时取本命值原值并跳过绑定倍率
- 模板回填 14 张：`yan_yun_bu`(10/15) `huan_hua_mi_zong_bu`(15/20) `you_ying_bu`(1/2) `san_yuan_ju_qi_gong`(1/2) `wan_xiang_zhen_dian`(1/2) `basic_attack`(100) `sha_qi_zhan`(150) `xue_sha_zhang`(100) `jian_bo_zhan`(120) `dan_xia_jian_qi`(140) `jin_qian_biao`(80) `bing_leng_ci`(100) `wan_hun_fan`(0.3/0.5) `shuang_po_jian_jue`(0.25/0.4)
- 测试：新增 `tests/unit/card_effect_engine/test_effect_vocabulary.gd`（22 例，解析/分发/边界/未知/概率/本命）、`tests/integration/card_system/test_template_effect_vocabulary.gd`（5 例资产层锁定）；扩 `test_card_template.gd`（3 新字段）、`test_play_card_target_resolution.gd`（3 例减伤公式）、`test_damage_settlement_wiring.gd`（1 例队列减伤）；`test_template_assets.gd` 移除已闭环的「留空」断言
- 全量：**3548 tests / 3547 passing / 1 pending 存量 / 3 orphans 存量**，exit 0，零回归（3518 → 净增 29）
- Tech debt：DEBT-CBT-018-8 已闭环；DEBT-CBT-018-10 部分解决（倍率与概率已建模，副效果仍缺）；`basic_attack` 的「普通」类型仍待 ADR
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（词表已能表达减伤/倍率，可出真实数值）

## Session Extract — 减伤链路真正接通：绑定减伤 → 攻击队列 → 伤害（2026-11-09）
- 任务：Attack 阶段把在场角色（防御方）的绑定减伤汇总写进攻击队列条目的 `damage_reduction_pcts`（DEBT-CBT-018-8 的残留闭环）
- 数据流向确认（先读后写）：队列条目由 `combat_damage_calculator.resolve_attack_queue` 消费（读 `entry.damage_reduction_pcts` → `combine_damage_reduction` → DEF 结算后乘算）；生产端此前只有 `set_attack_queue` 测试桩，无绑定来源 → 减伤字段在真实战斗中恒为空
- 新增 `src/feature/binding/binding_damage_reduction.gd`（104 行）：遍历 `get_binding_ids_by_character` → 逐条 `evaluate_effect`（复用效果词表，不重复解析 `effect_type`）取 `damage_reduction_pct`；跳过 `is_suspended`；`pct > 0` 才入列；模板查不到/ID 空即不贡献（**不臆造 0% 之外的猜测**）；同名叠层按一条计数（GDD §10 未定义减伤类叠层放大，不臆造）
- `BindingManager.get_damage_reduction_pcts(character_id) -> Array[float]` 为公开入口（薄委托子模块）
- 新增 `src/feature/combat/combat_attack_coverage.gd`（60 行）：Attack 阶段遍历队列按 `target_id` 写键；**已有该键的条目原样保留**（UI/测试可显式给定一次性格挡）；无来源不写键也不写空占位
- `CombatSystem._resolve_attack_queue` 在结算前调 `_get_attack_coverage().annotate_queue(_attack_queue)`（新增 `_attack_coverage` 字段 + getter，遵循既有子模块模式）
- **未另写公式**：乘算叠加与 60% 封顶仍只有 `CardEffectEvaluator.combine_damage_reduction` 一处
- 测试：新增 `tests/integration/combat_system/test_damage_reduction_wiring.gd`（253 行 / 8 例）——单角色 10% 生效（20→11）/ 本命取 `native_effect_value=15`（20→12，非 ×1.5 口径）/ 两来源 10%+15% 乘算 0.9×0.85=0.765 → 扣 7（20→13，等效 23.5%）/ 三来源 30% 封顶 60% → 扣 4（20→16）/ 两防御方互不合并 / 无来源不写键且伤害不变（20→10）/ 显式值不被覆盖 / 暂挂绑定不计
- 全量：**3556 tests / 3555 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3548 → 净增 8）
- Tech debt：DEBT-CBT-018-8 补记「链路闭环（减伤接线）」；`basic_attack` 的「普通」类型仍待 ADR；副效果（DEBT-CBT-018-10）仍只写在 description
- 已知边界（未建模，非本次范围）：敌方绑定经 `AISystem.register_preconfigured_bindings` 已能落 `BindingManager`，故敌方减伤同样会被汇总；玩家侧「谁在场上」的判定在绑定系统内无角色位查询，按 `character_id` 直接取绑定（与 `combat_damage_settlement` 的 binding 查询同口径）
- Next recommended: combat-ui-interaction 001/003/005 出牌链路（减伤已能真实影响数值）

## Session Extract — 同名叠层放大减伤（2026-11-09，策划裁定）
- 任务：把「同名叠层放大减伤」落地——单条记录贡献 = `pct × stack_multiplier^(stack_count-1)`，多来源仍走 `combine_damage_reduction` 乘算 + 60% 封顶
- 先读后写：`design/gdd/binding-system.md` §10「非数值效果的叠加行为」表原只有免疫/概率/持续回合/条件触发/抽牌五类，减伤无处归类；§3 同名叠加公式已给 `stack_multiplier: 1.2-2.0，默认 1.5`（§调优参数同值）→ **统一叠加因子取 1.5，未新造系数**（任务前提「若 GDD 没给就用 1.5」不成立，GDD 已有取值）
- GDD 补一行：§10 表新增首行「百分比效果（受到伤害降低等）——可叠加放大类」，与那五类并列，注明放大先于多来源乘算；并加「判定口径」引用块解释归类依据
- 代码：`binding_damage_reduction.gd`（104 → 128 行）新增 `DEFAULT_STACK_MULTIPLIER = 1.5` 常量 + `_stack_factor(record, template)`——系数读模板 `CardTemplate.stack_multiplier`，模板未声明（≤0）回退常量；`stack_count ≤ 1` 直接返回 1.0（不做 pow）；`_reduction_pct_of` 在基础 pct > 0 时才乘放大系数（0 仍被过滤，不产生 0 值来源）。`BindingManager.get_damage_reduction_pcts` 文档同步
- **未另写公式**：只改单条来源数值，乘算与封顶仍只有 `combine_damage_reduction` 一处
- 测试：新增 `tests/integration/combat_system/test_damage_reduction_stack_amplify.gd`（223 行 / 7 例）——1 层 10%（1.5^0）/ 2 层 15%（1.5^1）/ 3 层 22.5%（1.5^2）各为单条贡献；2 层→15% 与另一张 15% 乘算 0.85×0.85=0.7225 → 20→13；3 层 30%→67.5% + 15% 仍封顶 60% → 20→16；另有 2 层/3 层放大值经攻击队列落到伤害的 2 例
- 全量：**3563 tests / 3562 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3556 → 净增 7）
- Tech debt：DEBT-CBT-018-8 追加「叠层放大闭环」条目，含「GDD 原表无减伤分类 → 本轮补齐」的变更原因与 `get_binding_context()` 仍用常量 1.5 的口径不一致风险登记
- 已知边界：`get_binding_context()` 的 `stack_multiplier` 仍是「延后接 CardSystem」的临时常量（未改，非本次范围）；本命减伤仍取 `native_effect_value` 原值，叠层放大在其之上乘算（GDD §10「叠加乘法与本命乘法独立」）
- Next recommended: combat-ui-interaction 001/003/005 出牌链路

## Session Extract — get_binding_context 叠层系数口径收口（2026-11-09）
- 任务：`BindingManager.get_binding_context()` 里 `stack_multiplier` 仍硬编码 `DEFAULT_STACK_MULTIPLIER`（注释「延后接 CardSystem」），与上一轮减伤路径「读模板 `CardTemplate.stack_multiplier`」形成两套口径
- ADR-0013 对照：§同名叠加乘法公式 要求「multiplier = native × stack_multiplier^(count-1)，CardEffectEngine 查询预计算值，不在引擎中重复计算」；§变量表 `stack_multiplier` 来源明确为 `CardTemplate.stack_multiplier（可配置）` → 硬编码属实现债，非设计意图
- 方案：新增 `src/feature/binding/binding_stack_factor.gd`（69 行）作为**唯一取数实现**——`read_template(id)`（CardSystem 缺失/ID 空/模板缺失 → null）、`multiplier_of(template)`（null/无字段/≤0 → 1.5）、`stack_factor(count, template)`（count≤1 直接 1.0，不做 pow）+ 常量 `DEFAULT_STACK_MULTIPLIER = 1.5`
- `binding_manager.gd`（725 → 732 行）：`get_binding_context()` 改调 `StackFactor.read_template(record.card_template_id)` + `StackFactor.stack_factor()`；`DEFAULT_STACK_MULTIPLIER` 保留为 `StackFactor.DEFAULT_STACK_MULTIPLIER` 的**别名**（向后兼容既有引用，不再承载取数逻辑）；函数文档同步（去掉「延后」措辞）
- `binding_damage_reduction.gd`（128 → 96 行）：删除本地 `DEFAULT_STACK_MULTIPLIER` / `_stack_factor` / `_read_template` / `_autoload`，改调同一模块——**两条路径共用一处实现**，模板存在性判定仍留在减伤路径（模板缺失 → 不贡献来源）
- 向后兼容：现有模板资产未声明 `stack_multiplier` → 走默认 1.5，`test_serialize_snapshot_effect_integration` 的 AC-009 用例（1.5×1.5^1=2.25 等）数值不变
- 测试：新增 `tests/integration/binding_system/test_binding_context_stack_multiplier.gd`（223 行 / 9 例）——模板 ×2.0 叠 2/3 层上下文与减伤路径同系数（2.0 / 4.0 对 20% / 40%）、×1.2 叠 3 层同系数 1.44（14.4%）、模板缺失上下文回退 2.25 而减伤返回空（不臆造）、字段为 0 视为未声明、默认 1.5 向后兼容、单层不放大、本命叠层只共用叠层系数（本命基数口径差异为既有设计）
- 全量：**3572 tests / 3571 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3563 → 净增 9）
- Tech debt：DEBT-CBT-018-8 追加「口径收口（2026-11-09）」条目
- 已知边界：`compute_effective_value()` 仍由调用方显式传 `stack_multiplier`（无符号表，未改）；`get_accumulated_bonus()` 走 `stat_bonus_cb` 回调，不经模板系数（非本次范围）
- Next recommended: combat-ui-interaction 001/003/005 出牌链路

## Session Extract — 减伤飘字「玩家可见」（2026-11-09）
- 任务：把 attack 队列的减伤链路打通到表现层——飘字此前显示的是「减伤前原始伤害」口径，玩家看不出减伤生效
- 先读后写（呈现链路）：`CombatSystem._resolve_attack_queue` → `combat_attack_coverage.annotate_queue`（写 `damage_reduction_pcts`）→ `combat_damage_calculator.resolve_attack_queue`（算 `final_damage`，发 `attack_resolved`）→ `combat_damage_settlement.settle_attack`（落库 → 发 `character_damaged`）→ `CombatFeedbackCoordinator._enqueue_damage`（飘字 + 结算帧 `apply_hp`）→ `FloaterPool.spawn`
- 结论：**HP 条一直是对的**（结算帧从 `hp_reader_cb` 读终值），**飘字数值也是落库后的实际增量**（`character_damaged.damage`）。缺的是「这条伤害被减过」的标志——两个信号载荷都没有减伤信息，表现层无法区分
- 改动（全部向后兼容的**新增键/参数**）：
  - `combat_damage_calculator`：`attack_resolved` 载荷新增 `damage_reduced`（由 `damage_reduction_multiplier < 1.0` 派生，不另算数值、不新增公式）
  - `combat_damage_settlement`：`settle_attack` 透传 → `_apply(..., reduced)` → `_emit_damaged` → `character_damaged` 载荷新增 `damage_reduced`（出牌效果路径缺省 false）
  - `combat_feedback_coordinator`：两个伤害入口把 `damage_reduced` 透传给 `_enqueue_damage(..., reduced)` → `floater_pool.spawn(..., reduced)`
  - `floater_pool.spawn` 新增第 4 参数 `reduced: bool = false`——减伤伤害：琥珀色 `REDUCED_DAMAGE_COLOR (0.93,0.66,0.24)` + 纯文字后缀 `REDUCED_MARKER " 减"`（双通道，色盲可读）；治疗忽略该标志；每次发射重写颜色/文本（池复用不残留）
  - 不新增美术资源（同一 Label）
- GDD：`design/gdd/combat-ui-system.md` §HP条与视觉反馈 补一条 AC（减伤飘字显示实际扣血 + 琥珀色「减」角标；无减伤保持红色无角标）
- 测试：新增 `tests/integration/combat_ui/test_damage_reduction_floater.gd`（3 例，真实 CombatSystem + 真实 BindingManager 绑 15% 减伤卡走全链路）：减伤 15% → 载荷 `damage=8`（非 10）且 `damage_reduced=true` → 飘字 `-8 减` 琥珀色；结算帧后 HP 20→12 与飘字一致；无减伤保持 `-10` 红色无角标
- 测试：`test_floater_pool.gd` 扩 4 例（琥珀+角标 / 无减伤旧样式 / 治疗忽略减伤标志 / Label 复用重写样式）；`mock_combat_signals.emit_attack` 增 `reduced` 参数（mock 仍不带 `character_damaged`，既有用例走 attack_resolved 兼容路径不变）
- 全量：**3579 tests / 3578 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3572 → 净增 7）
- Tech debt：DEBT-CBT-018-8 追加「表现层闭环（2026-11-09，玩家可见）」条目
- 已知边界：出牌效果走 `settle_effect`，`CardEffectEngine.resolve` 不返回减伤标志 → 技能伤害因绑定减伤而降低时，数值正确但飘字不带「减」角标（登记在 tech debt）；`damage_reduced` 不影响任何数值，旧消费者忽略即可
- Next recommended: combat-ui-interaction 001/003/005 出牌链路

## Session Extract — DEBT-CBT-018-10 第三阶段：出牌执行端（倍率伤害 + 治疗落库）（2026-11-09）
- 任务：`damage_multiplier` 与 `heal` 只在评估层算出数值，`play_card` 结算时并未真正按倍率算伤害、也没把 heal 落库
- 先读后写（缺在哪一步）：`combat_card_resolver.play_card` 第 6 步 `_resolve_effects` 走 `CardEffectEngine.resolve`——**该 Autoload 上没有这个方法**（`CombatSystem._ready()` 注入的 `resolve_cb = Callable(cee, "resolve")` 无效），回退返回空数组 → 效果项从不产生 → 倍率伤害从未落库、出牌治疗只有击杀触发那条支路（`combat_kill_trigger.gd`）会落。评估层（`CardEffectEvaluator` 的 `DAMAGE_MULTIPLIER` 与 `heal` 分支）本身是正确的，缺的是执行端
- 新增 `src/feature/combat/combat_on_play_effects.gd`（244 行，守 300 行软上限）
  - `collect(card, targets, caster_id)`：经 `CardEffectComposer.effects_of` 取条目 → 按 `matches_trigger(TRIGGER_ON_PLAY)` 过滤（击杀条目仍由 `combat_kill_trigger.gd` 按事实触发）→ 逐条交评估器出数值 → 返回 `{damage_results, heals}`，**只收集不落库**
  - `apply_heals(heals)`：调 `CombatDamageSettlement.apply_heal`（治疗在落库侧就是负伤害）
  - 两段式（先伤害后治疗）：伤害并入 `play_card` 已有的统一落库链路 `settle_effect`，治疗在伤害落库**之后**才执行 → `character_damaged` 广播顺序「先掉血、后回血」，与击杀触发一致
  - **没有新开写 HP 的路径**——唯一写 `current_hp` 的实现仍是 `combat_roster_state.apply_damage`
- 攻击力取数：`combat_roster_state.gd` 状态字典新增 `atk` 键 + `get_atk()`，`read_hp()` 一并返回 `atk`；`seed_enemy_roster` 读 `attack`、`seed_player_field` 读注入的 `atk`/`attack`，缺省回退模板 `base_attack`（`_read_template_max_hp` 改名 `_read_template_field`）。三处 ATK 来源（敌方 `EnemyBattleState.attack` / 我方模板 `base_attack` / `battle_start` 的 `player_stats.atk`）汇于此，作为 `attacker_atk` 传给评估器
  - **信息不足不臆造**：ATK ≤ 0 时不写 `attacker_atk` 键，让评估器回退快照——而快照里**只有施法者带 ATK、目标条目一律不给**（若给目标也填 ATK，评估器会把防御方的 ATK 当成本次攻击力，凭空造出伤害）→ 回退值 0、伤害 0、不落库
- 目标裁定（防误伤）：`target=self` 的伤害**整条跳过**（GDD 无自伤模型，既不臆造自伤规则，也绝不把伤害打到调用方给的目标上）；`target=self` **与未声明 target** 的治疗一律落施法者（旧扁平卡如 `pei_yuan_dan` 只写 `target_type`，`han_yu_lun_hui_gong` / `ku_mu_feng_chun_jue` 连 target 都没写——漏认会让真实资产的治疗静默失效）；显式指向他人（`single_ally`）的治疗跳过并告警（无模型，不写错对象）
- 伤害结果项**不写 `card_data`**：由 `play_card` 的 `_with_card_context` 统一补成「打出的那张卡」——击杀触发要按整张卡取 `trigger="kill"` 条目，若此处塞进单条效果数据，击杀回血会被评成 0（静默失效）
- `combat_card_resolver.gd`（245 行）：`play_card` 在第 6 步后插入 6b（`_collect_on_play_effects` → 伤害并入 `results`）→ 第 7 步阵亡检查 → 再 `apply_heals`；新增 `_collect_on_play_effects()` / `_get_on_play_effects()`（惰性 `preload(...).new(_parent)`）；`play_card` 的 `caster_id` 文档补「倍率伤害的 ATK 取数对象与打出治疗/击杀回血的落点，缺省 -1 时两者都不结算」
- `combat_system.gd`：流程注释补 6b
- GDD：`design/gdd/card-system.md` §多效果承载 补「执行端」小节（逐条目行为表 + ATK 取数 + 施法者未知不结算 + 未建模类别跳过）
- 测试：新增 `tests/integration/combat_system/test_on_play_effects.gd`（14 例）：150% 倍率 ATK3 → 4（floori，20→16）/ 100% 即等于 ATK / 广播增量与落库一致（`character_damaged` 载荷 damage=4）/ 施法者 ATK 未知时不落伤害且不拿敌方 ATK（4）顶替 / self 治疗 8+3 → 10 夹上限 + 负增量广播 / 满血治疗 HP 不变 / 未声明 target 的治疗落施法者 / `single_ally` 治疗跳过 / self 伤害不误伤敌方也不自伤 / 同卡 self 治疗与非 self 伤害分流 / 无效果卡行为逐位不变（双方 HP 不动、零广播）/ 无 `caster_id` 不结算 / 真实资产 `pei_yuan_dan` 回血 / 真实资产 `han_yu_lun_hui_gong` 未声明目标仍落施法者 / 真实资产 `xue_sha_zhang` 未击杀时击杀回血不提前落库
- 全量：**3641 tests / 3640 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3626 → 净增 15）
- Tech debt：DEBT-CBT-018-10 追加「第三阶段已落地」
- **已知边界**：① `play_card` 的 `caster_id` 仍要靠 UI 出牌链路接线传入，缺省 -1 时倍率伤害与治疗都不结算（不猜「谁出的牌」）——真实对局接线前这几类效果只在测试里生效；② 出牌伤害走 `settle_effect`，`damage_reduced` 缺省 false → 技能伤害因绑定减伤而降低时数值正确但飘字不带「减」角标（同 DEBT-CBT-018-8）；③ 治疗载荷带的是**申请治疗量**的取负（上限夹取在 `apply_damage` 里做），满血时申请 3 点仍广播 -3 而实际 HP 不变——接线 UI 飘字时需改为按实际增量广播或由表现层读 HP 差值；④ 增益/控制/抽牌/阵法等未建模类别一律跳过（不静默降级）
- Next recommended: UI 出牌链路把场上施法者 ID 传进 `play_card`（否则前三条只在测试里成立）；或 combat-ui-interaction 001/003/005

## Session Extract — DEBT-CBT-018-10 第一阶段：一卡多效果（2026-11-09）
- 任务：让一张卡能挂多条异质效果——先弄清「一卡一效果」的扁平结构，再落 `EffectEntry` + `CardTemplate.effects`，保持旧卡零迁移
- 先读后写（扁平结构现状）：`CardTemplate` 的 `effect_type`/`effect_value`/`native_effect_value`/`trigger_chance`/`native_trigger_chance`/`duration_turns`/`target_type` 是一套**互斥语义**的扁平字段（数值单位随 `effect_type` 变）；`CardEffectEvaluator.evaluate_effect()` 只读这一组，一次调用只产出一个 `EffectEvaluation`。副效果（血杀掌击杀回血、剑波斩抽牌……）只能写在 `description` 里
- 新增 `src/core/card_system/effect_entry.gd`（135 行，`class_name EffectEntry extends Resource`）：`effect_type` / `value` / `native_value` / `trigger_chance` / `native_trigger_chance` / `duration_turns` / `target` / `trigger`（空 = 打出即生效，`kill` = 击杀触发）；`from_card()` 从旧扁平结构合成一条（兼容 CardTemplate 与 Dictionary），`to_card_data()` 展开成评估器可读字典（同时给 `value` 与 `effect_value` 两套键）
- `CardTemplate` 新增 `effects: Array[EffectEntry] = []`（168 行）。**空 = 未迁移 → 用扁平字段合成一条；非空 = 以列表为准，扁平字段忽略**——不一次性迁移 37 张
- 新增 `src/feature/card_effect_engine/card_effect_composer.gd`（219 行）：`effects_of()` 取列表 / `combine()` 汇总 / `combine_detailed()` 带明细（`unevaluable_count` / `skipped_count`）。汇总口径：伤害·治疗·属性增量·状态·加成类逐条累加；**减伤交 `combine_damage_reduction`（唯一公式），单来源短路保留原值**（0.9 这类浮点不可精确表示，旧卡必须逐位一致）；**多条伤害倍率取最强一条**（叠乘规则 GDD 未定义，不臆造）
- `CardEffectEvaluator`（317 行）：新增 `evaluate_effects()` / `get_composer()` / `category_of()`；`get_effect_categories()` 改为**逐条**返回标签；`simulate_chain()` 根效果改用汇总值。preload 方向单向（评估器 → 汇总器），汇总器反向用运行时 `load` 避免解析期循环依赖
- **触发时机分离**：`trigger="kill"` 的条目默认不进打出结算（干跑不知道击杀会不会发生，混入等于凭空多给一次治疗），需显式传 `trigger` 才参与
- **未知类型不污染**：单条落 `UNEVALUABLE` 时零贡献、其余照常，`unevaluable_count` 如实上报；不静默当 buff 的既有约定不变
- 示范卡迁移：`assets/cards/templates/xue_sha_zhang.tres`（血杀掌）→ 两条效果（`damage_multiplier` 100 `single_enemy` 打出即生效 + `heal` 2 `trigger=kill` `self`），**扁平效果字段一并清空**（留旧值会让「哪份是真源」永远吵不清）。数值 = GDD §②「造成ATK×1.0伤害，击杀后回复2HP」
- GDD：`design/gdd/card-system.md` §CardTemplate 共有字段表补 `effects` 行 + 新增「多效果承载」小节（EffectEntry 字段表 + 四条规则）
- 测试：新增 `tests/unit/card_effect_engine/test_multi_effect_composition.gd`（23 例）+ `tests/integration/card_system/test_multi_effect_templates.gd`（6 例）；`test_card_template.gd` 的 `ALL_EXPORT_FIELDS`/`COMMON_FIELDS` 加 `effects`（31 个）并把 `test_no_bare_arrays` 放宽为「StringName 或 Object 类型化数组」；`test_template_effect_vocabulary.gd` 移除已迁移的 `xue_sha_zhang`
- 全量：**3608 tests / 3607 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3579 → 净增 29）
- Tech debt：DEBT-CBT-018-10 追加「第一阶段已落地」条目
- **已知边界（下一批迁移前必须先处理）**：`binding_damage_reduction.gd::_card_data()` 直接读模板扁平字段后调 `evaluate_effect`——把减伤类绑定卡（`yan_yun_bu` / `huan_hua_mi_zong_bu`）迁到 `effects` 并清空扁平字段会让该路径**静默读出 0% 减伤**（不报错，玩家侧表现为减伤消失）。须先改为经 `evaluate_effects()` 取汇总值，且「叠层放大作用在汇总 pct 还是逐条」属设计口径需策划确认。`test_only_demonstration_card_is_migrated` 是绊线（迁移任何新卡即红）
- 另一处边界：`CombatSystem` 出牌结算尚未消费 `trigger="kill"` 条目——击杀回血目前**可评估不可执行**
- Next recommended: 出牌链路执行端（`damage_multiplier`/`heal` 落库）→ 再迁其余 36 张；或 combat-ui-interaction 001/003/005

## Session Extract — DEBT-CBT-018-10 第四阶段：UI 施法者接线 + 治疗按实际增量广播（2026-11-09）
- 任务：① 把「谁出的牌」接进生产链路（此前 `play_card` 的 `caster_id` 无人传入，倍率伤害与治疗在真实对局里从不结算）；② 治疗广播改成实际增量（此前带申请量，满血时飘出不存在的回血数字）
- 先读后写（UI 出牌链路现状）：`combat_system.gd::play_card` → `combat_card_resolver.play_card` → `combat_on_play_effects.collect(card, targets, caster_id)`；UI 侧**没有任何出牌手势实现**（`grep play_card src/ui` 零命中）——`combat_card_resolver` 头注释所说的「由 CombatUI 触发」是计划态，拖拽/点选/数字键全归 combat-ui-interaction epic（0/9 未实现）。`combat_layout.gd` / `combat_actor_stage.gd` 只做建卡与信号接线，**无「当前操作角色」概念**（`character_status_card.gd` 无选中态，`deploy_panel.gd` 的 `selected_ids` 是备战的瞬态选择，不延续到战斗）
- 施法者裁定（临时口径，按用户指示「用我方阵位第一个存活角色并写明理由」）：
  - 新增 `src/ui/combat/shared/combat_caster_rules.gd`（54 行，`class_name CombatCasterRules extends RefCounted`，纯函数）：`resolve_caster(field)` 按 slot_index 升序取第一个 `character_id >= 0` 且 `state != DEAD` 的角色；判不出返回 `NO_CASTER = -1`；非字典条目跳过、`state` 缺失视为未阵亡（只有显式 DEAD 才排除）。镜像 `FieldState` 的两个常量值（0 EMPTY / 4 DEAD），不依赖全局单例
  - 理由（写进代码注释与 GDD）：阵位正是备战确认时 `DeploymentSystem.setup_field()` 写入的那份名册，用它不引入第二份「谁上场了」的真理来源；interaction epic 落地「当前角色」后应改为显式传入，本裁定降级为兜底
  - 新增 `src/ui/combat/shared/combat_play_bridge.gd`（63 行，`class_name CombatPlayBridge`）：`setup(combat, deployment)` + `play_card(id, targets)` 现读阵位裁定施法者 → `CombatSystem.play_card(id, targets, caster)`；未注入战斗系统返回 false 并告警；目标数组传副本（不改调用方）
  - 接线：`combat_actor_stage.setup()` 里把同一组数据源注入桥，新增 `play_card()` / `current_caster_id()`；`combat_layout.play_card()` / `current_caster_id()` 转调装配台——交互 epic 落地时直接调 `CombatLayout.play_card()` 即可，不必自己拼 `caster_id`。**没有为出牌单独再造一个「点选」UI**（手势本体归 interaction epic）
- 治疗广播改为实际增量：
  - `combat_damage_settlement._apply()` 新增第 7 参 `delta_is_actual: bool = false`：true 时先读 `hp_before`，落库后用 `hp_before - current_hp` 作为广播增量；`outcome["damage"]` 同步为实际值
  - `apply_heal()` 传 `delta_is_actual = true`
  - **满血 / 全额溢出 → 选「不广播」而不是「广播 0」**：`character_damaged` 的既有契约是增量事件（零增量无信息量），表现层 `CombatFeedbackCoordinator._enqueue_damage` 本就对 `delta == 0` 早退；广播 0 只会多一次空事件。选型已写进 GDD 与 `apply_heal` 的文档注释
  - `combat_on_play_effects.apply_heals()` 的返回值也改为实际回血总量（累加 `-outcome.damage`），与广播数字一致
  - 击杀回血走同一个 `apply_heal` → 自动获得同样的口径（满血击杀不再飘「+2」）
- GDD：`design/gdd/card-system.md` §执行端 补两条——「施法者从哪来（UI 出牌链路）」与「治疗广播按实际增量」（含满血/部分溢出两个判别例）
- 测试：新增 `tests/unit/combat_ui/test_combat_caster_rules.gd`（12 例）+ `tests/integration/combat_ui/test_play_bridge_settlement.gd`（8 例）；`test_on_play_effects.gd` 治疗广播断言 -3 → -2、满血用例补零广播
- 全量：**3662 tests / 3661 passing / 1 pending 存量 / 3 orphans 存量**，零回归（3641 → 净增 21）
- Tech debt：DEBT-CBT-018-10 追加「第四阶段已落地」
- **已知边界**：① 施法者口径是临时裁定（阵位第一个存活者），**不是玩家选中的角色**——interaction epic 落地前，多角色阵容里出牌一律记在阵位首位身上；② `CombatLayout.play_card()` 目前只被测试与后续交互层调用，真实对局里还没有手势去触发它；③ 满血治疗**完全无反馈**（资源已消耗、无飘字）——若策划要「无效」提示需另加信号/标志；④ 出牌伤害的 `damage_reduced` 缺省 false（同 DEBT-CBT-018-8 残留）；⑤ 增益/控制/抽牌/阵法等类别仍未建模；⑥ `CombatLayout` 465 行，超 300 行软上限（既有门面，拆分宜单独成故事）

### 自审修复（同日，`/code-review` 后）
- **H1 真实缺陷**：`_apply` 的 `delta_is_actual` 分支原带 `and outcome.known` 守卫——未知角色时 `delta` 回落到申请量，`apply_heals` 会把「一分血都没回」算进总数（返回值虚高，且与「零广播」对不上）。去掉守卫：未知角色 `read_hp` 与返回的 `current_hp` 都是 0，差值自然为 0。新增 `test_heal_on_unknown_character_reports_zero` 锁死
- **M1 文档与实现不符**：`resolve_caster` 类文档承诺「按 slot_index 升序」，实现只按数组顺序（`get_field()` 恰好有序，但桩数据/过滤后的快照未必）。改为入口先 `sort_custom` 再扫描（缺 `slot_index` 的条目排末尾），并补 `FIELD_STATE_READY` 镜像常量、`state=EMPTY` 但 id 合法的脏条目跳过
- **L 系列**：`has_sources()` 语义对齐同层 `DeployPanel`/`SettlementHost`（两份数据源齐备才算 true）；裸 `-1` 收敛到 `CasterRulesScript.NO_CASTER`；参数命名统一 `p_` 前缀；`[method X.y]` 文档交叉引用与「场景挂载侧只持装配台」的事实描述更正
- 新增 `tests/integration/combat_ui/test_layout_play_card.gd`（3 例）——门面 `CombatLayout.play_card()` / `current_caster_id()` 此前无任何测试（含「装配台缺失」早退分支）
- 全量：**3670 tests / 3669 passing / 1 pending 存量 / 3 orphans 存量**，零回归
- 已按审查意见**未采纳**的一项：把实际增量下沉到 `combat_roster_state.apply_damage()` 返回值（加 `delta` 键、消掉 `_apply` 的 `delta_is_actual` 双布尔参数）——方向合理但会改动攻击结算的既有返回契约，超出本次范围，留作后续重构；同理 `combat_layout.gd` 的拆分与出牌伤害 `damage_reduced` 未在本次处理
- Next recommended: combat-ui-interaction 001/003/005（出牌手势 + 目标选择），落地后把施法者改成玩家选中的角色；或继续迁移其余 36 张扁平卡到 `effects`

## Session Extract — 探索事件境界筛选 + 事件面板场景补链（2026-11-12）
- 任务：① 事件节点按玩家境界筛事件 + 可注入 rng 随机（此前 Presenter 只按节点 id 调 pick_by_index，无境界过滤、无随机）；② event_panel.tscn 从占位脚本换挂真实 EventPanelScreen（事件已走探索层 overlay，占位成死路径）
- EventDef 新增 `min_realm`（缺省 1=炼气，导出组「出现条件」）；「剑冢遗蜕 chain_001」「斜月三星洞 xie_yue_san_xing_001」设 2（筑基起）——炼气候选 7→5
- 新增 `src/feature/exploration_event_selector.gd`（47 行 static 纯函数）：`eligible_ids`（境界下限 1 兜底 + id 稳定排序）+ `pick_for_node`（有 rng 候选内均匀随机 / 无 rng 按节点 id 取模）；`ExplorationEventSystem.pick_for_node(node_id, realm, rng)` 薄转发（系统 297 行贴 300 上限）
- EventNodePresenter：`_on_event_node_reached` 消费 player_realm → `_pick_event` 走 pick_for_node；候选空 → 不弹面板不报错且不占 `_shown_nodes` 名额（补回事件后同节点可再弹）
- rng 注入：NodeGraphScreen 生产路径注入 `RandomNumberGenerator.new()`（GDD §10 防 SL「到达时才确定」）；测试 attach 缺省 null → 确定性取模可复现
- NodeGraphScreen 拆出 `node_graph_component_assembly.gd`（交互三组件 + 事件 Presenter + 转发回调表 + reduce_motion 读取统一进装配器）——屏幕 318→279 行回软上限内
- event_panel.tscn 根节点改挂 `event_panel_screen.gd`（删 screen_id=7 与 mouse_filter=2——后者会覆盖 _init 的 STOP 使遮罩穿透）；placeholder TITLES/HINTS 删 7 号条目；test_placeholder_scenes 的 CASES 移除该行并新增「挂真实脚本」断言（未删未改名任何既有测试）
- 测试：新增 `tests/unit/exploration_event/test_event_selection.gd`（11 例）；loading 补 min_realm 边界 2 例；presenter 补境界筛选 + 缺事件降级 2 例
- 全量：4169 tests / 4167 passing / 1 pending 存量 / 3 orphans 存量；唯一失败 `cost_system::test_ac008_batch_updated_payload_contains_cost_paths`（old=0 实得 2——GSM battle 域跨测试状态泄漏；三轮全量均同此例，隔离跑 cost_system 14/14 全过）为**存量**：stash 本轮改动跑 HEAD 基线同样红（4154/4152，同用例同断言）——与本轮改动域零交集（cost_system 按目录序先于本轮全部新增测试执行），零回归（4154 → 4169，净增 15 全过）
- 已知边界：① `map_pool` 信号载荷仍未消费——本轮是「全局注册表 + min_realm + rng」近似，GDD §10 按地图池加权（select_event(map_pool)）仍归 Foundation EventSystem 规划态；② 转场到 SceneID.EVENT_PANEL(7) 会得到无事件空面板——全库无该转场请求，路径仅为 SceneManager 自检保留；③ `_shown_nodes` 瞬态不进存档，重进地图同节点会再弹；④ run_tests.ps1 在 Git Bash 下用 `>` 重定向会丢 Godot 控制台输出（只剩 banner），改 `2>&1 |` 管道可完整捕获——三轮全量 = 直跑脚本内同款 godot 命令 ×1 + run_tests.ps1 管道 ×2
- Next recommended: 其余 5 事件按策划意图补 min_realm 分层；EventSystem 按地图池加权落地后把 Presenter 切到 map_pool 口径

## Session Extract — 商店节点 + 回复节点最小可用交互（2026-11-13）
- 任务：闭合两类节点「确认之后」的断路——商店真能买（扣灵石 + 入收藏）、回复点真能回血（走 GSM，夹上限），并用集成测试盖住四条点名断言
- **两处断链（第 1 项调研的产出）**：① 商店——`ExplorationDAGBuilder._fill_node_content` 调 `generate_shop_inventory_cb`，但 `ExplorationBootstrap.mount()` 从未注入它 → 真实 `enter_map` 的商店节点 `inventory` 恒为 `{}`；且 `NodeInteractionPopupHost` 对商店只弹固定文案确认框、确认时仅发 `shop_opened` 信号，**无任何界面接手**。② 回复——`resolve_node` 对 REST 发的 payload 是空字典；宿主调 `NodePopupServices.rest_party()` 找的 `ExplorationSystem.rest_at_node()` 根本不存在 → push_warning + 返回 0
- **新增 4 个生产文件**：`exploration_rest.gd`（163 行，回复结算）、`exploration_shop_inventory.gd`（124 行，默认货架 + `make_for_realm` 一级入口）、`exploration_shop.gd`（298 行，货架 + 购买结算）、`shop_panel_screen.gd`（251 行，纯代码 overlay）、`shop_node_presenter.gd`（239 行，消费 `shop_opened`/`rest_used`/`popup_closed`）
- **回复口径**：读 `CombatHpCarryover.read_all` → `plan` → `write_back`（经 GSM `_set_player_character_hp`），**不另开第二条 HP 通路**。总额度一次算（`heal_for(total_lost)`）再按角色 ID 升序逐角色取 `min(缺口, 剩余额度)`——逐角色各 floor 会掉零头，`total_heal == heal_for(total_lost)` 恒成立。阵亡（`current_hp<=0`）不计入也不复活；越界存档值按上限参与
- **商店口径**：先建卡实例再扣费，入收藏失败则原价退回灵石（「失败不半完成」）；拒绝路径（越界/售罄/余额不足/系统不可用）全在扣费之前；售罄状态由 `stock` 单一推导（不另存「已售」）
- **InputManager 锁栈的真实缺陷（本轮实测）**：`InputManager._on_tree_changed()` → `input_lock_stack.on_tree_changed()` 会**整体清空锁栈**；`tree_changed` 每帧至多一次、面板入树即触发——同帧 `push_lock` 的锁被立刻抹掉（实测 `is_input_allowed` 仍返回 true）。**MODAL 输入锁不能用于面板期间冻结**，改用 `NodePopupStage`（普通字段）+ `NodeMoveInteractor.set_process_unhandled_key_input(bool)`
- **冻结时机约束（自查发现）**：`NodeInteractionPopupHost._on_confirmed` 顺序是 `shop_opened.emit()` → `close_popup()`（后者触发舞台解冻）。若在 `shop_opened` 里冻结，舞台保存的「原值」已是冻结态 → 商店关闭后节点图**永久锁死**。修复：新增 `_on_popup_closed` 处理，等弹窗关闭再接管冻结；舞台用**自建**实例（不复用弹窗宿主那份，避免两侧争抢基线）
- **公式单一来源**：`NodeInteractionRules.rest_heal_amount` 改为转发 `ExplorationRest.heal_for`（此前两处各写一遍 `floor(lost × 0.5)`）
- **测试**：新增 `test_shop_and_rest_node_flow.gd`（7 例端到端：到达弹面板/买一件扣钱加货/钱不够给提示不扣/结算层二次拒绝/回复不超上限/满队无恙/冻结与解冻）、`test_exploration_rest.gd`（11 例公式与边缘）、bootstrap +2 例货架装配；拆出 `shop_rest_node_fixture.gd`（199 行，装置与存档还原）与 `card_template_primer.gd`（40 行，CardSystem 异步加载的同步推进，两个用例文件共用）让各文件回 300 行内
- **商店节点是随机产物**：`_assign_node_types` 按权重随机（shop 15/100），单张图不保证有商店——bootstrap 的货架用例改为按 `entry_count` 扫描至多 12 次（seed 固定 → 扫到哪张图确定）
- 全量：**4193 tests / 4192 passing / 1 pending 存量 / 3 orphans 存量**，零失败、零回归（4173 → 净增 20，全过）
- 已知边界（见下方「遗留」段）：`NodeInteractionRules.rest_heal_amount` 与 `ExplorationRest.heal_for` 已合并为转发，但 `NodeInteractionRules` 仍留一层包装（既有测试锁定该 API，未删）；`ExplorationSystem` 686 行（既有超限，本轮 +22）；商店面板商品行无键盘/手柄导航（焦点停留首行）；`stock` 每次重进地图重置；`NodePopupStage` 与商店各持一份冻结基线（弹窗在商店期间开合的语义已在文档说明但无测试覆盖）
- Next recommended: 商店面板的键盘/手柄导航（UI 规则要求所有交互元素双输入）；回复点/商店的结算写入是否要进存档快照口径核对；`ExplorationSystem` 拆分（686 行，超 300 软上限）

## Session Extract — 通关之后能继续玩下去（2026-11-17）
- 任务：闭合「打完 Boss 通一张图之后」的三处断路，并给「通关 → 回选图 → 进下一张图」这条链路补真实断言测试（断言 GSM 状态与奖励口径，不只是界面可见性）
- **三处断链（第 1 项审计的产出）**：① `MapCard._status_text` 读的 `is_first_clear` 字段 `ExplorationMapList._entry_for` 从未产出（死代码），条目也没有通关次数——「通关一次」与「刷了十次」界面上完全一样；② `MapSelectScreen.reentry_requested` **全库零消费者**——重入确认弹窗点「确认传送」既不扣费也不进图，点击看起来像失灵；③ 通关后无「下一张」引导，17 张卡里最显眼的仍是刚通完那张（还亮着「已通关」），默认动作变成原地重刷
- **已验证无需改动**（重入语义本就成立）：`ExplorationSystem.enter_map` 已把行动力重置为境界上限、已访问重置为入口、`entry_count` 递增，Boss 节点重新生成；重复通关只给基础奖励（`ExplorationMapFlush._settle_boss_defeated` 的 `is_first_clear` 分支）——重入与首入走同一条进图路径，不存在第二条发奖分支
- **新增生产文件**：`exploration_reentry.gd`（152 行，资格判定 + 扣费，拒绝路径一律不扣、`cost` 恒 0）、`map_select_reentry_flow.gd`（111 行，接上无消费者的 `reentry_requested`，进图出口是 `_enter_map` 的 `bind(false)`）、`exploration_clear_report.gd`（83 行，结算载荷组装含 `next_playable` 求值）、`exploration_reward_notice.gd`（46 行）、`map_clear_card_detail.gd`（55 行）、`map_select_cards.gd`（99 行，卡片行构建 + 推荐高亮，重建时重放推荐态）、`exploration_entry_flow.gd`（86 行，从 `exploration_scene` 拆出）、`map_select_interaction.gd`（172 行，从 `map_select_screen` 拆出）
- **`ExplorationMapGate.next_playable`**（纯函数）：表序即推荐序，优先未通关且已解锁的图，无可玩时退而给第一张未通关但锁着并带上 `locked_hint`，全图通关返回空字典
- **顺带修正**：`evaluate` 的 `is_unlocked` 放宽为 `already_cleared or (realm_ok and prerequisite_ok)`——通关记录即入场证明。不认这一条时，老档里只写了后一张的图会灰显挂锁，玩家打过的图突然点不动（`prerequisite_cleared` 仍如实报前置的态）
- **踩到并修正的坑**：`Callable.bind` 把绑定参数接在调用参数**之后**——`Callable(self, &"emit_signal").bind(&"enter_map_requested")` 会让信号名落到地图 ID 的位置，发出去的是 `emit_signal(map_id, "信号名")`，引擎报 `ERR_UNAVAILABLE` 且节点图静默挂不上（三个用例同时红）。改回唯一的包装方法
- **测试**：新增 `test_clear_to_next_map_flow.gd`（8 例端到端）、`test_exploration_reentry.gd`（21 例）、`test_map_card_status.gd`（11 例）、`test_map_next_playable.gd`（8 例，从 `test_map_unlock_gate.gd` 分出以守文件长度，用例一条未删）；`map_clear_settlement_fixture` 的 `enter_map` / `map_state` 参数化以支持换图
- 全量：**4940 tests / 4940 passing / 3 orphans 存量**，零失败、零回归（4896 → 4940，净增 44 全过）
- 已知边界（见下方「遗留」段）：`ExplorationSystem` 686 行仍超限（既有）；推荐态是瞬态不入存档，重进场景即消失（下次通关会重新点亮）；`MapSelectScreen` 恰 300 行、`map_select_screen.gd` 的 `pending_reentry_id` 查询是仅转发的一层
- Next recommended: `ExplorationSystem` 拆分（686 行，超 300 软上限）；推荐高亮在「从暂停菜单回选图」等无通关动作的路径上是否也该给（现只由结算确认触发）

## Session Extract — 战斗底栏键盘/手柄焦点链（2026-11-20）
- 任务：补齐战斗底栏的键盘/手柄焦点路径（`.claude/rules/ui-code.md` 要求交互元素同时支持键鼠与手柄）；此前三个按钮只有鼠标可用
- **审计到的事实**：底栏按钮 = `CombatBagButton.button`（行囊，在 `CombatBottomBar` 内）、`EndTurnButton.button`（结束出牌）、`CombatLayoutSettlementMount.retreat_button`（撤退，右上角按钮位）；父容器分别是 `BottomBar` / `RetreatButtonSlot`，两者都是 `MOUSE_FILTER_IGNORE`，只有内层 `Button` 收事件；三个按钮的 `focus_mode` 都是引擎默认（Button 为 `FOCUS_ALL`，但**没有任何 `focus_neighbor`**，Tab 走的是几何自推）；**全库无统一焦点管理器**——只有 `settlement_panel_view.wire_focus_chain` 一处自建成环先例；手牌卡 `hand_card.gd` 是纯 `Control`，默认 `FOCUS_NONE`
- **三条实测约束（探针验证，写进了 `combat_focus_ring.gd` 类文档）**：① 留空 `NodePath` **不会**停住焦点——引擎退回几何自推，焦点会跳到链外的战斗日志折叠按钮，要停住必须**自指**；② 引擎对 `disabled` 的 `Button` **不做跳过**（`find_next_valid_focus` 照样选中它），跳过必须由链自己保证；③ 相对 `NodePath` 须同树，未入树时算出的路径不可用
- 另两条：场景节点 `_input` **早于** Autoload 的 `_input`（实测），故 Esc 路由挂场景侧能先一步消费；`mouse_filter=IGNORE` 不影响键盘派发
- **新增生产文件**：`combat_focus_chain.gd`（248 行，链「手牌[0..n] → 行囊 → 结束出牌 → 撤退」+ 阶段驱动可聚焦性 + 默认焦点）、`combat_focus_ring.gd`（160 行，邻居路径纯函数）、`combat_escape_router.gd`（147 行，Esc 逐层退）、`hand_area_keyboard.gd`（41 行，手牌卡键盘确认出口）
- **默认焦点选「第一张手牌」而不是底栏按钮**：出牌阶段玩家第一件事是出牌，落手牌 = 进战斗就能按回车出牌；手牌空时才退到行囊（此时唯一能做的是结束回合）
- **Esc 层级**：行囊自己管（它自己接 `_input`，重复接管会让关闭路径有两条）→ 撤退/渡劫弹窗（走按钮 `pressed`，不直调 `close_dialog`——直调不发信号，上层收不到「玩家放弃撤退」）→ 取消选中 → **都没有则放行**给暂停菜单（不打乱既有语义）
- **改动**：`hand_card.gd`（焦点环画在 `_draw` 末尾 + `activated` 信号）、`hand_area.gd`（`card_activated` 改成转发属性，逐卡收信交给 `hand_area_keyboard`）、`hand_area_cards.gd`（抽出 `nodes_of`）、三个按钮补 `focus_mode` + 复用 `shop_panel_layout.apply_focus_ring`、`combat_scene_interaction.gd`（接线焦点链 + 键盘确认 + Esc 路由 + 阶段闸）
- **测试**：新增 `test_combat_keyboard_focus_path.gd`（12 例）与 `test_combat_escape_layers.gd`（4 例），全部走真实 `combat_scene.tscn` + `Viewport.push_input` 投递真实按键（Tab / 方向键 / 回车 / 空格 / Esc），不走直调 `grab_focus`
- **踩到并修正的坑**：刷新手牌会**换一批卡节点**（快照条目不带 `node`），停在阶段切换前抓到的引用上验的是已退场的旧节点（`test_enemy_turn_takes_focus_chain_offline` 因此先红）；`CombatLayout.settlement_host` 是属性不是方法，`call("settlement_host")` 报 `Nonexistent function`
- 全量：**5420 tests / 5420 passing / 3 orphans 存量**，零失败、零回归（combat_ui 目录 403 → 419，净增 16 例全过）
- 已知边界：手柄按键映射属 InputMap 层，本轮未覆盖（`ui_accept` / `ui_cancel` / `ui_left..down` 这些**默认动作**在手柄上本就成立，但项目自定义的手柄按键映射未见配置）；撤退按钮在敌方回合仍可聚焦（有意——GDD §10「撤退按钮始终在战斗中可点击」）；焦点链只管战场控件，战斗日志折叠按钮等链外控件仍走几何自推
- Next recommended: 手柄按键映射（InputMap 层）核对；战斗内其它面板（结算战利品选择）的焦点链与战场链的交接

## Session Extract — 三条尾巴收尾（2026-11-20 续）
- 任务：收掉上一轮的三条尾巴——① 链外控件仍走几何自推；② 弹窗关闭后焦点不回原处；③ 手柄按键映射未核过
- **尾巴一（链外收拢）**：新增 `combat_focus_sweeper.gd`（约 125 行）。实测链外唯一可见可聚焦者是顶部条 `CombatTopBar/CombatLog/CollapseLabel`（战斗日志折叠按钮），且它的 `pressed` 全库无人接线——Tab 跳过去按回车什么都不发生。处理方式：**收掉**（`focus_mode = FOCUS_NONE`）而不是纳入链——它是顶栏信息控件、不是回合动作，纳入会把「按了没反应」从链外搬到链上。豁免覆盖层子树（`DeployPanel` / `SettlementHost` / `CombatBagScreen`，它们自管焦点）；隐藏控件不动；`FOCUS_ACCESSIBILITY`（RichTextLabel 默认 = 3）放过。逐控件记账、`restore()` 可逆、幂等
- **尾巴二（焦点记忆）**：新增 `combat_focus_memory.gd`（约 110 行），挂在**交互接线**上（`CombatSceneInteraction.focus_memory()`，整场战斗一份，兜底注册为 `focus_chain.focus_default`）。三条路径全覆盖：行囊面板（`CombatBagHost.open/close`）、撤退确认弹窗与渡劫警示（`retreat_dialog.dialog_closed` / `tribulation_warning.dialog_closed` → 宿主 `_restore_focus`）、战利品面板（新增 `settlement_panel.closed` 信号 → 同一出口）。Esc 关弹窗走按钮 `pressed`，同样经过这个出口
- **关键陷阱（探针 `tools/probe_freed_ref.gd` 验证）**：已释放的对象引用与 `null` **比较相等**，`_remembered == null` 无法区分「没记过」与「记过但控件已释放」——故加了独立的 `_recorded: bool` 标志，否则「目标控件失效时回默认焦点」这条永远走不到
- **第二个陷阱**：对已释放对象做 `is Control` 判断会报 `Left operand of 'is' is a previously freed instance` 并**中断调用**（`CombatFocusRing.inside_tree` / `CombatFocusSweeper.restore` 都踩到）——必须先 `is_instance_valid()` 再判类型，顺序不能颠倒
- **尾巴三（InputMap）**：审计发现 `ui_accept` / `ui_cancel` 只有键盘绑定（方向键四个动作本就有 JOY_BUTTON + JOY_AXIS）。在 `project.godot` 的 `[input]` 补 `ui_accept` 的 `InputEventJoypadButton button_index=0`（A）与 `ui_cancel` 的 `button_index=1`（B），键盘绑定原样保留（回车/小键盘回车/空格、Esc）。未新增自定义动作名
- **新增测试 42 例**：`test_combat_focus_sweeper.gd`（13 例，单元）、`test_combat_focus_memory.gd`（10 例，单元）、`test_combat_input_map_joypad.gd`（10 例，单元，断言六个动作各至少 1 个 JOY 事件且键盘绑定未丢）、`test_combat_focus_restore_paths.gd`（9 例，集成，真实场景 + 真实按键：链外已收干净、连按 10 次 Tab 不跳链外、撤退/战利品/战败三条路径的焦点还原、Esc 还原、没记过时不凭空塞焦点）
- 全量：**5462 tests / 5462 passing / 3 orphans 存量**，零失败、零回归（5420 → 5462，净增 42 全过）
- 已知边界：`combat_focus_chain.gd` 301 行、`settlement_host.gd` 371 行，均略超 300 软上限（既有文件本轮追加所致，未再拆分）；`settlement_host.set_focus_fallback` 已删除（兜底改由交互接线在建立记忆时注册）

## Session Extract — 真机试玩式走查（2026-11-23）
- 任务：对 5710 tests 基线（HEAD 5fa08eb）做**真机试玩式走查**——`extends SceneTree` 驱动、非 headless、真实场景 + 真实 `Viewport.push_input`，走「主菜单→新游戏→选身份→选图→节点图→战斗→结算→回探索→暂停存档→回主菜单→继续→读档」全链，每步一张 PNG（`%TEMP%/mht-playtest/`，不提交）+ 一行结构化 stdout（step / scene id / 可见按钮文案 / focus / hint / elapsed）
- **驱动**：`tools/playtest_driver.gd`（不提交）；命令 `Godot_v4.6.3-stable_win64.exe --path . --script res://tools/playtest_driver.gd`（**绝不能加 `--headless`**，否则无渲染截图全空）；`DisplayServer.window_set_position(Vector2i(0,0))`，1920×1080
- **修掉 4 处**（每处都有红→绿断言，逐条验证）：
  1. 🔴 备战面板角色卡点不动（`deploy_character_card.gd` 只接悬停、`mouse_filter = STOP` 吞左键）→ 补 `card_pressed` 信号 + `gui_input` + `FOCUS_ALL` 焦点环 + `ui_accept`；`deploy_panel.gd` 转发 `toggle_selection`
  2. 🔴 主菜单读档面板 Esc 关不掉（主菜单态 `InputManager` 锁栈空 → UI_NAV 判定通过并消费 Esc → `_unhandled_input` 收不到）→ 改走 `_input`（先例 `map_clear_panel_screen.gd`）
  3. 🔴 结算/战败屏焦点停在 `none`（`placeholder_scene._build` 无 `grab_focus`）→ `_ready` 末尾抓「返回」按钮，且视口已有焦点拥有者时不抢
  4. 🟡 摘要首行泄露 `(result=1)` 开发者字段（该文案直接进玩家可见摘要标签）→ 去掉枚举后缀，`result` 仍可从视图直读
- **新增回归 20 例**：`test_deploy_card_click.gd`（8，真实左键）、`test_load_slot_panel_close_paths.gd`（6，含真实 Esc 投递）、`test_settlement_screen_playability.gd`（6，真实 .tscn + 桩）
- **踩到的坑**：GridContainer 子节点排列在 `NOTIFICATION_SORT_CHILDREN`（晚于 `add_child` 那帧）——不在 `before_each` 里 `await process_frame` 两次，6 张卡全叠原点，「点第 0 张」会落到最后一张（实测选中 205）；GUT `-gtest=` 不限定范围，应用 `-gselect=<文件名子串>`
- **登记未修**：`playtime_seconds` 从不写入（`SaveAutoSave.build_meta` 缺字段 + 暂停菜单传 `{}` + `session` 属 `NON_PERSISTABLE_DOMAINS` 三重缺失 → 主菜单恒显示「游玩 0小时0分」）；结算屏战利品三选一与已到账汇总并存（DEBT-CUI-008-3）；`pop_lock('scene_manager') source not found` 重入警告 ×8（外观性）；`assets/` 无 BGM 资源 → `BgmStreamCache` 警告
- 全量：**5730 tests / 5730 passing / 0 failing / 3 orphans 存量**，零回归（5710 → 5730，净增 20 全过）
- 提交：`ebd5d01 fix: 真机走查修四处 UI 阻塞`（5 生产文件 + 3 测试文件，未提交任何 `prompt_*` / `run_out*` / `tools/probe_*` / `tools/shot_*` / `tools/playtest_*` / png）
