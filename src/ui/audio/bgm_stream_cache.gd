class_name BgmStreamCache
extends RefCounted
## BgmStreamCache —— BGM 流加载与缓存（audio-manager Story 002 AC-8）。
##
## [b]职责[/b]：bgm_id → 音频流的解析、异步加载与常驻缓存——[br]
##   - [method preload_bgm]：[code]ResourceLoader.load_threaded_request()[/code]
##     异步预加载（主线程不阻塞——ADR-0031/GDD §4 BGM 加载条款）[br]
##   - [method resolve]：缓存命中直接返回；冷路径 [code]request + get[/code]
##     同步回退（[code]load_threaded_get[/code] 等待已在途的异步请求完成）[br]
##   - [method trim]：逐出非保留条目并 [code]ResourceLoader.unload()[/code]
##     释放——常驻 ≤2 首（当前 + 预加载下一首，GDD guardrail）[br]
## [br][b]边缘 #1[/b]：路径无映射/文件损坏/缺失 → 返回 null + push_warning
## 一次（调用侧保留旧曲——GDD 边缘 #1）。[br]
## [br][b]注入[/b]：路径覆盖表由 AudioManager 传入共享引用（测试注入真实
## 资源路径；生产表为空时按无映射处理）。对象级注入（程序生成流）不经
## 本类——优先级高于缓存，由 AudioManager 前置短路。
##
## @experimental
## 来源: design/gdd/audio-system.md §4 BGM 加载、audio Story 002 AC-8、ADR-0031。

## 保留容量上限（GDD：常驻 2 首——当前 + 预加载下一首）。
const KEEP_CAPACITY: int = 2

## 缓存条目：bgm_id → {"stream": AudioStream, "path": String}。
var _cache: Dictionary = {}

## 保留集合头部（current 在前，preload 其后——trim 按 KEEP_CAPACITY 截取）。
var _keep_ids: Array[StringName] = []

## 路径覆盖表（共享引用——AudioManager 测试注入；生产为空）。
var _path_overrides: Dictionary


## 构造。[br]
## [param path_overrides]: bgm_id → 资源路径映射（Dictionary 引用共享——
## AudioManager 与本类读写同一表）。
func _init(path_overrides: Dictionary = {}) -> void:
	_path_overrides = path_overrides


## 异步预加载 BGM（不阻塞主线程——request 后由 [method resolve] 消费）。[br]
## 路径无映射/已在缓存/请求已在途 → 静默跳过（幂等）。
func preload_bgm(bgm_id: StringName) -> void:
	if bgm_id == &"" or _cache.has(bgm_id):
		return
	var path: String = _path_overrides.get(bgm_id, "")
	if path == "":
		push_warning("BgmStreamCache: BGM '%s' 无资源路径映射（跳过预加载）" % bgm_id)
		return
	if not ResourceLoader.exists(path):
		push_warning("BgmStreamCache: BGM 路径不存在（跳过预加载）: %s" % path)
		return
	ResourceLoader.load_threaded_request(path)
	_mark_keep(bgm_id)


## 解析 bgm_id → 音频流。[br]
## 缓存命中直接返回；冷路径同步回退（request + get）。失败返回 null
## （调用侧保留旧曲——边缘 #1）。
func resolve(bgm_id: StringName) -> AudioStream:
	if bgm_id == &"":
		return null
	if _cache.has(bgm_id):
		return _cache[bgm_id]["stream"]
	var path: String = _path_overrides.get(bgm_id, "")
	if path == "":
		push_warning("BgmStreamCache: BGM '%s' 无资源路径映射（保持旧曲）" % bgm_id)
		return null
	if not ResourceLoader.exists(path):
		push_warning("BgmStreamCache: BGM 路径加载失败（保持旧曲）: %s" % path)
		return null
	ResourceLoader.load_threaded_request(path)
	var stream: AudioStream = ResourceLoader.load_threaded_get(path) as AudioStream
	if stream == null:
		push_warning("BgmStreamCache: BGM 加载失败或类型不匹配（保持旧曲）: %s" % path)
		return null
	_cache[bgm_id] = {"stream": stream, "path": path}
	_mark_keep(bgm_id)
	return stream


## 标记当前播放曲（保留集合头部——trim 必留）。
func set_current(bgm_id: StringName) -> void:
	if bgm_id == &"":
		return
	_keep_ids.erase(bgm_id)
	_keep_ids.push_front(bgm_id)


## 逐出非保留条目并释放资源（常驻 ≤ [constant KEEP_CAPACITY] 首）。[br]
## 逐出条目经 [code]ResourceLoader.unload()[/code] 释放（GDD：不再需要的
## BGM 释放）。
func trim() -> void:
	var kept: Array[StringName] = []
	for bgm_id: StringName in _keep_ids:
		if _cache.has(bgm_id) and kept.size() < KEEP_CAPACITY:
			kept.append(bgm_id)
	_keep_ids = kept
	var evicted: Array[StringName] = []
	for bgm_id: StringName in _cache.keys():
		if not kept.has(bgm_id):
			evicted.append(bgm_id)
	for bgm_id: StringName in evicted:
		# 引用置空后由 Godot 引用计数回收（4.6 无 ResourceLoader.unload
		# 静态 API——GDD「unload 释放」措辞按引用语义落地）
		_cache.erase(bgm_id)


## 当前缓存的 bgm_id 列表（测试断言常驻容量/逐出行为用）。
func cached_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for bgm_id: StringName in _cache.keys():
		ids.append(bgm_id)
	return ids


## 记录保留集合（容量截取——set_current 置头、preload 追加）。
func _mark_keep(bgm_id: StringName) -> void:
	_keep_ids.erase(bgm_id)
	_keep_ids.push_front(bgm_id)
	if _keep_ids.size() > KEEP_CAPACITY:
		_keep_ids.resize(KEEP_CAPACITY)
