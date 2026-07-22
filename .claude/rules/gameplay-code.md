---
paths:
  - "src/gameplay/**"
---


# 游戏玩法代码规则 (Gameplay Code Rules)

- **所有**游戏数值**必须**来自外部配置/数据文件，**绝不**硬编码
- 对所有时间相关的计算使用增量时间 delta time（帧率无关性）
- **不**直接引用 UI 代码 —— 使用事件/信号进行跨系统通信
- 每个游戏玩法系统必须实现清晰的接口
- 状态机必须具有显式的转换表和文档化的状态
- 为所有游戏玩法逻辑编写单元测试 —— 将逻辑与表现分离
- 在代码注释中记录每个功能实现的是哪个设计文档
- 不使用静态单例来管理游戏状态 —— 使用依赖注入

## 示例

**正确**（数据驱动）：

```gdscript
var damage: float = config.get_value("combat", "base_damage", 10.0)
var speed: float = stats_resource.movement_speed * delta
```

**错误**（硬编码）：

```gdscript
var damage: float = 25.0   # VIOLATION: hardcoded gameplay value
var speed: float = 5.0      # VIOLATION: not from config, not using delta
```
