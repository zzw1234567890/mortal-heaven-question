# QA 缺陷登记（bugs/）

**用途**：Sprint 17 QA 签收条件 5 —— 建立缺陷通道。走查中任何 FAIL 项在此落盘为
`BUG-NNN-short-slug.md`，编号自 `BUG-001` 起**单调递增、不复用**（即使缺陷被关闭或
标记 invalid，编号也不回收）。

## 文件命名

`BUG-NNN-<kebab-slug>.md`，例如 `BUG-001-node-graph-blur-frame-drop.md`。

## 缺陷报告模板

```markdown
# BUG-NNN：<一句话标题>

| 字段 | 值 |
|------|---|
| 发现日期 | YYYY-MM-DD |
| 发现者 | 角色（qa-lead / qa-tester / …） |
| 归属 story | `<story 文件路径>` |
| 严重性 | S1 / S2 / S3 / S4 |
| 状态 | open / in-progress / fixed / verified / invalid / wontfix |
| 证据位置 | 证据文档 + 条目号（如 `settlement-retreat-evidence.md` §2 #2） |

## 复现步骤

1. …
2. …
3. …

## 预期结果

…

## 实际结果

…

## 影响

（玩家可见影响 / 阻塞哪个 AC / 是否有 workaround）

## 处置

（修复提交 hash / 转技术债编号 / 判定为预期现象的理由）
```

## 严重性口径

| 级别 | 定义 | 处理 |
|------|------|------|
| **S1** | 崩溃、数据丢失、核心循环无法继续 | 立即阻断，不得推进阶段 |
| **S2** | 主路径功能不可用 / AC 未达成且无 workaround | 阻断签收 |
| **S3** | 次要功能异常 / 有 workaround / 视觉可辨识性问题 | 可带条件推进，须排期 |
| **S4** | 打磨项（措辞、间距、微动画） | 转 polish 待办 |

S1/S2 打开时 QA 裁决强制 **NOT APPROVED**（见 `/team-qa` 规则）。
