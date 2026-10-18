class_name FloaterPool
extends Control
## FloaterPool —— 战斗飘字池（combat-ui-layout Story 003 AC-4）。
##
## [b]职责[/b]：伤害/治疗飘字的预创建 Label 池——上限 [constant POOL_SIZE]
## 16 个（GDD guardrail：同帧 12+ 飘字不产生节点风暴——池耗尽时最旧飘字
## 立即回收复用，绝不逐帧实例化节点）。[br]
## [b]动画规格[/b]（GDD 动画表）：伤害红色下落 0.5s / 治疗绿色上浮 0.5s；
## reduce_motion 路径直接淡出（无位移）。[br]
## [b]零轮询[/b]：无 [code]_process()[/code]——每个飘字一条一次性 Tween
## （§2.1 豁免），完成即回收入池。[br]
## [b]零状态所有权[/b]（ADR-0031 §2）：池占用位为瞬态视觉状态（§2.1 豁免）；
## 飘字文本/颜色由调用方从系统信号载荷计算后传入——本池不读游戏状态。[br]
## [b]Tween 约束[/b]（Godot 4.6 已知）：位移与透明度用两条独立
## [code]tween_property[/code]（不用 [code]from()[/code] + [code]set_delay()[/code]
## 组合——该组合会吞 delay）。
##
## @experimental
## 来源: design/gdd/combat-ui-system.md §动画表（伤害/治疗数字）、
## combat-ui-layout Story 003（AC-4 + Implementation Notes 飘字池条款）。

## === 数值常量（数据驱动——story 003 视觉调优旋钮集中处）======================

## 池上限（GDD guardrail：同帧 12+ 飘字不产生节点风暴——预创建 16）。
const POOL_SIZE: int = 16
## 飘字动画时长（秒——GDD 动画表伤害/治疗均 0.5s）。
const FLOAT_DURATION_SEC: float = 0.5
## 伤害飘字位移距离（px，向下——GDD「向下掉落消失」；Godot 2D y+ 向下）。
const DAMAGE_FALL_PX: float = 40.0
## 治疗飘字位移距离（px，向上——GDD「上浮消失」；y- 向上）。
const HEAL_RISE_PX: float = -40.0
## 伤害飘字颜色（红——GDD 动画表）。
const DAMAGE_COLOR: Color = Color(0.85, 0.25, 0.22)
## 治疗飘字颜色（绿——GDD 动画表）。
const HEAL_COLOR: Color = Color(0.22, 0.72, 0.30)
## 飘字基准字号（pt——与角色卡 ATK 数字同基准）。
const FLOAT_FONT_SIZE: int = 18

## 飘字种类。
enum FloaterKind {
	DAMAGE = 0,  ## 伤害——红色下落
	HEAL = 1,    ## 治疗——绿色上浮
}

## === 瞬态视觉状态（§2.1 豁免——池占用位/Tween 句柄）=========================

## 预创建 Label 池（索引 0..POOL_SIZE-1）。
var _pool: Array[Label] = []
## 池占用表——与 _pool 同索引；值为发起时间戳（0 = 空闲）。
var _busy: Array[float] = []
## 每飘字的 Tween 句柄（重入回收时 kill）。
var _tweens: Array = []
## 减少动态（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false


## _init 预创建全部 Label（不依赖场景树时序——池永不扩容）。
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in POOL_SIZE:
		var label: Label = Label.new()
		label.name = "Floater%d" % i
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_pool.append(label)
		_busy.append(0.0)
		_tweens.append(null)


## 设置减少动态（进场时读取设置——进场后静态）。
func set_reduce_motion(p_reduce: bool) -> void:
	reduce_motion = p_reduce


## 当前实例化的飘字节点总数（测试断言用——池上限守卫：恒 ≤ POOL_SIZE）。
func instance_count() -> int:
	return get_child_count()


## 空闲飘字数（测试断言用）。
func free_count() -> int:
	var count: int = 0
	for i: int in POOL_SIZE:
		if _busy[i] == 0.0:
			count += 1
	return count


## 发射一个飘字（伤害/治疗统一入口——Coordinator 从系统信号载荷计算后调用）。[br]
## 池耗尽时回收最旧飘字（占用时间戳最早者）复用——不新建节点。[br]
## [param position]: 飘字起始位置（目标角色卡中心，本池局部坐标）。[br]
## [param value]: 显示数值（伤害正值/治疗正值——符号由种类决定颜色与方向）。[br]
## [param kind]: [enum FloaterKind] 伤害/治疗。
func spawn(position: Vector2, value: int, kind: int) -> void:
	var index: int = _acquire_index()
	var label: Label = _pool[index]
	# 文本格式：伤害带负号（-25），治疗带加号（+25）——与 GDD「红色数字/绿色数字」
	# 语义一致（颜色+符号双重编码，色盲可区分）
	var text: String = ("-%d" % value) if kind == FloaterKind.DAMAGE \
			else ("+%d" % value)
	label.text = text
	label.add_theme_font_size_override("font_size", FLOAT_FONT_SIZE)
	label.add_theme_color_override("font_color",
		DAMAGE_COLOR if kind == FloaterKind.DAMAGE else HEAL_COLOR)
	label.position = position
	label.modulate.a = 1.0
	label.visible = true
	_play(label, index, kind)


## 回收飘字（动画完成回调 + 池耗尽强制回收共用）。
func _release(index: int) -> void:
	_kill_tween(index)
	_busy[index] = 0.0
	_pool[index].visible = false


## === 内部 ====================================================================

## 获取可用池索引——优先空闲位；耗尽时回收占用时间戳最早者。
func _acquire_index() -> int:
	var oldest_index: int = -1
	var oldest_time: float = 1e18
	for i: int in POOL_SIZE:
		if _busy[i] == 0.0:
			return i
		if _busy[i] < oldest_time:
			oldest_time = _busy[i]
			oldest_index = i
	# 池耗尽——回收最旧飘字（guardrail：不新建节点）
	_release(oldest_index)
	return oldest_index


## 播放飘字动画（一次性 Tween——位移+淡出两条独立 tween_property）。[br]
## reduce_motion：直接淡出（透明度 0.5s 过渡，无位移——静态替代条款）。[br]
## [b]完成即回收[/b]：用 [code]finished[/code] 信号绑定回收（非 chain 回调——
## chain 在 set_parallel 后需正确串联；finished 语义等价且更简）。
func _play(label: Label, index: int, kind: int) -> void:
	_kill_tween(index)
	_busy[index] = _now()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION_SEC)
	if not reduce_motion:
		# 位移：伤害下落（y+）/ 治疗上浮（y-）——不用 from()（组合吞 delay 约束）
		var offset: float = DAMAGE_FALL_PX if kind == FloaterKind.DAMAGE \
				else HEAL_RISE_PX
		tween.tween_property(label, "position:y",
			label.position.y + offset, FLOAT_DURATION_SEC)
	tween.finished.connect(_release.bind(index))
	_tweens[index] = tween


## 杀死指定飘字的 Tween（重入回收/复用前清理）。
func _kill_tween(index: int) -> void:
	var tween: Tween = _tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens[index] = null


## 当前时间戳（占用排序用——Time.get_ticks_msec 确定性足够）。
func _now() -> float:
	return float(Time.get_ticks_msec())
