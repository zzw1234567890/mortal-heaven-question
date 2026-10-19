# -*- coding: utf-8 -*-
"""对账 GDD 卡牌清单 vs spec 资产清单，输出精确差异（缺失/多余/错位）。"""
import re
import pathlib

GDD = pathlib.Path("design/gdd/card-system-design.md")
SPECS = {
    "功法": "design/assets/specs/card-system-techniques-assets.md",
    "法宝": "design/assets/specs/card-system-artifacts-assets.md",
    "丹药": "design/assets/specs/card-system-pills-assets.md",
    "符箓": "design/assets/specs/card-system-talismans-assets.md",
    "阵法": "design/assets/specs/card-system-formations-assets.md",
}
# GDD 段落标题 -> 类型
SECTION_MARKERS = [
    ("三、功法卡", "功法"),
    ("四、法宝卡", "法宝"),
    ("五、阵法卡", "阵法"),
    ("六、丹药卡", "丹药"),
    ("七、符箓卡", "符箓"),
]

gdd_text = GDD.read_text(encoding="utf-8")


def extract_gdd(section_title, next_title=None):
    """提取某段落表格第一列的卡名（跳过表头行与分隔行）。"""
    names = []
    start = gdd_text.index(section_title)
    end = gdd_text.index(next_title) if next_title and next_title in gdd_text else len(gdd_text)
    seg = gdd_text[start:end]
    for line in seg.splitlines():
        m = re.match(r"^\|\s*([^|]+?)\s*\|", line)
        if not m:
            continue
        name = m.group(1).strip()
        if not name or "名称" in name or set(name) <= {"-", ":"}:
            continue
        names.append(name)
    return names


def extract_spec(path):
    """提取 spec 中 ASSET 标题后的名称（去掉『（…视觉处理）』等说明性后缀，保留法宝括号）。"""
    text = pathlib.Path(path).read_text(encoding="utf-8")
    names = []
    for m in re.finditer(r"ASSET-\d+\s*—\s*(.+)", text):
        name = m.group(1).strip()
        names.append(name)
    return names


markers = dict(SECTION_MARKERS)
titles = [t for t, _ in SECTION_MARKERS]

for i, (title, typ) in enumerate(SECTION_MARKERS):
    next_title = titles[i + 1] if i + 1 < len(titles) else None
    gdd_names = extract_gdd(title, next_title)
    spec_names = extract_spec(SPECS[typ])
    gset = set(gdd_names)
    sset = set(spec_names)
    missing = sorted(gset - sset)          # GDD 有、spec 无
    extra = sorted(sset - gset)            # spec 有、GDD 无（含错位/重复）
    print(f"\n=== {typ} ===")
    print(f"GDD 列表 {len(gdd_names)} 张 | spec ASSET {len(spec_names)} 条")
    print(f"  缺失（GDD有/spec无）[{len(missing)}]: {missing}")
    print(f"  多余（spec有/GDD无）[{len(extra)}]: {extra}")
