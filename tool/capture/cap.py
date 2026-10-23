#!/usr/bin/env python3
"""화면설계서 촬영 보조 (에뮬레이터 adb). 사용은 tool/capture/README.md.

필요: Pillow, numpy (저장소 .venv 에 `pip install pillow numpy`).
  shot NAME            화면을 design/screens/NAME.png 로 저장
  tap TEXT [N]         화면 글자(text·content-desc 에 TEXT 포함)가 있는 N 번째 칸을 누른다
  tapxy X Y            좌표를 누른다
  hold X Y MS          좌표를 MS 밀리초 누른다
  swipe X1 Y1 X2 Y2 MS 끌기
  texts                화면에 보이는 글자 목록
  long NAME [--header PX] [--footer PX] [--max N]
                       천천히 끌어 내리며 찍어 이어 붙인다(NAME.png)
  importdemo KIND      설정 화면에서 예시 백업(chick|jelly|acorn)을 가져온다
  crop SRC DST X Y W H 잘라내기
  web NAME             design/screens/NAME.png → design/screens/web/NAME.png (폭 390)
"""
import io, os, re, subprocess, sys, time
import xml.etree.ElementTree as ET
from PIL import Image
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'design', 'screens')
ADB = os.environ.get('ADB') or os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')


def adb(*a, binary=False):
    r = subprocess.run([ADB, *a], capture_output=True)
    return r.stdout if binary else r.stdout.decode('utf-8', 'replace')


def grab():
    return Image.open(io.BytesIO(adb('exec-out', 'screencap', '-p', binary=True))).convert('RGB')


def nodes():
    adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml')
    root = ET.fromstring(adb('shell', 'cat', '/sdcard/ui.xml'))
    out = []
    for n in root.iter('node'):
        t = (n.get('text') or '') + '|' + (n.get('content-desc') or '')
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds'))
        x1, y1, x2, y2 = map(int, m.groups())
        out.append((t.strip('|'), (x1, y1, x2, y2), n.get('package')))
    return out


def find(text, nth=0):
    ns = [(t, b) for t, b, _ in nodes() if text in t and b[2] > b[0] and b[3] > b[1]]
    if len(ns) <= nth:
        raise SystemExit(f'글자 없음: {text}')
    # 글자가 정확히 같은 칸을 먼저, 그다음 작은 칸(안쪽 요소)
    ns.sort(key=lambda tb: (tb[0] != text, (tb[1][2] - tb[1][0]) * (tb[1][3] - tb[1][1])))
    return ns[nth][1]


def tapxy(x, y):
    adb('shell', 'input', 'tap', str(int(x)), str(int(y)))


def stitch(shots, header, footer):
    """끌어내리며 찍은 화면들을 이어 붙인다.

    다음 장의 r 행은 앞 장의 r + s 행이다. 겹치는 영역 전체를 비교해 s 를 찾는다.
    header 는 움직이지 않는 위쪽(상태 표시줄·고정 머리), footer 는 움직이지 않는 아래쪽(고정 버튼·탭바)이다.
    """
    h = shots[0].height
    gray = [np.asarray(x.convert('L')).astype(np.int16)[:, ::4] for x in shots]
    top = max(header, 300)  # 비교 영역의 위쪽
    parts = [shots[0].crop((0, 0, shots[0].width, h - footer))]
    for i in range(1, len(shots)):
        prev, cur = gray[i - 1], gray[i]
        best, best_err, best_score = None, 1e18, 1e18
        for s_ in range(60, h - footer - top - 200):
            n = h - footer - s_ - top  # 겹치는 행 수
            # 평균 절대 오차(움직이는 캐릭터는 작은 오차로만 남는다)
            err = np.abs(cur[top:top + n] - prev[top + s_:top + s_ + n]).mean()
            score = err + abs(s_ - 960) * 1e-3  # 평평한 바탕이면 끌어낸 거리(약 960)에 가까운 쪽
            if best is None or score < best_score:
                best, best_err, best_score = s_, err, score
        if best is None or best_err > 6:
            print('겹침 못 찾음', i, best_err)
            break
        print('이어 붙임', i, '이동', best, '오차', round(float(best_err), 2))
        last = i == len(shots) - 1
        cur_from = h - footer - best
        cur_to = h if last else h - footer
        parts.append(shots[i].crop((0, cur_from, shots[i].width, cur_to)))
    W = shots[0].width
    H = sum(p.height for p in parts)
    img = Image.new('RGB', (W, H))
    y = 0
    for p in parts:
        img.paste(p, (0, y))
        y += p.height
    return img


def main():
    a = sys.argv[1:]
    cmd = a[0]
    if cmd == 'shot':
        grab().save(os.path.join(OUT, a[1] + '.png'))
    elif cmd == 'tap':
        x1, y1, x2, y2 = find(a[1], int(a[2]) if len(a) > 2 else 0)
        tapxy((x1 + x2) / 2, (y1 + y2) / 2)
    elif cmd == 'tapxy':
        tapxy(a[1], a[2])
    elif cmd == 'hold':
        adb('shell', 'input', 'swipe', a[1], a[2], a[1], a[2], a[3])
    elif cmd == 'swipe':
        adb('shell', 'input', 'swipe', *a[1:6])
    elif cmd == 'texts':
        for t, b, p in nodes():
            if t and p == 'com.dhkim1522.runmagochi':
                print(b, t)
    elif cmd == 'long':
        name = a[1]
        header = int(a[a.index('--header') + 1]) if '--header' in a else 0
        footer = int(a[a.index('--footer') + 1]) if '--footer' in a else 0
        mx = int(a[a.index('--max') + 1]) if '--max' in a else 8
        for _ in range(6):  # 맨 위로
            adb('shell', 'input', 'swipe', '540', '600', '540', '2000', '150')
        time.sleep(1)
        shots = [grab()]
        for _ in range(mx):
            adb('shell', 'input', 'swipe', '540', '1700', '540', '700', '1800')  # 느린 끌기(관성 없음)
            time.sleep(0.8)
            s = grab()
            if np.abs(np.asarray(s).astype(np.int16) - np.asarray(shots[-1]).astype(np.int16)).mean() < 0.05:
                break
            shots.append(s)
        stitch(shots, header, footer).save(os.path.join(OUT, name + '.png'))
        print(name, len(shots), '장')
    elif cmd == 'importdemo':  # 설정 화면에서: 가져오기 › 확인 › 파일 고르기 (a[1]=chick|jelly|acorn)
        for _ in range(2):
            x1, y1, x2, y2 = find('가져오기')
            tapxy((x1 + x2) / 2, (y1 + y2) / 2)
            time.sleep(1.5)
        x1, y1, x2, y2 = find(f'demo-{a[1]}.json')
        tapxy((x1 + x2) / 2, (y1 + y2) / 2)
        time.sleep(4)
    elif cmd == 'crop':
        Image.open(a[1]).crop((int(a[3]), int(a[4]), int(a[3]) + int(a[5]), int(a[4]) + int(a[6]))).save(a[2])
    elif cmd == 'web':
        im = Image.open(os.path.join(OUT, a[1] + '.png'))
        w = 390
        im.resize((w, round(im.height * w / im.width)), Image.LANCZOS).save(
            os.path.join(OUT, 'web', a[1] + '.png'), optimize=True)
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
