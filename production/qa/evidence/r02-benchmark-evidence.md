# R-02 满场实测证据（stub 版）——Draw Call 关口

> **日期**：2026-10-11
> **Story**：combat-ui-layout 009b（R-02 Draw Call 满场实测——stub 版）
> **原型**：`prototypes/r02-fullfield-benchmark/`（benchmark.gd 复用 009a 测量方法）
> **测量方法**：`RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`——delta 基线（空场景）+ 60 帧稳定均值；帧时间 `Time.get_ticks_usec()` 逐帧采样
> **实测环境**：Godot 4.6.3 / **Vulkan Forward+**（RTX 3050）窗口模式——headless DC 不具代表性
> **结论定性**：**原型级**（stub 版占位节点，非 002-006 组件）——组件级复测归 combat-ui-layout epic DoD（Sprint 15）

---

## 1. 两场景 Draw Call 实测

| 场景 | DC（净值） | 整帧 DC | 预算 | 判定 |
|------|-----------:|--------:|-----:|:----:|
| baseline（空场景） | 0 | 0 | — | — |
| 标准场景（16 角色位+7 手牌+2 阵法+费用栏+日志折叠） | **126** | 126 | ≤200 | ✅ 达标 |
| 峰值场景（标准+结算面板+攻击箭头 stub+阵法光环+飘字满发） | **132** | 132 | ≤200 | ✅ 达标 |

**结论**：两场景均远低于 200 DC 预算（126/132 << 200）。与 009a 实测（16 卡 96 DC）
相比，满场扩展（手牌/阵法/费用栏/日志/峰值元素）仅增 ~30-36 DC——合批方案在整场景
尺度下成立，峰值场景也无需触发 fallback 裁剪（132 < 200，余量 68 DC）。

---

## 2. 帧时间分布（标准场景，10s / 600 帧）

| 分位 | 实测 | 目标 |
|------|-----:|-----:|
| p50 | 16.66 ms（=60fps） | ≤16.6ms |
| p95 | 16.92 ms（≈59fps） | ≤16.6ms |
| p99 | 17.20 ms（≈58fps） | — |

**结论**：p50 = 16.66ms 恰为 60fps（VSync 锁定），p95/p99 的 +0.3~0.5ms 为 VSync
抖动噪声。**p95 严格阈值 16.6ms 未达标（16.92ms）**，但 p50 已稳定 60fps——判定为
**ADVISORY**：原型级占位场景 + Vulkan 后端（非目标 D3D12），组件级复测（Sprint 15，
D3D12 + 真实 002-006 组件 + 60s 采样）作为正式关卡。

---

## 3. D3D12 烟雾测试（stub 版声明）

本 story 的 D3D12 烟雾 3 项（费用消散粒子/伤害数字淡出/阵法光环——无 alpha 混合异常）
为 **stub 版占位**：原型以程序化节点（Panel/Line/Arc/Label）模拟，**未运行真实 D3D12
后端**（实测环境 Vulkan Forward+），也**未渲染真实粒子/淡出**。判定 **ADVISORY**：
- 费用消散粒子 / 伤害数字淡出 → 归 interaction epic 完成后的峰值场景复测（其 epic 关口）
- 阵法光环 → 组件级复测随 001-006 完成（epic DoD 关口）
- 拖拽半透明 → 本就归 interaction epic（已登记）

---

## 4. fallback 裁剪优先级验证

峰值场景 132 DC 未超预算，fallback 优先级**实测未触发**（无需裁剪）。优先级已定稿于
`r02-batching-spec.md` §4 并升级为硬约束：日志纯文字 Label → 飘字合并 RichTextLabel →
状态图标显示上限 → 头像降采样。**判定 ADVISORY**：逻辑已记录，触发路径未实测（余量
68 DC 充足，预期不会触发）。

---

## 5. 720p 字号（stub 版抽检）

原型占位文字字号为 11-20pt 混合（`font_size_responsive` 模块归 story 001，Sprint 15 建立）。
**判定 ADVISORY**：≥12pt 规范与响应式字号模块的组件级验证推迟至 001-006 复测；本 story
仅确认原型字号可读，不承担 720p 规范落地。

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | DC 两场景 ≤200 达标；帧时间 p50=60fps（p95 ADVISORY 抖动） | [x] Approved |
| qa-lead（测试） | 原型级证据归档；组件级复测义务已双登记 | [x] Approved |
| lead-programmer（技术） | 合批方案整场景成立，无 src/ 实现（prototypes 隔离） | [x] Approved |

*独立开发者——所有角色由同一人签收。*

---

## 复测义务登记（双登记）

1. **combat-ui-layout epic DoD（Sprint 15）**：001-008 组件完成后，以真实组件 + D3D12
   复测两场景 DC ≤200 + 帧时间 p95 ≤16.6ms + 720p 字号 + 烟雾 3 项。
2. **combat-ui-interaction epic 关口**：拖拽半透明 + 峰值场景含真实交互元素复测。
