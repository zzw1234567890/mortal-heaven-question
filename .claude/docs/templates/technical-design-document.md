
# 技术设计 (Technical Design)：[系统名称]

## 文档状态 (Document Status)
- **版本 (Version)**：1.0
- **最后更新 (Last Updated)**：[日期]
- **作者 (Author)**：[智能体/人员]
- **审查者 (Reviewer)**：lead-programmer
- **相关 ADR**：[ADR-XXXX（如适用）]
- **相关设计文档**：[链接到此技术设计所实现的游戏设计文档]

## 引擎接口层面 (Engine API Surface)

| 字段 | 值 |
|-------|-------|
| **引擎 (Engine)** | [例如 Godot 4.6 / Unity 6 / Unreal Engine 5.4] |
| **依赖的 API** | [使用的特定类/方法/节点，锁定版本 —— 例如 `CharacterBody3D.move_and_slide() (Godot 4.x)`] |
| **参考文档** | [编写本文档前查阅的引擎参考文档 —— 例如 `docs/engine-reference/godot/modules/physics.md`] |
| **使用的截止日期后特性** | [来自超出 LLM 训练截止日期的引擎版本的特性，或"无 (None)"] |
| **未经验证的假设** | [假定但尚未针对目标版本测试的 API 行为，或"无 (None)"] |
| **引擎升级风险** | [低 (LOW) / 中 (MEDIUM) / 高 (HIGH) —— 如果引擎版本变更，此设计的脆弱程度如何？] |

> **规则**：如果列出了任何**未经验证的假设 (Unverified Assumptions)**，则该文档在那些假设于实际引擎环境中得到验证之前，不能标记为"已接受 (Accepted)"。

## 概述 (Overview)
[2-3 句话总结此系统的作用及其存在原因]

## 需求 (Requirements)
### 功能需求 (Functional Requirements)
- [FR-1]：[描述]
- [FR-2]：[描述]

### 非功能需求 (Non-Functional Requirements)
- **性能 (Performance)**：[预算 —— 例如"每帧 < 1ms"]
- **内存 (Memory)**：[预算 —— 例如"峰值 < 50MB"]
- **可扩展性 (Scalability)**：[限制 —— 例如"支持最多 1000 个实体"]
- **线程安全 (Thread Safety)**：[要求]

## 架构 (Architecture)

### 系统图 (System Diagram)
```
[展示组件和数据流的 ASCII 图]
```

### 组件分解 (Component Breakdown)
| 组件 | 职责 | 拥有者 |
| --------- | -------------- | ---- |
| [名称] | [它的作用] | [它拥有的数据] |

### 公共 API (Public API)
```
[伪代码或目标语言中的接口/API 定义]
```

### 数据结构 (Data Structures)
```
[关键数据结构及字段描述]
```

### 数据流 (Data Flow)
[逐步说明：在典型帧中，数据如何在系统中流动]

## 实施计划 (Implementation Plan)

### 阶段 1 (Phase 1)：[核心功能]
- [ ] [任务 1]
- [ ] [任务 2]

### 阶段 2 (Phase 2)：[扩展功能]
- [ ] [任务 3]
- [ ] [任务 4]

### 阶段 3 (Phase 3)：[优化/打磨]
- [ ] [任务 5]

## 依赖关系 (Dependencies)
| 依赖项 | 用途 |
| ---------- | -------- |
| [系统] | [原因] |

| 被依赖项 | 用途 |
| -------------- | -------- |
| [系统] | [原因] |

## 测试策略 (Testing Strategy)
- **单元测试 (Unit Tests)**：[在单元层级测试的内容]
- **集成测试 (Integration Tests)**：[需要的跨系统测试]
- **性能测试 (Performance Tests)**：[需要创建的基准测试]
- **边界情况 (Edge Cases)**：[需要测试的特定场景]

## 已知限制 (Known Limitations)
[此设计有意不支持的内容及其原因]

## 未来考虑 (Future Considerations)
[如果需求演进，可能需要变更的内容 —— 但当前不要为此构建]
