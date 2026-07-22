
# Unreal Engine 5.7 — 音频模块参考


**最后验证：** 2026-02-13
**知识空白：** UE 5.7 MetaSounds 生产就绪

---

## 概述

UE 5.7 音频系统：
- **MetaSounds**：基于节点的程序化音频（推荐，生产就绪）
- **Sound Cue**：旧版基于节点的音频（用于简单场景）
- **Audio Component**：在 Actor 上播放声音

---

## 基础音频播放

### 在指定位置播放声音

```cpp
#include "Kismet/GameplayStatics.h"

// ✅ Play 2D sound (no spatialization)
UGameplayStatics::PlaySound2D(GetWorld(), ExplosionSound);

// ✅ Play sound at location (3D spatial audio)
UGameplayStatics::PlaySoundAtLocation(GetWorld(), ExplosionSound, GetActorLocation());

// ✅ With volume and pitch
UGameplayStatics::PlaySoundAtLocation(GetWorld(), ExplosionSound, GetActorLocation(), 0.7f, 1.2f);
```

---

## Audio Component

### Audio Component（持久声音）

```cpp
// Create audio component
UAudioComponent* AudioComp = CreateDefaultSubobject<UAudioComponent>(TEXT("Audio"));
AudioComp->SetupAttachment(RootComponent);
AudioComp->SetSound(LoopingAmbience);

// Play/Stop
AudioComp->Play();
AudioComp->Stop();

// Fade in/out
AudioComp->FadeIn(2.0f); // 2 seconds
AudioComp->FadeOut(1.5f, 0.0f); // 1.5s to volume 0

// Adjust volume/pitch
AudioComp->SetVolumeMultiplier(0.5f);
AudioComp->SetPitchMultiplier(1.2f);
```

---

## 3D 空间音频

### 衰减设置

```cpp
// Create Sound Attenuation asset:
// Content Browser > Sounds > Sound Attenuation

// Configure:
// - Attenuation Shape: Sphere, Capsule, Box, Cone
// - Falloff Distance: Distance where sound becomes inaudible
// - Attenuation Function: Linear, Logarithmic, Inverse, etc.

// Assign in C++:
AudioComp->AttenuationSettings = AttenuationAsset;
```

### 在代码中覆盖衰减

```cpp
FSoundAttenuationSettings AttenuationOverride;
AttenuationOverride.AttenuationShape = EAttenuationShape::Sphere;
AttenuationOverride.FalloffDistance = 1000.0f;
AttenuationOverride.AttenuationShapeExtents = FVector(1000.0f);

AudioComp->AttenuationOverrides = AttenuationOverride;
AudioComp->bOverrideAttenuation = true;
```

---

## MetaSounds（程序化音频）

### 创建 MetaSound Source

1. Content Browser > Sounds > MetaSound Source
2. 打开 MetaSound 编辑器
3. 构建节点图：
   - **输入**：触发器、参数
   - **生成器**：振荡器、噪声、采样
   - **调制器**：包络、LFO
   - **效果**：滤波器、混响、延迟
   - **输出**：音频输出

### 播放 MetaSound

```cpp
// Play MetaSound like any sound
UGameplayStatics::PlaySound2D(GetWorld(), MetaSoundSource);

// Or with Audio Component
AudioComp->SetSound(MetaSoundSource);
AudioComp->Play();
```

### 设置 MetaSound 参数

```cpp
// Define parameter in MetaSound (Input node with exposed parameter)
// Set parameter in C++:
AudioComp->SetFloatParameter(FName("Volume"), 0.8f);
AudioComp->SetIntParameter(FName("OctaveShift"), 2);
AudioComp->SetBoolParameter(FName("EnableReverb"), true);
```

---

## Sound Cue（旧版）

### 创建 Sound Cue

1. Content Browser > Sounds > Sound Cue
2. 打开 Sound Cue 编辑器
3. 添加节点：Random、Modulator、Mixer 等

### 使用 Sound Cue

```cpp
// Play like any sound
UGameplayStatics::PlaySound2D(GetWorld(), SoundCue);
```

---

## Sound Class 与 Sound Mix

### Sound Class（音量组）

```cpp
// Create Sound Class: Content Browser > Sounds > Sound Class
// Hierarchy: Master > Music, SFX, Dialogue

// Assign to sound asset:
// Sound Wave > Sound Class = SFX

// Set volume in C++:
UAudioSettings* AudioSettings = GetMutableDefault<UAudioSettings>();
// Configure via Sound Class hierarchy
```

### Sound Mix（动态混音）

```cpp
// Create Sound Mix asset
// Define adjustments: Lower music during dialogue, etc.

// Push sound mix
UGameplayStatics::PushSoundMixModifier(GetWorld(), DuckedMusicMix);

// Pop sound mix
UGameplayStatics::PopSoundMixModifier(GetWorld(), DuckedMusicMix);
```

---

## 音频遮挡与混响

### 音频遮挡（墙壁阻挡声音）

```cpp
// Enable in Audio Component:
AudioComp->bEnableOcclusion = true;

// Requires geometry with collision
```

### 混响体积

```cpp
// Add Audio Volume to level (Volumes > Audio Volume)
// Configure reverb settings in Details panel
// Audio component automatically picks up reverb when inside volume
```

---

## 常见模式

### 脚步声（随机变化）

```cpp
// Use Sound Cue with Random node, or:
UPROPERTY(EditAnywhere, Category = "Audio")
TArray<TObjectPtr<USoundBase>> FootstepSounds;

void PlayFootstep() {
    int32 Index = FMath::RandRange(0, FootstepSounds.Num() - 1);
    UGameplayStatics::PlaySoundAtLocation(GetWorld(), FootstepSounds[Index], GetActorLocation());
}
```

### 音乐交叉淡入淡出

```cpp
UAudioComponent* MusicA;
UAudioComponent* MusicB;

void CrossfadeMusic(float Duration) {
    MusicA->FadeOut(Duration, 0.0f);
    MusicB->FadeIn(Duration);
}
```

### 检查声音是否正在播放

```cpp
if (AudioComp->IsPlaying()) {
    // Sound is playing
}
```

---

## 音频并发

### 限制并发声音

```cpp
// Create Sound Concurrency asset:
// Content Browser > Sounds > Sound Concurrency

// Configure:
// - Max Count: Maximum instances of this sound
// - Resolution Rule: Stop Oldest, Stop Quietest, etc.

// Assign to sound:
// Sound Wave > Concurrency Settings
```

---

## 性能提示

### 音频优化

```cpp
// Compression settings (Sound Wave asset):
// - Compression Quality: 40 (balance quality/size)
// - Streaming: Enable for large files (music)

// Reduce audio mixing cost:
// - Limit concurrent sounds via Sound Concurrency
// - Use simple attenuation shapes

// Disable audio for distant actors:
if (Distance > MaxAudibleDistance) {
    AudioComp->Stop();
}
```

---

## 调试

### 音频调试命令

```cpp
// Console commands:
// au.Debug.Sounds 1 - Show active sounds
// au.3dVisualize.Enabled 1 - Visualize 3D audio
// stat soundwaves - Show sound statistics
// stat soundmixes - Show active sound mixes
```

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/audio-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/metasounds-in-unreal-engine/
