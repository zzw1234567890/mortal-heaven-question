extends GutTest
## 主菜单版本号的显示链路回归（「显示成 [code]v?[/code]」的走查收口）。
##
## [b]走查结论：显示没有 bug[/b]。三轮取证（纯运行时 / 真实场景 / 真实渲染）实测：
## [code]project.godot[/code] 的 [code]application/config/version = "0.1.0-dev"[/code] 存在，
## [method MainMenuTexts.read_version] 返回 [code]"v0.1.0-dev"[/code]，渲染出的
## [code]VersionLabel.text[/code] 也是 [code]"v0.1.0-dev"[/code]。[br]
## [br][b]那 [code]v?[/code] 是从哪看到的[/b]：[code]MainMenu.tscn[/code] 的
## [code]VersionLabel[/code] 上写着 [code]text = "v?"[/code]——它是[b]场景文件的初始值[/b]，
## 在 [method Node._ready] 里必被 [method MainMenuTexts.apply_version] 覆盖。看
## [code].tscn[/code]（或只看首帧之前的编辑器预览）会读到这个占位串，于是被当成线上缺陷。[br]
## [br][b]本轮改了什么[/b]：把 [code].tscn[/code] 里那行 [code]text = "v?"[/code] 删掉
## （占位串不再存在，也就不会再被误读），并把「[code].tscn[/code] 不得写死版本字面量」
## 钉成断言——[code]v?[/code] 若回来，本案转红。[br]
## [br][b]为什么保留 [code]VERSION_FALLBACK = "v?"[/code][/b]：它是
## [code]ProjectSettings[/code] 完全没配 version 键时的安全回退（连键都没有，前缀也就
## 没有意义），并由 [method @GlobalScope.push_warning] accompany；story Implementation
## Notes 的「不硬编码」指的是 UI 层不写死版本号值，不是不许有读取失败时的占位。[br]
## [br][b]为什么进场景树[/b]：本文件要验的是「[code]_ready[/code] 之后标签上是真版本」，
## 而赋值发生在 [code]_ready[/code]（脱树不触发）。[br]
## [br]依据：story main-menu-system.md §2、[code]project.godot[/code] 的
## [code]application/config/version[/code]。

const MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")
const TextsScript := preload("res://src/ui/main_menu/main_menu_texts.gd")

## 场景文件路径（扫占位字面量用）。
const SCENE_PATH: String = "res://src/ui/main_menu/MainMenu.tscn"
## 走查里被误读成「线上显示值」的那个占位串。
const STALE_PLACEHOLDER: String = "v?"

var _menu: Control = null


func before_each() -> void:
	_menu = MENU_SCENE.instantiate() as Control
	_menu.animate = false  # 不播入场 Tween（本用例只看版本号）
	add_child(_menu)       # 进树才会跑 _ready（版本号在那里落标签）


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 显示的是 project.godot 里的真版本
# ═══════════════════════════════════════════════════════════════════════════════

func test_version_label_shows_project_setting_with_v_prefix() -> void:
	# Arrange —— 版本号的唯一出处
	var raw: String = str(ProjectSettings.get_setting(
			&"application/config/version", ""))
	# Act —— before_each 已进树（_ready 已落标签）
	var shown: String = _menu.get_node(^"VersionLabel").text
	# Assert
	assert_ne(raw, "", "project.godot 应配置 application/config/version（本用例的前提）")
	assert_eq(shown, "v" + raw,
			"版本标签应显示 project.godot 的值加 v 前缀（期望 v%s，实际 %s）" % [raw, shown])


func test_version_label_is_not_the_stale_placeholder() -> void:
	# Arrange + Act
	var shown: String = _menu.get_node(^"VersionLabel").text
	# Assert —— 「显示成 v?」这个现象若复现，本案转红
	assert_ne(shown, STALE_PLACEHOLDER, "版本标签不该是 v? 占位串")
	assert_false(shown.ends_with("?"),
			"版本标签不该带问号（说明读到的是占位而不是真版本）：%s" % shown)


func test_read_version_never_falls_back_while_setting_exists() -> void:
	# Arrange —— 回退只在「ProjectSettings 没这个键」时发生；本仓库有该键
	# Act
	var read: String = TextsScript.read_version()
	# Assert —— 若 project.godot 的 version 被误删，read 会返回 VERSION_FALLBACK，本案转红
	assert_ne(read, TextsScript.VERSION_FALLBACK,
			"仓库配了 version 时不该走回退（回退值 %s）" % TextsScript.VERSION_FALLBACK)
	assert_eq(read, "v" + str(ProjectSettings.get_setting(
			&"application/config/version", "")),
			"读取结果应与 ProjectSettings 同源")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 占位串不许写回场景文件
# ═══════════════════════════════════════════════════════════════════════════════

## 扫 [code]MainMenu.tscn[/code]，确认 [code]VersionLabel[/code] 段里没有写死的
## [code]text =[/code]。[br]
## 本案在删掉那行之前[b]会红[/b]——它锁的是「版本号的唯一出处是 ProjectSettings」，
## 而不是「当前这个值恰好是对的」。
func test_menu_scene_does_not_hardcode_version_text() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(SCENE_PATH)
	assert_ne(text, "", "应能读到 %s" % SCENE_PATH)
	# Act —— 找到 VersionLabel 段（到下一个 [node 或 [connection 为止）
	var start: int = text.find("[node name=\"VersionLabel\"")
	assert_gt(start, -1, "MainMenu.tscn 应有 VersionLabel 节点")
	var rest: String = text.substr(start)
	var ends: Array[int] = [rest.find("\n[node "), rest.find("\n[connection ")]
	var stop: int = rest.length()
	for candidate: int in ends:
		if candidate > 0 and candidate < stop:
			stop = candidate
	var block: String = rest.substr(0, stop)
	# Assert
	assert_false(block.contains("text ="),
			"VersionLabel 不得在场景里写死 text（唯一出处是 ProjectSettings）：\n%s" % block)


## [code]VERSION_FALLBACK[/code] 仍是 [constant STALE_PLACEHOLDER]——它是对「没这个键」
## 的回退，不是对「键有值」的覆盖。这条把「回退值存在」与「回退值被用到」分开钉住。
func test_version_fallback_is_only_a_missing_key_placeholder() -> void:
	# Arrange + Act
	var fallback: String = TextsScript.VERSION_FALLBACK
	var present: bool = ProjectSettings.has_setting(&"application/config/version")
	# Assert
	assert_eq(fallback, STALE_PLACEHOLDER, "回退值定义不应被改动")
	assert_true(present, "本仓库应配置 version——有配置时上面两案都会绕开回退")
	assert_ne(TextsScript.read_version(), fallback,
			"有配置时读取不得返回回退值")
