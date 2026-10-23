#!/usr/bin/env python3
"""예시 백업(러닝 33회, Lv.9, 코인 315, 배지 9)을 캐릭터 3종으로 만든다.

기준 파일 `demo-base.json` 은 앱 설정 › 내보내기로 만든 7판 이전(6판) 백업이고,
러닝·구간·경로·경험치·코인·배지는 게임 규칙(docs/specs/game-rules.md)대로 계산한 값이다.
이 스크립트는 아바타 종류·이름만 바꿔 `demo-chick.json`·`demo-jelly.json`·`demo-acorn.json` 을 쓴다.
모자·소품은 장착하지 않는다.

사용: python3 tool/capture/make_demo_backups.py [출력 폴더(기본 /tmp)]
그다음 adb push 로 /sdcard/Download 에 넣고 설정 › 가져오기로 고른다.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[1] if len(sys.argv) > 1 else '/tmp'
base = json.load(open(os.path.join(HERE, 'demo-base.json')))
for kind, name in [('chick', '삐약이'), ('jelly', '말랑이'), ('acorn', '토리')]:
    d = json.loads(json.dumps(base))
    av = d['tables']['avatars'][0]
    av.update(kind=kind, name=name, hatItemId=None, accessoryItemId=None)
    path = os.path.join(out, f'demo-{kind}.json')
    json.dump(d, open(path, 'w'), ensure_ascii=False)
    print(path)
