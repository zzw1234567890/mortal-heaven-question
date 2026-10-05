extends SceneTree
## R-04 分辨率枚举 API spike 探针脚本（main-menu 003 前置 S14-4a）。
##
## 查证 Godot 4.6 DisplayServer 分辨率/窗口相关 API 的：
##   1. 存在性（反射 ClassDB 方法列表）
##   2. 签名（参数/返回类型）
##   3. 实际返回值（当前环境）
##
## 重点：`screen_get_resolutions()` 是否为 4.6 新增（LLM 知识截止 ~4.3 后），
## 及其替代方案（get_screen_count + get_screen_size 手动组合）。
##
## 复现命令：
##   C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
##     --path E:/mortal-heaven-question \
##     --script prototypes/r04-displayserver-resolutions-spike/spike.gd
## （不带 --headless 用真实 DisplayServer；带 --headless 用 dummy）

func _init() -> void:
	_run_probe()


func _run_probe() -> void:
	print("\n=== R-04 DisplayServer 分辨率/窗口 API 查证 ===")
	print("Godot: ", Engine.get_version_info())
	print("DisplayServer 驱动: ", DisplayServer.get_name())

	# ── 1. 反射查证方法列表 ──────────────────────────────────────────
	print("\n--- 反射：DisplayServer 相关方法（screen/window/resolution/mode/fullscreen） ---")
	var methods: Array = ClassDB.class_get_method_list("DisplayServer")
	var interesting: Array[String] = []
	for m in methods:
		var mname: String = str(m.get("name", ""))
		if _keyword_in(mname):
			interesting.append(mname)
	interesting.sort()
	for n in interesting:
		print("  - ", n)

	# ── 2. 关键 API 存在性 + 实际调用 ─────────────────────────────────
	print("\n--- 关键 API 存在性 + 实际值 ---")
	_probe_method("screen_get_resolutions", [], true)
	_probe_method("get_screen_count", [])
	_probe_method("get_screen_size", [0])
	_probe_method("screen_get_size", [0])
	_probe_method("get_primary_screen", [])
	_probe_method("window_get_mode", [])
	_probe_method("window_set_mode", [DisplayServer.WINDOW_MODE_WINDOWED])
	_probe_method("window_set_fullscreen", [false])
	_probe_method("is_window_fullscreen", [])
	_probe_method("window_get_size", [])
	_probe_method("window_set_size", [Vector2i(1280, 720)])

	# ── 3. WindowMode 枚举值 ─────────────────────────────────────────
	print("\n--- DisplayServer.WindowMode 枚举 ---")
	_print_window_mode_enum()

	# ── 4. Engine 层帧率/渲染相关（story 003 画质/帧率项） ──────────
	print("\n--- Engine 层（帧率/渲染） ---")
	print("Engine.max_fps = ", Engine.max_fps)
	print("ProjectSettings rendering/renderer: ",
			ProjectSettings.get_setting("rendering/renderer/rendering_method", "<缺省>"))

	print("\n=== 探针结束 ===")
	quit()


func _keyword_in(s: String) -> bool:
	var kws := ["screen", "window", "resolution", "fullscreen", "mode", "display"]
	for k in kws:
		if k in s:
			return true
	return false


func _probe_method(method_name: String, args: Array, skip_if_missing: bool = false) -> void:
	if not DisplayServer.has_method(method_name):
		print("  [缺失] ", method_name, "() — DisplayServer 无此方法")
		return
	if skip_if_missing:
		# 仅确认存在性，不调用（headless dummy 下可能返回空或报错）
		print("  [存在] ", method_name, "()")
		return
	# 尝试调用
	var result: Variant = DisplayServer.callv(method_name, args)
	print("  [存在] ", method_name, "(", args, ") = ", result)


func _print_window_mode_enum() -> void:
	# DisplayServer 常量枚举：WINDOW_MODE_*
	var modes := [
		["WINDOW_MODE_WINDOWED", DisplayServer.WINDOW_MODE_WINDOWED],
		["WINDOW_MODE_MINIMIZED", DisplayServer.WINDOW_MODE_MINIMIZED],
		["WINDOW_MODE_MAXIMIZED", DisplayServer.WINDOW_MODE_MAXIMIZED],
		["WINDOW_MODE_FULLSCREEN", DisplayServer.WINDOW_MODE_FULLSCREEN],
		["WINDOW_MODE_EXCLUSIVE_FULLSCREEN", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN],
	]
	for m in modes:
		print("  ", m[0], " = ", m[1])
