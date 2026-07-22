
# Godot 动画 (Animation) — 快速参考

最近验证：2026-02-12 | 引擎：Godot 4.6

## 自 ~4.3（LLM 知识截止）以来的变化

### 4.6 变化
- **IK 系统完整恢复**：3D 骨骼的完整逆运动学 (Inverse Kinematics)
  - CCDIK、FABRIK、Jacobian IK、Spline IK、TwoBoneIK
  - 通过 `SkeletonModifier3D` 节点应用（而非旧的 IK 方式）
- **动画编辑器体验改进**：Bezier 节点组支持 Solo/hide/lock/delete；时间轴可拖动

### 4.5 变化
- **BoneConstraint3D**：通过修饰符将骨骼绑定到其他骨骼
  - `AimModifier3D`、`CopyTransformModifier3D`、`ConvertTransformModifier3D`

### 4.3 变化（已在训练数据中）
- **AnimationMixer**：AnimationPlayer 和 AnimationTree 的基类
  - `method_call_mode` → `callback_mode_method`
  - `playback_active` → `active`
  - `bone_pose_updated` 信号 → `skeleton_updated`
- **`Skeleton3D.add_bone()`**：现在返回 `int32`（原为 `void`）

## 当前 API 模式

### AnimationPlayer（API 不变，新增基类）
```gdscript
@onready var anim_player: AnimationPlayer = %AnimationPlayer

func play_attack() -> void:
    anim_player.play(&"attack")
    await anim_player.animation_finished
```

### IK 设置（4.6 — 新增）
```gdscript
# Add SkeletonModifier3D-based IK nodes as children of Skeleton3D
# Available types:
# - SkeletonModifiers3D (base)
# - TwoBoneIK (arms, legs)
# - FABRIK (chains, tentacles)
# - CCDIK (tails, spines)
# - Jacobian IK (complex multi-joint)
# - Spline IK (along curves)

# Configure in editor or code:
# 1. Add IK modifier node as child of Skeleton3D
# 2. Set target bone and tip bone
# 3. Add a Marker3D as the IK target
# 4. IK solver runs automatically each frame
```

### BoneConstraint3D（4.5 — 新增）
```gdscript
# Add as child of Skeleton3D
# Types:
# - AimModifier3D: Point bone at target
# - CopyTransformModifier3D: Mirror another bone's transform
# - ConvertTransformModifier3D: Remap transform values
```

### AnimationTree（基类在 4.3 变更）
```gdscript
# AnimationTree now extends AnimationMixer (not Node directly)
# Use AnimationMixer properties:
@onready var anim_tree: AnimationTree = %AnimationTree

func _ready() -> void:
    anim_tree.active = true  # NOT playback_active (deprecated 4.3)
```

## 常见错误
- 使用 `playback_active` 而非 `active`（自 4.3 起已弃用）
- 使用 `bone_pose_updated` 信号而非 `skeleton_updated`（在 4.3 重命名）
- 使用旧的 IK 方式而非 SkeletonModifier3D 系统（在 4.6 恢复）
- 在类型检查动画节点时未检查 `is AnimationMixer`
