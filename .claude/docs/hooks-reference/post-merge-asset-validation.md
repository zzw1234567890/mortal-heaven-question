
# 钩子：合并后资源验证 (Hook: post-merge-asset-validation)

## 触发条件

在任意合并到 `develop` 或 `main` 分支且包含对 `assets/` 目录的更改后运行。

## 目的

验证合并分支中的所有资源是否符合命名约定、大小预算和格式要求。防止不合规的资源在集成分支上累积。

## 实现

```bash
#!/bin/bash
# Post-merge hook: Asset validation
# Checks merged assets against project standards

MERGED_ASSETS=$(git diff --name-only HEAD@{1} HEAD | grep -E '^assets/')

if [ -z "$MERGED_ASSETS" ]; then
    exit 0
fi

EXIT_CODE=0
WARNINGS=""

for file in $MERGED_ASSETS; do
    filename=$(basename "$file")

    # Check naming convention (lowercase with underscores)
    if echo "$filename" | grep -qE '[A-Z[:space:]-]'; then
        WARNINGS="$WARNINGS\nNAMING: $file -- must be lowercase with underscores"
        EXIT_CODE=1
    fi

    # Check texture sizes (must be power of 2)
    if [[ "$file" == *.png || "$file" == *.jpg ]]; then
        # Requires ImageMagick
        if command -v identify &> /dev/null; then
            dims=$(identify -format "%w %h" "$file" 2>/dev/null)
            if [ -n "$dims" ]; then
                w=$(echo "$dims" | cut -d' ' -f1)
                h=$(echo "$dims" | cut -d' ' -f2)
                if (( (w & (w-1)) != 0 || (h & (h-1)) != 0 )); then
                    WARNINGS="$WARNINGS\nSIZE: $file -- dimensions ${w}x${h} not power-of-2"
                fi
            fi
        fi
    fi

    # Check file size budgets
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ -n "$size" ]; then
        # Textures: max 4MB
        if [[ "$file" == assets/art/* ]] && [ "$size" -gt 4194304 ]; then
            WARNINGS="$WARNINGS\nBUDGET: $file -- ${size} bytes exceeds 4MB texture budget"
            EXIT_CODE=1
        fi
        # Audio: max 10MB for music, 512KB for SFX
        if [[ "$file" == assets/audio/sfx* ]] && [ "$size" -gt 524288 ]; then
            WARNINGS="$WARNINGS\nBUDGET: $file -- ${size} bytes exceeds 512KB SFX budget"
        fi
    fi
done

if [ -n "$WARNINGS" ]; then
    echo "=== Asset Validation Report ==="
    echo -e "$WARNINGS"
    echo "================================"
    echo "Run /asset-audit for a full report."
fi

exit $EXIT_CODE
```

## 代理集成 (Agent Integration)

当此钩子报告问题时：
1. 对于命名违规：手动修复或调用 `art-director`（美术总监）获取指导
2. 对于大小违规：调用 `technical-artist`（技术美术）获取优化建议
3. 如需完整审计：运行 `/asset-audit` 技能
