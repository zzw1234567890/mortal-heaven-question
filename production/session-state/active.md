# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 14（Day-2）
Task: S14-1 CI 已推送观察——残余 3 非确定失败登记 TD-014 移交 S14-9；下一个入口 S14-7 audio 001 / S14-2 main-menu 001 / S14-5 009a
<!-- /STATUS -->

<!-- QA-PLAN：2026-09-08 | System：sprint-13 | Plan written：production/qa/qa-plan-sprint-13-2026-09-08.md -->
<!-- SPIKE：2026-09-08 | S13-1 R-01 | Report：production/spikes/r01-dual-focus-spike.md | OQ-02 已关闭 | R-01 已关闭 -->

## 当前任务

**S14-1 CI 配置——管道落地，残余失败已登记**（2026-09-21/22，提交 b429789 + f187efc）：

- `.github/workflows/tests.yml`：GitHub Actions + Godot 4.6.3 Linux headless 自托管下载 + GUT 全量；缓存二进制与 .godot 导入缓存；push/PR 触发
- 首跑 12 failing → 根因定位：event_system test_load_templates 8 个——向 `res://assets/events/<subdir>/` 写临时 .tres 但子目录是 git 不追踪的空目录，CI 干净检出后不存在 → ResourceSaver ERR_CANT_OPEN(19)。**git worktree 干净检出 100% 复现**
- 修复（f187efc）：before_each 对 7 个 TEST_SUBDIRS `make_dir_recursive`（测试自建自清理，card_system fixture 同款模式）→ 二跑 12→3
- 残余 3 个为测试非确定性（非代码 bug，非 CI 配置问题）：card_system ac006/ac009（load_threaded 完成顺序竞态，Linux 间歇红）+ realm ac010（已知 flaky）——**登记 TD-014 移交 S14-9**，CI 保持红是真实信号，不禁用不跳过
- 工作流注释已更新已知失败清单；sprint-status.yaml 14-1 → review

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
