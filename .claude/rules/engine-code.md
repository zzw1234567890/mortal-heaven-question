---
paths:
  - "src/core/**"
---


# 引擎代码规则 (Engine Code Rules)

- 热路径（更新循环、渲染、物理）中**零分配** —— 预分配、对象池、复用
- 所有引擎 API 必须是线程安全的，或明确文档化为仅单线程
- 每次优化**前后**都必须进行性能分析 —— 记录测量的数据
- 引擎代码**绝不能**依赖游戏玩法代码（严格的依赖方向：引擎 ← 玩法）
- 每个公共 API 必须在其文档注释中包含使用示例
- 公共接口的变更需要弃用期和迁移指南
- 对所有资源使用 RAII / 确定性清理
- 所有引擎系统必须支持优雅降级
- 在编写引擎 API 代码之前，查阅 `docs/engine-reference/` 以获取当前引擎版本，并对照参考文档验证 API

## 示例

**正确**（零分配热路径）：

```gdscript
# Pre-allocated array reused each frame
var _nearby_cache: Array[Node3D] = []

func _physics_process(delta: float) -> void:
    _nearby_cache.clear()  # Reuse, don't reallocate
    _spatial_grid.query_radius(position, radius, _nearby_cache)
```

**错误**（在热路径中分配）：

```gdscript
func _physics_process(delta: float) -> void:
    var nearby: Array[Node3D] = []  # VIOLATION: allocates every frame
    nearby = get_tree().get_nodes_in_group("enemies")  # VIOLATION: tree query every frame
```
