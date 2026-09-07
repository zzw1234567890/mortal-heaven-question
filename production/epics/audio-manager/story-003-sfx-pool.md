# Story 003: SFX 池——16 节点池与淘汰/冷却/随机化

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: AC-SFX-01~07 + §7 UI 音效规则 + 边缘 #2/#4/#15
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: SfxPool 独立类（GDD 明示 200-400 行）——淘汰/冷却/随机化/UI 打断全部确定性逻辑，时间注入可单测。节点池挂 PersistentLayer（Story 001 结构）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `play_sfx(sfx_id, options)` options 含 `is_attack_sfx`（战斗 100ms 门控标记，QL-STORY-READY 2026-09-07 裁决：标记机制走 options 参数）。RNG 注入固定种子供测试复现。

**Control Manifest Rules (this layer)**:
- Required: SfxPool 类时间注入（clock: Callable）+ RNG 注入；信号断言（sfx_cooldown_discarded / sfx_pool_exhausted）
- Forbidden: 硬编码 MAX_SIMULTANEOUS 等参数（调优参数表数据驱动）
- Guardrail: 冷却/淘汰判定不逐帧轮询（请求时惰性计算）

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`，scoped to this story:*

- [ ] 卡牌 SFX 播放随机化：pitch ∈ [0.9, 1.1]、volume ∈ -3dB±3dB（AC-SFX-01）
- [ ] 12 槽满时按「优先级→年龄」淘汰，新请求优先级更高则播放（AC-SFX-02）
- [ ] 12 槽全优先级 2 时拒绝 + `sfx_pool_exhausted` 信号（AC-SFX-03）
- [ ] 同 sfx_id 冷却 50ms：窗口内（elapsed < 50ms）丢弃 + `sfx_cooldown_discarded` 信号；≥50ms 接受并重置（AC-SFX-04/05，边界澄清 2026-09-07）
- [ ] 战斗攻击 SFX 100ms 门控（options.is_attack_sfx 标记）（AC-SFX-06）
- [ ] SFX 缺失静默失败 + push_warning，不影响其他 SFX（AC-SFX-07 / 边缘 #2）
- [ ] 异步加载失败→标记不可用→后续静默丢弃（边缘 #15）
- [ ] UI 音效打断规则：新 UI 音效打断旧 UI 音效；最低播放时长 80ms（GDD §7，边界澄清 2026-09-07 归本 story）
- [ ] 16 节点池（12 活跃 + 4 余量）挂 PersistentLayer

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`SfxPool` 类——构造函数接收 `clock: Callable`（返回毫秒）与 RNG；`request_sfx(sfx_id, options)` 完整实现 GDD 公式 2 伪代码（冷却→空槽→淘汰→拒绝分支）。全部调优参数（MAX=12、冷却 50ms、攻击间隔 100ms、随机化范围、UI 最低 80ms）来自数据驱动配置。

- UI 音效层：独立的 UI SFX 播放路径（单实例打断语义 + 80ms 最低时长计时）——与通用池共存，UI 总线路由。
- 攻击门控：`options.is_attack_sfx = true` 的请求走独立 100ms 窗口判定。
- 信号：`sfx_cooldown_discarded(sfx_id, elapsed_ms)`、`sfx_pool_exhausted(sfx_id)`。
- 资源缺失：请求时查加载表；未加载/标记不可用→静默丢弃+日志（不影响池状态）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 节点池挂载结构（本 story 消费 16 节点池）
- Story 004: 场景信号→播放编排（谁在何时调 play_sfx）
- 音频资产制作（8 BGM / ~50 SFX）：资产管线任务
- F1 静音图标：hud epic story 008

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/audio/test_sfx_pool.gd`，时间/RNG 注入）

- **AC-1**: 冷却窗口内丢弃（AC-SFX-04）
  - Given: clock=0ms 时 play("sword_hit") 成功
  - When: clock=30ms 再次 play("sword_hit")
  - Then: 不分配播放器；emit `sfx_cooldown_discarded("sword_hit", 30)`；active_player_count 不变
  - Edge cases: 窗口内第 3 次请求同样丢弃

- **AC-2**: 冷却到期接受（AC-SFX-05）
  - Given: clock=0 播放
  - When: clock=50ms（恰为边界）再次请求
  - Then: 正常播放，计时器重置为 50
  - Edge cases: clock=49ms（丢弃）与 50ms（接受）分界

- **AC-3**: 池满淘汰——优先级然后年龄（AC-SFX-02）
  - Given: 12 槽满（2 个 prio 0 于 t=0/t=100，3 个 prio 1，7 个 prio 2）
  - When: 新请求 prio 2
  - Then: t=0 的 prio 0 被停止，其播放器承载新 SFX
  - Edge cases: 同优先级按年龄；候选与请求优先级相同时拒绝

- **AC-4**: 全优先级 2 拒绝（AC-SFX-03）
  - Given: 12 槽全为 prio 2
  - When: 第 13 个请求
  - Then: 拒绝；emit `sfx_pool_exhausted(sfx_id)`；无播放器状态变化

- **AC-5**: 随机化范围（AC-SFX-01）
  - Given: 注入固定 RNG 种子
  - When: play("card_play_gongfa")
  - Then: pitch_scale ∈ [0.9, 1.1]；volume_db ∈ [-6, 0]；同种子可复现
  - Edge cases: options 覆盖随机（不随机化）

- **AC-6**: 战斗攻击门控（AC-SFX-06）
  - Given: is_attack_sfx 请求于 t=0
  - When: 同类请求于 t=99ms / t=100ms
  - Then: 99ms 丢弃；100ms 通过
  - Edge cases: 非攻击 SFX 不受 100ms 门控

- **AC-7**: 缺失资源静默失败（AC-SFX-07）
  - When: play("missing_sfx")
  - Then: 无崩溃、无播放器分配、push_warning 记录、后续 play 正常
  - Edge cases: 标记不可用的资源（边缘 #15）同样静默丢弃

- **AC-8**: UI 音效打断 + 80ms 最低时长（GDD §7）
  - Given: UI 确认音正在播放
  - When: 30ms 后新 UI 取消音请求
  - Then: 旧 UI 音被打断，新音播放；且任何 UI 音播放时长不足 80ms 时不被无声截断（最低时长保证）
  - Edge cases: 快速连续 3 个 UI 音（仅最后一个可听全）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/audio/test_sfx_pool.gd` — must exist and pass（BLOCKING）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（节点池与骨架）
- Unlocks: Story 004（场景状态触发 SFX 清理等）
