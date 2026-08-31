# Notice Tab Menu Scheme

공지 탭 가운데 메뉴 동작을 검증하기 위한 스킴 문서입니다.

- 작성자: 제옹(euijjang97)

## 1) 사용 저장값 (AppStorage)

- `memberId`
- `schoolId`
- `schoolName`
- `gisuId`
- `challengerId`
- `chapterId`
- `chapterName`
- `responsiblePart` (예: `IOS`, `SPRINGBOOT`)
- `organizationType`
- `organizationId`
- `memberRole`

## 2) 메뉴 구성 규칙

`organizationType == CENTRAL` 인 경우 메뉴를 아래 순서로 노출합니다.

1. 전체
2. 중앙운영사무국
3. 본인 지부 (`chapterName`)
4. 본인 학교 (`schoolName`)
5. 본인 파트 (`responsiblePart`가 있을 때만)

## 3) 값 매핑 규칙

- 본인 지부 라벨: `chapterName` (없으면 "지부")
- 본인 학교 라벨: `schoolName` (없으면 "학교")
- 본인 파트 라벨: `responsiblePart`를 `Part`로 변환
  - `PLAN` -> `Plan`
  - `DESIGN` -> `Design`
  - `WEB` -> `Web`
  - `ANDROID` -> `Android`
  - `IOS` -> `iOS`
  - `NODEJS` -> `Node.js`
  - `SPRINGBOOT` -> `SpringBoot`

## 4) API 요청 기본값

- 목록/검색 모두 선택된 기수의 `gisuId`를 사용
- 검색도 동일하게 선택 기수의 `gisuId` + 검색어로 요청

## 5) 코드 확인 포인트

- 메뉴 구성: `AppProduct/AppProduct/Features/Notice/Presentation/ViewModels/NoticeViewModel.swift`
  - `mainFilterItems`
  - `configureUserInfoFromStorage()`
- 상단 메뉴 렌더링: `AppProduct/AppProduct/Features/Notice/Presentation/Views/NoticeView.swift`
  - `ToolBarCollection.ToolBarCenterMenu`
