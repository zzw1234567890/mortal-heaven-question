extends Node
## CardSystem mock——测试 InscriptionSystem 铭刻编排时替换 CardSystem。[br]
## [br]模拟 get_template 行为：返回带 type 字段的模板。[br]
## [br]来源: ADR-0030 §inscribe ① 校验法宝类型。

## 模板返回的类型——测试设置（"artifact" 或 "pill" 等）。
var _template_type: String = "artifact"


func get_template(id: StringName) -> Dictionary:
	return {"id": str(id), "type": _template_type}


func has_template(id: StringName) -> bool:
	return true
