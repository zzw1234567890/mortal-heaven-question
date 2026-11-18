extends RefCounted
## MainMenuLaunch —— 主菜单「读档 → 进探索」这一跳的编排（从 main_menu.gd 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]main_menu.gd[/code] 已超 300 行软上限
## （.claude/docs/coding-standards.md），而「继续游戏 / 读档两条路径怎么把玩家送进
## 探索」与「按钮接线、文本、动画、HUD 承载」是两件事——后者才是那份文件的职责。[br]
## [br][b]三条路径的差别只在这一层[/b]（GDD main-menu-system.md）：[br]
##   · 新游戏 → 身份选择 → 探索第一张图（意图由身份选择侧发出，不经本模块）；[br]
##   · 继续游戏 → 读最新档 → 回上次那张图（本模块 [method load_and_resume]）；[br]
##   · 读档 → 玩家指定槽位 → 同上（本模块 [method load_and_resume]，只是槽位不同）。[br]
## [br][b]为什么读档成功还要再判一次载荷[/b]：[code]load_game[/code] 返回 SUCCESS
## 只说明「文件读出来了、校验过了」，而「这份档里有没有东西可进」是另一回事——
## 空载荷（[code]data == {}[/code]）下导航过去只会让探索场景面对一份空 GSM，玩家
## 看到的是没有身份、没有卡组的空局。这类「成功但没用」必须停在主菜单。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块[b]不写任何游戏状态[/b]——GSM 的
## 恢复由 [code]SaveLoadSystem.load_game[/code] 内部完成；「这次进探索要干什么」经
## [ExplorationEntryIntent] 作为跨场景意图传递（与 [CombatLaunchContext] /
## [MapClearView] 同一口径的 static 缓存），本模块不越权去写探索域。[br]
## [br]来源: ADR-0005（导航唯一入口）、ADR-0031 §1/§2、
## design/gdd/main-menu-system.md、design/gdd/exploration-system.md §1。
##
## 持有对 MainMenu 宿主的引用（同 [code]exploration_map_flush.gd[/code] 形态）。

## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源（同 main_menu 口径）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## SaveLoadSystem 脚本常量——LoadResult 枚举真理来源。
const SLScript := preload("res://src/foundation/save_load_system.gd")
## 跨场景进入意图（读到哪、进哪张图由探索场景自己按 GSM 现取）。
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")
## 跨场景续战意图（读到进行中的战斗时留下——战斗场景取走并重建那一场）。
const ResumeIntentScript := preload("res://src/feature/combat/battle_resume_intent.gd")
## 载荷模块（「存档里这一段能不能读回来」的唯一判据）。
const ResumePayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")

## 宿主节点（[code]get_node_or_null[/code] 回退 Autoload 用）。
var host: Node = null
## 注入的 SceneManager（测试替换；null 时回退 Autoload）。
var scene_manager: Node = null
## 注入的 SaveLoadSystem（测试替换；null 时回退 Autoload）。
var save_load: Node = null
## 注入的 GameStateManager（读「存档里有没有进行中的战斗」；null 时回退 Autoload）。[br]
## [br][b]为什么读 GSM 而不是翻存档容器[/b]：[code]load_game[/code] 已把整份存档反序列化
## 进 GSM，[code]battle_resume[/code] 就在那里；再翻一遍 [code]data["game_state"][/code]
## 等于把同一事实读两处（口径漂移的起点）。
var gsm: Node = null


## 读档并续玩——成功且载荷非空时请求导航到探索。[br]
## [br][b]返回[/b]：[enum SaveLoadSystem.LoadResult]；依赖不可用时
## [code]DESERIALIZE_ERROR[/code]（与真实读档失败的判定同码，调用方无需分支）。[br]
## [br][b]顺序[/b]：先发意图再请求导航——探索场景在 [code]_ready[/code] 里取走意图，
## 而 [code]_ready[/code] 发生在转场之后；反过来则场景挂载时读到的还是 NONE。[br]
## [br][b]不导航的两种情况[/b]：读档失败（返回码非 SUCCESS）、载荷为空
## （见类文档「为什么读档成功还要再判一次载荷」）。[br]
## [br][b]存档里有进行中的战斗时改去战斗场景[/b]（[method request_battle_resume]）：
## 玩家存的是「打了一半的那场仗」，送回探索地图等于把它丢掉。[br]
## [br][param p_slot_type] 槽位类型（AUTOSAVE / MANUAL）。[br]
## [param p_slot_id] 手动槽编号（自动槽为 0）。
func load_and_resume(p_slot_type: int, p_slot_id: int) -> int:
	var sl: Node = get_save_load()
	if sl == null or not sl.has_method(&"load_game"):
		push_error("MainMenu: SaveLoadSystem 不可用——读档中止")
		return SLScript.LoadResult.DESERIALIZE_ERROR
	var result: Dictionary = sl.load_game(p_slot_type, p_slot_id)
	var code: int = int(result.get("result", SLScript.LoadResult.DESERIALIZE_ERROR))
	if code != SLScript.LoadResult.SUCCESS:
		return code
	if not has_payload(result):
		# 成功但空载荷——留在主菜单（不弹损坏框：文件没坏，只是没有可续玩的内容）
		push_warning("MainMenu: 读档成功但载荷为空——留在主菜单不导航")
		return code
	if request_battle_resume():
		return code
	IntentScript.request_resume()
	request_exploration()
	return code


