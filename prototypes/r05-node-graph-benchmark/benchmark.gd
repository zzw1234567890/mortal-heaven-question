extends SceneTree
## R-05 节点图基准（stub 版）——最坏情况场景 DC + 缩放平移帧时间采样。
##
## 复用 R-02 测量方法（delta 基线 + 60 帧稳定均值 + p50/p95/p99 分位）。
## 场景 = NodeGraphRenderer + NodeGraphViewport（exploration-ui 001 渲染基座）
## + stub 最坏情况 DAG（6 层×4 节点 = 24 节点 + 连线 + 迷雾 + 10 类图标）。
##
## 采集三组数据（story 001 AC-1/2/3）：
##   1. 缩放平移期间帧时间 p50/p95/p99（AC-1: p95 ≤16.6ms）
##   2. 静态 + 缩放中两状态 DC（AC-2: ≤200，stub 基准值记录）
##   3. 迷雾增减时 DC 变化量（AC-3: 与迷雾节点数无强线性关系——合批验证）
##
## 复现命令（窗口模式——headless DC 不具代表性）：
##   C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
##     --path E:/mortal-heaven-question \
##     --script prototypes/r05-node-graph-benchmark/benchmark.gd

const FRAME_SAMPLE_SECONDS := 10.0
const LAYERS := 6
const PER_LAYER := 4

## 节点详情缓存——_build_worst_case_dag 填充（graph 邻接 + detail 分离）。
var _nodes_detail: Dictionary = {}
## 缩放终值记录（viewport 释放前采样——AC-2 缩放中状态佐证）。
var final_zoom: float = 1.0


func _init() -> void:
	# R-02 先例：p50 恰为 16.66ms 表明 VSync 锁定遮蔽真实帧预算——
	# 本基准关闭 VSync 以测 CPU+GPU 实际合成耗时（AC-1 的严格读法）。
	# D3D12 后端（story 指定）——4.6 Windows 默认，显式指定防环境漂移。
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _sample_dc() -> int:
	for i in 5:
		await process_frame
	var acc := 0
	for i in 60:
		acc += int(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		await process_frame
	return int(round(float(acc) / 60.0))


func _sample_frame_times(seconds: float, drive: Callable = Callable(),
		probe: Callable = Callable()) -> Array:
	var deltas: Array = []
	var prev := Time.get_ticks_usec()
	var frames := int(seconds * 60.0)
	for i in frames:
		if drive.is_valid():
			drive.call(i)
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - prev) / 1000.0)
		prev = now
	return deltas


func _percentile(sorted_deltas: Array, p: float) -> float:
	if sorted_deltas.is_empty():
		return 0.0
	var idx := int(clamp(p, 0.0, 1.0) * (sorted_deltas.size() - 1))
	return sorted_deltas[idx]


## stub 最坏情况 DAG——6 层×4 节点（node_id = layer*100+idx），
## 全部 10 类节点类型轮转覆盖（含入口 0 与渡劫台 9），层间全连接
## 逼近最坏连线数（每节点连向下一层全部 4 节点）。
func _build_worst_case_dag() -> Dictionary:
	var graph: Dictionary = {}
	var type_i: int = 0
	for layer in LAYERS:
		for idx in PER_LAYER:
			var id: int = layer * 100 + idx
			graph[id] = []
			# 入口固定 layer0 idx0；Boss 固定末层 idx0；其余轮转覆盖 10 类
			var type_id: int
			if layer == 0 and idx == 0:
				type_id = 0
			elif layer == LAYERS - 1 and idx == 0:
				type_id = 3
			else:
				type_id = type_i % 10
				type_i += 1
			_nodes_detail[id] = {"type": type_id, "layer": layer, "idx": idx,
					"label": NodeIconAtlas.get_label(type_id)}
	for from_layer in LAYERS - 1:
		for from_idx in PER_LAYER:
			var children: Array = []
			for to_idx in PER_LAYER:
				children.append((from_layer + 1) * 100 + to_idx)
			graph[from_layer * 100 + from_idx] = children
	return graph


## 最坏情况迷雾：已访问走查前 2 层（迷雾覆盖其余 4 层 ≈ 16 节点 >50%）。
func _visited_worst_case() -> Array:
	var visited: Array = []
	for layer in 3:
		for idx in PER_LAYER:
			visited.append(layer * 100 + idx)
	return visited


