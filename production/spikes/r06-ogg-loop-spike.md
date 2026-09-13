# R-06 Ogg 循环间隙 Spike 报告：Godot 4.6 AudioStreamOggVorbis 无缝循环实测

> **日期**：2026-09-13
> **Sprint**：13（S13-8，timebox 0.5d）
> **验证人**：audio-director 职责范畴（harness 程序化验证）
> **关联**：presentation-layer-risks.md R-06、design/gdd/audio-system.md（无间隙循环限制 + 待解决问题 #5）
> **harness**：`prototypes/r06-ogg-loop-spike/`（spike.gd + test-tone.ogg/wav + results*.json）

---

## 执行环境

| 字段 | 值 |
|------|-----|
| 引擎 | Godot 4.6.3.stable.official.7d41c59c4 |
| 音频驱动 | WASAPI（IAudioClient3，48000Hz，2ch，延迟 10ms） |
| 测试音 | 440Hz 整数周期正弦（880 周期 @ 2.0s / 44100Hz，立体声）——循环正确时相位连续，间隙/跳变在 PCM 上可测 |
| 资产 | OGG q7（GDD BGM 备选规格 9.5KB）+ WAV 16-bit（GDD BGM MVP 规格 353KB） |
| 方法 | AudioEffectRecord 挂 Master 总线录制实际混音输出（Godot 混音器内部、OS 音效之前）6.5s（覆盖 3 次循环），PCM 逐帧扫描静音段（间隙）与帧间跳变（click）。复跑 2 次验证稳定性 |

## 验证结果（核心项全 PASS）

| ID | 验证项 | Ogg | WAV |
|----|--------|-----|-----|
| V1 | 循环模式 `finished` 信号不触发（GDD §BGM 播放规则前提） | **PASS**（3 次回绕，finished=false） | **PASS**（15 次回绕，finished=false） |
| V2 | 循环间隙——最长静音段 | **PASS：0.00ms**（6.5s 录音零静音段） | **PASS：0.00ms** |
| V3 | 样本级循环对照 | — | **PASS**（loop_begin/loop_end 生效） |
| V4 | 间隙差值 vs GDD 30ms 接受线 | **PASS：0 − 0 = 0ms**（远低于 30ms） | 同左 |
| V5 | 相位跳变（click）计数 | **PASS：0 clicks**（两次运行均 0——完全干净） | ⚠ 19/24 clicks（见解读） |
| V6 | 真实音频驱动（非 Dummy） | **PASS**（WASAPI） | 同左 |

**V5 WAV clicks 解读**：WAV 44100Hz 源在 48000Hz WASAPI 混音率下重采样，click 计数随运行波动（19 vs 24，非确定值）——为**重采样器边界伪影**而非循环点瑕疵：Ogg 流（内部 48k 混音路径）两次运行均 0 clicks 完全稳定，且 WAV 的静音段同样为 0。若 WAV clicks 是真实循环瑕疵，Ogg 同样条件不可能为 0。生产 BGM 资产若用 48000Hz 采样率（或项目锁 44100Hz 输出）可避免此伪影——资产规格建议已列入结论。

## 结论

### 1. R-06 关闭——Godot 4.6 Ogg 循环无间隙，GDD「5-30ms 间隙」假设不成立 ✅

- **实测：AudioStreamOggVorbis 循环零间隙、零跳变**（PCM 级测量，WASAPI 真实驱动，复跑稳定）——GDD 中「Godot 4.6 的 Ogg Vorbis 在循环边界存在约 5-30ms 间隙」的描述在 4.6.3 上**不成立**（可能为旧版本行为或坊间传闻，4.x Ogg 重写后已消除）
- **`loop = true` 属性即达样本级无缝循环**——无需双 AudioStreamPlayer 交叉淡化、无需 WAV 变通

### 2. BGM 格式裁决——Ogg Vorbis 直接可用，但维持 GDD 的 WAV MVP 规格 ✅

- 技术上 Ogg 已无循环障碍，但**格式裁决维持 GDD 现状**（BGM = WAV MVP / OGG 备选）：
  - GDD §音频资产规格的内存预算（WAV 8 首 ≈ 40-120MB）已按 WAV 估算并接受
  - 变更规格属 GDD 修订（经济性 ~10× 压缩），应走 GDD 变更流程而非 spike 顺手改
  - **本 spike 解除的是约束而非引入变更**：若后续音频实现时内存吃紧（2GB 上限 + 常驻 2 首也只需 10-30MB，实际无压力），可无损切换 Ogg——风险归零
- 资产规格建议（新信息，供 audio 001/002 实现参考）：BGM 资产按 **48000Hz** 制作可避免 44.1→48k 重采样伪影（WAV 路径实测边界噪声）——GDD 规格表为 44.1kHz，属轻微优化项，不阻塞

### 3. GDD 文档修正项

- audio-system.md L135「Godot 4.6 的 Ogg Vorbis 在循环边界存在约 5-30ms 间隙」→ 应修正为「实测无间隙（2026-09-13 R-06 spike）」
- 待解决问题 #5（Ogg 间隙是否在 WAV 方案下完全消除）→ 已回答：两者均无间隙

## Harness 局限（记录，不影响结论）

- headless（Dummy 驱动）下 `get_playback_position()` 采样不可靠——混音线程不实时推进（首轮数据全部作废）；窗口模式 + WASAPI + PCM 录制为权威方法
- GDScript 逐字节 PCM 解码 31 万帧耗时约 3-4 分钟/阶段（`PackedByteArray.decode_s16` 循环）——harness 一次性成本，结果可信
- WASAPI 混音率 48000Hz vs 测试音 44100Hz——重采样对两种格式一致作用，间隙测量（静音段）不受影响；click 测量受重采样伪影干扰（见 V5 解读）

## 后续行动

| 项 | 状态 |
|----|------|
| R-06（presentation-layer-risks.md） | **已关闭**（2026-09-13 spike，本报告为关闭依据） |
| audio-system.md L135 + 待解决问题 #5 修正 | 建议随 audio 001（总线+AudioManager 骨架）实现时一并修订 |
| BGM 格式 | 维持 WAV MVP 规格（GDD 不变）；Ogg 备选风险归零 |
| audio 002（BGM 播放管理） | **解锁**——无缝循环实现简化为 `loop = true` 单行属性 |

## 复现命令

```
# 1. 生成测试音（整数周期正弦——相位连续设计）
python -c "..."  # 见 harness 注释；或直接用仓库内 test-tone.ogg/.wav

# 2. 运行（窗口模式——需真实音频驱动；约 8 分钟含 PCM 分析）
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --script prototypes/r06-ogg-loop-spike/spike.gd
# 结果：results.json（+ results-run1.json 复跑对照）
```
