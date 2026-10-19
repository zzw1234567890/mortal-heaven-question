# -*- coding: utf-8 -*-
"""修复 MJ --no 列表中残留的裸 token（background/scene/landscape/environment/color）。

前一轮清理只删除了「no background」等形式，漏掉了原始列表中已是裸词（如
`--no background, no person, ...`）的 background。这些裸词与「现在要背景 + 淡彩」
的新方向直接矛盾，需删除；但保留「empty/plain white/pure white/blank background」
与「vibrant/saturated colors/colorful」等防留白/防高饱和的负向词。
"""
import re
import pathlib

FILES = {
    "techniques": "design/assets/specs/card-system-techniques-assets.md",
    "artifacts": "design/assets/specs/card-system-artifacts-assets.md",
    "pills": "design/assets/specs/card-system-pills-assets.md",
    "talismans": "design/assets/specs/card-system-talismans-assets.md",
    "formations": "design/assets/specs/card-system-formations-assets.md",
}

DROP_BARE = {"background", "scene", "landscape", "environment", "color"}


def fix_mj(match):
    body = match.group(1)
    out = [x.strip() for x in body.split(",") if x.strip().lower() not in DROP_BARE and x.strip()]
    return "--no " + ", ".join(out)


for name, rel in FILES.items():
    p = pathlib.Path(rel)
    text = p.read_text(encoding="utf-8")
    before = text.count("--no ")
    text = re.sub(r"--no ([^\n]+)", fix_mj, text)
    p.write_text(text, encoding="utf-8")
    print(f"{name}: {before} 处 --no 已清理裸背景/色彩 token")
