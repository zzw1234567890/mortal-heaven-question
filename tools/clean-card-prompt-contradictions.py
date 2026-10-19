# -*- coding: utf-8 -*-
"""清理 5 类卡牌 spec 的 MJ/SD 提示词残留矛盾（A + B 项）。

A: Midjourney --no 列表——移除 no background/no background scene/no scene/no landscape
   与 no color except ...（现允许淡彩），并去掉 token 前多余的 "no " 前缀（--no 本身即否定），
   追加「空背景 + 鲜艳」负向词，保留人物/部位负向词。
B: Stable Diffusion 反向提示——移除独立 token background/landscape/environment/no background/color
   （与「现在要背景 + 淡彩」矛盾），保留 pure white/empty/blank background（防留白）与
   person/human/figure 等抽象铁律负向词，补齐 colorful（防高饱和）。
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

MJ_ADD = [
    "empty background", "plain white background", "pure white background",
    "blank background", "vibrant colors", "saturated colors",
    "high saturation", "colorful",
]
MJ_DROP = {"no background", "no background scene", "no scene", "no landscape"}
SD_DROP = {"background", "landscape", "environment", "no background", "color"}


def _dedup(items):
    seen = set()
    out = []
    for it in items:
        if it.lower() not in seen:
            seen.add(it.lower())
            out.append(it)
    return out


def clean_mj(match):
    body = match.group(1)
    keep = []
    for raw in body.split(","):
        it = raw.strip()
        low = it.lower()
        if low.startswith("no color except"):
            break  # 之后全是旧「禁一切颜色」短语，整体丢弃
        if low in MJ_DROP:
            continue
        # 去掉 --no 内的冗余 "no " 前缀（--no 本身即否定）
        if low.startswith("no "):
            it = it[3:].strip()
        if it:
            keep.append(it)
    keep = _dedup(keep)
    keep.extend(MJ_ADD)
    return "--no " + ", ".join(keep)


def clean_sd_line(line):
    items = [x.strip() for x in line.split(",")]
    out = [it for it in items if it.lower() not in SD_DROP and it]
    out = _dedup(out)
    if "colorful" not in [x.lower() for x in out]:
        out.append("colorful")
    return ", ".join(out)


for name, rel in FILES.items():
    p = pathlib.Path(rel)
    text = p.read_text(encoding="utf-8")
    mj_before = text.count("--no ")
    text = re.sub(r"--no ([^\n]+)", clean_mj, text)
    mj_after = text.count("--no ")
    sd_before = len(re.findall(r"\*\*反向提示[^*]*\*\*\n[^\n]+", text))
    text = re.sub(
        r"(\*\*反向提示[^*]*\*\*\n)([^\n]+)",
        lambda m: m.group(1) + clean_sd_line(m.group(2)),
        text,
    )
    p.write_text(text, encoding="utf-8")
    print(f"{name}: MJ --no {mj_before} 处 / SD 反向 {sd_before} 处 已清理")
