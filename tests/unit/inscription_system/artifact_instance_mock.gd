extends RefCounted
## ArtifactInstance mock——测试 InscriptionSystem 铭刻编排时的法宝实例替身。[br]
## [br]持有 template_id / inscriptions / inscription_count / total_materials_spent 属性。[br]
## [br]来源: ADR-0030 §inscribe / §apply_inscription 测试桩。

var template_id: String = ""
var inscriptions: Array = []
var inscription_count: int = 0
var total_materials_spent: int = 0
