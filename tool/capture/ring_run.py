#!/usr/bin/env python3
"""에뮬레이터 가상 GPS 로 물결 모양 고리 경로를 1초마다 보낸다(`adb emu geo fix`).

tool/fake_run.dart 는 직선이라 경로 그림이 곧은 선이 된다. 화면설계서 촬영용으로 고리 경로와
속도 변화(페이스 색 구분), 멈춤, 탈것 흉내(빠른 구간)를 넣을 수 있게 만들었다.

  ring_run.py --meters 3600 [--speed 4.2] [--wobble 0.9]
              [--stop-at 100 --stop-for 20]      그 초부터 그 시간 동안 제자리(자동 일시정지 확인)
              [--burst-at 200 --burst-for 40 --burst-speed 7.5]   탈것 의심 확인
              [--silent-after 300]               그 초부터 점을 보내지 않는다(신호 끊김)
진행은 ring_run.log 에 한 줄씩 `경과초 거리m` 로 남는다(촬영 시점 잡기용).
"""
import argparse, math, os, subprocess, sys, time

ADB = os.environ.get('ADB') or os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')
LAT0, LNG0 = 37.5260, 126.9240  # 여의도
M_LAT = 111320.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--meters', type=float, default=3600)
    ap.add_argument('--speed', type=float, default=4.2)
    ap.add_argument('--wobble', type=float, default=0.9, help='속도 변화 폭(m/s)')
    ap.add_argument('--radius', type=float, default=560)
    ap.add_argument('--stop-at', type=int)
    ap.add_argument('--stop-for', type=int, default=0)
    ap.add_argument('--burst-at', type=int)
    ap.add_argument('--burst-for', type=int, default=0)
    ap.add_argument('--burst-speed', type=float, default=7.5)
    ap.add_argument('--silent-after', type=int)
    ap.add_argument('--log', default=os.path.join(os.path.dirname(__file__), 'ring_run.log'))
    a = ap.parse_args()
    m_lng = M_LAT * math.cos(math.radians(LAT0))
    dist = 0.0   # 경로를 따라간 거리(탈것 구간 포함)
    t = 0
    log = open(a.log, 'w')
    while dist < a.meters:
        moving = not (a.stop_at is not None and a.stop_at <= t < a.stop_at + a.stop_for)
        burst = a.burst_at is not None and a.burst_at <= t < a.burst_at + a.burst_for
        if moving:
            v = a.burst_speed if burst else a.speed + a.wobble * math.sin(dist / 420.0)
            dist += v
        ang = dist / a.radius
        r = a.radius * (1 + 0.12 * math.sin(5 * ang))
        lat = LAT0 + r * math.sin(ang) / M_LAT
        lng = LNG0 + r * math.cos(ang) / m_lng
        silent = a.silent_after is not None and t >= a.silent_after
        if not silent:
            subprocess.run([ADB, 'emu', 'geo', 'fix', f'{lng:.6f}', f'{lat:.6f}'], capture_output=True)
        log.write(f'{t} {dist:.0f}\n'); log.flush()
        t += 1
        time.sleep(1)
    print('끝', t, '초', round(dist), 'm')


if __name__ == '__main__':
    main()
