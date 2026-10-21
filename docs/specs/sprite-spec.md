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
- hat·accessory: 상점 아이템(모자 `cap`·`beanie`·`straw_hat`, 소품 `sunglasses`·`headphones`·`flower_pin`). 아이템마다 종류별 그림이 있고, 한 종류 안에서는 4개 단계가 공유한다. 목록은 `lib/shop/domain/catalog.dart`.

## 파일 이름

`assets/sprites/<종류>/<레이어>/<이름>_<동작>.png` (종류: `chick`·`jelly`·`acorn`, 결정 0011)

- 예: `chick/body/stage1_run.png`, `acorn/face/sleepy_idle.png`, `jelly/hat/cap_walk.png`, `chick/accessory/sunglasses_idle.png`
- 아이템 레이어 폴더는 부위 이름(`hat`·`accessory`), 이름은 아이템 id 다.
- 경로는 `lib/avatar/ui/sprite_sheet.dart` 의 `bodySheet`·`faceSheet`·`itemSheet` 가 만든다.

## 기준점

모든 레이어가 같은 기준점을 쓴다. 발끝은 프레임 아래에서 2px 위(y=29)에 둔다. 레이어끼리 따로 어긋나지 않게 한다.

face 레이어는 4개 외형 단계가 모두 공유한다. 그래서 어느 단계의 body 든 머리·눈이 프레임 안에서 같은 위치에 있어야 한다 (실제 아트 교체 시 반드시 지킨다).

아이템 레이어도 face 와 같은 머리 오프셋으로 프레임마다 위아래로 움직인다. 종류마다 기준점 두 개를 둔다.

| 종류 | 모자 기준점 | 소품 기준점 |
|---|---|---|
| chick | 가로 가운데 x=16, 챙 아랫줄 y=18 | x=16, 눈 윗줄 y=20 |
| jelly | x=16, y=18 | x=16, y=20 |
| acorn | x=16, y=17 (도토리 모자 아랫줄) | x=16, y=20 |

- 모자는 눈(y=20·21)을 가리지 않는다.
- 4단계 헤어밴드(y=18)는 모자에 가려도 된다.

## 화면 표시

정수 배율로 키우고 `FilterQuality.none` 으로 그린다.

## 만드는 방법

그림은 코드 안의 데이터다(작업 9, 페이즈 6 실제 아트 전까지).

- `tool/sprites/<kind>.dart` (chick·jelly·acorn): 단계별 기본 그림(몸 + 장비, 눈 없음)과 표정 그림. 한 글자가 한 픽셀이고 색은 `tool/sprites/pet_art.dart` 의 팔레트에서 찾는다.
- `tool/sprites/pet_art.dart`: 자세표로 기본 그림에서 idle·walk·run 프레임을 만든다. 머리가 움직인 만큼 face 프레임도 같이 움직이므로 4단계가 face 를 함께 쓸 수 있다. 1단계 알(병아리)은 걷기·달리기 대신 통통 튄다.
- 장비(결정 0013): 1단계 없음, 2단계 러닝화, 3단계 + 손목 밴드, 4단계 + 헤어밴드 + 완주 메달.
- `tool/sprites/items.dart`: 아이템 그림 6장. 그림 한 장을 종류의 기준점(`PetKind.hatAnchor`·`accessoryAnchor`)에 가운데 맞춰 놓는다.
- 다시 만들기: `fvm dart run tool/render_sprites.dart` — 아래 파일을 쓴다.
  - `assets/sprites/**` 시트
  - `design/character/<kind>.png` 8배 미리보기: 줄 = 단계, 칸 = idle·walk·run 프레임, 마지막 줄 = 표정
  - `design/character/items.png` 8배 아이템 미리보기: 줄 = 아이템 없음 + 아이템 6개, 칸 = 종류 3 × 단계 1~4
- 검사: `test/tool/sprite_data_test.dart`
  - 프레임 형식, face 가 4단계 몸 위에 있음, 프레임끼리 다름, 발끝 y=29·공중 y=28, 단계별 장비
  - 아이템 프레임 형식, 아이템 세로 이동 = face 세로 이동, 모자가 face 를 가리지 않음
