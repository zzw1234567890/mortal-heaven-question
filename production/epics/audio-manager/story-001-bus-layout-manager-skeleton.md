# Story 001: AudioBusLayout 与 AudioManager 骨架（PersistentLayer 挂载）

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: §2 总线架构 + 边缘 #14 + AC-BUS 默认值部分
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§1.2 PersistentLayer）
**ADR Decision Summary**: AudioManager 为 RefCounted 控制类，启动时实例化并将 AudioStreamPlayer 节点池挂入 SceneManager PersistentLayer（root 直挂 Node，`register_persistent(node)` API）——**结构已定死，本 epic 不得改动**。总线引用一律按名称（子总线使整数索引不可靠）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后，但本 story 无焦点交互）
**Engine Notes**: AudioBusLayout 资产（`resources/audio/default_bus_layout.tres`）+ AudioServer 运行时管理。AudioServer 不可用的静默模式需可注入的包装层（headless 测试无法直接模拟）。

**Control Manifest Rules (this layer)**:
- Required: 总线按名称访问（`AudioServer.get_bus_index("BGM")`）；AudioServer 包装层可注入
- Forbidden: 硬编码总线索引；零新增 Autoload（节点池经 PersistentLayer）
- Guardrail: 启动时异步加载不阻塞主线程

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`，scoped to this story:*

- [ ] `default_bus_layout.tres` 定义 6 总线 + 3 SFX 子总线（Combat/Card/Explore SFX），默认 dB：Master 0 / BGM 0 / SFX -3 / UI -8 / Ambient -10 / Voice -1
- [ ] 效果器：Master Limiter（ceiling -0.5dB）、SFX Limiter（ceiling -1dB）、Ambient Reverb（可选）
- [ ] AudioManager（RefCounted）启动实例化，AudioStreamPlayer 节点池挂入 PersistentLayer（ADR-0031 §1.2 定死结构）
- [ ] AudioServer 不可用时进入静默模式：所有 API 调用 no-op 不崩溃，开发日志记录（边缘 #14）
- [ ] 全部 API 骨架（play_sfx/play_bgm/stop_bgm/pause_all/resume_all/play_ambient/stop_ambient/set_bus_volume/get_bus_volume/toggle_mute/set_state）签名与 GDD §8 一致

---

## Implementation Notes

*Derived from ADR-0031 §1.2 Implementation Guidelines:*

- PersistentLayer：SceneManager 启动时创建 root 直挂 Node；AudioManager 启动时实例化（RefCounted 控制类）并注册节点池。**此结构 audio epic 内任何 story 不得改动**。
- **总线名称常量**：定义 `AudioBus` 枚举与名称映射（MASTER/BGM/SFX/UI/AMBIENT/VOICE），一切访问经 `get_bus_index(name)`——GDD 总线表中的「索引1/2/3」是结构示意，不作硬编码依据（QL-STORY-READY 2026-09-07：子总线占用索引使数值不稳定）。
- AudioServer 包装：`AudioServerAdapter` 薄层（get/set bus volume、mute 检测）——静默模式 = 适配器检测 AudioServer 不可用后所有调用 no-op + 日志。可注入以便 headless 测试。
- API 骨架空实现（后续 story 填充），签名与 GDD §8 完全一致。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: BGM 交叉淡化实现
- Story 003: SFX 池逻辑
- Story 004: set_state 过渡矩阵
- Story 005: 暂停/静音/音量控制行为
- Story 006: 环境音层与无障碍
- Story 007: BGM 存档恢复
- R-06 spike（独立前置任务，非本 epic story）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 总线结构存在性（按名称断言）
  - Given: 加载 `default_bus_layout.tres`
  - When: 按名称查询总线
  - Then: Master/BGM/SFX/UI/Ambient/Voice 6 总线 + Combat SFX/Card SFX/Explore SFX 3 子总线全部存在；默认 dB 与 GDD 表一致；Master Limiter ceiling -0.5dB、SFX Limiter ceiling -1dB 存在
  - Edge cases: 重名总线不存在；效果器参数在安全范围

- **AC-2**: PersistentLayer 挂载（ADR-0031 §1.2）
  - Given: 游戏启动完成
  - When: 检查 PersistentLayer 子节点
  - Then: AudioManager 节点池节点存在且 process_mode 不受场景切换影响
  - Edge cases: 场景切换后节点池仍存在（不随场景卸载）

- **AC-3**: 静默模式
  - Given: 注入 AudioServer 不可用的适配器
  - When: 调用任意 API
  - Then: no-op 不崩溃，日志记录一次
  - Edge cases: 恢复可用后 API 正常

**[Unit — API 骨架]:**

- **AC-4**: API 签名完整性
  - Given: AudioManager 类
  - When: 检查方法签名
  - Then: 与 GDD §8 的 11 个 API 签名一致（参数名/类型/默认值）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/audio/test_bus_layout.gd` — must exist and pass（BLOCKING）
- Unit: `tests/unit/audio/test_audio_manager_api_skeleton.gd` — must exist and pass（BLOCKING）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（SceneManager PersistentLayer 已实现）
- Unlocks: Story 002~007（骨架与总线结构）
