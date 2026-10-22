#!/usr/bin/env python3
r"""앱 글꼴(Pretendard 가변)을 앱에 필요한 글자만 남긴 서브셋으로 만든다(작업 17).

실행 (저장소 루트에서, fonttools 는 저장소의 .venv/ 에 둔다. .venv/ 는 gitignore 됨):

  macOS·Linux
    python3 -m venv .venv
    .venv/bin/pip install fonttools==4.67.0
    .venv/bin/python tool/subset_fonts.py

  Windows (PowerShell)
    py -m venv .venv
    .venv\Scripts\pip install fonttools==4.67.0
    .venv\Scripts\python tool\subset_fonts.py

하는 일
  1. 글자 목록을 모아 tool/font_chars.txt 에 쓴다.
     KS X 1001 한글 2,350자 + 한글 호환 자모 + 영문·숫자(ASCII)·Latin-1 + 자주 쓰는 기호
     + lib/**.dart 에 나오는 모든 글자(문자열 리터럴·알림·음성 문구를 포함하도록 파일 전체를 본다).
  2. 원본 전체 글꼴 tool/fonts/PretendardVariable.ttf 를 이 목록으로 서브셋해
     assets/fonts/RunmagochiSans.ttf 에 쓴다. 굵기 축(wght)·글리프 변형·조판 기능(tnum 등)은 유지한다.
  3. OFL 3조(Reserved Font Name "Pretendard")에 따라 서브셋 글꼴 내부 이름을 Runmagochi Sans 로 바꾼다.
     저작권·라이선스·제작자 정보는 그대로 둔다. 파일 이름과 앱의 family 이름(pubspec)도 RunmagochiSans 다.

lib 문구에 새 글자를 쓰면 test/tool/font_chars_test.dart 가 실패한다. 그때 이 스크립트를 다시 실행한다.
"""

import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tool/fonts/PretendardVariable.ttf"
TARGET = ROOT / "assets/fonts/RunmagochiSans.ttf"
CHARS = ROOT / "tool/font_chars.txt"

NEW_FAMILY = "Runmagochi Sans"
NEW_PS = "RunmagochiSans"
# 출처를 밝히는 이름은 그대로 둔다: 저작권·상표·제작사·디자이너·설명·URL·라이선스.
CREDIT_NAME_IDS = {0, 7, 8, 9, 10, 11, 12, 13, 14}
DESCRIPTION = (
    "Subset of Pretendard 1.3.9 (Kil Hyung-jin, SIL OFL 1.1) for the Runmagochi app: "
    "KS X 1001 Hangul, Latin and the characters used in the app. "
    "Renamed under OFL condition 3 (Reserved Font Name Pretendard)."
)

# 자주 쓰는 기호. 원본에 없는 것은 빠진다(필수 아님).
SYMBOLS = (
    " ­"  # 줄바꿈 없는 공백, 소프트 하이픈
    "​‌‍⁠﻿"  # 폭 없는 공백·결합자. U+2060 은 lib/core/korean.dart 가 쓴다
    "‐‑‒–—―‘’‚“”„†‡•…‰′″‹›※‼⁇⁈⁉"
    "₩€℃™←↑→↓↔−∞≈≠≤≥"
    "■□▲△▶▷▼▽◀◁◆◇○●◎★☆♡♥✓✔"
    "、。〈〉《》「」『』【】〔〕〜"
)


def ks_x_1001_hangul():
    """KS X 1001(EUC-KR) 완성형 한글 2,350자: 상위 바이트 0xB0~0xC8, 하위 0xA1~0xFE."""
    out = {bytes([hi, lo]).decode("euc-kr") for hi in range(0xB0, 0xC9) for lo in range(0xA1, 0xFF)}
    assert len(out) == 2350, len(out)
    return out


def lib_chars():
    """lib/**.dart 에 나오는 글자. 제어 문자는 빼고 \\uXXXX·\\u{X} 이스케이프는 실제 글자로 더한다.

    test/tool/font_chars_test.dart 의 libRunes() 와 같은 규칙이다.
    """
    escape = re.compile(r"\\u([0-9a-fA-F]{4})|\\u\{([0-9a-fA-F]{1,6})\}")
    out = set()
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        out |= {c for c in text if ord(c) >= 0x20}
        for m in escape.finditer(text):
            code = int(m.group(1) or m.group(2), 16)
            if code >= 0x20:
                out.add(chr(code))
    return out


def rename(font):
    """name 표에서 출처 정보를 뺀 이름의 Pretendard 를 새 이름으로 바꾼다."""
    name = font["name"]
    for rec in name.names:
        if rec.nameID in CREDIT_NAME_IDS:
            continue
        text = rec.toUnicode()
        new = (
            text.replace("Pretendard Variable", NEW_FAMILY)
            .replace("PretendardVariable", NEW_PS)
            .replace("Pretendard", NEW_FAMILY)
        )
        if rec.nameID == 3:
            new = f"{font['head'].fontRevision:.3f};subset;{NEW_PS}"
        if new != text:
            rec.string = new
    name.removeNames(nameID=10)
    name.setName(DESCRIPTION, 10, 3, 1, 0x409)


def main():
    source = TTFont(SOURCE, recalcTimestamp=False)
    cmap = source.getBestCmap()

    required = {chr(c) for c in range(0x20, 0x7F)} | ks_x_1001_hangul() | lib_chars()
    optional = {chr(c) for c in range(0xA0, 0x100)} | {chr(c) for c in range(0x3131, 0x318F)} | set(SYMBOLS)

    lacking = sorted(c for c in required if ord(c) not in cmap)
    if lacking:
        sys.exit("원본 글꼴에 없는 필수 글자: " + " ".join(f"U+{ord(c):04X}" for c in lacking))
    dropped = sorted(c for c in optional if ord(c) not in cmap)
    if dropped:
        print("원본에 없어 뺀 기호:", " ".join(f"U+{ord(c):04X}" for c in dropped))

    chars = sorted((required | optional) - set(dropped))
    lines = ["".join(chars[i : i + 64]) for i in range(0, len(chars), 64)]
    with open(CHARS, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(c) for c in chars])
    subsetter.subset(source)
    rename(source)
    source.save(TARGET)

    print(f"글자 {len(chars)}개 → {TARGET.relative_to(ROOT)} {TARGET.stat().st_size:,} B (원본 {SOURCE.stat().st_size:,} B)")


if __name__ == "__main__":
    main()
