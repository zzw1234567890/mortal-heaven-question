# Epic: 卡牌系统 (Card System)

> **Layer**: Core
> **GDD**: design/gdd/card-system.md
> **Architecture Module**: 数据基础设施 — Autoload #6
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories card-system`

## Overview

实现卡牌数据模型的 Template/Instance 分离架构——CardTemplate（Resource，持久化在磁盘）+ CardInstance（RefCounted，运行时实例）。支持 6 种卡牌类型（角色/功法/法宝/阵法/丹药/符箓）+ 5 级稀有度 + 5 种流派方向。提供 222 个模板文件的异步加载策略（防止启动卡顿）、收藏池管理（增删查）、以及 CardSystem 模板加载完成后触发 GSM.enable_validation(db) 激活流程。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0006: 卡牌数据模型 | Template/Instance 分离 + Resource 异步加载 + 插画字段扩展 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-001 | 卡牌数据模型——Template/Instance 分离的两层架构 | ADR-0006 ✅ |
| TR-card-002 | 222 个模板文件的异步加载策略——防止启动卡顿 | ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-system.md` are verified
- 全部 6 种卡牌类型的 Template 可正确序列化/反序列化
- 异步加载管线在 1000ms 内完成全部 222 个模板的加载（不阻塞主线程）

## Next Step

Run `/create-stories card-system` to break this epic into implementable stories.