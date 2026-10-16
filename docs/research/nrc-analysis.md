# Nike Run Club Android 기술 구조 분석

> Nike Run Club 4.80.0 (Android) 의 기술 스택과 러닝 기록 구조를 정적 분석으로 파악한 참고 자료. 코드 재사용 X, 구조 참고용.

- 대상: `com.nike.plusgps` 4.80.0, Play Store 설치본 (`nrc-4.80.0.apk`, SHA-256 `108062736b24…4854`)
- 방법: APK 매니페스트와 DEX 클래스 이름 목록 (약 9.7만 개) 집계. 앱 실행 X, 코드 복원 X

## 핵심 결론

- **플랫폼별 네이티브 개발** — Android 는 Kotlin + Jetpack Compose. Flutter·React Native 흔적 없음. iOS 는 별도 Swift 앱으로 추정 (미확인)
- **GPS·페이스 계산은 외부 상용 엔진 사용** — Fullpower Technologies 의 모션 엔진 (`com.fullpower.*`) 을 Nike 래퍼 (`com.nike.activitytracking`) 로 감쌈
- **기능별 모듈 분리** — 챌린지·프로그램·오디오 가이드런·업적 등이 독립 패키지

## 기술 스택

### UI
- Jetpack Compose + Material3
- Lottie 애니메이션
- Glide 이미지 로딩
- Navigation (Compose)

### 아키텍처
- Hilt (Dagger) 의존성 주입
- Kotlin Coroutines/Flow 중심, RxJava 일부 잔존
- Room 로컬 DB

### 네트워크
- Retrofit + OkHttp, Ktor 일부 병행
- 직렬화: Moshi · kotlinx.serialization · Gson 혼재

### 위치·지도·건강
- Google Play Services Location (Fused Location)
- Google Maps
- Health Connect 기록 (거리·칼로리·심박·걸음)

### 운영 도구
- Firebase, New Relic (성능 모니터링)
- Adobe Analytics, 자체 clickstream (행동 분석)
- Optimizely (A/B 테스트), Urban Airship (푸시)

## 러닝 기록 구조

```
화면 (inrun/phone)
   ↓ 시작·일시정지·종료
러닝 서비스 (runtracking/inrunservice) — 포그라운드 서비스, 알림 표시
   ↓
트래킹 엔진 (activitytracking/engine)
   ├─ Fullpower 엔진 — GPS + 모션 센서 융합으로 거리·페이스 계산
   ├─ 트리거 버스 — 랩, 자동 일시정지, 목표 달성 등 이벤트 전달
   └─ 음성 안내 (voiceover)
   ↓ 종료 시
저장 (activitytracking/storage → activitystore) — 로컬 DB 저장 후 서버 동기화
```

### 권한
- 위치: 정밀 위치 + `FOREGROUND_SERVICE_LOCATION` — 화면 꺼진 상태 기록
- 센서: `HIGH_SAMPLING_RATE_SENSORS` — 고빈도 가속도 센서로 GPS 보정 추정
- 기타: 블루투스 (심박계), 녹음 (음성), 카메라

## 내 앱 적용 시사점

- **GPS 정확도가 품질의 핵심** — Nike 도 직접 안 만들고 전문 엔진을 샀다. 처음엔 OS 기본 위치 API + 간단한 필터 (튀는 점 제거, 정지 감지) 로 시작
- **포그라운드 서비스는 필수** — 화면 꺼진 상태에서 기록이 끊기지 않아야 함. iOS 는 Background Location 모드
- **이벤트 기반 구조 차용** — 트래킹 엔진이 랩·목표 달성 이벤트를 발행하는 구조는 아바타 성장·재화 지급을 붙이기 좋음
- **크로스플랫폼 선택은 유효** — Nike 는 플랫폼별 네이티브지만 1인 개발엔 Flutter / React Native 가 현실적. 위치 추적은 검증된 플러그인 사용

## 미확인 (TBD)

- iOS 앱 구조
- Fullpower 엔진 내부 알고리즘 (네이티브·난독화 영역)
- 서버 API 구조
