class_name PauseAudioAdapter
extends RefCounted
## PauseAudioAdapter —— 暂停菜单音频暂停/恢复接口（INAD-1 条件性条款裁决）。
##
## 定义 [method suspend] / [method resume] 两方法接口。[br]
## 本文件提供 no-op 桩实现——暂停/恢复经 adapter 调用；真实总线操作
## （AudioServer BGM/SFX 总线暂停）归 audio-manager epic 实现，其 QA 计划
## 须登记回归项「暂停时音频同步暂停/恢复」。[br]
## [br]测试可注入子类记录调用次数（AC-3 桩阶段断言）。[br]
## [br]来源: hud Story 005（2026-09-11 QL-STORY-READY INAD-1 裁决）、
## ADR-0031 §1.1。


## 暂停音频——打开暂停菜单时调用。[br]
## [br]桩实现为 no-op；audio-manager epic 覆盖此方法执行
## [code]AudioServer.set_bus_mute(bgm_bus, true)[/code] 等总线操作。
func suspend() -> void:
	pass


## 恢复音频——关闭暂停菜单时调用。[br]
## [br]桩实现为 no-op；audio-manager epic 覆盖此方法恢复总线。
func resume() -> void:
	pass
