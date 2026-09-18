# QA 计划：Sprint 14——主菜单 + R-02 关闭 + CI 回归网 + audio 骨架

**日期**：2026-09-13
**由**：/qa-plan 生成
**范围**：14 个 story/任务（main-menu 5 + combat-ui-layout 2 + audio-manager 1 + hud 3 结转 + CI 1 + TD 打包 1 + QA 签收 1）——涉及 4 个系统
**引擎**：Godot 4.6（GDScript，GUT 9.6.1）
**Sprint 文件**：`production/sprints/sprint-14.md`（2026-09-21 至 10-02）

---

## 测试摘要

| Story | 类型 | 需要自动化测试 | 需要手动验证 |
|-------|------|------------------------|------------------------------|
| S14-1 CI 配置 | 工具 | CI 工作流自身（首次运行即全量测试绿） | 无 |
| S14-2 main-menu 001 场景与按钮组 | UI（Logic+Integration 内核） | 单元 2 文件 + 集成 2 文件 | 截图 + 交互走查 |
| S14-3 main-menu 002 设置框架+音量 | UI（Logic 内核） | 单元 2 文件 + 集成 1 文件 | 实时生效可听验证 |
| S14-4 main-menu 003 画面设置+回退 | UI（Logic 内核） | 单元 2 文件 + 集成 1 文件 | 分辨率回退提示走查 |
| S14-5 009a 合批方案定型 | Visual/Feel | 无（规范文档） | 原型 DC 实测记录 |
| S14-6 009b R-02 满场实测 | Visual/Feel（性能关卡） | 无（本地关卡脚本——**不进 CI**，QL-STORY-READY 裁决） | 两场景 DC 实测 + 帧时间人工签批 |
| S14-7 audio 001 总线+骨架 | Integration | 集成 1 文件 + 单元 1 文件 | 无 |
| S14-8 QA 签收 | QA | 全量零回归复跑 | 冒烟检查 |
| S14-9 TD-007/012 + test_ac010 | 测试补齐 | 单元/集成补齐（本文档定义） | 无 |
| S14-10 main-menu 004 按键绑定 | UI（Logic 内核） | 单元（story QA Test Cases 已备） | 走查 |
| S14-11 hud 006 探索右下信息组 | UI | story QA Test Cases 已备（Sprint 13 QA 计划遗留） | 截图 |
| S14-12 hud 007 场景过渡提示 | UI | story QA Test Cases 已备 | 截图 |
| S14-13 main-menu 005 语言切换 | UI + Integration | story QA Test Cases 已备 | 走查 |
| S14-14 hud 008 F1 静音图标 | UI | story QA Test Cases 已备 | 截图 |

---

## 需要自动化测试

### main-menu 001 主菜单场景与按钮组 — UI（Logic+Integration 内核）

**测试文件路径**（story Test Evidence 已锁定）：
- `tests/unit/main_menu/test_continue_button_state.gd`——has_continuable_save 纯函数（空列表/全损坏/单损坏/最新损坏其余有效/全有效 5 态）
- `tests/unit/main_menu/test_latest_save_selection.gd`——最近存档选取（多时间戳/单存档/时间戳相同槽序 tie-break）
- `tests/integration/main_menu/test_corrupt_save_continue.gd`——存档损坏路径（点击继续→弹提示→确认→回主菜单）
- `tests/integration/main_menu/test_menu_navigation.gd`——场景导航（新游戏→request_scene_change(IDENTITY_SELECT)，无 GSM 直接写）

**预估测试数量**：~14 个（单元 8 + 集成 6）

### main-menu 002 设置面板框架与音量控制 — UI（Logic 内核）

**测试文件路径**：
- `tests/unit/main_menu/test_db_from_percent.gd`——音量转换（0→-80/负→-80/100→0/50→≈-6.02/1→有限负值/101 与 -1 钳制/浮点步进）
- `tests/unit/main_menu/test_settings_rollback.gd`——未保存回滚（拖动→关闭→回滚已保存值且文件未改；拖动→应用→保留；关闭→重开显示已保存值）
- `tests/integration/main_menu/test_volume_bus_apply.gd`——滑条→总线端到端（音乐 50% → get_bus_volume_db(Music)≈-6.02；总音量 0% → Master -80dB）

