---
name: hud-story005-ql-review
description: hud Story 005（暂停菜单）QL-STORY-READY 审查 2026-09-11——GAPS+1 INADEQUATE（音频 AC 不可实现）、ESC 信号链路、探索进度三重数据缺口
metadata:
  type: project
---

hud epic story-005-pause-menu QL-STORY-READY 审查（2026-09-11）。主审判 READY，我方裁决 **GAPS + 1 项 INADEQUATE**。

关键发现：
- **INAD-1（阻塞）**：AC-5 音频总线暂停不可实现——src/ 零 AudioServer 引用，audio-manager epic 未排期（S13-14 nice-to-have）。推荐选项 A：AC-5 改条件性条款 + PauseAudioAdapter 桩（suspend_audio/resume_audio no-op），真实总线归 audio-manager epic 并登记回归项。
- **GAP-1**：ESC 链路未裁决。input_manager.gd `_input()` 拦截 ESC 且 set_input_as_handled() 但不发信号（L342-346）——HUD 侧 _unhandled_input 永远收不到。裁决：InputManager 发 `pause_requested()` 信号，HUD 监听；鼠标路径直连按钮。
- **GAP-2**：探索进度「青云剑宗 · 层3/5」三重缺口：无 map_id→显示名映射；GSM 无总层数字段（且 map_states 快照只存 entry_count/graph/nodes，**不存 layers 键**，但 exploration_system.gd L396 重建时读 state.get("layers", []) 恒空——读档重建既有缺陷，已建议报 lead-programmer S3）；node_position.layer 0 基 vs 显示 1 基。裁决：显示名走地图注册表配置；分母从 nodes 快照推导 max layer+1；显示层号 layer+1。
- **GAP-3**：AC-6 HUD 侧接收接口无契约无测试用例。裁决：`hud.request_pause(source: StringName)` + 增补集成测试用例。
- **GAP-4**：背景模糊技术无裁决（4.6 glow 重做在知识截止后），建议先过 TD-ENGINE-RISK，候选 ColorRect+自写 shader。
- **GAP-5**：「保存并退出」vs「返回主菜单」语义差异未定义。

**Why:** 就绪度清单只查文档存在性；这些缺口全部是「实现者必须做未授权裁决」类型，左移关卡的价值即在编码前拦下。

**How to apply:** story 修订后复审只须核对 INAD-1 裁决落地 + GAP 文本并入；adequate 项（AC-2 战斗状态集成测试规格等）不重审。audio-manager epic 的 QA 计划中登记「暂停时音频同步」回归项。

相关：[[qa-lead-working-conventions]] [[hud-story002-ql-review]]
