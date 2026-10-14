# 关卡检查：presentation-layer-complete 里程碑（Sprint 14 后）

**日期**：2026-10-13
**检查者**：gate-check 技能
**类型**：里程碑关口检查（Production 阶段内——非阶段推进关卡；里程碑规划已从 2-3 冲刺修正至 3+，当前完成 Sprint 13+14 共 2 个）
**审查模式**：full（四位主管关卡已运行）

---

## 里程碑关口条件对照

**来源**：`production/milestones/presentation-layer-complete.md`

| # | 条件 | 状态 | 证据 |
|---|------|------|------|
| 1 | 7 个 Presentation 层 epic 全部 Complete | ❌ 0/7 | hud 5/8、main-menu 3/5、audio-manager 1/7、combat-ui-layout 2/10、combat-ui-interaction 0/9、exploration-ui 0/10、deck-editing-ui 0/7——**仍无任一 epic 完整** |
| 2a | R-01 双焦点 spike 关闭 | ✅ | 2026-09-08 spike 10/10 PASS，OQ-02 关闭 |
| 2b | R-02 Draw Call 基准（<200 且 60fps） | ◐ 有条件关闭 | 009b stub 实测标准 126/峰值 132 DC <<200，p50=60fps；**p95 微超 + Vulkan 后端（非目标 D3D12）+ 占位节点（非 002-006 组件）——原型级，组件级+interaction 双复测义务已登记** |
| 2c | R-05 节点图基准（缩放平移 60fps） | ❌ 开放 | exploration-ui 001 已排入 Sprint 15 must（S15-2，R-05 关闭前置） |
| 3 | ADR-0031 验证标准全部通过 | ◐ 部分 | 双焦点✅ / 暂停三态✅ / Autoload==25✅ / 零状态所有权·零轮询持续验证✅；**战斗满场（2b）/节点图（2c）/PersistentLayer 音频跨场景连续** 未验 |
| 4 | 6 个 UI GDD 验收标准 QA 验证 | ◐ 11/200 | hud 11 项已验（Sprint 13 QA）；其余 189 项未验——combat-ui 73 / exploration-ui 50 / audio 31 / main-menu 22 / deck-editing-ui 13 |
| 5 | 全流程可演示（主菜单→…→通关） | ❌ 未达成 | 仅主菜单段可达（启动→主菜单→设置面板）；身份选择/地图/节点图/战斗/结算/通关全未达 |

**Sprint 14 内推进**：main-menu 0→3/5、audio 0→1/7、combat-ui-layout 0→2/10；R-02 开放→有条件关闭；CI 无→上线；测试 2598→2723。**零回归**（2722/2723，TD-014 flaky 既有）。

## 质量检查

- [x] 测试套件全绿——2723 tests / 2722 passing / 1 pending（save_load 占位）/ 0 failing（Sprint 14 QA 2026-10-11）
- [x] QA 签收报告存在且 APPROVED WITH CONDITIONS（`production/epics/qa/story-001-sprint-14-qa.md`）
- [x] QA 计划存在（`production/qa/qa-plan-sprint-14-2026-09-13.md`）
- [x] CI 上线（`.github/workflows/tests.yml`）——Sprint 13 关卡遗留的条件 B 已兑现
- [x] 一致性失败日志无未解决条目（6 条全部 fixed）
- [x] 技术债稳定（2 TODO / 0 FIXME；TD-014 已登记 flaky，S15-1 根治）
- [x] 冒烟——最新 smoke-2026-09-11（Sprint 14 手动冒烟为 QA 条件 C，待编辑器演练）
- [?] realm test_ac010 flaky——TD-014 关联确认（Linux CI 两跑两红证据登记），根治归 S15-1

## 主管小组评估

**创意总监**：NOT READY
- 进度失控信号，非健康中途态。5 项关口 0 项达成，7 epic 无一个 Complete——收口尚未真正开始。轨迹 2-3→3+→5+ 冲刺两度翻倍是系统性估算失效（UI story 真实成本被低估约 2 倍）。R-05 仍开放；R-02 仅 stub 原型级弱关闭。最大瓶颈恰在核心：combat-ui 最滞后（interaction 0/9、layout 2/10）——卡牌游戏战斗即心脏却排最末。建议按支柱接近度重排（战斗 UI > 节点图/结算 > 探索/牌组编辑）、R-05 限期给关闭路径或正式降级、「全流程可演示」降级为「核心循环可演示」作为中间里程碑。

**技术总监**：CONCERNS
- 技术地基稳固（2723 测试 0 失败、CI 上线、四红线持续验证、技债仅 2 TODO），R-05 关闭路径清晰。两处关注：① TD-014 连续三冲刺结转——load_threaded 竞态是核心系统正确性 bug，flaky 侵蚀 CI 信任，应从「结转项」升 blocker 级处理；② R-02 未完全关闭——仅 Vulkan 后端复测、p95 微超帧预算，目标后端 D3D12 未验证。建议 TD-014 设 Sprint 15 must 硬截止；R-02 复测补 D3D12 测量并排查 p95 尖峰。

