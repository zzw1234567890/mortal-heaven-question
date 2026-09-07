# Story 007: BGM 存档恢复（save-load 对接）

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: 边缘 #10/#11（BGM 存档恢复）+ GDD 边界澄清 2026-09-07
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 存档记录当前 BGM ID 与播放位置(ms)；读档后恢复到存档时的 BGM 与位置继续播放；场景不匹配时优先当前场景默认 BGM。音频侧提供恢复 API，存档 schema 协调双侧对接（QL-STORY-READY 2026-09-07 新增——此前无 story 认领）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: SaveLoadSystem（Foundation 层已 Complete）存档字典扩展字段：`audio.bgm_id` + `audio.bgm_position_ms`——须核对其既有 schema 兼容性（未知字段容忍策略）。

**Control Manifest Rules (this layer)**:
- Required: 恢复位置断言（自动化）；场景不匹配回退判定纯函数
- Forbidden: 音频状态自行读写存档文件（经 SaveLoadSystem API）
- Guardrail: 恢复流程不阻塞读档主流程（异步加载 BGM）

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md` 边缘 #10/#11，scoped to this story:*

- [ ] 存档时记录当前 BGM ID 与播放位置(ms)（边缘 #10）
- [ ] 读档后 BGM 恢复到存档时的曲目与位置，继续播放（边缘 #10）
- [ ] 存档 BGM 与读档后场景不匹配时，优先播放当前场景默认 BGM（忽略存档 BGM）（边缘 #11）
- [ ] 恢复 API：`restore_bgm(bgm_id, position_ms)`（AudioManager 公共接口）
- [ ] BGM 位置数据与 SaveLoadSystem 存档往返无丢失

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`resolve_restored_bgm(saved_bgm_id, saved_scene, current_scene) -> Dictionary` 纯函数——场景匹配→返回存档 BGM+位置；不匹配→返回当前场景默认 BGM+位置 0。

- SaveLoadSystem 对接：存档字典追加 `audio.bgm_id`/`audio.bgm_position_ms` 字段（在其既有快照域模式下扩展——核对其未知字段容忍策略，必要时协调 save-load 侧小改）。
- AudioManager 暴露 `get_bgm_state() -> Dictionary`（存档时由 SaveLoadSystem 或其调用方采集）与 `restore_bgm(bgm_id, position_ms)`。
- 恢复经异步加载后 seek 到位置播放（`AudioStreamPlayer.play(position)`）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: BGM 播放/淡化原语（本 story 消费）
- SaveLoadSystem 核心机制：既有系统（本 story 仅扩展字段与采集时机）
- 环境音的存档恢复：GDD 未要求（存档恢复时环境音按当前地图重新播放）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/audio/test_bgm_restore_resolution.gd`）

- **AC-1**: 场景匹配恢复
  - Given: 存档 bgm_id="bgm_explore_qi"、position=32000ms、当前场景为探索
  - When: `resolve_restored_bgm()`
  - Then: 返回 {bgm_id: "bgm_explore_qi", position_ms: 32000}
  - Edge cases: position 超出曲目长度（钳制到起点）；bgm_id 为空

- **AC-2**: 场景不匹配回退（边缘 #11）
  - Given: 存档 bgm_id="bgm_explore_qi"、当前场景为商店
  - When: 求解
  - Then: 返回商店对应默认 BGM、position 0
  - Edge cases: 当前场景无默认 BGM 映射（静默不播放）

**[Integration — automated test specs]**（`tests/integration/audio/test_bgm_save_restore.gd`）

- **AC-3**: 存档/读档往返
  - Given: BGM 播放至 t=5.0s，执行存档
  - When: 读档完成
  - Then: BGM 曲目与位置与存档时一致（±50ms 容差），继续播放
  - Edge cases: 存档后手动改场景再读档（走回退分支）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Logic: `tests/unit/audio/test_bgm_restore_resolution.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/audio/test_bgm_save_restore.gd` — must exist and pass（BLOCKING）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（BGM 播放原语）；SaveLoadSystem（既有）
- Unlocks: None
