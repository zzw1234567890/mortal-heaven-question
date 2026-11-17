extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单「存档」验收：成功给「已存档」、失败给原因、失败不关菜单。[br]
## [br][b]为什么需要[/b]：暂停菜单此前只有「保存并退出」——那条路要么静默写盘后离开、
## 要么失败后什么都不说；玩家按了存档键却看不出成没成。[br]
## [br][b]覆盖[/b]：[br]
##   1. 成功写自动槽（与场景切换的自动存档同一格）并显示「已存档」（松石青）；[br]
##   2. 写盘失败（磁盘满 / 校验不过）显示带错误码的原因，菜单保持打开、锁不释放；[br]
##   3. 依赖缺失（SaveLoadSystem 未注入）与载荷为空（GSM 不可用）都不以空载荷覆盖自动槽；[br]
##   4. 进度行现读 GSM 的探索层数（层数 0 基 → 显示 1 基）；[br]
##   5. 重新打开菜单时清掉上一条反馈（上一条结果与这一次无关）。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]（三个替身注入，脱离真实文件系统）。[br]
## [br]注：[code]SLS[/code]（SaveLoadSystem 枚举常量）由夹具提供，此处不再声明
## ——GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/pause-menu.md（存档反馈）、ADR-0031 §1.1/§2。


# ═══════════════════════════════════════════════════════════════════════════════
# 成功
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_button_shows_saved_text_on_success() -> void:
	# Arrange
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_eq(status_text(), "已存档", "存档成功应显示「已存档」")
	assert_eq(status_color(), menu.COLOR_STATUS_OK,
			"成功反馈应为「正向」色档（松石青）")
	assert_eq(sl.save_calls.size(), 1, "save_game 应被调用 1 次")


func test_save_writes_the_autosave_slot() -> void:
	## 写哪一格是硬约定：与场景切换的自动存档同一格，「继续游戏」才读得到。
	# Arrange
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	var call: Array = sl.save_calls[0]
	assert_eq(int(call[0]), SLS.SaveSlotType.AUTOSAVE, "应写入自动槽（AUTOSAVE）")
	assert_eq(int(call[1]), 0, "自动槽编号应为 0")
	assert_false((call[2] as Dictionary).is_empty(), "写入载荷不应为空")


func test_save_payload_comes_from_gsm_serialize() -> void:
	# Arrange
	gsm.payload = {"game_state": {"player": {"realm": 7, "identity_id": "x"}}}
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_eq(sl.last_payload, gsm.payload,
			"写入载荷应原样来自 GSM.serialize()（UI 不参与组装）")


func test_save_keeps_menu_open_on_success() -> void:
	## 「存档」不是退出——成功也应留在菜单里（退出是另两个按钮的事）。
	# Arrange
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_true(menu.visible, "存档成功后菜单应保持打开")
	assert_true(get_tree().paused, "存档成功后应仍处于暂停")
	assert_true(InputManager.has_lock(&"pause_menu"), "存档不应动锁栈")


# ═══════════════════════════════════════════════════════════════════════════════
# 失败
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_failure_shows_error_code_and_keeps_menu_open() -> void:
	# Arrange —— WRITE_ERROR（2）
	sl.save_result = SLS.SaveResult.WRITE_ERROR
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_eq(status_text(), "存档失败（错误码 2）",
			"失败应给出带错误码的原因（排障不必翻日志）")
	assert_eq(status_color(), menu.COLOR_STATUS_FAIL,
			"失败反馈应为「警报」色档（朱砂红）")
	assert_true(menu.visible, "存档失败应保持菜单打开（不丢进度）")
	assert_true(InputManager.has_lock(&"pause_menu"), "存档失败不应释放 MODAL 锁")


func test_save_unavailable_when_save_load_missing() -> void:
	# Arrange —— 未注入 SaveLoadSystem
	menu.save_load = null
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_eq(status_text(), "存档系统不可用，未能存档",
			"依赖缺失应说明原因而不是静默")
	assert_true(menu.visible, "依赖缺失时应保持菜单打开")


func test_save_refuses_to_write_empty_payload() -> void:
	## 空载荷 = 序列化失败——以空字典覆盖自动槽会毁掉玩家上一份档。
	# Arrange
	gsm.payload = {}
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_eq(sl.save_calls.size(), 0, "载荷为空时不得调用 save_game（不覆盖自动槽）")
	assert_eq(status_text(), "存档系统不可用，未能存档", "应给出「未能存档」的交待")


func test_save_status_updates_between_attempts() -> void:
	## 先失败后成功：反馈行必须跟着最新一次结果走。
	# Arrange
	sl.save_result = SLS.SaveResult.DISK_FULL
	open_menu()
	menu._on_save_pressed()
	assert_eq(status_text(), "存档失败（错误码 1）", "前置：第一次失败")
	# Act —— 腾出空间后重试
	sl.save_result = SLS.SaveResult.SUCCESS
	menu._on_save_pressed()
	# Assert
	assert_eq(status_text(), "已存档", "重试成功后应改为「已存档」")
	assert_eq(status_color(), menu.COLOR_STATUS_OK, "颜色应同步切到成功档")
	assert_eq(sl.save_calls.size(), 2, "两次尝试应各写一次")


# ═══════════════════════════════════════════════════════════════════════════════
# 进度行与反馈行
# ═══════════════════════════════════════════════════════════════════════════════

func test_progress_row_reads_gsm_layer() -> void:
	## 层数为 0 基存储、1 基显示（GAP-2 降级裁决：仅「层 N」）。
	# Arrange
	gsm.exploration = {"node_position": {"layer": 4}}
	# Act
	open_menu()
	# Assert
	assert_eq(progress_text(), "探索进度：层 5", "显示层数应为存储层数 + 1")


func test_progress_row_falls_back_to_first_layer_without_gsm() -> void:
	# Arrange —— 未注入 GSM（动作层回退 Autoload；测试里用 gsm=null 走降级）
	menu.gsm = null
	# Act
	open_menu()
	# Assert —— 只断言「不崩且给出一个层号」，不断言具体值
	# （gsm=null 时动作层回退真实 Autoload，其探索域内容不属于本用例的断言面）
	assert_true(progress_text().begins_with("探索进度：层 "),
			"无依赖时进度行仍应给出层号而不是空白")


func test_status_row_cleared_on_reopen() -> void:
	# Arrange —— 写一次失败留下反馈，然后关掉菜单
	sl.save_result = SLS.SaveResult.WRITE_ERROR
	open_menu()
	menu._on_save_pressed()
	assert_ne(status_text(), "", "前置：菜单里留着一条失败反馈")
	menu.request_close()
	# Act —— 重新打开
	open_menu()
	# Assert
	assert_eq(status_text(), "", "重开菜单应清掉上一条反馈（与这一次无关）")
