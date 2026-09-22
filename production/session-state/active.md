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
