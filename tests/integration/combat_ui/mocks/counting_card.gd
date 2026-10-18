extends CharacterStatusCard
## CountingCard —— apply_hp 调用计数卡（LP-CODE-REVIEW M-2 修复）。[br]
## [br][b]用途[/b]：证明 AC-1 同帧多次伤害合并为**单次** [code]apply_hp[/code]
## 调用——终值断言无法区分「一次直达终值」与「三次逐次 kill 重建」
## （两条路径终值相同），必须以调用计数区分。[br]
## [br][b]GDScript 无 monkey patch[/b]：以子类覆写 `apply_hp` 先计数再
## super 链上——与 Coordinator 的鸭子类型注册兼容（register_card 收
## Control，卡实例的覆写方法自然生效）。[br]
## [br][b]参照先例[/b]：tests/integration/combat_ui/mocks/ 目录 mock 模式
## （stub 子类替代完整系统）。

## apply_hp 累计调用次数（before_each 重置）。
var apply_hp_call_count: int = 0
## 最近一次调用参数 [code][current, max][/code]（终值断言辅助）。
var last_apply_args: Array = []


func apply_hp(p_current: int, p_max: int) -> void:
	apply_hp_call_count += 1
	last_apply_args = [p_current, p_max]
	super(p_current, p_max)
