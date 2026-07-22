---
paths:
  - "assets/data/**"
---


# 数据文件规则 (Data File Rules)

- 所有 JSON 文件必须是有效的 JSON —— 损坏的 JSON 会阻塞整个构建管线
- 文件命名：仅使用小写字母和下划线，遵循 `[system]_[name].json` 模式
- 每个数据文件必须有文档化的模式（JSON Schema 或相应设计文档中的说明）
- 数值必须包含注释或配套文档，解释数字的含义
- 使用一致的键命名：JSON 文件内使用 camelCase
- 没有孤立的数据条目 —— 每个条目必须被代码或其他数据文件引用
- 当进行破坏性模式更改时，对数据文件进行版本控制
- 为所有可选字段提供合理的默认值

## 示例

**正确**的命名和结构 (`combat_enemies.json`)：

```json
{
  "goblin": {
    "baseHealth": 50,
    "baseDamage": 8,
    "moveSpeed": 3.5,
    "lootTable": "loot_goblin_common"
  },
  "goblin_chief": {
    "baseHealth": 150,
    "baseDamage": 20,
    "moveSpeed": 2.8,
    "lootTable": "loot_goblin_rare"
  }
}
```

**错误** (`EnemyData.json`)：

```json
{
  "Goblin": { "hp": 50 }
}
```

违规项：大写文件名、大写键、缺少 `[system]_[name]` 模式、缺少必要字段。
