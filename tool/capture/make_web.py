#!/usr/bin/env python3
"""design/screens/*.png → design/screens/web/ 게시용 390px 사본과 무대 조각(stage-light·stage-dark)을 만든다.
사용: .venv/bin/python tool/capture/make_web.py [이름 ...]  (이름이 없으면 전부)
"""
import glob, os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'design', 'screens')
names = sys.argv[1:] or [os.path.basename(p)[:-4] for p in sorted(glob.glob(os.path.join(OUT, '*.png')))]
for n in names:
    im = Image.open(os.path.join(OUT, n + '.png'))
    im.resize((390, round(im.height * 390 / im.width)), Image.LANCZOS).save(os.path.join(OUT, 'web', n + '.png'), optimize=True)
# 홈 화면의 무대(사각 하늘+길) 조각. 부품 견본이 쓴다. 안드로이드 1080 폭 기준 위치.
for src, dst in [('06-home', 'stage-light'), ('40-dark-home', 'stage-dark')]:
    im = Image.open(os.path.join(OUT, src + '.png'))
    c = im.crop((52, 346, 52 + 976, 346 + 1136))
    c.resize((390, 454), Image.LANCZOS).save(os.path.join(OUT, 'web', dst + '.png'), optimize=True)
print(len(names), '장')
