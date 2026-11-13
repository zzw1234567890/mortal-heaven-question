extends RefCounted
## CardTemplatePrimer —— 集成测试用的卡牌模板就位助手（静态纯函数）。[br]
## [br][b]为什么需要[/b]：CardSystem 在 [code]_ready[/code] 里用
## [code]load_threaded_request[/code] 异步加载模板（每帧 10 个），而 GUT 下的帧驱动
## 时机不保证——「查不到模板」会让依赖真实模板的用例（货架定价、建卡实例、入收藏
## 校验）静默走向降级分支，断言随之失真。本助手同步推进
## [method CardSystem._process] 直到目标模板可查。[br]
## [br][b]为什么单独一处[/b]：多个集成用例文件各写一遍这段驱动逻辑必然漂移
## （[code]test_shop_and_rest_node_flow.gd[/code] 与
## [code]test_exploration_bootstrap.gd[/code] 都要用）。[br]
## [br][b]不涉 GSM[/b]：只负责让模板进注册表；是否打开 GSM 校验、是否补
## [code]_card_template_database[/code] 由调用方决定（各用例的校验口径不同）。[br]
##
## 来源: [code]card_system.gd[/code] 的异步加载实现、
## [code]test_battle_reward_grant.gd[/code] 的喂帧先例。

## 单次就位尝试里最多推进的帧数（远大于模板数量的 MAX_PER_FRAME 分批需求）。
const MAX_FRAMES: int = 200
## 就位尝试轮数——首轮可能还在 [code]_ready[/code] 之前。
const MAX_ATTEMPTS: int = 5
## 每帧之间的等待——让 ResourceLoader 的后台线程有机会推进请求状态。
const FRAME_DELAY_MSEC: int = 5


## 同步推进 CardSystem 直到 [param p_card_id] 可查（已可查则立即返回）。[br]
## [br][b]返回[/b]：目标模板是否就位——调用方可据此断言「模板环境确实备好了」，
## 而不是在模板缺失时静默跑出一条假的通过路径。[br]
## [br][param p_card_system] 卡牌系统（可空——为 null 或缺少所需方法时返回 false）。[br]
static func prime(p_card_system: Node, p_card_id: StringName) -> bool:
	if p_card_system == null or not p_card_system.has_method(&"get_template"):
		return false
	for _attempt: int in range(MAX_ATTEMPTS):
		if p_card_system.call(&"get_template", p_card_id) != null:
			return true
		for _frame: int in range(MAX_FRAMES):
			p_card_system.call(&"_process", 0.016)
			if (p_card_system.get(&"_pending_paths") as Array).is_empty():
				break
			OS.delay_msec(FRAME_DELAY_MSEC)
	return p_card_system.call(&"get_template", p_card_id) != null