## 存档里若有进行中的战斗，留下续战意图并请求导航到战斗场景。[br]
## [br][b]返回[/b]：是否走了这条路（false = 没有战斗段，调用方按常走的探索续玩）。[br]
## [br][b]导航仍经 SceneManager[/b]（ADR-0005）：本模块只决定「去哪」，
## 转场参数与 from 的取法同 [method request_exploration]。[br]
## [br][b]载荷不可续时按没有战斗段处理[/b]：清掉意图走探索——玩家最多是「回到地图
## 重新点一次那个节点」，而不是被带进一场判不出胜负的仗。
func request_battle_resume() -> bool:
	var payload: Variant = _battle_resume_payload()
	if not ResumePayloadScript.is_resumable_payload(payload):
		return false
	if not ResumeIntentScript.request(payload):
		return false
	request_combat()
	return true


## 请求导航到战斗场景（读档续战路径）。[br]
## [br][b]不去渡劫场景[/b]：渡劫战没有探索来源，不存在续战段（见
## [code]battle_resume_payload.gd[/code] §「为什么不渡劫」）。
func request_combat() -> void:
	var sm: Node = get_scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("MainMenu: SceneManager 不可用——续战导航中止")
		return
	var from_id: int = SceneManagerScript.SceneID.MAIN_MENU  # 守卫失败回退
	if sm.has_method(&"get_current_scene_id"):
		from_id = sm.get_current_scene_id()
	sm.request_scene_change(from_id,
			SceneManagerScript.SceneID.COMBAT,
			SceneManagerScript.TransitionType.EXPLORE_TO_COMBAT)


## 当前 GSM 里的续战段（GSM 不可用 / 域缺失时为空字典——按「没有战斗段」处理）。[br]
## [br][b]读的是 GSM 内存现值[/b]：[code]load_game[/code] 刚刚把它反序列化到位
## （见 [member gsm] 的注记）。
func _battle_resume_payload() -> Dictionary:
	var node: Node = get_gsm()
	if node == null:
		return {}
	var raw: Variant = node.get(&"battle_resume")
	return raw if raw is Dictionary else {}


## 读档结果里是否真的有可续玩的载荷。[br]
## [br][b]判据是 [code]data[/code] 非空[/b]：真实 [code]load_game[/code] 成功时
## [code]data[/code] 一定是完整存档容器（含 [code]game_state[/code]）——空字典只可能
## 出现在「读到了但什么也没有」的降级路径上。[br]
## [br][param p_result] [code]load_game[/code] 的返回值。
## [br][b]返回[/b]：有载荷为 true。
static func has_payload(p_result: Dictionary) -> bool:
	var data: Variant = p_result.get("data", null)
	return data is Dictionary and not (data as Dictionary).is_empty()


## 请求导航到探索（继续游戏 / 读档两条路径共用）。[br]
## [br][b]为什么目标固定是 EXPLORATION[/b]：读档路径[b]绕过身份选择[/b]——身份已在
## 存档里（AC-4 Edge：「读档路径绕过身份选择」）。[br]
## [br]from 动态取当前场景 ID（先例 [code]main_menu._on_new_game_pressed[/code] 去魔数）。
func request_exploration() -> void:
	var sm: Node = get_scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("MainMenu: SceneManager 不可用——读档导航中止")
		return
	var from_id: int = SceneManagerScript.SceneID.MAIN_MENU  # 守卫失败回退
	if sm.has_method(&"get_current_scene_id"):
		from_id = sm.get_current_scene_id()
	sm.request_scene_change(from_id,
			SceneManagerScript.SceneID.EXPLORATION,
			SceneManagerScript.TransitionType.MENU_TO_GAME)


## 获取 SaveLoadSystem——注入对象优先，否则回退 Autoload（先例 main_menu）。
func get_save_load() -> Node:
	if save_load != null:
		return save_load
	if host == null:
		return null
	return host.get_node_or_null("/root/SaveLoadSystem")


## 获取 SceneManager——同上。
func get_scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	if host == null:
		return null
	return host.get_node_or_null("/root/SceneManager")


## 获取 GameStateManager——注入优先，否则回退 Autoload。
func get_gsm() -> Node:
	if gsm != null:
		return gsm
	if host == null:
		return null
	return host.get_node_or_null("/root/GameStateManager")