**制作人**：NOT READY（PR-MILESTONE）
- 进度可控但排期仍不诚实：「5+ 冲刺」与内部测算（剩余 45 故事 ≈70-80 工作日 ≈10-11 冲刺）自相矛盾，差约 2 倍。回顾已实证 UI story 真实成本 2 日历日/story，连续两冲刺低估是系统性误差。TD-014 三连结转 + should/nice 连续积压 = 容量触顶（93% 利用率、零缓冲），must 靠约 2 倍日历时间硬撑，不可持续——系统性容量问题：must 一直吃到真实容量 100%，技债与次要项被永久挤出。建议砍范围而非再延里程碑（deck-editing-ui 0/7、combat-ui-interaction 0/9、exploration-ui 0/10 拆出或降级）；关口拆两段（MVP 核心流可演示／full）；must 上限降回 80%（6d）+ 技债专属槽位；TD-014 本轮必须根治，否则设止损线。

**美术总监**：CONCERNS
- 视觉基础部分到位（UX 规范 5 项 Approved、HUD/主菜单证据签收），但两处性能风险证据链不充分：R-02 仅 stub 原型级（组件级复测延 S15）、R-05 仍开放。combat-ui-interaction/exploration-ui/deck-editing-ui 均 0 进度，缺一份「风格指南」作为调色板/材质/视觉层级单一真理来源，无法锚定后续 UI 一致性。建议 S15 前补风格指南；R-02 复测与 R-05 关闭列为阻塞项而非开放项。

## 裁决：FAIL（里程碑未达成——符合预期，非质量信号）

**判定依据**：关口条件 1（7 epic）0/7、条件 5（可演示）仅主菜单段——两项独立即足以 FAIL。与 Sprint 13 后检查（2026-09-13）相比：仍是「里程碑未完成」的事实陈述，Sprint 14 交付质量全优（零回归 +2723 测试 + CI 上线 + R-02 有条件关闭）。

**注意**：此 FAIL 不是「质量不达标」——Sprint 14 QA 为 APPROVED WITH CONDITIONS，must 8/8 全交付。它是「里程碑尚未完成」的预期中途结果。项目**不应**也**不需要**推进阶段（Production → Polish）——继续 Sprint 15 推进本里程碑。

### 验证链（Chain-of-Verification）：5 个问题已检查——裁决未变

1. **是否将 FAIL 条件过度软化？** 否——条件 1（7 epic）0 完整、条件 5 可演示性仅 1/7 段，两项独立即 FAIL。
2. **是否有遗漏的额外阻塞项？** [TOOL ACTION] 重扫质量检查：TD-014 flaky（条件 A）与主菜单 E2E 冒烟（条件 C）已在质量检查与 QA 遗留条件列出，非新阻塞。
3. **是否有误判为 FAIL 实为 CONCERNS 的项？** [TOOL ACTION] 重新验证 epic 完成度口径（grep Story Status: Complete 计数 hud 5/menu 3/audio 1/layout 2/interaction 0/exploration 0/deck 0）——口径正确。
4. **主管分歧如何处理？** 创意总监 NOT READY、制作人 NOT READY（PR-MILESTONE）与其余两位 CONCERNS 指向同一实质结论（里程碑收口未真正开始、排期不诚实），NOT READY 是范围仲裁裁决、CONCERNS 是技术/容量关切——无矛盾，方向一致（继续推进 + 砍范围/根治 TD-014）。
5. **通往 PASS 的最小路径？** Sprint 15：TD-014 根治（S15-1）+ exploration-ui 001 关 R-05（S15-2）+ combat-ui-layout 001/002 建 R-02 组件级复测核心单元（S15-3/4）；Sprint 16：layout 主体 003-008 + exploration 主体 + interaction 启动；Sprint 17：interaction + deck-editing-ui + 全流程演示收口。

## 建议行动

1. **范围仲裁（制作人 + 创意总监共识）**：Don't 仅延里程碑——在 Sprint 16 规划时按「支柱接近度」重排，评估将 deck-editing-ui（0/7）与 exploration-ui 后半拆出 presentation-layer-complete 或降级，将「全流程可演示」降级为「核心循环可演示」作为下一中间里程碑（提议由创意总监起草重排后的里程碑退出条件 ADR，producer 级联）。
2. **TD-014 根治设为 Sprint 15 硬关口**（技术总监 + 制作人）：S15-1 已排 must，闭环标准 = CI 连续两跑绿（非单次）；未解则升为表现层终验 blocker。
3. **R-05 限期关闭**（创意总监 + 美术总监）：S15-2（exploration-ui 001）为本里程碑 R-05 关闭前置；Sprint 15 末仍未关闭则正式裁决降级路径，不接受隐性拖尾。
4. **R-02 复测补 D3D12**（技术总监）：组件级复测义务加注 D3D12 后端测量 + p95 尖峰排查（非仅 Vulkan）。
5. **风格指南补齐**（美术总监）：Sprint 15 内建立 `design/art/` 风格指南单一真理来源，锚定剩余 UI epic 一致性。

## 结论文档修正（随本关卡检查待执行）

| 文件 | 修正 |
|------|------|
| production/milestones/presentation-layer-complete.md | 目标日期「2-3 冲刺」→「5+ 冲刺」（Sprint 15 规划已写，本检查后同步里程碑文件）；Epic 排期指引表补充 Sprint 15/16 实际承载 |
| design/art/ | 风格指南缺口——Sprint 15 补齐（美术总监建议） |