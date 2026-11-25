## SceneManager (Autoload #3) —— 场景转换的单一仲裁者。
##
## 所有场景转换必须通过 [method request_scene_change]——禁止任何系统直接调用
## [method SceneTree.change_scene_to_file]。[br]
## [br]
## [b]5 阶段异步转换管线[/b]:[br]
##   1. VALIDATE —— 并发守卫 + 场景 ID 存在性校验[br]
##   2. PRE-TRANSITION —— 锁输入 + 自动存档 + 发射 [signal pre_transition] 信号[br]
##   3. LOAD —— 加载画面 → 目标场景（两段式 change_scene_to_file）[br]
##   4. POST-LOAD —— GSM 写入 + 解锁输入 + 发射 [signal post_transition] 信号[br]
##   5. FINALIZE —— [member _transitioning] = false, [member _transition_type] = NONE[br]
## [br]
## [b]依赖注入[/b]: [method set_dependencies] 注入 GSM/InputManager/SaveLoad——单元测试可用
## 轻量 mock 对象替代真实 Autoload。[br]
## [br]
## [b]调用示例[/b]:[br]
## [codeblock]
##   SceneManager.request_scene_change(SceneManager.SceneID.EXPLORATION,
##                                     SceneManager.SceneID.COMBAT,
##                                     SceneManager.TransitionType.EXPLORE_TO_COMBAT)
## [/codeblock]
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  scene_manager_contract.gd [/code] ← 声明面：2 枚举 / 2 信号 / 2 常量表 / 11 实例字段[br]
## [code]  scene_manager_access.gd   [/code] ← 依赖与访问面：注入 / 惰性获取 / 音频门面 / 持久层注册[br]
## [code]  scene_manager_pipeline.gd [/code] ← 转场管线面：请求入口 / 信号发射包装 / 异步管线[br]
## [code]  scene_manager.gd          [/code] ← 本层：装配与出口面（_ready / 查询 / 自检 / 静态工具）[br]
##
## [b]链序不是自由选择[/b]：GDScript 解析期要求被调方在[b]本段或祖先段[/b]——祖先段用裸
## 标识符引用后代段成员会直接报 [code]Function "xxx()" not found in base self[/code]。
## 故 [code]scene_transition.gd[/code] 按名字符串调的 [code]_get_gsm[/code] /
## [code]_get_im[/code] / [code]_execute_post_load[/code] 等落在前段，而
## [method _ready]（要调全部惰性获取器与 [method verify_scene_paths]）必须在链尾。[br]
## [b]路径即契约[/b]：[code]project.godot[/code] 的 [code][autoload][/code] 把
## [code]SceneManager[/code] 绑在 [code]res://src/foundation/scene_manager.gd[/code]
## 这一串字符上，另有 16 处调用点按同一路径 [code]preload[/code] 取类，故本文件名逐字不动
## （本类[b]不声明[/b] [code]class_name[/code]——Foundation Autoload 固有权衡，
## 同 [code]game_state_manager.gd[/code] 头注释）。[br]
## 守卫用例：[code]tests/unit/scene_manager/test_scene_manager_public_face_lock.gd[/code]。
##
## 来源: ADR-0005 §5 阶段异步转换管线、ADR-0031 §1.2、.claude/docs/coding-standards.md
## §文件行数限制（300 行软上限）。

extends "res://src/foundation/scene_manager_pipeline.gd"

## === 内置虚方法 ================================================================

func _ready() -> void:
	_transitioning = false
	_transition_type = TransitionType.NONE
	# _current_scene_id 默认 MAIN_MENU——首个启动场景
	# PersistentLayer 创建（ADR-0031 §1.2——挂为 SceneManager 子节点，
	# 见 scene_persistent_layer.gd 头注释的等价性说明）
	_get_persistent_layer().ensure_layer()
	# AudioManager 启动实例化（audio Story 001——零新增 Autoload，
	# ADR-0031 §1.2：音频节点池经 PersistentLayer 挂载）
	_get_audio_manager()
	# SCENE_PATHS 启动自检（R3 硬化）：注册路径指向不存在的 .tscn 时，
	# [method request_scene_change] 的 ID 校验依然通过，失败被推迟到 Phase 3
	# 的 change_scene_to_file → 静默回退 MAIN_MENU。启动即 push_error 暴露。
	verify_scene_paths()


## === 公共 API：查询与自检 ============================================================

## 获取当前场景 ID（O(1) 查询——不依赖 GSM）。
func get_current_scene_id() -> int:
	return _current_scene_id


## 是否正在转场中。
func is_transitioning() -> bool:
	return _transitioning


## 校验 [constant SCENE_PATHS] 的每条注册路径都有真实资源文件（R3 硬化）。[br]
## [br][b]为什么需要[/b]：[method request_scene_change] 只校验 ID 是否在字典中，
## 路径指向缺失文件时校验通过、Phase 3 的 [code]change_scene_to_file[/code] 才失败，
## 并被降级成「静默回退 MAIN_MENU」——玩家点的按钮看起来没反应。
## 启动自检把这类缺口暴露在 [method _ready] 的 push_error 里。[br]
## [br][b]返回[/b]：缺失路径数组（空 = 全部存在；测试断言用）。
## [param paths]: 待校验路径表（缺省为 [constant SCENE_PATHS]——测试可传入假表）。
func verify_scene_paths(paths: Dictionary = SCENE_PATHS) -> Array:
	var missing: Array = []
	for scene_id: int in paths.keys():
		var path: String = str(paths[scene_id])
		if not ResourceLoader.exists(path):
			missing.append(path)
			push_error("SceneManager: SCENE_PATHS[%d] 指向不存在的场景文件：%s"
					% [scene_id, path])
	return missing


## === 静态叠加工具 ==============================================================

## 创建全屏不透明 ColorRect 用于目标场景的淡入保护。[br]
## [br][b]D3D12 闪烁缓解[/b]（ADR-0005 风险 #5）：目标场景在 [code]_ready()[/code] 中调用
## 本方法叠加一个黑色矩形，然后调用 [method fade_out_overlay] 淡出显示场景。[br]
## [br][b]用法[/b]（在目标场景中）：[br]
## [codeblock]
## var _overlay: ColorRect
## func _ready():
##     _overlay = SceneManager.create_fade_overlay()
##     SceneManager.fade_out_overlay(_overlay, 0.25)
## [/codeblock]
## [br]返回全屏锚定的 ColorRect，设置 Color.BLACK 和 mouse_filter = IGNORE。
static func create_fade_overlay() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "FadeOverlay"
	rect.color = Color.BLACK
	rect.anchor_left = 0.0
	rect.anchor_right = 1.0
	rect.anchor_top = 0.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(rect)
	return rect


## 淡出全屏叠加 ColorRect 并移除。[br]
## [br]使用 [method Node.create_tween]（Godot 4.0+ API——[code]Tween[/code] 节点已废弃）。[br]
## 渐变完成后通过 [method Node.queue_free] 释放叠加层。[br]
## [br][b]参数[/b]:[br]
##   - [param overlay]: 要淡出并移除的 ColorRect。[br]
##   - [param duration]: 渐变持续时间，单位秒（默认 0.25s——依据 AC-5 建议）。
static func fade_out_overlay(overlay: ColorRect, duration: float = 0.25) -> void:
	if overlay == null:
		return
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(overlay.queue_free)
