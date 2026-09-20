---
name: audio-story001-ql-review
description: QL-STORY-READY 对 audio-manager Story 001（S14-7）的裁决（2026-09-19，GAPS：2 BLOCKING+4 ADVISORY）——R-06 GDD 修订义务未承接、「root 直挂」表述过时、bus_layout 应用路径与两套默认值关系未声明
metadata:
  type: project
---

2026-09-19 对 `production/epics/audio-manager/story-001-bus-layout-manager-skeleton.md`（S14-7，audio 001 总线+AudioManager 骨架，blocker of 14-3）执行 QL-STORY-READY，裁决 **GAPS**（2 BLOCKING + 4 ADVISORY）。

**Why:** ① 风险登记册 R-06 关闭记录（2026-09-13）明确「audio-system.md L135 与待解决问题 #5 随 audio 001 实现时修订」，但 story 的 Out of Scope 只写「R-06 spike 非本 epic story」——修订义务无载体，将静默丢失；② story ADR Summary/Implementation Notes 写「root 直挂 Node」，而 ADR-0031 §1.2 已于 2026-09-09 修订为「PersistentLayer 挂为 SceneManager（Autoload）子节点」——代码实况（scene_manager.gd `_ready()`→`ensure_layer()`，`register_persistent()` L216）与修订后 ADR 一致，story 文本过时；③ bus_layout .tres 运行时应用路径（project.godot 设置 vs `AudioServer.set_bus_layout()`）未指定；④ bus_layout 默认 dB（出厂值）与「启动真值=设置文件覆盖」（2026-09-19 裁决，加载归 audio 005）两套默认并存——时序自洽非矛盾，但需在 story 文字固化。

**How to apply:** story 修复后复审 4 点：
- BLOCKING-1：加交付项「修订 GDD L135（删「5-30ms 间隙」→ 引用 `production/spikes/r06-ogg-loop-spike.md` 实测零间隙，BGM 维持 WAV MVP）+ 关闭待解决问题 #5」
- BLOCKING-2：「root 直挂」→「SceneManager（Autoload）子节点」（2026-09-09 ADR 修订）
- ADVISORY：Estimate 占位（yaml 14-7 已有 1.0d）；bus_layout 应用路径明确；两套默认值时序说明（资产加载→启动设置覆盖，覆盖逻辑归 audio 005）；AudioState 枚举（12 值）归属本 story 骨架（004 只做矩阵）

已验证无缺口项：AC-1 默认 dB 与 GDD 音量规格表逐项一致（Master 0/BGM 0/SFX -3/UI -8/Ambient -10/Voice -1，Limiter ceiling -0.5/-1dB）；AC-4 的 11 个 API 与 GDD §8 签名完全一致；PersistentLayer/register_persistent 真实存在且场景切换可测（Autoload 子树不随 current_scene 释放）；引擎参考 `docs/engine-reference/godot/modules/audio.md` 覆盖按名总线访问/池模式，且确认 4.4-4.6 音频无破坏性变更（与分辨率零覆盖情况不同，本 story 无引擎参考缺口）。

相关：[[main-menu-story002-003-ql-review]]（设置文件胜出/启动加载归 audio 005 的裁决来源）[[hud-story005-ql-review]]（音频总线不存在先例——本 story 正是补齐者）
