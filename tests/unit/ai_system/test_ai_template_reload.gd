extends GutTest
## 回归测试：AISystem.load_templates() 扫描失败不得破坏已加载的注册表。
##
## [b]缺陷[/b]：原实现把 `_template_registry.clear()` 放在扫描之前，
## 目录打不开（null DirAccess）时直接 `_templates_loaded = true` + emit + return——
## 注册表被留在空状态，却对外宣称「加载完了」。调用方看到 `_templates_loaded == true`
## 不会重试、不会报错，战场侧只表现为「没有敌人可选」，排查成本极高。
##
## [b]修复口径[/b]：先扫描到局部容器，成功后才整体换入；失败保留旧注册表 +
## 记 `last_error` + push_error，`_templates_loaded` 只在成功路径置 true。
##
## 测试策略：
##   - AISystem 用 AI_SCRIPT.new() + var ai: Node 持有（同 test_enemy_template_factory）
##   - 「已加载」状态用真实目录 res://assets/enemies/ 取得（不 mock 磁盘）
##   - 失败路径用不存在的目录（DirAccess.open → null）

const AI_SCRIPT := preload("res://src/feature/ai_system.gd")

## 真实存在且含 .tres 的模板目录。
const REAL_DIR: String = "res://assets/enemies/"
## 真实存在但没有任何 .tres 的目录（encounters 子目录不含顶层 .tres 之外的干扰项）。
const MISSING_DIR: String = "res://assets/enemies/__no_such_dir__/"

var ai: Node = null


func before_each() -> void:
	ai = AI_SCRIPT.new()


func after_each() -> void:
	if ai != null:
		ai.free()
		ai = null


## 以真实目录完成一次成功加载，返回加载到的模板数。
func _load_real_dir() -> int:
	ai.set("template_dir", REAL_DIR)
	ai.call("load_templates")
	return ai.call("get_template_count")


# === ① 已加载状态下再指向不存在的目录：原注册表必须保留 ======================

func test_reload_failure_keeps_existing_registry() -> void:
	# Arrange：先用真实目录装载出一份非空注册表
	var before: int = _load_real_dir()
	assert_gt(before, 0, "前置：真实目录加载后模板数 > 0")

	# Act：改为指向不存在的目录后重新加载
	ai.set("template_dir", MISSING_DIR)
	ai.call("load_templates")

	# Assert：原注册表原样保留
	assert_eq(ai.call("get_template_count"), before,
			"扫描失败不得清空已加载的注册表")
	assert_true(ai.call("has_template", &"san_xiu"),
			"失败后原有模板 san_xiu 仍可查到")
	assert_not_null(ai.call("get_template", &"san_xiu"),
			"失败后 get_template 仍返回非 null")


# === ② 失败路径不得伪装成「加载完成」 ========================================

func test_failed_load_does_not_report_loaded() -> void:
	# Arrange / Act
	ai.set("template_dir", MISSING_DIR)
	ai.call("load_templates")

	# Assert：loaded 标志不置位，且留下可分辨的错误说明
	assert_false(ai.get("_templates_loaded"),
			"扫描失败时 _templates_loaded 不得为 true")
	var err: Variant = ai.get("last_error")
	assert_true(err is String and not (err as String).is_empty(),
			"扫描失败时 last_error 须为非空字符串（中文一句话）")


func test_failed_load_signal_not_claimed_as_success() -> void:
	# Arrange：失败路径不得让调用方误以为「模板已就绪」
	ai.set("template_dir", MISSING_DIR)
	var hits: Array = []
	ai.connect("enemy_templates_loaded", func() -> void: hits.append(true))

	# Act
	ai.call("load_templates")

	# Assert
	assert_eq(hits.size(), 0, "扫描失败不得发射 enemy_templates_loaded")


# === ③ 失败后恢复：成功加载可清空 last_error 并重建注册表 ====================

func test_success_after_failure_clears_error() -> void:
	# Arrange：先失败一次
	ai.set("template_dir", MISSING_DIR)
	ai.call("load_templates")
	assert_false(ai.get("_templates_loaded"), "前置：失败后未置 loaded")

	# Act：换回真实目录重新加载
	var count: int = _load_real_dir()

	# Assert
	assert_gt(count, 0, "恢复加载后模板数 > 0")
	assert_true(ai.get("_templates_loaded"), "恢复加载后置 loaded")
	assert_eq(str(ai.get("last_error")), "", "恢复加载后 last_error 清空")


# === ④ 正常路径不受影响（幂等回归）==========================================

func test_normal_path_loads_and_is_idempotent() -> void:
	# Arrange / Act：连续两次成功加载
	var first: int = _load_real_dir()
	var second: int = _load_real_dir()

	# Assert：非空且两次结果一致
	assert_gt(first, 0, "正常路径加载后模板数 > 0")
	assert_eq(second, first, "重复加载模板数一致（幂等）")
	assert_true(ai.get("_templates_loaded"), "成功路径置 loaded")
	assert_eq(str(ai.get("last_error")), "", "成功路径 last_error 为空")


func test_success_path_replaces_registry_wholesale() -> void:
	# Arrange：用真实目录加载，再清空目录（成功但为空）——注册表应被整体换掉
	var before: int = _load_real_dir()
	assert_gt(before, 0, "前置：真实目录加载后有模板")

	# Act：指向真实存在但不含 .tres 的目录（成功路径，非失败路径）
	ai.set("template_dir", "res://assets/enemies/encounters/")
	ai.call("load_templates")

	# Assert：encounters 下只有 .tres 的 enemy_encounter 文件不匹配 EnemyTemplate，
	# 注册表被换为空——证明「成功才替换」不会退化成「永不替换」
	assert_eq(ai.call("get_template_count"), 0,
			"成功扫描空目录 → 注册表清空（不是保留旧的）")
	assert_true(ai.get("_templates_loaded"), "空目录仍属成功路径")
