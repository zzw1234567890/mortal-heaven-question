extends GutTest
## 地名系统单元测试（本轮任务书任务二：节点图地图化 + 每个节点有地名）。
##
## [b]覆盖[/b]：地名池的[b]完整性[/b]（17 张图各有池、每池够长、池内不重复）、
## [b]确定性[/b]（同 map_id + node_id 恒同结果）、[b]同图不重复[/b]（单射下标）、
## [b]回落[/b]（未登记地图走「无名之地 %d」）、[b]别名归一[/b]（历史写法与规范写法
## 同结果）、[b]种子可复现[/b]（同种子恒同、不同种子仍不重复）。[br]
##
## [br][b]为什么这些断言值钱[/b]：地名的重名/漂移都是「不会报错的缺陷」——画面上
## 只是两个格子叫同一个名字，运行期日志干净。只有断言拦得住。[br]
##
## [br][b]缺口登记[/b]：GDD 全库没有「地名」系统，本表是自拟占位
## （[code]docs/tech-debt-register.md[/code] DEBT-EUI-007-1）。[br]
##
## 来源: 本轮任务书任务二、src/feature/exploration/exploration_place_catalog.gd。

const Places := preload("res://src/feature/exploration/exploration_place_catalog.gd")
const MapCatalog := preload("res://src/feature/exploration/exploration_map_catalog.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 完整性——每张登记地图都有自己的地名池
# ═══════════════════════════════════════════════════════════════════════════════

## 探明表里每一张地图都必须有地名池——漏一张，那张图的节点全叫「无名之地 N」。[br]
## [br][b]为什么按探明表遍历而不是按本表遍历[/b]：反过来只能发现「池子多了一个」，
## 发现不了「新增地图忘了配池」——后者才是真会发生的那个。
func test_every_registered_map_has_a_place_pool() -> void:
	for map_id: StringName in MapCatalog.MAPS.keys():
		assert_false(Places.pool_of(map_id).is_empty(),
				"地图 %s 没有地名池——它的节点会全叫「无名之地」" % map_id)


## 每池长度 ≥ [constant Places.MIN_POOL]——短于它，「层 × 4 + 格」的下标会绕回，
## 同一张图出现两个同名地点。[br]
## [br][b]为什么这条是硬下限[/b]：见 [method Places.place_for] 的算法第 2 步。
func test_every_pool_is_long_enough_for_the_index_scheme() -> void:
	for map_id: StringName in Places.PLACES.keys():
		var pool: Array = Places.pool_of(map_id)
		assert_gte(pool.size(), Places.MIN_POOL,
				"地图 %s 的地名池只有 %d 个（需要 ≥ %d）——下标会绕回、地名会重复"
				% [map_id, pool.size(), Places.MIN_POOL])


## 池内无重复项——池子自己重名的话，再怎么设计下标也救不回来。
func test_no_pool_contains_duplicate_names() -> void:
	for map_id: StringName in Places.PLACES.keys():
		var seen: Dictionary = {}
		for place: Variant in Places.pool_of(map_id):
			assert_false(seen.has(place),
					"地图 %s 的池内「%s」出现两次（池子自己有重名）" % [map_id, place])
			seen[place] = true


## 每个地名都是非空中文串——空串画出来是「节点下什么都没有」，不会报错。
func test_every_place_name_is_non_empty() -> void:
	for map_id: StringName in Places.PLACES.keys():
		for place: Variant in Places.pool_of(map_id):
			assert_false(str(place).strip_edges().is_empty(),
					"地图 %s 的池里有一个空地名" % map_id)


## 地名长度 ≤ 4 字——标签排版盒宽 = 节点边长 × [code]Style.LABEL_BOX_RATIO[/code]，
## 同层节点间距是 [constant Style.NODE_GAP]；超过 4 字会顶到隔壁节点的名字上。[br]
## [br][b]与类型标签同一条布局约束[/b]（见 test_node_graph_legibility 的 4 字断言）。
func test_every_place_name_fits_the_label_box() -> void:
	for map_id: StringName in Places.PLACES.keys():
		for place: Variant in Places.pool_of(map_id):
			assert_lte(str(place).length(), 4,
					"地图 %s 的地名「%s」超过 4 字——会溢出到相邻节点" % [map_id, place])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 确定性 + 同图不重复（单射下标）
# ═══════════════════════════════════════════════════════════════════════════════

## 同一输入恒同输出——连问三次结果一致（无随机源、无内部状态）。[br]
## [br][b]为什么单独断三次[/b]：一次调用只能证明「有返回值」，证明不了「稳定」；
## 而地名的稳定性是玩家存档前后能不能认出同一个地方的前提。
func test_place_for_is_deterministic() -> void:
	for map_id: StringName in MapCatalog.MAPS.keys():
		for node_id: int in [0, 101, 202, 303, 504]:
			var first: String = Places.place_for(map_id, node_id)
			assert_eq(Places.place_for(map_id, node_id), first,
					"%s/%d 第二次调用结果不同（地名漂了）" % [map_id, node_id])
			assert_eq(Places.place_for(map_id, node_id), first,
					"%s/%d 第三次调用结果不同（地名漂了）" % [map_id, node_id])
			assert_false(first.is_empty(), "%s/%d 的地名不能为空" % [map_id, node_id])


## 同一张图内[b]任意两个合法节点[/b]的地名互不相同。[br]
## [br][b]遍历范围[/b]：[constant Places.MAX_LAYERS] 层 × [constant Places.IDX_SLOTS]
## 格——正是算法里单射下标的取值空间；超出这个范围的组合本就可能绕回
## （见 [method Places.place_for] 的越界注记）。
func test_places_are_unique_within_one_map() -> void:
	for map_id: StringName in MapCatalog.MAPS.keys():
		var seen: Dictionary = {}
		for layer: int in Places.MAX_LAYERS:
			for idx: int in Places.IDX_SLOTS:
				var node_id: int = layer * 100 + idx
				var place: String = Places.place_for(map_id, node_id)
				assert_false(seen.has(place),
						"地图 %s 里 %d 与 %d 同名「%s」" % [map_id, seen.get(place, -1),
						node_id, place])
				seen[place] = node_id


## 种子整体循环移位——换种子仍不重复（移位是双射）。[br]
## [br][b]为什么现在就测[/b]：种子当前恒 0（DAG 的 seed 不进渲染快照，
## 见 [method Places.place_for] 第 3 步），这一步是为将来留的口子——留的口子
## 现在不锁住，将来接上时才发现重名就晚了。
func test_seed_rotates_without_introducing_duplicates() -> void:
	for seed_value: int in [0, 1, 7, 23, 100]:
		var seen: Dictionary = {}
		for layer: int in Places.MAX_LAYERS:
			for idx: int in Places.IDX_SLOTS:
				var node_id: int = layer * 100 + idx
				var place: String = Places.place_for(&"qing_yun_jian_zong",
						node_id, seed_value)
				assert_false(seen.has(place),
						"种子 %d 下 %d 与 %d 同名「%s」" % [seed_value,
						seen.get(place, -1), node_id, place])
				seen[place] = node_id


## 同种子恒同结果、不同种子[b]能[/b]给出不同结果（旋转真的生效了）。[br]
## [br][b]为什么两条一起断[/b]：只断「同种子同结果」的话，把种子参数整个忽略掉
## 也能通过——那就成了一个永远不生效的参数。
func test_seed_changes_the_result_but_stays_reproducible() -> void:
	var base: String = Places.place_for(&"qing_yun_jian_zong", 101, 0)
	assert_eq(Places.place_for(&"qing_yun_jian_zong", 101, 0), base,
			"同种子应复现同结果")
	assert_ne(Places.place_for(&"qing_yun_jian_zong", 101, 1), base,
			"种子 +1 应给出池里的下一个地名（旋转没生效？）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 回落 + 别名归一
# ═══════════════════════════════════════════════════════════════════════════════

## 未登记地图回落「无名之地 %d」——带节点 ID，不是所有节点一个名字。[br]
## [br][b]为什么格式里必须有 %d[/b]：统一一个名字会让未登记地图上每个格子长得
## 一模一样，玩家连「我走到第几格」都读不出来。
func test_unregistered_map_falls_back_with_node_id() -> void:
	var place: String = Places.place_for(&"not_a_real_map", 203)
	assert_eq(place, Places.FALLBACK_FORMAT % 203, "未登记地图应回落带节点 ID 的文案")
	assert_ne(Places.place_for(&"not_a_real_map", 203),
			Places.place_for(&"not_a_real_map", 204),
			"回落文案应随节点 ID 变化（每格一个名字）")


## 空地图 ID 也走回落（stub 降级路径没有 map_id，见渲染器 [code]place_name_of[/code]）。
func test_empty_map_id_falls_back() -> void:
	assert_eq(Places.place_for(&"", 101), Places.FALLBACK_FORMAT % 101,
			"空地图 ID 应回落，而不是取到某张图的池")


## 未登记地图的池查询返回空数组（调用方据此走回落，不臆造一个默认池）。
func test_pool_of_unknown_map_is_empty() -> void:
	assert_true(Places.pool_of(&"not_a_real_map").is_empty(), "未登记地图不应有池")
	assert_true(Places.pool_of(&"").is_empty(), "空 ID 不应有池")


## 别名写法与规范写法得到同一个地名——历史写法经 [code]canonical_id[/code] 归一。[br]
## [br][b]为什么这条重要[/b]：别名表住在探明表里，本表不复制；一旦有人在本表里
## 手写别名键，这条会红——重名池的幽灵就是这么进来的。
func test_legacy_alias_resolves_to_the_same_place() -> void:
	assert_eq(Places.place_for(&"guixu_gumo_zhanchang", 101),
			Places.place_for(&"gui_xu_gu_mo_zhan_chang", 101),
			"别名写法与规范写法应得到同一套地名")
	assert_eq(Places.place_for(&"mulan_caoyuan", 202),
			Places.place_for(&"mu_lan_cao_yuan", 202),
			"别名写法与规范写法应得到同一套地名")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 池与地图风格对应（抽样——防「把所有图都配上同一套池」）
# ═══════════════════════════════════════════════════════════════════════════════

## 不同地图的池[b]内容不同[/b]——同一个地名出现在两张图里说明池被复制粘贴了。[br]
## [br][b]为什么只抽首图与血渊[/b]：全量两两比较是 O(17² × 24) 次断言，收益与抽样
## 相同（复制粘贴是一整池一起复制的）。
func test_different_maps_have_different_pools() -> void:
	var qingyun: Array = Places.pool_of(&"qing_yun_jian_zong")
	var xueyuan: Array = Places.pool_of(&"xue_yuan_mi_jing")
	assert_ne(qingyun, xueyuan, "两张不同地图的地名池不应完全相同")
	assert_false(qingyun.has(Places.place_for(&"xue_yuan_mi_jing", 0)),
			"青云剑宗入口的地名不应出现在血渊秘境的池里（池被复制了？）")
