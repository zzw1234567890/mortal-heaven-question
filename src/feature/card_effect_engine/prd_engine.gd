## PRDEngine —— 伪随机分布 (Pseudo-Random Distribution) 引擎。
##
## 概率效果（如"30% 冰冻"）采用 PRD 而非独立随机（ADR-0009 / GDD §9）。
## [b]标准 PRD 公式[/b]（game-designer 裁决 2026-08-16）：
##   - 起始概率 = 校准常数 C（[b]远小于标示值 p[/b]，非 p 本身）
##   - 失败累加 [code]P += C[/code]（单一常数，非 [code]p × C[/code]）
##   - 触发重置 [code]P = C[/code]
##   - 怜悯保护：连败 [code]ceil(1/p)[/code] 次后第 M+1 次强制触发（AC-001，不可移除）
##
## [b]C 的确定[/b]：对每个标示概率 p 求解 C，使含怜悯截断后的期望触发次数
## [code]E[N] = 1/p[/code]（长期触发率收敛到标示值）。[method _calibrate_C] 运行时二分求解并缓存。
## 30% → C ≈ 0.108（含怜悯；纯标准 PRD 无怜悯为 0.11895）。
##
## [b]独立 RNG[/b]：持有独立 [RandomNumberGenerator]，绝不使用全局 [code]randf()[/code]。
## 种子由 [method reset_prng_seed] 注入（生产来自 GSM.meta.seed——接线属 CardEffectEngine Autoload）。
##
## [b]纯逻辑、无 GSM 依赖[/b]——确定性：同种子 + 同操作序列 = 相同结果（GDD §9）。
##
## 来源: ADR-0009 §PRD 伪随机分布引擎 / GDD §9 / game-designer 裁决（C 校准）。
class_name PRDEngine
extends RefCounted


# === 内部状态 =====================================================================

## 独立随机数生成器——非全局 randf()。
var _prng := RandomNumberGenerator.new()

## 每卡牌实例的当前累加概率。[code]{card_instance_id: float}[/code]。
var _p_current: Dictionary[int, float] = {}

## 每卡牌实例的连续失败计数。[code]{card_instance_id: int}[/code]。
var _failure_streak: Dictionary[int, int] = {}

## 校准常数 C 缓存——[code]{p_base: C}[/code]。C 由 [method _calibrate_C] 二分求解，O(1) 复用。
var _c_cache: Dictionary[float, float] = {}


# === 种子 =========================================================================

## 设置确定性种子——所有后续 [code]randf()[/code] 调用可重现（测试模式）。
func reset_prng_seed(seed: int) -> void:
	_prng.seed = seed


# === 核心 API =====================================================================

## 掷一次 PRD 判定。[br]
## [br][b]算法[/b]（标准 PRD + 怜悯）：
##   1. 求校准常数 C（[method _calibrate_C]）。[br]
##   2. 怜悯保护——连败已达 [code]ceil(1/p)[/code] 次 → 强制触发（重置）。[br]
##   3. 掷 [code]roll = _prng.randf()[/code]。[br]
##   4. [code]roll < P_current[/code] → 触发，重置，返回 [code]true[/code]。[br]
##   5. 否则失败——[code]P_current += C[/code]（上限 1.0），失败计数 +1，返回 [code]false[/code]。[br]
## [br][param card_instance_id] 效果来源卡牌实例 ID（PRD 状态键）。[br]
## [br][param p_base] 标示概率（5% 步进，[code](0.0, 1.0][/code]）。非法值 push_error 并返回 false。[br]
## [br][b]返回[/b]: 是否触发。
func next_random(card_instance_id: int, p_base: float) -> bool:
	if p_base <= 0.0 or p_base > 1.0:
		push_error("PRDEngine.next_random: p_base 必须在 (0.0, 1.0]，收到 %.3f" % p_base)
		return false

	var c: float = _calibrate_C(p_base)
	var p_current: float = _p_current.get(card_instance_id, c)  # 起始 = C（非 p_base）
	var streak: int = _failure_streak.get(card_instance_id, 0)
	var mercy: int = ceili(1.0 / p_base)

	# 怜悯保护——连败达 ceil(1/p) 后下一次强制触发（独立于掷骰）。
	if streak >= mercy:
		_reset_card_state(card_instance_id)
		return true

	var roll: float = _prng.randf()
	if roll < p_current:
		_reset_card_state(card_instance_id)
		return true

	# 失败——累加 C（上限 1.0）+ 失败计数。
	_p_current[card_instance_id] = minf(1.0, p_current + c)
	_failure_streak[card_instance_id] = streak + 1
	return false


