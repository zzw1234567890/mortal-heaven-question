# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 13 表现层 story 创建
Task: combat-ui-layout 10 stories 已写入；下一步 combat-ui-interaction /create-stories
<!-- /STATUS -->

## 当前任务

Sprint 13 表现层 story 创建推进中（2026-09-07）：

**已完成的 epic**：
- hud（8 stories，commit dcda76f + b622ff6）
- main-menu（5 stories，commit d3d6662）
- audio-manager（7 stories + hud story 008，commit b622ff6）
- **combat-ui-layout（10 stories，本次完成，未提交）**：
  - QL-STORY-READY（qa-lead）R1-R6 全部裁决（用户已批准）：
    - 顶部条组成按 UX（日志+阶段指示器+阵法区+暂停按钮转发 hud）；撤退按钮右上角独立常驻
    - 划界：面板视觉框架+状态判定纯函数+信号驱动渲染归 layout；输入锁栈+点击/拖拽流转+确认后系统 API 调用归 interaction（interaction EPIC.md Overview 已重写）
    - 阶段 0 指示器名=「准备」；渡劫 warning 在备战界面弹出（story 008 实现弹窗本体，story 007 备战面板）
    - >7 张手牌合成语义：间距优先+角度自适应（card_overlap_offset 求有效间距→压缩 arc_angle 使弦长匹配）——已写入 GDD 公式 2 后注释
    - 009 拆分前置：009a 合批方案定型（排在 002 之前）+ 009b 满场实测关口
    - font_size_responsive 等共享纯函数模块上移至 story 001；音频对接声明（set_state(IN_COMBAT)/阶段切换音/胜负音）
    - R-02 验证策略：DC 半自动化断言（本地关卡脚本不进 CI）、60fps advisory 人工签批、峰值场景 stub 版
  - GDD 修正 2 处（combat-ui-system.md 公式 2 合成语义+边界澄清 6 条）；UX 修正 2 处（combat-ui.md Boss 入口+导航路径）
  - 10 stories：001 布局骨架+共享纯函数/002 角色卡 L0-L5/003 标记阵亡飘字/004 顶部条/005 费用栏/006 手牌弧形（三纯函数）/007 备战面板（4 态+阵位映射）/008 结算撤退面板（0.5s 延迟+渡劫变体）/009a 合批定型/009b DC 实测关口
  - EPIC.md Stories 表+实现顺序提示（009a 在 002 前、009b 最后）已更新；index.md 已更新

## Git 状态

- b622ff6：audio-manager 7 stories + hud story 008（已提交）
- 工作树未提交：combat-ui-system.md + combat-ui.md（UX）+ interaction EPIC.md 划界修订 + combat-ui-layout EPIC.md + 10 stories + index.md + active.md

## 下一步

- 提交本批变更
- `/create-stories combat-ui-interaction`（下一 epic，R-01 双焦点关卡，交互侧——消费 layout 的面板框架与判定函数；含 009b 峰值场景复测关口）
- 后续：exploration-ui
- deck-editing-ui：须先 `/ux-design deck-editing-ui`
- Sprint 13 前置 spike（非 story）：R-01 双焦点、R-06 Ogg 循环间隙（各 0.5-1 天）

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
