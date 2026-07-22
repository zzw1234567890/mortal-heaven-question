
# 规则：密钥 / PII 编辑 (Secret / PII Redaction)

在持久化、记录或回显 **用户提供的内容**（配置文件、错误消息、验证输出、MCP 载荷、智能体返回数据、`docs/pending-confluence-updates.md` 条目）时，首先通过 `redactSecrets()` 运行。这是纵深防御 —— 不能替代通过 ACL 和预提交钩子将密钥排除在文件之外。

## 使用编辑工具 (Use a Redaction Utility)

将用户内容通过项目的编辑助手运行后再写入任何目标。此规则随 `open-spec-kit` CLI 一起提供，其自带的助手是 `redactSecrets()` —— 下面的导入相对于 **该 CLI 内部** 的调用模块，而不是可从任意项目导入的包：

```js
// open-spec-kit CLI only — adjust the path to your project's own helper
import { redactSecrets } from '../utils/redaction.js';
console.error(redactSecrets(message));
```

`redactSecrets(text)` 返回相同的文本，但每个可能是密钥的片段被替换为 `<REDACTED:XXXX***YYYY>`。非字符串输入直接通过。

如果您的项目没有这样的助手，原则仍然适用：绝不要记录原始的用户提供内容 —— 首先用高熵掩码覆盖（下面的算法是您可以移植的参考）。

## 适用场景 (Where This Applies)

- `console.log` / `console.error` / `console.warn` 在回显用户输入、环境值或已解析 YAML 的 CLI 命令中。
- 记录到 `docs/` 或 `specs/` 中文件的堆栈跟踪或诊断转储。
- 包含已解析的 brief.md / contracts.md / projects.yml 内容的错误消息（例如 Zod issue paths）。
- 追加到 `docs/pending-confluence-updates.md` 的通知 —— `payload` 字段可以包含带有任意内容的 MCP 响应。

## 不适用的场景 (Where It Does NOT Apply)

- 内部测试夹具（有意的）。测试使用字面高熵字符串来断言检测。
- 由 `NODE_ENV !== 'production'` 门控且不持久化到磁盘的调试日志。
- 仅引用字段名称而非值的模式验证错误路径。

## 检测算法 (Detection Algorithm)

带白名单的双阈值香农熵（参见 `cli/src/utils/redaction.js` JSDoc 以了解主要来源）：

| 字母表 | 最小长度 | 熵下限 | 备注 |
|--------------------------|-----------:|--------------:|-------|
| 仅十六进制 (`[a-fA-F0-9]`) | 20 | 3.0 bits/char | Gitleaks / detect-secrets `HexHighEntropyString` |
| Base64 类 | 20 | 4.5 bits/char | detect-secrets `Base64HighEntropyString` |

运行扫描器正则表达式排除 `=`，因此 `key=value` 行在赋值运算符处分词，掩码仅覆盖值。

### 白名单（高熵但安全）

- UUID v4 — 规范的 8-4-4-4-12 格式，版本 nibble 为 `4`。
- Git SHA — 7-40 个十六进制字符（覆盖短 SHA 和完整 SHA）。
- 数字 ID — 10-25 位数字（Snowflake、Confluence 页面 ID 等）。

### 已知限制

- 32 字符的十六进制 API 密钥与 git SHA 白名单冲突，**不会被**编辑。缓解措施：将此类密钥排除在此工具可访问的文件之外 —— `.env` 受 `windows-acl.js` (T0-2) 保护，CI 应通过 gitleaks 拒绝硬编码密钥。
- 填充前长度 ≤ 19 字符的裸 base64 字符串低于运行扫描器的最小值并被跳过。大多数密钥为 32+ 字符，因此这是一个小的假阴性。
- 带有 `=` 填充的 base64 字符串会从编辑范围中丢失填充（字母表排除 `=` 以用于片段提取）；掩码输出仍然保护密钥主体。

## 扩展白名单 (Extending the Whitelist)

当新的合法高熵标识符出现在您的项目中时，将其添加到 `cli/src/utils/redaction.js` 中的 `SAFE_PATTERNS`，并附带一个标识符来源的行内注释。在 `cli/tests/unit/redaction.test.js` 中至少添加一个正面测试和一个负面测试。

## 相关制品 (Related Artifacts)

- `cli/src/utils/redaction.js` — 实现
- `cli/tests/unit/redaction.test.js` — 测试
- `cli/src/utils/windows-acl.js` — T0-2 .env 权限（主要防御）
- `docs/decisions/ADR-003-untrusted-confluence-content.md` — T0-1 不可信输入边界（兼容：编辑在隔离后运行）