## 迷雾减半场景（AC-3 用）：已访问扩到前 4 层（迷雾从 16 节点降到 8 节点）。
func _visited_more_revealed() -> Array:
	var visited: Array = []
	for layer in 5:
		for idx in PER_LAYER:
			visited.append(layer * 100 + idx)
	return visited


func _run() -> void:
	print("=== R-05 节点图基准（stub 版）——最坏情况 DC + 缩放平移帧时间 ===")
	print("渲染后端: ", RenderingServer.get_current_rendering_method())
	var window: Window = root as Window
	if window != null:
		window.size = Vector2i(1280, 720)

	# 基线（空场景）
	var baseline_box := Control.new()
	baseline_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(baseline_box)
	var baseline: int = await _sample_dc()
	baseline_box.queue_free()
	await process_frame

	# 渲染基座 + 最坏情况 stub DAG（迷雾覆盖 16/24 节点 >50%——AC-3 场景前置）
	var graph: Dictionary = _build_worst_case_dag()
	var viewport := NodeGraphViewport.new()
	viewport.size = Vector2(1280, 720)  # 直接 size——不设锚（避免锚点覆盖告警）
	root.add_child(viewport)
	await process_frame
	viewport.setup(graph, _nodes_detail, _visited_worst_case(),
			200)  # current_node=200（第 3 层 idx0——迷雾豁免当前邻接）
	await process_frame

	# AC-2 状态一：静态 DC
	var static_dc: int = await _sample_dc()

	# AC-1 缩放平移驱动采样——滚轮 50%↔150% 往返 + 中键拖拽平移混合
	var frame_times: Array = await _sample_frame_times(FRAME_SAMPLE_SECONDS,
			_drive_zoom_pan.bind(viewport))  # bind 追加 viewport → (frame, viewport)

	# AC-2 状态二：缩放中 DC（采样期间画布处于 50%-150% 变换中）
	final_zoom = viewport.zoom
	var zooming_dc: int = await _sample_dc()

	# AC-3 迷雾增减 DC 变化：迷雾 16 节点 → 8 节点（揭雾后）
	viewport.renderer.setup(graph, _nodes_detail,
			_visited_more_revealed(), 400)
	await process_frame
	var revealed_dc: int = await _sample_dc()

	viewport.queue_free()
	await process_frame

	# 统计
	var sorted_ft: Array = frame_times.duplicate()
	sorted_ft.sort()
	var p50: float = _percentile(sorted_ft, 0.50)
	var p95: float = _percentile(sorted_ft, 0.95)
	var p99: float = _percentile(sorted_ft, 0.99)

	print("baseline DC: ", baseline)
	print("静态 DC（净值）: ", static_dc - baseline, "（整帧 ", static_dc, "）")
	print("缩放中 DC（净值）: ", zooming_dc - baseline, "（整帧 ", zooming_dc, "）")
	print("迷雾 16 节点 → 8 节点 DC（净值）: ", revealed_dc - baseline,
			"（整帧 ", revealed_dc, "）—— AC-3: 变化量 ",
			revealed_dc - static_dc, "（逐节点实例化会随迷雾节点数线性增长）")
	print("缩放终值实测: ", final_zoom)
	print("帧时间采样（", FRAME_SAMPLE_SECONDS, "s, ", sorted_ft.size(), " 帧）:")
	print("  p50: %.2f ms" % p50)
	print("  p95: %.2f ms" % p95)
	print("  p99: %.2f ms" % p99)
	print("  目标: p95 ≤ 16.6ms (60fps) / DC ≤200")
	print("=== 基准结束 ===")
	quit()


## 缩放平移驱动——每帧混合操作：滚轮步进（50%↔150% 往返）+ 每 2s 平移脉冲。
## [param frame]: 帧序号（Callable.call 传入）。[br][param viewport]: 目标视口（bind 追加）。
func _drive_zoom_pan(frame: int, viewport: NodeGraphViewport) -> void:
	# 滚轮缩放往返：60 帧一方向（50%→150% 约 13 步 × 平滑 0.2s）
	var up: bool = (frame / 60) % 2 == 0
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = Vector2(640, 360)
	viewport._gui_input(ev)
	# 平移脉冲：每 120 帧注入一次拖拽（press → motion → release）
	if frame % 120 == 0:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_MIDDLE
		press.pressed = true
		viewport._gui_input(press)
	elif frame % 120 == 1:
		for step in 10:
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(6.0, -4.0)
			viewport._gui_input(motion)
	elif frame % 120 == 2:
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_MIDDLE
		release.pressed = false
		viewport._gui_input(release)