**预估测试数量**：~14 个（单元 10 + 集成 4）

### main-menu 003 画面设置与应用/回退 — UI（Logic 内核）

**测试文件路径**：
- `tests/unit/main_menu/test_resolution_filter_fallback.gd`——分辨率过滤回退（R∈L 通过/R∉L 回退上一可用/链终止 1920×1080/L 空/宽高比剔除）
- `tests/unit/main_menu/test_unsaved_changes_detection.gd`——脏检测（任一键不同 true/全同 false/int 60==float 60.0/空字典/单键）
- `tests/integration/main_menu/test_graphics_apply.gd`——应用端到端（max_fps 30/60/120/0 全枚举断言；画质预设映射值变更；不支持分辨率回退不崩溃）

**⚠️ 实现前置**：分辨率枚举 API（`screen_get_resolutions()`）须先查证 `docs/engine-reference/godot/`——查不到先 spike（story Engine Notes 已标注）。

**预估测试数量**：~14 个（单元 9 + 集成 5）

### audio-manager 001 总线+AudioManager 骨架 — Integration

**测试文件路径**：
- `tests/integration/audio/test_bus_layout.gd`——总线结构存在性（6 总线+3 子总线按名称断言+默认 dB 与 GDD 表一致+双 Limiter ceiling）
- `tests/unit/audio/test_audio_manager_api_skeleton.gd`——API 签名完整性（11 个 API 与 GDD §8 一致）+ 静默模式（AudioServer 不可用注入→no-op 不崩溃+日志一次）

**预估测试数量**：~10 个（单元 5 + 集成 5）

### TD-007/012 + test_ac010 根治 — 测试补齐（S14-9）

**测试文件路径**：
- TD-007：`tests/unit/hud/test_realm_bar_signal_wiring.gd`——realm_bar 信号接线四路径（batch 过滤 player.realm/is_fallen、setup 重入防重复连接、脉动合成翻转序列化神期满→回落重显→恢复、_refresh 幂等）；需 hud 专用 mock GSM（含 player 域+三信号）
- TD-012：`tests/integration/hud/test_deck_overlimit_visual.gd`——超限态集成断言（直写 current_deck 超 cap + emit batch + 断言 `deck_label.label_settings.font_color == Color("#B3424A")` + `overlimit_label.visible == true`）；_on_batch_updated lingshi+deck 同帧双键 elif 遮蔽路径
- test_ac010：`tests/integration/realm_system/test_realm_up.gd` 内隔离修复——GSM 信号时序问题（Sprint 12 遗留 flaky；根因排查 + 确定性化，不改断言语义）

**预估测试数量**：~12 个新增/修复

### CI 配置 — 工具（S14-1）

**验证方式**：首次 push 触发即全量 2598+ 测试绿——CI 的测试就是测试套件本身。
- 工作流：`.github/workflows/tests.yml`（Godot headless runner——容器镜像或自托管，S14-1 内选定）
- 断言：push/PR 双触发；坏测试即红（CI/CD 规则：测试是阻塞关卡，绝不禁用失败测试）
- 注意：GUT 命令行 `godot --headless -s addons/gut/gut_cmdln.gd -gexit`（本地已验证模式，CI 复用）

---

## 手动 QA 检查清单

### 009a 合批方案定型 — Visual/Feel
**验证方法**：原型 DC 实测记录 + 规范文档审阅
**必须签收人**：lead-programmer
**需要捕获的证据**：`production/qa/evidence/r02-batching-spec.md`（16 角色卡原型每位 DC ≤4、连续 60 帧稳定采样、图集结构/HP 条/DC 分组/fallback/测量方法五节）

