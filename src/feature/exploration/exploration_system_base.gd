extends Node
## ExplorationSystemBase —— 探索系统 Autoload 继承链的[b]最底层[/b]：枚举 / 状态 /
## 注入点。[br]
## [br][b]为什么拆成继承链[/b]：[code]exploration_system.gd[/code] 686 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。本链是[b]机械拆分[/b]的产物——成员的
## 名字、类型、默认值与拆分前逐字一致，只是换了落脚的脚本；行为零改动。[br]
## [br][b]为什么用继承链而不是 RefCounted 子模块[/b]：测试与子模块大量通过
## [code]es.get("DIFFICULTY_CONFIGS")[/code] / [code]es.set("_dag_ready", true)[/code] /
## [code]_parent.call("_get_map_config")[/code] / [code]_parent.NodeType.SHOP[/code]
## 访问这些成员。实测 [method Object.get] / [method Object.set] /
## [method Object.call] 与 [code]_parent.NodeType[/code] 都[b]沿继承链解析[/b]，
## 而 RefCounted 子模块做不到——那样得给每个成员补一个转发器，那才是真改行为面。
## 继承是 GDScript 里唯一能保持「成员名与访问路径不变」的拆法。[br]
## [br][b]层次[/b]（各守 300 行内）：[br]
##   1. 本文件——枚举 / 状态与注入点；[br]
##   2. [code]exploration_system_helpers.gd[/code]——常量表 / 通用助手 /
##      子模块句柄与获取；[br]
##   3. [code]exploration_system_ops.gd[/code]——对外契约面（Cat 2b 信号 /
##      只读查询 / DAG 缓存生命周期 / 测试桩）；[br]
##   4. [code]exploration_system_forward.gd[/code]——子模块转发；[br]
##   5. [code]exploration_system.gd[/code]——编排面（也是 project.godot 注册的那份脚本）。[br]
## [br][b]本层不声明 [code]_ready[/code][/b]：Godot 只调最派生类的 [code]_ready[/code]
## （实测父类 [code]_ready[/code] 不会自动链式执行），故生命周期钩子统一放在链尾，
## 不存在「父子各写一半」的隐患。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型 / §决策 2 程序化 DAG 生成 / §决策 3 信号表、
## GDD exploration-system.md §2-3、本轮「炼丹台/炼器台节点」任务。


# === 枚举 ========================================================================

## 节点类型枚举——DAG 节点的类型标识。
enum NodeType {
	ENTRY = 0,         ## 入口——第 0 层固定
	COMBAT = 1,        ## 普通战斗
	ELITE = 2,         ## 精英战斗
	BOSS = 3,          ## Boss——末层固定
	EVENT = 4,         ## 事件
	SHOP = 5,          ## 商店
	TELEPORT = 6,      ## 传送——不消耗行动力
	ACTION_SPRING = 7, ## 行动力泉——回复全部行动力
	REST = 8,          ## 回复点——全体回复 50% 已损失 HP
	TRIBULATION = 9,   ## 渡劫台——修为已满时触发渡劫
	HARVEST = 10,      ## 采集点——灵草/矿脉，按节点载荷采材料入背包
	ALCHEMY = 11,      ## 炼丹台——列出丹药配方，消耗灵材产出丹药卡
	FORGE = 12,        ## 炼器台——列出法宝配方，消耗灵材产出法宝卡
	MEDITATION = 13,   ## 打坐/洞府——用当前修为尝试突破下一境界（无战斗，可反复尝试）
}

## 地图难度枚举。
enum MapDifficulty {
	LOW = 0,       ## 低——4 层，2-3 节点/层
	MEDIUM = 1,    ## 中——5 层，2-4 节点/层
	HIGH = 2,      ## 高——5 层，3-4 节点/层
	VERY_HIGH = 3, ## 极高——6 层，3-4 节点/层
}

## 探索结束原因枚举。
enum EndReason {
	BOSS_DEFEATED,  ## Boss 击败——通关奖励结算
	BATTLE_LOST,    ## 战斗失败——修为保留 50%
	AP_DEPLETED,    ## 行动力耗尽——全额保留
	PLAYER_QUIT,    ## 玩家主动退出——全额保留
}


# === 状态与注入点 ================================================================

## DAG 邻接表——{node_id: [child_ids]}。
var _node_graph: Dictionary = {}

## 节点详情——{node_id: {type, layer, idx, ...}}。
var _node_details: Dictionary = {}

## 可达性缓存——{node_id: bool}。
var _reachable_cache: Dictionary = {}

## 当前地图配置快照。
var _map_config: Dictionary = {}

## DAG 缓存就绪标志——_ready() 末尾设为 true，公共方法入口守卫（ADR-0014 R7）。
var _dag_ready: bool = false

## 独立 RNG 实例——确定性 DAG 生成。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 可注入回调——获取地图配置（桩阶段返回默认配置）。
var get_map_config_cb: Callable = Callable()

## 可注入回调——生成敌人阵容（桩阶段返回空 Array）。
var generate_enemy_roster_cb: Callable = Callable()

## 可注入回调——获取事件池（桩阶段返回空 Array）。
var get_event_pool_cb: Callable = Callable()

## 可注入回调——生成商店库存（桩阶段返回空 Dictionary）。
var generate_shop_inventory_cb: Callable = Callable()

## 可注入回调——按模板 ID 查 EnemyTemplate（[code]func(template_id) -> Resource[/code]）。[br]
## [b]用途[/b]：DAG 生成时按 [code]reward_config[/code] 聚合节点掉落；空 = 走
## Autoload AISystem 的 [code]get_template[/code]（单测可注入桩，不依赖场景树）。
var enemy_template_lookup_cb: Callable = Callable()

## 可注入回调——获取 RNG seed（桩阶段返回 42）。
var get_seed_cb: Callable = Callable()
