extends SceneTree
## R-01 spike 主脚本：双焦点行为验证 harness（注入式）。
##
## 运行方式（目标硬件，窗口模式）：
##   Godot_v4.6.3-stable_win64.exe --path . --script prototypes/r01-dual-focus-spike/spike.gd
##
## 六项验证：
##   V1 grab_focus() 是否影响鼠标 hover（悬停态视觉在 grab_focus 后是否保持）
##   V2 键盘焦点与鼠标 hover 是否可同时激活（双视觉并存）
##   V3 _gui_input() 对鼠标事件的响应（点击是否到达组件）
##   V4 _unhandled_input() 在键盘焦点被 grab 后是否仍触发（关键分派行为）
##   V5 InputManager.check_device_allowed() 设备掩码在双焦点下的判定（纯逻辑复核）
##   V6 accept_event() 后事件是否停止传播
##
## 结果以结构化行输出到 stdout，末尾汇总。全程序化事件注入——无需人工交互。

var results: Array[Dictionary] = []

func _initialize() -> void:
	# _initialize 阶段 root 场景尚未首次绘制——将协程交给首帧后执行
	call_deferred("_run_deferred")

func _run_deferred() -> void:
	await _run()
	quit(0)

func _record(id: String, label: String, observed: Variant, expected: Variant, pass_note: String = "") -> void:
	var status := "PASS" if str(observed) == str(expected) else "DIFF"
	results.append({"id": id, "label": label, "observed": observed,
	                "expected": expected, "status": status})
	print("  [%s] %s | 观测=%s | 预期=%s%s" % [status, label, observed, expected,
	      ("" if pass_note == "" else " | " + pass_note)])

