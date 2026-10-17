# 스프라이트 규격

아바타는 레이어를 겹쳐 그린다. 실제 에셋은 같은 이름의 파일로 교체하면 되고, 코드는 고치지 않는다.

## 프레임과 시트

- 프레임은 32×32px 이다. 동작마다 프레임을 가로 한 줄로 이은 시트 하나를 쓴다. 시트 크기는 `(프레임 수 × 32) × 32` 이다.
- 투명 배경 PNG. 팔레트 제한은 없다.

| 동작 | 프레임 수 | fps |
|---|---|---|
| idle | 2 | 4 |
| walk | 4 | 6 |
| run | 4 | 10 |

## 레이어

아래에서 위 순서: `body`, `face`, `bottom`, `top`, `shoes`, `hat`, `accessory`. 페이즈 2는 `body`·`face` 만 쓴다.

- body: 외형 단계 1~4 (`stage1` ~ `stage4`). 단계가 오를수록 키가 커진다.
- face: 표정 `normal`·`sleepy`·`asleep`. face 는 종류마다 따로 있고, 한 종류 안에서는 4개 단계가 공유한다. 한 종류의 4개 단계는 머리·눈 위치를 같게 유지한다.

## 파일 이름

`assets/sprites/<종류>/<레이어>/<이름>_<동작>.png` (종류: `chick`·`jelly`·`acorn`, 결정 0011)

- 예: `chick/body/stage1_run.png`, `acorn/face/sleepy_idle.png`
- 경로는 `lib/avatar/ui/sprite_sheet.dart` 의 `bodySheet`·`faceSheet` 가 만든다.

## 기준점

모든 레이어가 같은 기준점을 쓴다. 발끝은 프레임 아래에서 2px 위(y=29)에 둔다. 레이어끼리 따로 어긋나지 않게 한다.

face 레이어는 4개 외형 단계가 모두 공유한다. 그래서 어느 단계의 body 든 머리·눈이 프레임 안에서 같은 위치에 있어야 한다 (실제 아트 교체 시 반드시 지킨다).

## 화면 표시

정수 배율로 키우고 `FilterQuality.none` 으로 그린다.

## 임시 스프라이트

`tool/gen_placeholder_sprites.dart` 가 단순 도형으로 만든 임시 파일이다. `fvm dart run tool/gen_placeholder_sprites.dart` 로 다시 만든다. 실제 에셋이 나오면 파일만 교체한다.
