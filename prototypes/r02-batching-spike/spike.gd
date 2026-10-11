extends SceneTree
## R-02 Draw Call 测量 API spike 探针脚本（combat-ui-layout 009a 前置）。
##
## 查证 Godot 4.6 RenderingServer 的 DC 测量 API：
##   1. `RenderingServer.get_rendering_info(info)` 是否存在 + 签名
##   2. `RenderingServer.RenderingInfo` 枚举常量（尤其
##      RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME 与
##      RENDERING_INFO_2D_DRAW_CALLS_IN_FRAME）
##   3. 实际调用返回值（headless 下 DC 数不具代表性——仅验证可读不崩溃）
##
## 复现命令：
##   C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
##     --path E:/mortal-heaven-question \
##     --script prototypes/r02-batching-spike/spike.gd
##
## 结论回写 docs/engine-reference/godot/modules/rendering.md（当前零覆盖）。

func _init() -> void:
	_run_probe()


func _run_probe() -> void:
	print("\n=== R-02 RenderingServer DC 测量 API 查证 ===")
	print("Godot: ", Engine.get_version_info())
	print("渲染后端: ", RenderingServer.get_current_rendering_method())

	# ── 1. 反射查证方法列表 ──────────────────────────────────────────
	print("\n--- 反射：RenderingServer 相关方法（rendering/info/draw/call） ---")
	var methods: Array = ClassDB.class_get_method_list("RenderingServer")
	var interesting: Array[String] = []
	for m in methods:
		var mname: String = str(m.get("name", ""))
		if _keyword_in(mname):
			interesting.append(mname)
	interesting.sort()
	for n in interesting:
		print("  - ", n)

	# ── 2. 关键 API 存在性 ────────────────────────────────────────────
	print("\n--- get_rendering_info 存在性 ---")
	_probe_method("get_rendering_info", [0])

	# ── 3. RenderingInfo 枚举 ─────────────────────────────────────────
	print("\n--- RenderingServer.RenderingInfo 枚举（DC 相关） ---")
	_print_rendering_info_enum()

	print("\n=== 探针结束 ===")
	quit()


func _keyword_in(s: String) -> bool:
	var kws := ["render", "info", "draw_call", "drawcall", "call", "total"]
	for k in kws:
		if k in s.to_lower():
			return true
	return false


func _probe_method(method_name: String, args: Array) -> void:
	if not RenderingServer.has_method(method_name):
		print("  [缺失] ", method_name, "() — RenderingServer 无此方法")
		return
	var result: Variant = RenderingServer.callv(method_name, args)
	print("  [存在] ", method_name, "(", args, ") = ", result)


func _print_rendering_info_enum() -> void:
	# 反射 RenderingServer 的 RenderingInfo 枚举（含 4.6 可能新增项）
	var enum_list := ClassDB.class_get_integer_constant_list("RenderingServer")
	if enum_list.is_empty():
		print("  (无整数常量——枚举反射为空)")
		return
	for c in enum_list:
		var cname: String = str(c)
		if "DRAW_CALL" in cname or "RENDERING_INFO" in cname or "TOTAL" in cname:
			print("  ", cname, " = ", RenderingServer.get(cname))
