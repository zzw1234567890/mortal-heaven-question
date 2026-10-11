# R-02 满场实测（stub 版）基准

combat-ui-layout 009b 基准——标准 + 峰值两场景 Draw Call 与帧时间采样。
复用 009a 的测量方法（`RenderingServer.get_rendering_info` + delta 基线 + 60 帧稳定均值）。

## 测试假设

- 标准场景（16 角色位 + 7 手牌 + 2 阵法 + 费用栏 + 日志折叠）DC ≤200
- 峰值场景（标准 + 结算面板 + 攻击箭头 stub + 阵法光环 + 飘字满发）DC ≤200
- 标准场景 p95 帧时间 ≤16.6ms（60fps）
- fallback 裁剪优先级在超预算时按序生效（日志→飘字→图标上限）——stub 版记录，实测未触发

## 运行方式（窗口模式——headless DC 不具代表性）

```bash
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --script prototypes/r02-fullfield-benchmark/benchmark.gd
```

## 状态

已结束——标准/峰值两场景 DC 与帧时间已采样，结果归档
`production/qa/evidence/r02-benchmark-evidence.md`。

## 发现（2026-10-11）

- 标准场景（净值）DC 与峰值场景 DC 均 ≤200——达标。
- 帧时间 p95 采样见 evidence；stub 版缩短采样时长（10s），完整 60s 归组件级复测。
- 实测后端沿用 009a 的 Vulkan Forward+（RTX 3050），D3D12 烟雾项与 720p 字号抽检
  为 ADVISORY 人工项——记录在 evidence 偏差节。
