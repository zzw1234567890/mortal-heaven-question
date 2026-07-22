
# Unreal Engine — 版本参考


| 字段 | 值 |
|-------|-------|
| **Engine Version** | Unreal Engine 5.7 |
| **Release Date** | 2025 年 11 月 |
| **Project Pinned** | 2026-02-13 |
| **Last Docs Verified** | 2026-02-13 |
| **LLM Knowledge Cutoff** | 2025 年 5 月 |

## 知识空白警告

LLM 的训练数据可能仅覆盖 Unreal Engine 至 ~5.3 版本。5.4、5.5、5.6 和 5.7
引入了重大变更，模型对此并不知情。在建议任何 Unreal API 调用之前，务必先查阅本目录。

## 截止日期之后的版本时间线

| 版本 | 发布 | 风险等级 | 主题 |
|---------|---------|------------|-----------|
| 5.4 | ~2025 年中 | HIGH | Motion Design 工具、动画改进、PCG 增强 |
| 5.5 | ~2025 年 9 月 | HIGH | Megalights（百万级光源）、动画创作、MegaCity 演示 |
| 5.6 | ~2025 年 10 月 | MEDIUM | 性能优化、缺陷修复 |
| 5.7 | 2025 年 11 月 | HIGH | PCG 生产就绪、Substrate 生产就绪、AI 助手 |

## 从 UE 5.3 到 UE 5.7 的主要变更

### 破坏性变更
- **Substrate 材质系统 (Substrate Material System)**：新材质框架（取代旧版材质）
- **PCG (Procedural Content Generation)**：生产就绪，API 重大变更
- **Megalights**：新光照系统（百万级动态光源）
- **动画创作 (Animation Authoring)**：新绑定与动画工具
- **AI 助手 (AI Assistant)**：编辑器内 AI 指导（实验性）

### 新特性（截止日期之后）
- **Megalights**：大规模动态光照（百万级光源）
- **Substrate 材质**：生产就绪的模块化材质系统
- **PCG 框架**：程序化世界生成（5.7 起生产就绪）
- **增强虚拟制片 (Enhanced Virtual Production)**：MetaHuman 集成、更深入的 VP 工作流
- **动画改进**：更优的绑定、混合、程序化动画
- **AI 助手 (AI Assistant)**：编辑器内 AI 帮助（实验性）

### 已弃用的系统
- **旧版材质系统 (Legacy Material System)**：新项目请迁移至 Substrate
- **旧版 PCG API**：使用新的生产就绪 PCG API（5.7+）

## 已验证的来源

- 官方文档：https://docs.unrealengine.com/5.7/
- UE 5.7 发布说明：https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5-7-release-notes
- 5.7 新特性：https://dev.epicgames.com/documentation/en-us/unreal-engine/whats-new
- UE 5.7 公告：https://www.unrealengine.com/en-US/news/unreal-engine-5-7-is-now-available
- UE 5.5 博客：https://www.unrealengine.com/en-US/blog/unreal-engine-5-5-is-now-available
- 迁移指南：https://docs.unrealengine.com/5.7/en-US/upgrading-projects/
