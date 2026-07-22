
# 钩子：pre-commit-design-check

## 触发器

在每次会修改 `design/` 或 `assets/data/` 中文件的提交之前运行。

## 目的

确保设计文档和游戏数据文件在进入版本控制之前保持一致性及完整性。在缺失章节、断裂的交叉引用和无效数据扩散之前将其捕获。

## 实现

```bash
#!/bin/bash
# 预提交钩子：设计文档和游戏数据验证
# 放置在 .git/hooks/pre-commit 或通过您的钩子管理器配置

DESIGN_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^design/')
DATA_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^assets/data/')

EXIT_CODE=0

# 检查设计文档的必需章节
if [ -n "$DESIGN_FILES" ]; then
    for file in $DESIGN_FILES; do
        if [[ "$file" == *.md ]]; then
            # 检查 GDD 文档中的必需章节
            if [[ "$file" == design/gdd/* ]]; then
                for section in "Overview" "Detailed" "Edge Cases" "Dependencies" "Acceptance Criteria"; do
                    if ! grep -qi "$section" "$file"; then
                        echo "错误：$file 缺少必需章节：$section"
                        EXIT_CODE=1
                    fi
                done
            fi
        fi
    done
fi

# 验证 JSON 数据文件
if [ -n "$DATA_FILES" ]; then
    for file in $DATA_FILES; do
        if [[ "$file" == *.json ]]; then
            # 查找可用的 Python 命令
            PYTHON_CMD=""
            for cmd in python python3 py; do
                if command -v "$cmd" >/dev/null 2>&1; then
                    PYTHON_CMD="$cmd"
                    break
                fi
            done
            if [ -n "$PYTHON_CMD" ] && ! "$PYTHON_CMD" -m json.tool "$file" > /dev/null 2>&1; then
                echo "错误：$file 不是有效的 JSON"
                EXIT_CODE=1
            fi
        fi
    done
fi

exit $EXIT_CODE
```

## 代理集成

当此钩子失败时，提交者应：
1. 设计章节缺失：调用 `game-designer` 代理来完成文档
2. JSON 无效：调用 `tools-programmer` 代理或手动修复
