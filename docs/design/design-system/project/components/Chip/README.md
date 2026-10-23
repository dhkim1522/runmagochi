# Chip

높이 48 알약 선택 칩. 분할 선택(거리·시간)과 목표 칩이 같은 모양·같은 선택 표시를 쓴다.

- 선택 안 됨: `surface-soft` 바탕, `ink` 글자 17/700.
- 선택됨: `primary` 바탕 + 체크 아이콘 + `elevation-float`(경계선 없음), `on-primary` 글자 17/800. 체크가 색 말고 선택을 알린다.
- 선택 표시는 이것 하나다. 검은 알약(`panel`)은 탭바 선택에만.
- 바뀔 때 `duration-quick` 160ms, `curve-standard`.
