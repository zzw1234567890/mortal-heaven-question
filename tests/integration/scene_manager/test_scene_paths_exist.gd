extends GutTest
## Sprint 18 场景补链回归：SCENE_PATHS 每条注册路径必须有真实资源文件。
##
## [b]背景[/b]（gate-check 2026-11-08 §三）：`request_scene_change()` 只校验 SceneID
## 是否在 SCENE_PATHS 字典中，不校验目标文件存在——12 条注册路径曾 8 条指向缺失的
## `.tscn`（含 COMBAT），节点图「进入战斗」因此必然落到
## `scene_transition.gd` 的「目标场景缺失 → 回退 MAIN_MENU」失败路径。
##
## [b]本测试的角色[/b]：把「路径有资产」从文档承诺变成 CI 断言。新增场景 story 若
## 只改 SCENE_PATHS 不落盘，此处即失败。

const SM := preload("res://src/foundation/scene_manager.gd")

var sm: Node = null


func before_each() -> void:
	sm = SM.new()
	sm._test_mode = true
	add_child_autofree(sm)


func test_all_scene_paths_point_to_existing_resources() -> void:
	## AC: 12 条注册路径全部存在（含 LOADING）。
	for scene_id: int in SM.SCENE_PATHS.keys():
		var path: String = SM.SCENE_PATHS[scene_id]
		assert_true(ResourceLoader.exists(path),
				"SceneID=%d 注册路径 %s 应存在" % [scene_id, path])


func test_verify_scene_paths_returns_empty_for_real_paths() -> void:
	## Act: 启动自检对真实路径表应零缺失。
	var missing: Array = sm.verify_scene_paths()
	# Assert
	assert_eq(missing.size(), 0, "真实 SCENE_PATHS 不应有缺失路径（实测 %s）" % [missing])


func test_verify_scene_paths_reports_missing_file() -> void:
	## Arrange: 假路径表（不存在文件）。
	var bogus: Dictionary = {0: "res://src/does_not_exist/bogus_scene.tscn"}
	# Act
	var missing: Array = sm.verify_scene_paths(bogus)
	# Assert: 缺失被如实上报（guard 非空转）
	assert_eq(missing.size(), 1, "不存在的路径应被上报")
	assert_eq(str(missing[0]), "res://src/does_not_exist/bogus_scene.tscn")


func test_every_scene_asset_instantiates() -> void:
	## 每条注册路径的 PackedScene 都可实例化（防「文件在但场景损坏」）。
	for scene_id: int in SM.SCENE_PATHS.keys():
		var path: String = SM.SCENE_PATHS[scene_id]
		var packed: Resource = load(path)
		assert_true(packed is PackedScene, "SceneID=%d → %s 应为 PackedScene" % [scene_id, path])
		if not packed is PackedScene:
			continue
		var node: Node = (packed as PackedScene).instantiate()
		assert_not_null(node, "SceneID=%d → %s 应可实例化" % [scene_id, path])
		if node != null:
			node.free()
