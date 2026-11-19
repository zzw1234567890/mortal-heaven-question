extends RefCounted
## StubActorReader —— 战场角色卡取数入口的测试替身。
##
## [b]职责[/b]：提供与 [code]CombatActorReader[/code] 完全同名同形状的取数方法
## （[code]hp[/code] / [code]base_hp[/code] / [code]attack[/code] /
## [code]display_name[/code] / [code]enemy_entries[/code] / [code]player_entries[/code]），
## 数据由用例直接摆。[br]
## [br][b]为什么不用 mock 库[/b]：名册建卡只调这几个方法，桩就是几个 Dictionary；
## 用真类做替身反而要起战斗系统与卡牌系统两个 Autoload 依赖。[br]
## [br][b]不缓存[/b]：每次调用现读 [member hp_map]——与真实现的「现读」口径一致，
## 用例改完字典再调一次就能看到新值。
##
## 来源: tests/integration/combat_ui/test_enemy_hp_visibility.gd、ADR-0031 §2。

## 角色 ID → [code]{current, max}[/code]。
var hp_map: Dictionary = {}
## 角色 ID → 攻值。
var atk_map: Dictionary = {}
## 角色 ID → 显示名。
var name_map: Dictionary = {}


## HP 读取——契约同 [code]CombatActorReader.hp[/code]。
func hp(character_id: int) -> Dictionary:
	var entry: Dictionary = hp_map.get(character_id, {})
	return {"current": int(entry.get("current", 0)), "max": int(entry.get("max", 0))}


## 基础 HP 回退——契约同真实现（读不到给 0，不臆造）。
func base_hp(character_id: int) -> int:
	return int(hp_map.get(character_id, {}).get("max", 0))


## 攻值读取。
func attack(character_id: int) -> int:
	return int(atk_map.get(character_id, 0))


## 显示名——读不到时按 ID 段兜底（同 [code]EnemyActionText.fallback_name[/code]）。
func display_name(character_id: int) -> String:
	return str(name_map.get(character_id, "敌人 #%d" % character_id))