# === 状态查询 / 重置 ==============================================================

## 查询某卡牌实例显式存储的累加值（失败累加后 > 0；触发重置或未初始化均移除键，返回 0.0）。[br]
## [br][b]注意[/b]：内部判定的真实生效概率是「存储值存在则用之，否则回退校准常数 C」——
## 本方法返回 0.0 表示「回退到 C」，而非判定概率 0。仅供调试/测试观察累加进度。
func get_p_current(card_instance_id: int) -> float:
	return _p_current.get(card_instance_id, 0.0)


## 查询某卡牌实例当前的连续失败计数（未初始化返回 0）。
func get_failure_streak(card_instance_id: int) -> int:
	return _failure_streak.get(card_instance_id, 0)


## 查询某标示概率的校准常数 C（会触发 [method _calibrate_C] 求解并缓存）。
func get_calibrated_c(p_base: float) -> float:
	return _calibrate_C(p_base)


## 重置某卡牌实例的 PRD 状态（触发后内部自动调用；也可手动重置）。
func reset_card_state(card_instance_id: int) -> void:
	_reset_card_state(card_instance_id)


## 重置全部卡牌实例的 PRD 状态（保留种子与 C 缓存）——用于战斗结束清理。
func reset_all_state() -> void:
	_p_current.clear()
	_failure_streak.clear()


# === 内部 =========================================================================

## 求解校准常数 C——使含怜悯截断的期望触发次数 [code]E[N] = 1/p[/code]。[br]
## [br][b]C 恒 < p[/b]（标准 PRD 收敛必要条件）。二分求解（200 迭代，double 精度），结果缓存。[br]
## [br][param p_base] 标示概率。[br]
## [br][b]返回[/b]: 校准常数 C。
func _calibrate_C(p_base: float) -> float:
	if _c_cache.has(p_base):
		return _c_cache[p_base]

	var mercy: int = ceili(1.0 / p_base)
	# C ∈ (0, p_base)——C < p 是收敛到标示值的必要条件。
	# 二分下界取极小正值（避免 C=0 使 P 永不增长），200 次迭代足以收敛到 double 精度。
	var lo := 0.0000001
	var hi := p_base
	for _i in range(200):
		var mid := (lo + hi) * 0.5
		if _expected_trials(mercy, mid) > 1.0 / p_base:
			lo = mid  # E[N] 太大 → C 太小 → 增大 C
		else:
			hi = mid
	var c := (lo + hi) * 0.5
	_c_cache[p_base] = c
	return c


## 计算给定 C 与怜悯阈值 M 下的期望触发次数 E[N]。[br]
## [br][b]推导[/b]（game-designer 裁决）：
##   [code]P(N=k) = min(1,k·C) · Π_{j<k}(1 - min(1,j·C))[/code]（k=1..M）
##   [code]P(N=M+1) = Π_{j≤M}(1 - min(1,j·C))[/code]（怜悯强制）[br]
## [br][param mercy] 怜悯阈值 [code]M = ceil(1/p)[/code]。[br]
## [br][param c] 校准常数。[br]
## [br][b]返回[/b]: E[N]。
func _expected_trials(mercy: int, c: float) -> float:
	var e := 0.0
	var prod := 1.0
	for k in range(1, mercy + 1):
		var p_hit := minf(1.0, k * c)
		e += k * p_hit * prod
		prod *= (1.0 - p_hit)
	e += (mercy + 1) * prod
	return e


## 重置单卡 PRD 状态（移除状态键，下次调用回退到校准常数 C 初始值）。
func _reset_card_state(card_instance_id: int) -> void:
	_p_current.erase(card_instance_id)
	_failure_streak.erase(card_instance_id)
