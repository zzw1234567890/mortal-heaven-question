
# 技能测试规格：/tech-debt（技术债务）

## 技能概述（Skill Summary）

`/tech-debt` 跟踪、分类和优先处理跨代码库的技术债务（Technical Debt）。它读取 `docs/tech-debt-register.md` 获取现有债务登记表，并扫描 `src/` 中的源文件以查找行内的 `TODO` 和 `FIXME` 注释。它按严重程度合并和排序项目。不调用任何主管关卡（Director Gate）。该技能在更新前会询问"我可以写入 `docs/tech-debt-register.md` 吗？"。裁决结果（Verdict）：REGISTER UPDATED（登记表已更新）或 NO NEW DEBT FOUND（未发现新债务）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：REGISTER UPDATED、NO NEW DEBT FOUND
- [ ] 包含"May I write"用语（技能写入债务登记表）
- [ ] 具有下一步交接说明（登记表更新后的操作建议）

---

## 主管关卡检查（Director Gate Checks）

无。技术债务跟踪是一项内部代码库分析技能；不调用任何关卡。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 行内 TODO 与现有登记表项目合并

**测试夹具（Fixture）：**
- `docs/tech-debt-register.md` 存在，包含 2 个项目（严重程度 LOW 和 MEDIUM）
- `src/gameplay/combat.gd` 有 2 个 `# TODO` 注释和 1 个 `# FIXME` 注释
- `src/ui/hud.gd` 有 0 个行内债务注释

**输入：** `/tech-debt`

**预期行为：**
1. 技能读取 `docs/tech-debt-register.md` —— 发现 2 个现有项目
2. 技能扫描 `src/` —— 发现 3 个行内注释（2 个 TODO，1 个 FIXME）
3. 技能检查行内注释是否已存在于登记表中（去重）
4. 技能按严重程度排序展示合并列表（FIXME 默认排在 TODO 之前）
5. 技能询问"我可以写入 `docs/tech-debt-register.md` 吗？"
6. 用户批准；登记表更新；裁决结果为 REGISTER UPDATED

**断言：**
- [ ] 通过递归扫描 `src/` 发现行内注释
- [ ] 现有登记表项目不被重复
- [ ] 合并列表按严重程度排序
- [ ] 在任何写入之前出现"May I write"提示
- [ ] 裁决结果为 REGISTER UPDATED

---

### 用例 2：登记表不存在 —— 提供创建选项

**测试夹具：**
- `docs/tech-debt-register.md` 不存在
- `src/` 包含 4 个行内 TODO/FIXME 注释

**输入：** `/tech-debt`

**预期行为：**
1. 技能尝试读取 `docs/tech-debt-register.md` —— 未找到
2. 技能通知用户："未找到 tech-debt-register.md"
3. 技能主动提供使用找到的行内项目创建登记表
4. 技能询问"我可以写入 `docs/tech-debt-register.md` 吗？"（创建）
5. 用户批准；登记表创建完成，包含 4 个项目；裁决结果为 REGISTER UPDATED

**断言：**
- [ ] 当登记表文件不存在时，技能不崩溃
- [ ] 向用户提供创建登记表的选项（而非静默跳过）
- [ ] "May I write"提示反映的是文件创建（而非更新）
- [ ] 创建后裁决结果为 REGISTER UPDATED

---

### 用例 3：检测到已解决项目 —— 在登记表中标记为已解决

**测试夹具：**
- `docs/tech-debt-register.md` 有 3 个项目；其中一项引用了 `src/gameplay/legacy_input.gd`
- `src/gameplay/legacy_input.gd` 已被删除（重构移除）
- 引用的 TODO 注释在源码中不再存在

**输入：** `/tech-debt`

**预期行为：**
1. 技能读取登记表 —— 发现 3 个项目
2. 技能扫描 `src/` —— 未找到项目 2 引用的源位置
3. 技能将项目 2 标记为 RESOLVED（已解决）（源码已不存在）
4. 技能将已解决的项目呈现给用户进行确认
5. 经批准后，登记表更新，项目 2 标记为 `Status: Resolved`

**断言：**
- [ ] 技能检查每个登记表项目的源引用是否仍然存在
- [ ] 缺失的源位置导致项目被标记为 RESOLVED
- [ ] 用户在已解决项目被写入前进行确认
- [ ] RESOLVED 项目保留在登记表中（而非删除）以供审计追溯

---

### 用例 4：边界情况 —— CRITICAL 债务项目突出显示

**测试夹具：**
- `src/core/network_sync.gd` 有一条注释：`# FIXME(CRITICAL): race condition in sync buffer — can corrupt save data`
- `docs/tech-debt-register.md` 存在，包含 5 个较低严重程度的项目

**输入：** `/tech-debt`

**预期行为：**
1. 技能扫描源码并找到标记为 CRITICAL 的 FIXME
2. 技能将 CRITICAL 项目置于输出顶部 —— 在完整表格之前
3. 技能要求用户在处理前确认关键项目
4. 确认后，技能展示完整债务表并询问是否写入
5. 登记表更新，CRITICAL 项目位于顶部；裁决结果为 REGISTER UPDATED

**断言：**
- [ ] CRITICAL 项目出现在输出顶部，而非埋没在表格中
- [ ] 技能在询问写入前突出显示 CRITICAL 项目
- [ ] 请求用户确认 CRITICAL 项目
- [ ] CRITICAL 严重程度保留在写入的登记表条目中

---

### 用例 5：关卡合规性 —— 无关卡；仅经批准后方更新登记表

**测试夹具：**
- 行内扫描发现 2 个新的 TODO；登记表有 3 个现有项目
- `review-mode.txt` 包含 `full`

**输入：** `/tech-debt`

**预期行为：**
1. 技能扫描源码并读取登记表；编译合并的债务列表
2. 无论审核模式如何，均不调用任何主管关卡
3. 技能向用户展示排序后的债务表
4. 技能询问"我可以写入 `docs/tech-debt-register.md` 吗？"
5. 用户批准；登记表更新；裁决结果为 REGISTER UPDATED

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 债务表在任何写入提示之前展示
- [ ] 在文件更新前出现"May I write"提示
- [ ] 仅在用户明确批准后才进行写入

---

## 协议合规性（Protocol Compliance）

- [ ] 在编译前读取 `docs/tech-debt-register.md` 并扫描 `src/`
- [ ] 对行内注释与现有登记表项目进行去重
- [ ] 按严重程度对合并列表排序
- [ ] 在更新登记表前始终询问"May I write"
- [ ] 不调用任何主管关卡
- [ ] 裁决结果为 REGISTER UPDATED 或 NO NEW DEBT FOUND

---

## 覆盖范围说明（Coverage Notes）

- `src/` 为空或不存在的情况未进行测试；行内扫描的行为遵循 NO NEW DEBT FOUND 路径，但登记表项目仍会被读取和展示。
- 没有严重程度标签的 TODO 注释默认被视为 LOW 严重程度；此分类细节是实现问题，此处不进行测试。