检查清单：
- [ ] 原型实测 16 位合计 ≤64 DC（D3D12 窗口模式）
- [ ] 规范五节齐备——002-006 开发者按文档可实现无需再做渲染决策

### 009b R-02 Draw Call 满场实测（stub 版） — Visual/Feel（性能关卡）
**验证方法**：本地关卡脚本实测（不进 CI——QL-STORY-READY 2026-09-07 裁决）+ 帧时间人工签批
**必须签收人**：lead-programmer + ui-programmer
**需要捕获的证据**：`production/qa/evidence/r02-benchmark-evidence.md`

检查清单：
- [ ] 标准场景（16 位满+7 手牌+2 阵法+费用栏+日志折叠）DC ≤200
- [ ] 峰值场景（胜利结算+攻击箭头 stub+阵法光环+飘字+弹窗）DC ≤200
- [ ] 标准场景帧时间 ≤16.6ms 采样分布记录+人工签批
- [ ] 1280×720 所有 UI 文字 ≥12pt（font_size_responsive）
- [ ] D3D12 烟雾 3 项（费用消散粒子/伤害数字淡出/阵法光环）无 alpha 混合异常
- [ ] **R-02 只更新为「有条件关闭（provisional）」**——复测义务登记到 combat-ui-interaction epic（PR-SPRINT 监督条件 #3）

### main-menu 001/002/003 — UI 走查
**验证方法**：截图 + 交互逐步验证（debug 宿主或游戏内）
**必须签收人**：lead-programmer
**需要捕获的证据**：`production/qa/evidence/main-menu-scene-evidence.md` / `settings-audio-evidence.md` / `settings-graphics-evidence.md`

检查清单（每 story 验收标准全项，重点）：
- [ ] 001：0.8s 淡入+标题滑落；5 按钮键盘 Tab/方向键可达；无存档继续灰态；D3D12 60fps；DC ≤50；720p 不溢出
- [ ] 002：拖动滑条即时可听变化；0.3s 滑入/0.2s 滑出；未保存关闭回滚
- [ ] 003：不支持分辨率弹提示不黑屏；未保存关闭确认弹窗两分支；恢复默认四分类归位

---

## 冒烟测试范围

在此 sprint 的任何 QA 交接前需要验证的关键路径：

1. 游戏启动到主菜单无崩溃（**新路径**——main-menu 001 交付后）
2. 主菜单→新游戏→身份选择场景切换正常（**新路径**）
3. 设置面板打开/关闭/音量实时生效（**新路径**）
4. HUD 既有功能回归（境界/修为条、灵石计数、通知、暂停——Sprint 13 交付物无回归）
5. 存档/读档周期完成无数据丢失（继续游戏路径）
6. 全量测试套件 CI 绿（S14-1 交付后每次 push）

*冒烟测试由开发者通过 `/smoke-check` 验证。*

---

## 试玩要求

本次 sprint 无需正式试玩会期——主菜单/设置为功能性 UI，无手感调优诉求；全流程试玩归里程碑收尾（Sprint 16 全流程可演示验证）。

---

## 完成定义 — 本次 Sprint

- [ ] 所有验收标准已验证——自动化测试结果或手动证据（截图/实测记录 + 签收）
- [ ] 所有逻辑和集成类 story 的测试文件存在于 story Test Evidence 指定路径并通过
- [ ] 所有 Visual/Feel 和 UI 类 story 的手动证据文档存在于 `production/qa/evidence/`（ADVISORY 证据随关即补——回顾行动项 #5）
- [ ] CI 工作流上线且首次全量运行绿
- [ ] 冒烟检查通过（`/smoke-check sprint`）
- [ ] 未引入回归问题（2598+ 既有测试零失败）
- [ ] 代码已审查（`/code-review`——main-menu 001-003 + audio 001 为重点对象）
- [ ] Story 文件已更新为 `Status: Complete`（`/story-done`）
- [ ] R-02 风险登记册更新为「有条件关闭（provisional）」+ 复测义务登记
