---
name: main-menu-ql-review-2026-09
description: QL-STORY-READY 对 main-menu epic 5 story 分解的裁决（2026-09-07，全部 GAPS）及待用户裁决的阻塞问题清单
metadata:
  type: project
---

2026-09-07 我以 QA Lead 身份对 main-menu epic（5 stories，Sprint 13）执行 QL-STORY-READY full 审查，裁决全部 GAPS（无 ADEQUATE/INADEQUATE）。沿用 hud epic 先例标准（UI story 埋没确定性逻辑 → 提取 Logic 内核纯函数单测 BLOCKING）。

**Why:** 5 个 story 都正确提取了 Logic 内核（db_from_percent、冲突检测、分辨率回退、存档存在性），但存在 GDD 级规格矛盾和归属不清，不先裁决则测试用例写不出。

**How to apply:** 后续会话若涉及 main-menu story 实现或 /story-done，先确认以下 4 个阻塞裁决是否已解决：
1. 音量「实时变化」(AC-8) vs 设置「手动应用」(AC-13/调优参数)——音量持久化时机矛盾（Story 002 最大阻塞）
2. 恢复默认是全局按钮还是分类各自（GDD 原型图全局 vs story 分散；音量恢复默认无人认领）
3. 分辨率「可用列表」来源（Godot 4.6 DisplayServer 无直接枚举 API，需引擎参考验证或 spike）
4. EPIC.md DoD 写「18 条 AC」但 GDD 实为 22 条——计数不一致

其他已识别缺口：画质预设（低/中/高）具体映射未定义；全屏(是/否)与显示模式(窗口化)在 GDD 表格中重复；键位绑定启动加载/鼠标类动作绑定边缘未入 story；语言切换缺翻译资源管线说明；主菜单「上次：元婴期」存档摘要（UX spec main-menu.md）未入 Story 001 scope；音频 set_state(MAIN_MENU) 交互无人覆盖；音量总线布局（Master/Music/SFX）依赖 audio-manager epic 未声明。

相关：[[qa-lead-working-conventions]]
