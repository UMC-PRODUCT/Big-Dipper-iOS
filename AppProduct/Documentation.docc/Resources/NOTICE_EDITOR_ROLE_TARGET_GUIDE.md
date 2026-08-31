# Notice Editor Role Target Guide

공지 생성 화면에서 역할별 타겟(지부/학교/파트) 선택 규칙과 API 요청 매핑을 정리한 문서입니다.

- 작성자: 제옹(euijjang97)
- 기준 코드:
  - `AppProduct/AppProduct/Features/Notice/Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+Targeting.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+Submit.swift`
  - `AppProduct/AppProduct/Features/Notice/Data/DTOs/NoticePostRequestDTO.swift`

## 1) 입력 컨텍스트

공지 작성 권한/범위 계산에 사용되는 값:

- `memberRole` (`ManagementTeam`)
- `organizationType`
- `gisuId`, `chapterId`, `schoolId` (AppStorage + 사용자 컨텍스트)
- 사용자 선택값
  - 메인 카테고리: `EditorMainCategory`
  - 서브 카테고리: `EditorSubCategory`
  - 필터 선택: `selectedBranch`, `selectedSchool`, `selectedParts`

## 2) 역할 그룹 매핑

`memberRole`은 내부적으로 아래 그룹으로 변환됩니다.

- `central`
  - `CENTRAL_PRESIDENT`
  - `CENTRAL_VICE_PRESIDENT`
  - `CENTRAL_OPERATING_TEAM_MEMBER`
  - `CENTRAL_EDUCATION_TEAM_MEMBER`
- `chapter`
  - `CHAPTER_PRESIDENT`
- `school`
  - `SCHOOL_PRESIDENT`
  - `SCHOOL_VICE_PRESIDENT`
  - `SCHOOL_PART_LEADER`
  - `SCHOOL_ETC_ADMIN`
- `noPermission`
  - `SUPER_ADMIN`
- `unknown`
  - `CHALLENGER` 또는 미정

## 3) 역할별 노출 규칙

### 메인 카테고리(`availableCategories`)

- `central`: `전체 기수`, `지부`, `학교`
- `chapter`: `지부`
- `school`: `전체 기수`, `학교`
- `noPermission`: `전체 기수` (단, 저장 시 차단)
- `unknown`: `전체 기수`, `지부`, `학교`

### 서브 카테고리(`visibleSubCategories`)

- `central`: `전체`, `파트`
- `chapter`: `지부`, `학교`
- `school`: `학교`, `파트`
- `noPermission`: 없음
- `unknown`: 카테고리 기본 규칙 사용

## 4) 검증 규칙 (`targetValidationMessage`)

공지 생성 시 아래 조건을 위반하면 저장이 차단됩니다.

- `SUPER_ADMIN`은 공지 작성 불가
- 지부/학교 둘 다 노출되는 역할에서는 둘 중 하나 필수 선택
- `전체 기수` 카테고리에서 지부/파트 동시 사용 금지
- 지부와 학교 동시 선택 금지
- 기수 미선택 상태(`gisuId <= 0`)에서 지부 대상 공지 금지
- 기수 미선택 상태에서 학교 + 파트 동시 지정 금지

## 5) API 요청 매핑 (`targetInfo`)

공지 생성 API: `POST /api/v1/notices`

요청 본문:

```json
{
  "title": "...",
  "content": "...",
  "shouldNotify": true,
  "targetInfo": {
    "targetGisuId": 0,
    "targetChapterId": null,
    "targetSchoolId": null,
    "targetParts": null
  }
}
```

카테고리별 매핑(`buildTargetInfo`)은 아래와 같습니다.

- `전체 기수`
  - `targetGisuId = 0`
  - `targetChapterId = nil`
  - `targetSchoolId = 선택 학교(있을 때만)`
  - `targetParts = nil`
- `중앙`
  - `targetGisuId = resolvedGisuId`
  - 학교를 선택하면 `targetChapterId = nil`
  - 학교 미선택 시 `targetChapterId = selectedBranch.id`
  - `targetSchoolId = selectedSchool.id`
  - `targetParts = selectedParts`
- `지부`
  - `targetGisuId = resolvedGisuId`
  - 학교를 선택하면 `targetChapterId = nil`
  - 학교 미선택 시 `targetChapterId = selectedBranch.id`
  - `targetSchoolId = selectedSchool.id`
  - `targetParts = selectedParts`
- `학교`
  - `targetGisuId = resolvedGisuId`
  - `targetChapterId = nil`
  - `targetSchoolId = selectedSchool.id ?? mySchoolId`
  - `targetParts = selectedParts`
- `파트`
  - `targetGisuId = resolvedGisuId`
  - `targetChapterId = nil`
  - `targetSchoolId = nil`
  - `targetParts = [selectedPart]`

## 6) 타겟 옵션 조회 API

타겟 선택 시트 데이터는 아래 API를 사용합니다.

- `GET /api/v1/chapters` (전체 지부)
- `GET /api/v1/schools/all` (전체 학교)
- `GET /api/v1/chapters/with-schools?gisuId={id}` (기수별 지부-학교)

## 7) 구현 체크리스트

- 역할 변경 시 `applyMemberRole()` 호출 여부
- 사용자 컨텍스트 변경 시 `updateUserContext(gisuId:chapterId:)` 호출 여부
- 저장 전 `targetValidationMessage` 검사 여부
- `targetInfo` 필드가 실제 선택값과 일치하는지 로그 검증 여부

## 8) 트러블슈팅

- 저장 버튼이 눌리는데 생성 실패:
  - `targetValidationMessage`가 없는지 먼저 확인
  - `resolvedGisuId`가 0인지 확인
- 지부/학교가 비어 보임:
  - 타겟 조회 API 실패 시 Mock 데이터 fallback 동작 여부 확인
- 역할에 맞지 않는 칩 노출:
  - `memberRole` AppStorage 저장값(`AppStorageKey.memberRole`) 확인

