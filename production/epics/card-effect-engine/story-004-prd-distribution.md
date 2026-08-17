# Story 004: PRD 伪随机分布引擎（5% 步进 + 怜悯保护）

> **Epic**: 卡牌效果解析引擎 (Card Effect Engine)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Completion Notes
**Completed**：2026-08-16
**Criteria**：2/2 通过（AC-001~002 由单元测试覆盖）
**Deviations**：重大公式修订（game-designer 裁决）——原 ADR-0009/GDD 公式「起始=P_base + 失败累加 P_base×C」结构上无法收敛到标示值（实测 C=0.3 长期触发率 40%），改为**标准 PRD**：起始=校准常数 C（C<p），失败累加 C，触发重置 C，runtime `calibrate_C(p)` 二分求解使含怜悯截断的 E[N]=1/p（30%→C≈0.108）。已同步 GDD §9 + 调优表 + 待解决问题 #4 + ADR-0009 §PRD 伪随机分布引擎
**Test Evidence**：`tests/unit/card_effect_engine/test_prd_distribution.gd`（11 测试全通过）；全量套件 66 scripts / 1208 tests / 1207 passing / 1 pending / 0 failing 零回归
**Code Review**：已完成（lead-programmer CONCERNS→已采纳 C1 get_p_current 语义注释 + C2 ADR 伪代码顺序回写 + 二分常量注释；qa-lead ADEQUATE）
**QA 缺口 #2 已解决**：C 校准完成，AC-002 的 [24,36] 区间在修正公式 + seed=42 下实测 31 次通过

## Context

**GDD**: `design/gdd/card-effect-engine.md`
**Requirement**: `TR-effect-003`（PRD 伪随机分布属触发链管理需求——`TR-effect-003` 涵盖"深度 10 层 + 循环检测 + PRD 伪随机分布"）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0009（卡牌效果引擎——Resource 模板 + RefCounted 运行时实例 + 栈式结算）
**ADR Decision Summary**: 概率效果使用 PRD 伪随机分布（非独立随机）——独立 `RandomNumberGenerator` 实例（非全局 `randf()`），`P_base` 5% 步进，失败累加 `P_current += P_base × C`，连续失败 `ceil(1/P_base)` 次怜悯保护强制触发。`P_current` 按 `card_instance_id` 独立追踪。测试模式 `prng_override_seed`。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `RandomNumberGenerator` 为 Godot 4.x 稳定 API（非截止后风险）。关键约束来自 ADR——绝不使用全局 `randf()`，每个引擎实例独立 RNG。种子来自 `GSM.meta.seed`，测试模式用 `prng_override_seed`。

**Control Manifest Rules (Feature 层)**:
- **Required**: PRD 引擎——独立 `RandomNumberGenerator` 实例——5% 步进 + 怜悯保护
- **Forbidden**: 绝不使用全局 `randf()` 处理 PRD 效果——每个引擎实例独立 `RandomNumberGenerator`
- **Forbidden**: 绝不复制 `OutcomeType` 枚举（概率效果的 outcome 类型复用扩展后的权威枚举）

---

## Acceptance Criteria

*From GDD `design/gdd/card-effect-engine.md` §验收标准 → 概率效果 (PRD):*

- [x] **AC-001**: GIVEN 效果配置为"30%概率冰冻"，WHEN 连续失败4次（PRD理论连续失败上限≈4），THEN 第5次必然触发（怜悯强制触发）
- [x] **AC-002**: GIVEN 同一PRNG种子执行100次30%PRD效果，WHEN 统计触发次数，THEN 触发次数在24-36次之间（99% CI区间近似值；PRD收敛后该区间比独立随机更紧）

---

## Implementation Notes

*Derived from ADR-0009 §决策 → PRD 伪随机分布引擎:*

1. **文件位置**: `src/feature/card_effect_engine/prd_engine.gd`（`class_name PRDEngine extends RefCounted`，CardEffectEngine 持有单例实例）。
2. **状态**:
   - `var prng := RandomNumberGenerator.new()`——独立 RNG 实例（不共享全局状态），初始化 `prng.seed = GSM.meta.seed`
   - `P_base ∈ {0.05, 0.10, 0.15, ..., 0.95}`——5% 步进
   - `C: float`——调优参数（控制收敛速度，默认待游戏测试校准，安全范围 0.3-1.0）
   - `P_current[card_instance_id] = P_base`——每卡牌实例独立的状态（Dictionary 追踪）
3. **`next_random(card_instance_id, p_base) → bool`** 算法:
   - 测试模式：若 `GSM.meta.prng_override_seed != null` → `test_prng := RandomNumberGenerator.new()`，`test_prng.seed = prng_override_seed`，`roll = test_prng.randf()`
   - 否则 `roll = prng.randf()`（实例 RNG `[0.0, 1.0)`）
   - `if roll < P_current[card_instance_id]:` → `P_current[card_instance_id] = P_base`（触发——重置），`return true`
   - `else:` → `P_current[card_instance_id] += P_base × C`（失败——累加概率）；`if failure_streak >= ceil(1/P_base):` → 重置 `P_base`，`return true`（怜悯保护）；`return false`
4. **`reset_prng_seed(seed: int)`**: 测试模式设置确定性种子——所有 `randf()` 调用可重现。
5. **为什么 PRD 不是全局单例**: `P_current` 状态按 `card_instance_id` 独立追踪——不同卡牌的"30% 概率"不共享失败计数。玩家打出一张"30% 冰冻"失败后，下一次同卡牌 P_current 累加，但另一张"30% 眩晕"从独立 P_base 开始。
6. **怜悯保护阈值**: 连续失败次数达 `ceil(1/P_base)` 后强制触发——30% 概率 → `ceil(1/0.3)=4` 次连续失败后第 5 次强制触发。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: 触发链深度 10 硬限制 + `visited_card_ids` 循环检测（同属 TR-effect-003，但本 Story 仅实现 PRD 部分）
- **Story 001**: EffectInstance 对象模型（本 Story 消费实例的 `source_card_instance_id` 作为 PRD 状态键）
- **CombatUI PRD 指示器**: "30% (×4 未触发)" 提示——战斗 UI Epic 职责

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: 怜悯保护强制触发
  - Given: 效果配置为"30% 概率冰冻"（P_base=0.3）
  - When: 连续失败 4 次（PRD 理论连续失败上限 ≈4）
  - Then: 第 5 次必然触发（怜悯强制触发）
  - Edge cases: 不同 card_instance_id 各自独立累计失败次数；触发后 P_current 重置为 P_base

- **AC-002**: 100 次试验触发次数区间
  - Given: 同一 PRNG 种子执行 100 次 30% PRD 效果
  - When: 统计触发次数
  - Then: 触发次数在 24-36 次之间（99% CI 区间近似值；PRD 收敛后比独立随机更紧）
  - Edge cases: 固定种子 → 100 次结果确定性可重现（同种子同操作序列 = 相同结果）；测试模式 prng_override_seed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_effect_engine/test_prd_distribution.gd` — must exist and pass
**Status**: [x] Created and passing（11 测试函数，全通过）

---

## Dependencies

- Depends on: Story 001（EffectInstance 对象模型——`source_card_instance_id` 作为 PRD 每卡牌独立状态键）
- Unlocks: Story 005（`evaluate_effect_probabilistic` 复用 PRD 分布逻辑生成离散概率分布）