func _run() -> void:
	print("=== R-01 双焦点 spike 开始（Godot %s）===" % Engine.get_version_info().string)

	# --- 场景搭建：root + probe ---
	var root_ctl := Control.new()
	root_ctl.name = "SpikeRoot"
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child.call_deferred(root_ctl)
	await process_frame
	await process_frame  # 等待布局稳定（anchors 生效）

	var probe := preload("probe_control.gd").new()
	probe.name = "Probe"
	probe.position = Vector2(200, 200)
	root_ctl.add_child(probe)
	await process_frame
	await process_frame  # 等 probe 进入树且完成首次布局
	# 探针中心全局坐标（打印以便核对——GUI 命中测试按全局矩形）
	print("  probe 全局矩形=%s | 视口大小=%s" % [probe.get_global_rect(), root.size])

	# 输入锁栈模块可用则做 V5 复核；不可用则标记 SKIPPED
	var im_script := load("res://src/foundation/input_manager.gd")

	# ================================================================
	# V1: grab_focus() 对鼠标 hover 的影响
	# ================================================================
	print("\n-- V1 grab_focus() 与鼠标 hover 的独立性 --")
	probe.simulate_mouse_enter()
	probe.simulate_mouse_exit()
	probe.simulate_mouse_enter()  # 保持 hover 态
	var hover_before := probe.hover_visual_active
	probe.grab_focus()
	await process_frame
	var hover_after := probe.hover_visual_active
	_record("V1", "grab_focus() 后 hover 视觉保持",
	        hover_after, true,
	        "grab_focus 前后 hover=%s→%s" % [hover_before, hover_after])
	# 补充事实观测：has_focus 是否获得（键盘焦点域）
	_record("V1b", "grab_focus() 获得键盘焦点（has_focus）",
	        probe.has_focus(), true)

	# ================================================================
	# V2: 双视觉并存——键盘焦点 + 鼠标 hover 同时激活
	# ================================================================
	print("\n-- V2 双视觉并存 --")
	var both_active := probe.focus_visual_active and probe.hover_visual_active
	_record("V2", "焦点环与悬停边框可同时激活", both_active, true,
	        "focus=%s hover=%s" % [probe.focus_visual_active, probe.hover_visual_active])

	# ================================================================
	# V3: _gui_input() 对注入鼠标事件的响应
	# ================================================================
	print("\n-- V3 _gui_input() 鼠标事件响应 --")
	var gui_count_before: int = probe.log.filter(func(e): return e.source == "gui_input").size()
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = probe.get_global_rect().get_center()
	# InputEventMouseButton 需要全局坐标 + device 设备号才会被 Viewport GUI 命中测试路由
	mb.device = 0
	mb.global_position = mb.position
	Input.parse_input_event(mb)  # 注入到事件队列，走完整 GUI 分派路径
	await process_frame
	await process_frame
	var gui_hits: int = probe.log.filter(func(e): return e.source == "gui_input").size()
	print("  [diag] parse_input_event 后 gui_input 记录数=%d（注入前=%d）" % [gui_hits, gui_count_before])
	if gui_hits == gui_count_before:
		# parse_input_event 在 SceneTree 脚本环境下不触发 Viewport GUI 命中测试
		# （无主场景窗口消息循环）——直接手动调用 _gui_input 验证回调契约本身。
		# 这是降级验证：确认「若事件到达组件，_gui_input 会被调用且 accept 生效」。
		probe._gui_input(mb)
		gui_hits = probe.log.filter(func(e): return e.source == "gui_input").size()
		print("  [diag] 手动派发后 gui_input 记录数=%d" % gui_hits)
	_record("V3", "_gui_input 收到鼠标点击（手动派发降级）", gui_hits >= 1, true,
	        "gui_input 记录数=%d（注入前=%d）| parse_input_event 在 SceneTree 脚本环境下不路由 GUI——见 REPORT.md 说明" % [gui_hits, gui_count_before])

	# ================================================================
	# V4: _unhandled_input 在键盘焦点被 grab 后是否触发
	# ================================================================
	print("\n-- V4 _unhandled_input 与键盘焦点 --")
	# 焦点仍在 probe 上（V1 已 grab）——注入一次键盘事件
	var before_unhandled := probe.log.size()
	var uk := InputEventKey.new()
	uk.keycode = KEY_F4
	uk.pressed = true
	Input.parse_input_event(uk)
	await process_frame
	await process_frame
	var unhandled_hits := 0
	for e in probe.log:
		if e.source == "unhandled_input":
			unhandled_hits += 1
	# 诊断：键盘事件是否同时被焦点路由到 _gui_input（焦点所有者收到键事件）
	var key_gui_hits := 0
	for e in probe.log:
		if e.source == "gui_input" and e.detail.get("event", null) is InputEventKey:
			key_gui_hits += 1
	print("  [diag] F4 注入后：gui_input(键盘)=%d unhandled_input=%d" % [key_gui_hits, unhandled_hits])
	_record("V4", "probe 持有键盘焦点时 _unhandled_input 触发",
	        unhandled_hits >= 1, true,
	        "unhandled_input 记录数=%d | 若 DIFF：焦点 Control 消耗键盘事件，_unhandled_input 不触发——ADR-0004 路径 B 设计被证实" % unhandled_hits)

	# 无焦点基线对照：释放焦点后再注入
	probe.release_focus()
	await process_frame
	var before_unhandled2 := probe.log.size()
	var uk2 := InputEventKey.new()
	uk2.keycode = KEY_F5
	uk2.pressed = true
	Input.parse_input_event(uk2)
	await process_frame
	await process_frame
	var unhandled_hits2 := 0
	for e in probe.log.slice(before_unhandled2):
		if e.source == "unhandled_input":
			unhandled_hits2 += 1
	_record("V4b", "无焦点时 _unhandled_input 触发（基线）",
	        unhandled_hits2 >= 1, true, "记录数=%d" % unhandled_hits2)

	# ================================================================
	# V5: InputManager 设备掩码独立判定（纯逻辑复核）
	# ================================================================
	print("\n-- V5 InputManager check_device_allowed 双焦点判定 --")
	if im_script != null:
		var im: Node = im_script.new()
		im._ready()  # Autoload 手动初始化（prototype 放宽——跳过 GSM 接线）
		im.push_lock(im.LockType.ANIMATION, &"spike_keyboard_only",
		             im.DeviceType.KEYBOARD | im.DeviceType.GAMEPAD)
		# 键盘锁——鼠标仍允许（ADR-0004 速查表场景）
		var mouse_ok: bool = im.is_input_allowed(im.ActionType.UI_NAV, im.DeviceType.MOUSE)
		var kbd_nav_ok: bool = im.is_input_allowed(im.ActionType.UI_NAV, im.DeviceType.KEYBOARD)
		var gameplay_ok: bool = im.is_input_allowed(im.ActionType.GAMEPLAY, im.DeviceType.KEYBOARD)
		_record("V5", "ANIMATION 锁（仅键鼠白名单含鼠标）下鼠标 UI_NAV",
		        mouse_ok, false, "白名单=KEYBOARD|GAMEPAD——鼠标被锁")
		_record("V5b", "ANIMATION 锁下键盘 UI_NAV", kbd_nav_ok, true)
		_record("V5c", "ANIMATION 锁下键盘 GAMEPLAY", gameplay_ok, false,
		        "gameplay_ok=%s（对照 GUT 基线应为 false）" % gameplay_ok)
		im.free()
	else:
		results.append({"id": "V5", "label": "InputManager 加载", "observed": "load 失败",
		                "expected": "script", "status": "SKIPPED"})
		print("  [SKIPPED] input_manager.gd 无法加载")

	# ================================================================
	# V6: accept_event() 阻止传播
	# ================================================================
	print("\n-- V6 accept_event() 传播阻断 --")
	# V3 的 gui_input 记录中点击事件已 accept——检查 root 兄弟层未收到同事件
	# 通过 probe 日志顺序对照：gui_input 收到后 unhandled_input 不应收到同一鼠标点击
	var mouse_gui := 0
	var mouse_unhandled := 0
	for e in probe.log:
		var ev = e.detail.get("event", null)
		if ev is InputEventMouseButton:
			if e.source == "gui_input":
				mouse_gui += 1
			elif e.source == "unhandled_input":
				mouse_unhandled += 1
	_record("V6", "gui_input accept 后鼠标事件不落入 _unhandled_input",
	        mouse_unhandled == 0, true,
	        "gui=%d unhandled=%d" % [mouse_gui, mouse_unhandled])

	# ================================================================
	# 汇总
	# ================================================================
	print("\n=== 汇总 ===")
	var pass_n := 0
	var diff_n := 0
	var skipped_count := 0
	for r in results:
		match r.status:
			"PASS": pass_n += 1
			"DIFF": diff_n += 1
			_: skipped_count += 1
		print("  %s %s %s（观测=%s 预期=%s）" % [r.status, r.id, r.label, r.observed, r.expected])
	print("PASS=%d DIFF=%d SKIPPED=%d" % [pass_n, diff_n, skipped_count])

	# 结果 JSON 落盘——供 spike 报告引用
	var json := JSON.stringify({"engine": Engine.get_version_info().string,
	                            "results": results}, "  ")
	var f := FileAccess.open("res://prototypes/r01-dual-focus-spike/results.json", FileAccess.WRITE)
	if f:
		f.store_string(json)
		f.close()
		print("结果已写入 prototypes/r01-dual-focus-spike/results.json")

	root_ctl.queue_free()
