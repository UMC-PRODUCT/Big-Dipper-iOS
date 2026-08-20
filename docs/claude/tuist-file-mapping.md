# Tuist 파일별 이관 매핑 (레거시 766개 → 목적지 모듈)

> **목적**: 레거시 `AppProduct/AppProduct/`의 **모든 Swift 파일**을 Tuist `UMCApp/`의 어느 모듈로 옮기는지 파일 단위로 정리한 표입니다.
> 배치 *규칙*의 근거는 `tuist-module-placement-guide.md`, 남은 작업은 `tuist-migration-roadmap.md` 참고.

| 항목 | 값 |
|------|-----|
| 작성 기준일 | 2026-06-27 |
| 총 파일 | 766 (Swift) |
| 확정 완료 | 59/59 (개발 에이전트 7명 병렬 분석으로 목적지 확정, 2026-06-27) |
| 잔여 판단 | 7 — 목적지는 정했으나 신규 모듈/의존성/파일분할 등 메인테이너 최종 승인 필요 |
| 분류 근거 | 레거시가 이미 `Domain/Data/Presentation` 구조라 대부분 기계적으로 결정 |

## 규칙 요약 (표 읽는 법)

- `Features/{X}/Presentation/**` → **{X}Presentation** · `Domain/**` → **{X}Domain** · `Data|DTO/**` → **{X}Data**
- UseCase 구현체는 **Domain**, Repository 프로토콜은 **Domain/Interfaces**, 구현체는 **Data** (규칙은 placement-guide 참고)
- `Provider` 폴더(프리뷰/목) → 해당 레이어 안에서 `Sources/Mock` + `#if DEBUG`
- = 목적지는 확정했으나 신규 모듈 신설/외부 의존성 추가/파일 분할 등 **메인테이너 최종 승인**이 필요한 항목

> ⚠️ **이 표는 기계적 매핑이다 — "표에 있다 = 지금 이식해야 한다" 가 아니다.**
> 레거시 전 파일을 폴더 구조 규칙으로 일괄 분류한 결과라, 실제로는 참조 0건인 dead code
> 나 이미 다른 형태로 대체된 파일도 그대로 한 줄을 차지한다. 이식에 착수하기 전 **소비자
> 존재 여부를 직접 확인**하고, 아래 상태 표기가 붙은 행은 그 지시를 따를 것.

### 상태 표기 범례

| 표기 | 의미 | 행동 |
|---|---|---|
| (없음) | 정상 이식 대상 | 목적지 모듈로 이식 |
| **이식 제외(dead)** | 레거시 참조 0건으로 확인된 dead code | 이식하지 말 것. UMCApp 에 이미 있으면 제거 대상 |
| **보류 — #N 선행** | 살아날 예정이나 선행 이슈가 열려 있음 | 단독 이식 금지. 해당 이슈 범위에서 함께 처리 |
| **superseded → X** | UMCApp 에서 다른 설계로 대체됨 | 이식하지 말 것. 대체 컴포넌트 X 를 사용 |
| **dormant** | UMCApp 에 이식됐으나 소비자 0건 (의도적 존치) | 삭제 금지. 재활성화 이슈를 먼저 닫을 것 |

## 목적지별 파일 수 (요약)

| 목적지 | 파일 수 |
|--------|:---:|
| NoticePresentation | 84 |
| ActivityDomain | 56 |
| ActivityPresentation | 52 |
| HomeDomain | 50 |
| HomePresentation | 46 |
| CommunityDomain | 45 |
| AuthDomain | 42 |
| MyPagePresentation | 34 |
| AuthData | 32 |
| CoreUIComponents | 30 |
| ActivityData | 28 |
| AuthPresentation | 28 |
| HomeData | 27 |
| NoticeData | 24 |
| MyPageDomain | 22 |
| CommunityData / NoticeDomain | 17 / 17 |
| CommunityPresentation | 14 |
| Core* (Foundation·Network·DI·DesignSystem 등) | 나머지 |

---

## 파일별 목적지

### Features/Activity

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Data/DTOs/AttendanceDecisionResponseDTO.swift` | ActivityData |
| `Data/DTOs/ChallengerPointCreateRequestDTO.swift` | ActivityData |
| `Data/DTOs/ChallengerSearchOffsetDTO.swift` | ActivityData |
| `Data/DTOs/CurriculumDTO.swift` | ActivityData |
| `Data/DTOs/DecideAttendanceItemDTO.swift` | ActivityData |
| `Data/DTOs/ExcuseAttendanceRequestDTO.swift` | ActivityData |
| `Data/DTOs/MemberManagementProfileDTO.swift` | ActivityData |
| `Data/DTOs/MemberProfileBestWorkbookDTO.swift` | ActivityData |
| `Data/DTOs/MyStudyGroupsPageDTO.swift` | ActivityData |
| `Data/DTOs/RequestAttendanceRequestDTO.swift` | ActivityData |
| `Data/DTOs/ScheduleAttendanceInfoDTO.swift` | ActivityData |
| `Data/DTOs/ScheduleListDTO.swift` | **이식 제외(dead)** — 레거시 참조 0건(생산자·소비자 모두 없음). 유일한 출력 대상이던 `ScheduleAttendanceStats` 도 dead 로 확정돼 UMCApp 에서 제거됨. 실사용 경로는 `ScheduleAttendanceInfoDTO` |
| `Data/DTOs/StudyGroupCreateRequestDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupDetailDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupNameItemDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupScheduleCreateRequestDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupUpdateRequestDTO.swift` | ActivityData |
| `Data/DTOs/V2AttendanceParticipantDTO.swift` | ActivityData |
| `Data/Provider/ActivityRepositoryProvider.swift` | **superseded → `UMCApp/Sources/DIContainer+Activity.swift`** — Repository 조립은 앱 타깃 DIContainer 확장이 담당 |
| `Data/Repositories/ActivityRepository.swift` | **분해 → `StudyRepository`·`MemberRepository`·`AttendanceRepository`** (ActivityData) — 레거시 단일 Repository 를 도메인별로 쪼갬 |
| `Data/Repositories/AttendanceRepository.swift` | ActivityData |
| `Data/Repositories/MemberRepository.swift` | ActivityData |
| `Data/Repositories/Mock/MockActivityRepository.swift` | **이식 제외** — UMCApp 은 목을 프로덕션 타깃에 두지 않고 각 테스트 타깃 안에 둔다(`Presentation/Tests/*ViewModelTests.swift`) |
| `Data/Repositories/Mock/MockAttendanceRepository.swift` | **이식 제외** — 위 `MockActivityRepository` 와 동일. 목은 테스트 타깃 소유 |
| `Data/Repositories/Mock/MockMemberRepository.swift` | ActivityData |
| `Data/Repositories/Mock/MockStudyRepository.swift` | ActivityData |
| `Data/Repositories/StudyRepository.swift` | ActivityData |
| `Data/Router/StudyRouter.swift` | ActivityData |
| `Domain/Enum/ActivityConstants.swift` | ActivityDomain |
| `Domain/Enum/ActivitySection.swift` | ActivityDomain |
| `Domain/Enum/Attendance/AttendanceStatus.swift` | ActivityDomain |
| `Domain/Enum/Attendance/AttendanceStatusV2.swift` | **superseded → `ActivityDomain.AttendanceStatus`** — 레거시는 구·신 두 enum 을 병존시켰으나 UMCApp 은 하나로 통합. `V2` 접미사를 남기지 말 것 |
| `Domain/Enum/Attendance/AttendanceTimeWindow.swift` | ActivityDomain |
| `Domain/Enum/Attendance/MyAttendanceItemStatus.swift` | ActivityDomain |
| `Domain/Enum/Session/SessionStatus.swift` | ActivityDomain |
| `Domain/Enum/Study/MissionStatus.swift` | ActivityDomain |
| `Domain/Enum/Study/MissionSubmissionType.swift` | ActivityDomain |
| `Domain/Enum/Study/MissionType.swift` | ActivityDomain |
| `Domain/Interfaces/ActivityRepositoryProtocol.swift` | **분해 → `StudyRepositoryProtocol`·`MemberRepositoryProtocol`·`ChallengerAttendanceRepositoryProtocol`·`OperatorAttendanceRepositoryProtocol`** |
| `Domain/Interfaces/ChallengerAttendanceRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/MemberRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/OperatorAttendanceRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/StudyRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Models/Attendance/Attendance.swift` | ActivityDomain |
| `Domain/Models/Attendance/AttendanceDecisionResult.swift` | ActivityDomain |
| `Domain/Models/Attendance/AttendanceGeofenceConstants.swift` | **분해** — 반경은 `UMCFoundation.GeofenceCalculator`(호출자가 radius 주입), 임계 분은 `ActivityDomain.AttendancePolicy.onTimeThresholdMinutes`/`lateThresholdMinutes` |
| `Domain/Models/Attendance/AttendanceType.swift` | ActivityDomain |
| `Domain/Models/Attendance/LocationVerification.swift` | ActivityDomain |
| `Domain/Models/Attendance/MyAttendanceItemModel.swift` | ActivityDomain |
| `Domain/Models/Identifier.swift` | ActivityDomain |
| `Domain/Models/Map/Address.swift` | ActivityDomain |
| `Domain/Models/Map/Coordinate.swift` | ActivityDomain |
| `Domain/Models/Map/Geofence.swift` | ActivityDomain |
| `Domain/Models/MemberManagement/MemberAttendanceRecord.swift` | ActivityDomain |
| `Domain/Models/MemberManagement/MemberManagementItem.swift` | ActivityDomain |
| `Domain/Models/MemberManagement/MemberPage.swift` | ActivityDomain |
| `Domain/Models/Operator/OperatorMemberPenaltyHistory.swift` | ActivityDomain |
| `Domain/Models/Operator/ParticipantAttendance.swift` | ActivityDomain |
| `Domain/Models/Operator/ScheduleAttendanceInfo.swift` | ActivityDomain |
| `Domain/Models/Operator/ScheduleAttendanceStats.swift` | **이식 제외(dead)** — 선이식됐으나 UMCApp 참조 0건이라 제거됨(#1016). 유일한 생산자가 dead 인 `ScheduleListDTO.toDomain()` 이었음. 실사용 경로는 `ScheduleAttendanceInfo` |
| `Domain/Models/Session/Session.swift` | ActivityDomain |
| `Domain/Models/Session/SessionInfo.swift` | ActivityDomain |
| `Domain/Models/Study/CurriculumProgressModel.swift` | ActivityDomain |
| `Domain/Models/Study/MissionCardModel.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupDetailsPage.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupInfo.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupItem.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupMember.swift` | ActivityDomain |
| `Domain/Models/Study/WeeklyCurriculumOption.swift` | ActivityDomain |
| `Domain/Models/StudyManagement/StudyManagementItem.swift` | ActivityDomain · **dormant** — 이식 완료됐으나 소비자 0건. `#586` 으로 제출 현황 UI 가 꺼지며 소비자가 사라졌고 `#999` 에서 재활성화 예정(서버 API 대기). 삭제 금지 |
| `Domain/UseCases/ChallengerAttendanceUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchCurriculumUseCaseProtocol.swift` | ActivityDomain (`FetchCurriculumOverviewUseCaseProtocol` 로 개명) |
| `Domain/UseCases/FetchMembersUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchSessionsUseCaseProtocol.swift` | **이식 제외 — #994 가 일정 조회로 흡수.** `Session` 은 일정에서 파생한다(`ActivityViewModel.swift:17` 주석) |
| `Domain/UseCases/FetchStudyMembersUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchUserIdUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/ChallengerAttendanceUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/FetchCurriculumUseCase.swift` | ActivityDomain (`FetchCurriculumOverviewUseCase` 로 개명) |
| `Domain/UseCases/Implementations/FetchMembersUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/FetchSessionsUseCase.swift` | **이식 제외 — #994 가 일정 조회로 흡수** (위 프로토콜과 한 쌍) |
| `Domain/UseCases/Implementations/FetchStudyMembersUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/FetchUserIdUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/OperatorAttendanceUseCase.swift` | ActivityDomain |
| `Domain/UseCases/OperatorAttendanceUseCaseProtocol.swift` | ActivityDomain |
| `Presentation/Components/Challenger/Attendance/ChallengerAttendanceReasonSheet.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Attendance/ChallengerAttendanceSessionList.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Attendance/ChallengerAttendanceView.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Attendance/ChallengerMyAttendanceCard.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Attendance/ChallengerMyAttendanceStatusView.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Attendance/ChallengerPendingApprovalView.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Attendance/ChallengerSessionCard.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Curriculum/ChallengerCurriculumProgressCard.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Curriculum/ChallengerCurriculumView.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Mission/ChallengerMissionCard.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Mission/ChallengerMissionCardContent.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Mission/ChallengerMissionCardHeader.swift` | ActivityPresentation |
| `Presentation/Components/Challenger/Mission/ChallengerMissionStatusIcon.swift` | ActivityPresentation |
| `Presentation/Components/CoreStudyManagementList.swift` | ActivityPresentation · **보류 — #999 선행** — 레거시 외부 소비자 0건(Preview 상호 참조뿐)이라 단독 이식 금지. `#999` 가 제출 현황 UI 신규 구현과 함께 포팅 대상으로 지정 |
| `Presentation/Components/Map/ActivityCompactMapView.swift` | ActivityPresentation |
| `Presentation/Components/Map/BaseMapComponent.swift` | ActivityPresentation |
| `Presentation/Components/Member/CoreMemberManagementList.swift` | **superseded → `CoreMemberManagementRow`** — 이식 누락이 아니라 의도적 대체. `#897` 이 리스트 컨테이너를 행 단위 `CoreMemberManagementRow` 로 재설계해 이식했고, 레거시 소비자 2곳(`ChallengerMemberListView`·`OperatorMemberManagementView`)은 UMCApp 에서 해당 Row 조립으로 대체됨. 이 파일 자체는 이식하지 말 것 |
| `Presentation/Components/Member/MemberManagementCard.swift` | ActivityPresentation |
| `Presentation/Components/Member/PointGrantFormSheet.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Attendance/OperatorLocationChangeSheetView.swift` | ActivityPresentation (`OperatorLocationChangeSheet` 로 개명 — `View` 접미사 제거) |
| `Presentation/Components/Operation/Attendance/OperatorSessionStatusIcon.swift` | **이식 제외(dead)** — 레거시 참조 0건. 상태 아이콘은 `OperatorSessionStatus+UI` 확장이 담당 |
| `Presentation/Components/Operation/Attendance/OperatorStatusSectionStyle.swift` | **이식 제외(dead)** — 레거시 참조 0건 |
| `Presentation/Components/Operation/Study/OperatorStudyGroupEditSheet.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/StudyGroupCard.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/StudyGroupLeaderRow.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/StudyGroupMemberChip.swift` | ActivityPresentation |
| `Presentation/Components/StudyManagementCard.swift` | ActivityPresentation · **보류 — #999 선행** — `CoreStudyManagementList` 와 한 쌍. 레거시 외부 소비자 0건이라 단독 이식 금지. 운영 스터디 목록은 `StudyGroupCard` 가, 멤버 관리는 `CoreMemberManagementRow` 가 이미 담당 |
| `Presentation/Enum/AttendancePeriodPreset.swift` | ActivityPresentation |
| `Presentation/Extensions/OperatorSessionStatus+UI.swift` | ActivityPresentation |
| `Presentation/Provider/ActivityUseCaseProvider.swift` | **superseded → `UMCApp/Sources/DIContainer+Activity.swift`** |
| `Presentation/ViewModels/ActivityViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Challenger/ChallengerAttendanceViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Map/BaseMapViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Member/MemberListViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Member/OperatorMemberDetailSheetViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Operation/AttendanceDetailViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Operation/AttendanceListViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Operation/OperatorStudyManagementViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Operation/StudyScheduleRegistrationViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/Study/ChallengerStudyViewModel.swift` | ActivityPresentation |
| `Presentation/Views/ActivityView.swift` | ActivityPresentation |
| `Presentation/Views/Challenger/ChallengerAttendanceSessionView.swift` | ActivityPresentation |
| `Presentation/Views/Challenger/ChallengerMemberListView.swift` | ActivityPresentation |
| `Presentation/Views/Challenger/ChallengerStudyView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/AttendanceDetailView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/AttendanceListView.swift` | ActivityPresentation (`OperatorAttendanceView` 로 개명) |
| `Presentation/Views/Operation/ChallengerMemberDetailSheetView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/OperatorMemberDetailSheetView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/OperatorMemberManagementView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/OperatorStudyGroupCreateView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/OperatorStudyManagementView.swift` | ActivityPresentation |
| `Presentation/Views/Operation/StudyScheduleRegistrationView.swift` | ActivityPresentation |

### Features/Auth

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Data/DTOs/AddMemberOAuthRequestDTO.swift` | AuthData |
| `Data/DTOs/ChangePasswordRequestDTO.swift` | AuthData |
| `Data/DTOs/CheckEmailAvailabilityQuery.swift` | AuthData |
| `Data/DTOs/CheckEmailAvailabilityResponseDTO.swift` | AuthData |
| `Data/DTOs/DeleteMemberOAuthRequestDTO.swift` | AuthData |
| `Data/DTOs/EmailLoginRequestDTO.swift` | AuthData |
| `Data/DTOs/EmailRegisterRequestDTO.swift` | AuthData |
| `Data/DTOs/EmailVerificationResponseDTO.swift` | AuthData |
| `Data/DTOs/LoginAppleRequestDTO.swift` | AuthData |
| `Data/DTOs/LoginByIdPwResponseDTO.swift` | AuthData (`EmailLoginResponseDTO` 로 개명 — 아이디/비번이 아니라 이메일 로그인) |
| `Data/DTOs/LoginGoogleRequestDTO.swift` | AuthData |
| `Data/DTOs/LoginKakaoRequestDTO.swift` | AuthData |
| `Data/DTOs/MemberOAuthDTO.swift` | AuthData |
| `Data/DTOs/OAuthLoginResponseDTO.swift` | AuthData |
| `Data/DTOs/RegisterByIdPwResponseDTO.swift` | AuthData |
| `Data/DTOs/RegisterCredentialRequestDTO.swift` | AuthData |
| `Data/DTOs/RegisterExistingChallengerRequestDTO.swift` | AuthData |
| `Data/DTOs/RegisterRequestDTO.swift` | AuthData |
| `Data/DTOs/RegisterResponseDTO.swift` | AuthData |
| `Data/DTOs/RenewTokenRequestDTO.swift` | **superseded → `CoreNetwork` 토큰 갱신 파이프라인**(`TokenRefreshServiceImpl`·`TokenPair`) — 재발급은 Feature DTO 가 아니라 네트워크 계층이 처리 |
| `Data/DTOs/ResendEmailVerificationRequestDTO.swift` | AuthData |
| `Data/DTOs/ResetPasswordRequestDTO.swift` | AuthData |
| `Data/DTOs/SchoolDTO.swift` | AuthData |
| `Data/DTOs/SendEmailVerificationRequestDTO.swift` | AuthData |
| `Data/DTOs/TermsDTO.swift` | AuthData |
| `Data/DTOs/TokenRenewResponseDTO.swift` | **superseded → `CoreNetwork` 토큰 갱신 파이프라인** (위 Request 와 한 쌍) |
| `Data/DTOs/VerifyEmailCodeRequestDTO.swift` | AuthData |
| `Data/DTOs/VerifyEmailCodeResponseDTO.swift` | AuthData |
| `Data/Provider/AuthRepositoryProvider.swift` | **superseded → `UMCApp/Sources/DIContainer+Auth.swift`** |
| `Data/Repositories/AuthRepository.swift` | AuthData |
| `Data/Repositories/Mock/MockAuthRepository.swift` | AuthData |
| `Data/Router/AuthRouter.swift` | AuthData |
| `Domain/Interfaces/AuthRepositoryProtocol.swift` | AuthDomain |
| `Domain/Models/EmailVerificationPurpose.swift` | AuthDomain |
| `Domain/Models/LoginByIdPwResult.swift` | AuthDomain |
| `Domain/Models/MemberOAuth.swift` | AuthDomain |
| `Domain/Models/OAuthLoginResult.swift` | AuthDomain |
| `Domain/Models/OAuthProvider.swift` | AuthDomain |
| `Domain/Models/RegisterByIdPwResult.swift` | AuthDomain |
| `Domain/Models/RegisterResult.swift` | AuthDomain |
| `Domain/Models/School.swift` | AuthDomain |
| `Domain/Models/Terms.swift` | AuthDomain |
| `Domain/UseCases/AddMemberOAuthUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/ChangePasswordUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/CheckEmailAvailabilityUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/DeleteMemberOAuthUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/FetchMyOAuthUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/FetchSignUpDataUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/Implementations/AddMemberOAuthUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/ChangePasswordUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/CheckEmailAvailabilityUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/DeleteMemberOAuthUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/FetchMyOAuthUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/FetchSignUpDataUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/LoginByEmailUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/LoginUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/RegisterByEmailUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/RegisterCredentialUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/RegisterExistingChallengerUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/RegisterUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/ResendEmailVerificationUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/ResetPasswordUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/SendEmailVerificationUseCase.swift` | AuthDomain |
| `Domain/UseCases/Implementations/VerifyEmailCodeUseCase.swift` | AuthDomain |
| `Domain/UseCases/LoginByEmailUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/LoginUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/RegisterByEmailUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/RegisterCredentialUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/RegisterExistingChallengerUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/RegisterUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/ResendEmailVerificationUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/ResetPasswordUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/SendEmailVerificationUseCaseProtocol.swift` | AuthDomain |
| `Domain/UseCases/VerifyEmailCodeUseCaseProtocol.swift` | AuthDomain |
| `Presentation/Components/FormEmailField.swift` | AuthPresentation |
| `Presentation/Components/FormPickerField.swift` | AuthPresentation |
| `Presentation/Components/FormTextField.swift` | AuthPresentation |
| `Presentation/Components/SignUpEmailSection.swift` | AuthPresentation |
| `Presentation/Components/SignUpNameNicknameSection.swift` | AuthPresentation |
| `Presentation/Components/SignUpPasswordSection.swift` | AuthPresentation |
| `Presentation/Components/SignUpSchoolSection.swift` | AuthPresentation |
| `Presentation/Components/SignUpTermsSection.swift` | AuthPresentation |
| `Presentation/Components/TitleLabel.swift` | AuthPresentation |
| `Presentation/Components/UnderlineTextField.swift` | **이식 제외** — #1119 에서 되살리지 않기로 결정. 입력 필드는 `EmailLoginView`·`ChangePasswordView` 가 glass capsule 로 조립 |
| `Presentation/Enum/SignUpByIdPwField.swift` | AuthPresentation (`SignUpFocusField` 로 개명) |
| `Presentation/Enum/SignUpFieldType.swift` | **superseded → `SignUpFocusField` + `FormTextField`/`FormEmailField`/`FormPickerField`** — 필드 종류를 열거형 한 곳에 모으는 대신 컴포넌트로 분리 |
| `Presentation/Models/PostRegisterLoginContext.swift` | CoreFoundation (AppFlow) — `AppFlow.showSignUp`가 Core에서 이 타입을 요구해 이관(#944 Q6, `SocialType`과 동일 사유) |
| `Presentation/Provider/AuthUseCaseProvider.swift` | **superseded → `UMCApp/Sources/DIContainer+Auth.swift`** |
| `Presentation/ViewModels/ChangePasswordViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/FailedVerificationUMCViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/LoginByIdPwViewModel.swift` | AuthPresentation (`EmailLoginViewModel` 로 개명). 내부 `IdPwLoginDestination` 은 `PathStore` 라우팅으로 대체돼 이식 제외 |
| `Presentation/ViewModels/LoginViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/ResetPasswordViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/SignUpByIdPwViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/SignUpViewModel.swift` | AuthPresentation |
| `Presentation/Views/ChangePasswordView.swift` | AuthPresentation |
| `Presentation/Views/FailedVerificationUMC.swift` | AuthPresentation |
| `Presentation/Views/LoginByIdPwView.swift` | AuthPresentation (`EmailLoginView` 로 개명) |
| `Presentation/Views/LoginView.swift` | AuthPresentation |
| `Presentation/Views/ResetPasswordView.swift` | AuthPresentation |
| `Presentation/Views/SignUpByIdPwView.swift` | AuthPresentation |
| `Presentation/Views/SignUpView.swift` | AuthPresentation |

### Features/AuthBootstrap

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Presentation/ViewModels/AuthBootstrapViewModel.swift` | AuthPresentation (ViewModels) |
| `Presentation/Views/AuthBootstrapView.swift` | AuthPresentation (Views) |

### Features/Community

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `DTO/CommunityCommentRequestDTO.swift` | CommunityData |
| `DTO/CommunityCommentResponse.swift` | CommunityData |
| `DTO/CommunityCommonRequestDTO.swift` | CommunityData |
| `DTO/CommunityPostRequestDTO.swift` | CommunityData |
| `DTO/CommunityPostResponseDTO.swift` | CommunityData |
| `DTO/CommunitySchoolResponseDTO.swift` | CommunityData |
| `DTO/CommunityTrophyRequestDTO.swift` | CommunityData |
| `DTO/CommunityTrophyResponseDTO.swift` | CommunityData |
| `Data/Repositories/CommunityDetailRepository.swift` | CommunityData |
| `Data/Repositories/CommunityPostRepository.swift` | CommunityData |
| `Data/Repositories/CommunityRepository.swift` | CommunityData |
| `Data/Repositories/Mock/MockCommunityRepositories.swift` | CommunityData |
| `Data/Repositories/TMapGeocodingRepository.swift` | CommunityData |
| `Data/Router/CommunityDetailRouter.swift` | CommunityData |
| `Data/Router/CommunityPostRouter.swift` | CommunityData |
| `Data/Router/CommunityRouter.swift` | CommunityData |
| `Data/Router/TMapGeocodingRouter.swift` | CommunityData |
| `Domain/Enums/CommunityButtonType.swift` | CommunityDomain |
| `Domain/Enums/CommunityItemCategory.swift` | CommunityDomain |
| `Domain/Enums/CommunityMenu.swift` | CommunityDomain |
| `Domain/Interfaces/CommunityDetailRepositoryProtocol.swift` | CommunityDomain |
| `Domain/Interfaces/CommunityPostRepositoryProtocol.swift` | CommunityDomain |
| `Domain/Interfaces/CommunityRepositoryProtocol.swift` | CommunityDomain |
| `Domain/Interfaces/TMapGeocodingRepositoryProtocol.swift` | CommunityDomain |
| `Domain/Models/CommunityCommentModel.swift` | CommunityDomain |
| `Domain/Models/CommunityFameItemModel.swift` | CommunityDomain |
| `Domain/Models/CommunityItemModel.swift` | CommunityDomain |
| `Domain/Models/CommunityLightningInfo.swift` | CommunityDomain |
| `Domain/UseCases/CreateLightningUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/CreatePostUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/DeleteCommentUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/DeletePostUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/FetchCommentsUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/FetchCommunityItemsUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/FetchCommunitySchoolsUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/FetchFameItemsUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/FetchPostDetailUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/CreateLightningUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/CreatePostUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/DeleteCommentUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/DeletePostUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/FetchCommentsUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/FetchCommunityItemUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/FetchCommunitySchoolsUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/FetchFameItemsUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/FetchPostDetailUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/PostCommentUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/PostLikeUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/PostScrapUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/ReportCommentUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/ReportPostUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/SearchPostUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/UpdateLightningUseCase.swift` | CommunityDomain |
| `Domain/UseCases/Implementations/UpdatePostUseCase.swift` | CommunityDomain |
| `Domain/UseCases/PostCommentUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/PostLikeUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/PostScrapUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/ReportCommentUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/ReportPostUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/SearchPostUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/UpdateLightningUseCaseProtocol.swift` | CommunityDomain |
| `Domain/UseCases/UpdatePostUseCaseProtocol.swift` | CommunityDomain |
| `Presentation/Components/CommunityCommentItem/CommunityCommentItem.swift` | CommunityPresentation |
| `Presentation/Components/CommunityFameItem/CommunityFameItem.swift` | CommunityPresentation |
| `Presentation/Components/CommunityItem/CommunityItem.swift` | CommunityPresentation |
| `Presentation/Components/CommunityLightningCard/CommunityLightningCard.swift` | CommunityPresentation |
| `Presentation/Components/CommunityPostCard/CommunityPostCard.swift` | CommunityPresentation |
| `Presentation/Provider/CommunityUseCaseProvider.swift` | CommunityPresentation |
| `Presentation/ViewModels/CommunityDetailViewModel.swift` | CommunityPresentation |
| `Presentation/ViewModels/CommunityFameViewModel.swift` | CommunityPresentation |
| `Presentation/ViewModels/CommunityPostViewModel.swift` | CommunityPresentation |
| `Presentation/ViewModels/CommunityViewModel.swift` | CommunityPresentation |
| `Presentation/Views/CommunityDetailView.swift` | CommunityPresentation |
| `Presentation/Views/CommunityFameView.swift` | CommunityPresentation |
| `Presentation/Views/CommunityPostView.swift` | CommunityPresentation |
| `Presentation/Views/CommunityView.swift` | CommunityPresentation |

### Features/Home

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Data/DTO/AttendanceDetailQuery.swift` | ActivityData (출석 도메인 소유 — `Data/Sources/DTOs/`) |
| `Data/DTO/AttendanceListQuery.swift` | ActivityData (출석 도메인 소유 — `Data/Sources/DTOs/`) |
| `Data/DTO/ChallengerMemeberDTO.swift` | ActivityData (`ChallengerProfileDTO`로 개명 — 포인트 히스토리 필드만 부분 디코딩) |
| `Data/DTO/ChallengerSearchDTO.swift` | ActivityData (`ChallengerSearchQuery`/`ChallengerSearchCursorDTO`로 분리) |
| `Data/DTO/GenerateScheduleRequetDTO.swift` | HomeData |
| `Data/DTO/GisuDetailDTO.swift` | HomeData |
| `Data/DTO/HomeScheduleDTO.swift` | HomeData |
| `Data/DTO/MyProfileDTO.swift` | CoreNetwork (Member — MemberProfileResponseDTO로 통합, #961) |
| `Data/DTO/MySchedulesQuery.swift` | HomeData |
| `Data/DTO/NoticeListDTO.swift` | NoticeData (`NoticeListQuery`로 개명 — 홈 최근 공지도 공지 모듈 쿼리를 재사용) |
| `Data/DTO/RegisterFCMTokenRequestDTO.swift` | HomeData |
| `Data/DTO/ScheduleCapabilitiesDTO.swift` | HomeData |
| `Data/DTO/ScheduleDetailDTO.swift` | HomeData |
| `Data/DTO/ScheduleParticipantDTO.swift` | HomeData |
| `Data/DTO/UpdateScheduleRequestDTO.swift` | HomeData |
| `Data/DTO/V2AttendancePolicyDTO.swift` | HomeData (`ScheduleAttendancePolicyDTO` 로 개명 — `V2` 접미사 제거) |
| `Data/DTO/V2LocationDTO.swift` | HomeData |
| `Data/GenerationMappingRecord.swift` | HomeData |
| `Data/Repository/ChallengerGenRepository.swift` | HomeData |
| `Data/Repository/ChallengerSearchRepository.swift` | ActivityData (`MemberRepository`로 통합) |
| `Data/Repository/HomeRepository.swift` | HomeData |
| `Data/Repository/MockHomeRepository.swift` | HomeData |
| `Data/Repository/ScheduleCapabilitiesRepository.swift` | HomeData |
| `Data/Repository/ScheduleRepository.swift` | HomeData |
| `Data/Router/ChallengerSearchRouter.swift` | ActivityData (`StudyRouter`의 챌린저 검색 케이스로 통합) |
| `Data/Router/HomeRouter.swift` | HomeData |
| `Data/Router/ScheduleV2Router.swift` | HomeData |
| `Domain/Impl/Notice/NoticeClassifierRepositoryImpl.swift` | **HomeData** (`NoticeClassifierRepository` 로 개명) — 구현체는 Domain 이 아니라 Data 레이어 소유 |
| `Domain/Impl/Notice/NoticeClassifierUseCaseImpl.swift` | HomeDomain (`ClassifyNoticeUseCase` 로 개명 — `Impl` 접미사 대신 동사형) |
| `Domain/Impl/Schedule/ScheduleClassifierRepositoryImpl.swift` | **HomeData** (`ScheduleClassifierRepository` 로 개명) |
| `Domain/Impl/Schedule/ScheduleClassifierUseCaseImpl.swift` | HomeDomain (`ClassifyScheduleUseCase` 로 개명) |
| `Domain/Interface/ChallengerGenRepositoryProtocol.swift` | CoreDomain (Member — 생산자 Home/소비자 Notice 공용, #1083) |
| `Domain/Interface/ChallengerSearchRepositoryProtocol.swift` | ActivityDomain (`MemberRepositoryProtocol`로 통합) |
| `Domain/Interface/HomeRepositoryProtocol.swift` | HomeDomain |
| `Domain/Interface/Notice/NoticeClassifierRepository.swift` | HomeDomain |
| `Domain/Interface/Notice/NoticeClassifierUseCase.swift` | HomeDomain (`ClassifyNoticeUseCaseProtocol` 로 개명) |
| `Domain/Interface/Schedule/ScheduleClassifierRepository.swift` | HomeDomain |
| `Domain/Interface/Schedule/ScheduleClassifierUseCase.swift` | HomeDomain |
| `Domain/Interface/ScheduleCapabilitiesRepositoryProtocol.swift` | HomeDomain |
| `Domain/Interface/ScheduleRepositoryProtocol.swift` | HomeDomain |
| `Domain/Models/Home/ChallengerRole.swift` | **superseded → CoreDomain `ProfileRole`** — 한 파일에 3개 타입이 들어 있어 목적지가 갈린다. `ChallengerRole`은 CoreDomain `ProfileRole`로 대체, `GenerationOrganizationContext`는 NoticeDomain 으로, `HomeProfileResult` 만 HomeDomain 으로 이식됨 |
| `Domain/Models/Home/GenerationData.swift` | HomeDomain (`HomeGeneration`으로 개명 — `UMCFoundation.Generation`과 이름 충돌 회피) |
| `Domain/Models/Home/RecentNoticeData.swift` | **superseded → `NoticeDomain.NoticeItemModel`** — 홈 최근 공지도 공지 정본 모델을 그대로 사용한다. 홈 전용 사본을 두지 말 것 |
| `Domain/Models/Home/ScheduleData.swift` | HomeDomain. 단 안의 `ScheduleDDayDisplayable` 프로토콜은 **이식 제외** — 유일 채택자였던 `ScheduleDetailData` 가 `dDay`/`dDayText` 를 직접 계산한다 |
| `Domain/Models/Home/ScheduleDetailData.swift` | HomeDomain |
| `Domain/Models/NoticeHistory/NoticeHistoryData.swift` | HomeDomain |
| `Domain/Models/Schedule/AttendancePolicy.swift` | HomeDomain |
| `Domain/Models/Schedule/AttendancePolicyError.swift` | ActivityDomain (`Models/Attendance/`) |
| `Domain/Models/Schedule/ScheduleCapabilities.swift` | HomeDomain |
| `Domain/Models/Schedule/ScheduleLocation.swift` | HomeDomain |
| `Domain/Models/Schedule/ScheduleParticipant.swift` | HomeDomain |
| `Domain/Models/ScheduleGeneration/CSVImportResult.swift` | **이식 제외(dead)** — 레거시 참조 0건 |
| `Domain/Models/ScheduleGeneration/PlaceSearchResult.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Domain/Models/ScheduleGeneration/RecentPlace.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Domain/Models/ScheduleGeneration/ScheduleRegistrationData.swift` | HomeDomain (`ScheduleCreationRequest`로 개명 — 장소·출석 정책은 조회 모델 재사용) |
| `Domain/UseCases/DeleteScheduleUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/FetchMyProfileUseCaseProtocol.swift` | HomeDomain (FetchHomeProfileUseCaseProtocol로 개명, CoreDomain 프로필 파이프라인 합성 — #961) |
| `Domain/UseCases/FetchRecentNoticesUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/FetchScheduleCapabilitiesUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/FetchScheduleDetailUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/FetchSchedulesUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/ForceDeleteScheduleUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/GenerateScheduleUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/Implementations/DeleteScheduleUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/FetchMyProfileUseCase.swift` | HomeDomain (FetchHomeProfileUseCase로 개명, CoreDomain 프로필 파이프라인 합성 — #961) |
| `Domain/UseCases/Implementations/FetchRecentNoticesUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/FetchScheduleCapabilitiesUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/FetchScheduleDetailUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/FetchSchedulesUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/ForceDeleteScheduleUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/GenerateScheduleUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/RegisterFCMTokenUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/SearchChallengersUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/UpdateScheduleUseCase.swift` | HomeDomain |
| `Domain/UseCases/RegisterFCMTokenUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/SearchChallengersUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/UpdateScheduleUseCaseProtocol.swift` | HomeDomain |
| `Presentation/Components/Card/ChallengerSearchCard.swift` | ActivityPresentation (`Components/Challenger/`) |
| `Presentation/Components/Card/NoticeAlarmCard.swift` | HomePresentation |
| `Presentation/Components/Card/PenaltyCard.swift` | HomePresentation |
| `Presentation/Components/Card/RecentNoticeCard.swift` | HomePresentation |
| `Presentation/Components/Card/ScheduleCard.swift` | HomePresentation |
| `Presentation/Components/Card/ScheduleListCard.swift` | HomePresentation |
| `Presentation/Components/Card/SeasonCard.swift` | HomePresentation |
| `Presentation/Components/Map/SelectedPlaceAnnotation.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Presentation/Components/Row/DatePickerRow.swift` | CoreUIComponents (`Sources/Schedule/`) |
| `Presentation/Components/Row/DateTimeRow.swift` | CoreUIComponents (`Sources/Schedule/`) |
| `Presentation/Components/Row/TimePickerRow.swift` | CoreUIComponents (`Sources/Schedule/`) |
| `Presentation/Components/Schedule/AttendancePolicyDisplaySection.swift` | HomePresentation |
| `Presentation/Components/Schedule/AttendancePolicyTimeSection.swift` | CoreUIComponents (`Sources/Schedule/`) |
| `Presentation/Components/Schedule/Calendar/CalendarGridCard.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/CalendarHorizonCard.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/DateCell.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/DatePill.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/ScheduleHeader.swift` | HomePresentation |
| `Presentation/Components/Schedule/InPersonToggle.swift` | CoreUIComponents (`Sources/Schedule/`) |
| `Presentation/Enum/NoticeAlarmType.swift` | HomeDomain (`Models/NoticeHistory/NoticeAlarmType.swift` — Presentation 아님) |
| `Presentation/Enum/PenalyInfoType.swift` | **타입별로 갈림** — ① `PointLogItem` → **superseded → `HomeDomain.PointLog`** (`id` 를 `UUID()` → 서버 발급 `String` 으로, `point` 를 `Int` → `Double` 로 확장해 서버의 `-0.5` 소수 배점 보존). 소비처 `PenaltyCard` 는 `fileprivate enum PointLogFilter` 까지 레거시 그대로 이식됨 ② `PenaltyInfoItem` → **이식 제외(dead)** — `GenerationData.penaltyLogs`(레거시 주석 "하위호환")에 담기기만 하고 읽는 곳 0건 ③ `InfoType` → **이식 제외(dead)** — 레거시 참조 0건 |
| `Presentation/Enum/RecentCategory.swift` | **superseded → `NoticeDomain.NoticeCategory`** — 레거시 소비자는 함께 대체된 `NoticeListDTO`·`RecentNoticeData` 뿐 |
| `Presentation/Enum/ScheduleCategory.swift` | **이식 제외(dead)** — 레거시 참조 0건(`HomeView`의 `isScheduleCategoryLoading` 은 이름만 겹치는 별개 상태) |
| `Presentation/Enum/ScheduleGenerationType.swift` | **superseded → 각 View 의 `fileprivate enum Constants` + `PlaceSelectView(placeholder:)`** — 폼 placeholder 를 열거형 한 곳에 모으는 설계를 버렸다. 레거시 소비자(`ScheduleRegistrationView`·`PlaceSelectView`)는 UMCApp 에서 각자 상수를 갖는다 |
| `Presentation/Enum/ScheduleMode.swift` | HomePresentation |
| `Presentation/Enum/SeasonType.swift` | HomeDomain (`Models/SeasonType.swift` — Presentation 아님) |
| `Presentation/Provider/HomeUseCaseProvider.swift` | **superseded → `UMCApp/Sources/DIContainer+Home.swift`** — 레거시 유일 소비자는 `Core/DIContainer/DIContainer.swift`. UseCase 조립은 앱 타깃 DIContainer 확장이 담당 |
| `Presentation/ViewModels/HomeViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/InlineMapPickerState.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Presentation/ViewModels/ScheduleDetailViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleDraft.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleRegistrationViewModel+AI.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleRegistrationViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/SearchChallengerViewModel.swift` | ActivityPresentation |
| `Presentation/ViewModels/SearchPlaceViewModel.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Presentation/Views/HomeView.swift` | HomePresentation |
| `Presentation/Views/NoticeAlarmView.swift` | HomePresentation |
| `Presentation/Views/Registration/Challenger/ChallengerFormView.swift` | ActivityPresentation (`Components/Challenger/`) |
| `Presentation/Views/Registration/Challenger/SearchChallengerView.swift` | ActivityPresentation (`Components/Challenger/`) |
| `Presentation/Views/Registration/Challenger/SelectedChallengerView.swift` | ActivityPresentation (`Components/Challenger/`) |
| `Presentation/Views/Registration/InlineMapPlacePicker.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Presentation/Views/Registration/ScheduleDetailView.swift` | HomePresentation (`Views/ScheduleDetailView.swift` — Registration 하위 아님) |
| `Presentation/Views/Registration/ScheduleRegistrationView.swift` | HomePresentation |
| `Presentation/Views/Registration/SearchPlaceResultRow.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Presentation/Views/Registration/SearchPlaceView.swift` | **이식 제외(dead)** — 텍스트 장소 검색 체인. 아래 ⓟ 주석 참조 |
| `Presentation/Views/Registration/TagListView.swift` | HomePresentation |

> **ⓟ 텍스트 장소 검색 체인 (8파일) — 이식 제외(dead)**
>
> `SearchPlaceView` · `SearchPlaceViewModel` · `SearchPlaceResultRow` · `InlineMapPlacePicker` ·
> `InlineMapPickerState` · `SelectedPlaceAnnotation` · `PlaceSearchResult` · `RecentPlace`
>
> 레거시가 지도 피커로 전환하면서 연결이 끊긴 잔해다. **8파일 모두 AppProduct 내 참조 0건**이고,
> 레거시 `ScheduleRegistrationView.swift:135` 는 이미 `PlaceSelectView(place:)` 를 쓴다 —
> 이 컴포넌트가 `CoreUIComponents/Sources/PlaceSelectView/` 로 이식된 현재 구현이므로
> **"레거시에서 쓰던 방식"은 이미 UMCApp 에 그대로 있다.** 이식하면 레거시에서도 한 번도 돌지 않은
> 코드를 되살리는 셈이라 대상에서 제외한다.
>
> 다만 그 결과로 **지도 피커에 텍스트 검색이 없다** (POI 길게누르기 + 리버스 지오코딩만 가능).
> 이는 이관 누락이 아니라 신규 기능이며 #1122 에서 다룬다. `AppStorageKey.recentSearchPlaces`
> 키가 UMCApp 에 정의만 되고 미사용으로 남아 있는 것도 같은 이유다.

### Features/Maintenance

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Data/RemoteConfigService.swift` | MaintenanceData (RemoteConfig) — Firebase 의존 추가 |
| `Domain/CheckForceUpdateUseCase.swift` | MaintenanceDomain (UseCases/Implementations; 프로토콜 Interfaces) |
| `Domain/CheckMaintenanceUseCase.swift` | MaintenanceDomain (UseCases/Implementations; 프로토콜 Interfaces) |
| `Domain/MaintenanceInfo.swift` | MaintenanceDomain (Models) |
| `Presentation/ViewModels/MaintenanceViewModel.swift` | MaintenancePresentation (ViewModels) |
| `Presentation/Views/MaintenanceView.swift` | MaintenancePresentation (Views) |

### Features/MyPage

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Data/DTO/AddChallengerRecordRequestDTO.swift` | MyPageData |
| `Data/DTO/MyPageFlexibleNumberDecoding.swift` | MyPageData |
| `Data/DTO/MyPagePostDTO.swift` | MyPageData |
| `Data/DTO/MyPageProfileDTO.swift` | CoreNetwork (Member — MemberProfileResponseDTO로 통합, #961) |
| `Data/DTO/MyPageTermsDTO.swift` | MyPageData |
| `Data/DTO/MyPageUploadDTO.swift` | MyPageData |
| `Data/Repository/Mock/MockMyPageRepository.swift` | MyPageData |
| `Data/Repository/MyPageRepository.swift` | MyPageData |
| `Data/Router/MyPageRouter.swift` | MyPageData |
| `Domain/Interface/MyPageRepositoryProtocol.swift` | MyPageDomain |
| `Domain/Models/MyActivePostPage.swift` | MyPageDomain |
| `Domain/Models/MyPageTerms.swift` | MyPageDomain |
| `Domain/Models/ProfileData.swift` | MyPageDomain |
| `Domain/UseCases/AddChallengerRecordUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/DeleteMemberUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/FetchMyCommentedPostsUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/FetchMyPageProfileUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/FetchMyPostsUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/FetchMyScrappedPostsUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/FetchTermsUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/AddChallengerRecordUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/DeleteMemberUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/FetchMyCommentedPostsUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/FetchMyPageProfileUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/FetchMyPostsUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/FetchMyScrappedPostsUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/FetchTermsUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/UpdateMyPageProfileImageUseCase.swift` | MyPageDomain |
| `Domain/UseCases/Implementations/UpdateMyPageProfileLinksUseCase.swift` | MyPageDomain |
| `Domain/UseCases/UpdateMyPageProfileImageUseCaseProtocol.swift` | MyPageDomain |
| `Domain/UseCases/UpdateMyPageProfileLinksUseCaseProtocol.swift` | MyPageDomain |
| `Presentation/Components/Row/MyPageProfileView/ReadOnlyTextField.swift` | MyPagePresentation |
| `Presentation/Components/Row/MyPageRow/ActiveLogRow.swift` | MyPagePresentation |
| `Presentation/Components/Row/MyPageRow/MyPageSectionRow.swift` | MyPagePresentation |
| `Presentation/Components/Section/MyPageProfileSection/ActiveLogs.swift` | MyPagePresentation |
| `Presentation/Components/Section/MyPageProfileSection/ConnectionSocial.swift` | MyPagePresentation |
| `Presentation/Components/Section/MyPageProfileSection/NameAndNickname.swift` | MyPagePresentation |
| `Presentation/Components/Section/MyPageProfileSection/ProfileImagePicker.swift` | MyPagePresentation |
| `Presentation/Components/Section/MyPageProfileSection/ProfileLinkSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MyPageProfileSection/SchoolSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/AppBundleSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/AuthSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/FollowsSection.swift` | MyPagePresentation (`UMCChannelSection` 으로 개명 — 팔로우 기능이 아니라 UMC 공식 채널 링크). 딥링크 폴백은 `UIApplication.canOpenURL` 대신 `openURL(_:completion:)` 사용 → `LSApplicationQueriesSchemes` 등록 불필요 |
| `Presentation/Components/Section/MypageSection/HelpSection.swift` | **이식 제외(dead)** — 레거시 호출처 0건(`HelpSection()` 을 그리는 화면이 없음) |
| `Presentation/Components/Section/MypageSection/LawSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/LinkSection.swift` | MyPagePresentation (`ProfileLinkSection` 으로 개명) |
| `Presentation/Components/Section/MypageSection/MyActiveLogSection.swift` | MyPagePresentation · **dormant** — 이식 완료됐으나 마이페이지 v3 재편(#1196)으로 소비자 0건. 루트의 활동 요약은 신규 `MyActivitySection` 이 대체. 라우팅 enum `MyActiveLogsType` 은 계속 사용 중이므로 enum 까지 지우지 말 것. 삭제 금지(의도적 존치) |
| `Presentation/Components/Section/MypageSection/ProfileCardSection.swift` | MyPagePresentation · **dormant** — 이식 완료됐으나 마이페이지 v3 재편(#1196)으로 루트가 명함 카드(`BusinessCardSection`)로 교체되며 소비자 0건. 삭제 금지(의도적 존치) |
| `Presentation/Components/Section/MypageSection/SettingSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/SocialSection.swift` | MyPagePresentation (`SocialConnectSection` 으로 개명) |
| `Presentation/Enum/AuthType.swift` | MyPagePresentation |
| `Presentation/Enum/FollowType.swift` | MyPagePresentation (`UMCChannelType` 으로 개명). 아이콘은 `CoreUIComponents` 번들 자산 접근자 `Image.umcInstagram`/`.umcChannelLogo` 로 노출 |
| `Presentation/Enum/HelpType.swift` | **이식 제외(dead)** — 유일 소비자인 `HelpSection` 이 dead |
| `Presentation/Enum/LawsType.swift` | MyPagePresentation |
| `Presentation/Enum/MyActiveLogsType.swift` | MyPagePresentation |
| `Presentation/Enum/MyPageSectionType.swift` | MyPagePresentation |
| `Presentation/Enum/ScocialLinkType.swift` | MyPagePresentation |
| `Presentation/Enum/SettingType.swift` | MyPagePresentation |
| `Presentation/Provider/MyPageUseCaseProvider.swift` | MyPagePresentation |
| `Presentation/ViewModels/MyActivePostsViewModel.swift` | MyPagePresentation |
| `Presentation/ViewModels/MyPageProfileViewModel.swift` | MyPagePresentation |
| `Presentation/ViewModels/MyPageViewModel.swift` | MyPagePresentation |
| `Presentation/Views/MyActivePostsView.swift` | MyPagePresentation |
| `Presentation/Views/MyPageProfileView.swift` | MyPagePresentation |
| `Presentation/Views/MyPageView.swift` | MyPagePresentation |

### Features/Notice

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Data/AITokenDailyUsageRecord.swift` | **NoticeDomain** (`Sources/Models/`) — SwiftData 영속 모델이지만 소비자가 `NoticeEditorViewModel+AI` / `NoticeDetailViewModel+AI` / `ScheduleRegistrationViewModel+AI` 로 전부 Presentation 이라, NoticeData 로 내리면 NoticePresentation·HomePresentation → NoticeData 역방향 의존이 생긴다. `Home/Domain/.../NoticeHistoryData.swift` 와 동일 선례(#1096) |
| `Data/DTOs/NoticeDTO.swift` | NoticeData |
| `Data/DTOs/NoticeDetailContentDTO.swift` | NoticeData |
| `Data/DTOs/NoticeDetailDTO.swift` | NoticeData |
| `Data/DTOs/NoticeEditorTargetDTO.swift` | NoticeData |
| `Data/DTOs/NoticeImagesRequestDTO.swift` | NoticeData |
| `Data/DTOs/NoticeLinksRequestDTO.swift` | NoticeData |
| `Data/DTOs/NoticePageDTO.swift` | NoticeData |
| `Data/DTOs/NoticePatchRequestDTO.swift` | NoticeData |
| `Data/DTOs/NoticePostRequestDTO.swift` | NoticeData |
| `Data/DTOs/NoticeReadStatusDTO.swift` | NoticeData |
| `Data/DTOs/NoticeReadStatusListQuery.swift` | NoticeData |
| `Data/DTOs/NoticeReminderRequestDTO.swift` | NoticeData |
| `Data/DTOs/NoticeTargetInfoMapper.swift` | NoticeData |
| `Data/DTOs/NoticeVoteResponseRequestDTO.swift` | NoticeData |
| `Data/DTOs/VoteDTO.swift` | NoticeData |
| `Data/NoticeReadRecord.swift` | NoticeData |
| `Data/Repositories/Mock/MockNoticeReadRepository.swift` | NoticeData |
| `Data/Repositories/Mock/MockNoticeRepository.swift` | NoticeData |
| `Data/Repositories/NoticeEditorTargetRepository.swift` | NoticeData |
| `Data/Repositories/NoticeReadRepository.swift` | NoticeData |
| `Data/Repositories/NoticeRepository.swift` | NoticeData |
| `Data/Router/NoticeEditorTargetRouter.swift` | NoticeData |
| `Data/Router/NoticeRouter.swift` | NoticeData |
| `Domain/Enums/NoticeItemTag.swift` | **NoticePresentation** (`Sources/Tags/`) — `SwiftUI.Color` 를 프로퍼티로 갖는 UI 표시용 값 타입이고 소비자도 `NoticeItemModel+Tags` / `NoticeDetail+UI` / `NoticeDetailView` 로 전부 Presentation 이다(#1096) |
| `Domain/Enums/NoticeRequestFactory.swift` | **이식 제외(dead)** — 이식됐다가 소비자 0건으로 확인돼 제거됨(#1028). `NoticeListRequest` 조립은 `NoticeViewModel+Fetch.buildNoticeListRequest` 가 담당 |
| `Domain/Enums/NoticeType.swift` | NoticeDomain |
| `Domain/Enums/StaffNoticeTab.swift` | NoticeDomain |
| `Domain/Interfaces/NoticeEditorTargetRepositoryProtocol.swift` | NoticeDomain |
| `Domain/Interfaces/NoticeReadRepositoryProtocol.swift` | NoticeDomain |
| `Domain/Interfaces/NoticeRepositoryProtocol.swift` | NoticeDomain |
| `Domain/Models/NoticeDetailModel.swift` | NoticeDomain |
| `Domain/Models/NoticeEditorModel.swift` | NoticeDomain |
| `Domain/Models/NoticeItemModel.swift` | NoticeDomain |
| `Domain/Models/NoticeModel.swift` | NoticeDomain |
| `Domain/Models/NoticePart.swift` | NoticeDomain |
| `Domain/Models/NoticeReadStatusItemModel.swift` | NoticeDomain |
| `Domain/UseCases/Implementations/NoticeEditorTargetUseCase.swift` | NoticeDomain |
| `Domain/UseCases/Implementations/NoticeUseCase.swift` | NoticeDomain |
| `Domain/UseCases/NoticeEditorTargetUseCaseProtocol.swift` | NoticeDomain |
| `Domain/UseCases/NoticeUseCaseProtocol.swift` | NoticeDomain |
| `Presentation/Components/Attachment/ImageAttachmentCard.swift` | NoticePresentation |
| `Presentation/Components/Attachment/LinkAttachmentCard.swift` | NoticePresentation |
| `Presentation/Components/Attachment/VoteAttachmentCard.swift` | NoticePresentation |
| `Presentation/Components/DetailCard/NoticeImageCard.swift` | NoticePresentation |
| `Presentation/Components/DetailCard/NoticeLinkCard.swift` | NoticePresentation |
| `Presentation/Components/DetailCard/NoticeVoteCard.swift` | NoticePresentation |
| `Presentation/Components/DetailCard/VoteAllVotersSheet.swift` | NoticePresentation |
| `Presentation/Components/DetailCard/VoteVoterListSheet.swift` | NoticePresentation |
| `Presentation/Components/FlowLayout.swift` | NoticePresentation |
| `Presentation/Components/NoticeChip.swift` | NoticePresentation |
| `Presentation/Components/NoticeItem/NoticeItem.swift` | NoticePresentation |
| `Presentation/Components/NoticeReadStatusButton.swift` | NoticePresentation |
| `Presentation/Components/NoticeReadStatusItem/NoticeReadStatusItem.swift` | NoticePresentation |
| `Presentation/Components/NoticeSubFilter.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeDetail/NoticeDetailViewModel+AI.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeDetail/NoticeDetailViewModel+NoticeActions.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeDetail/NoticeDetailViewModel+ReadStatus.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeDetail/NoticeDetailViewModel.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeDetail/NoticeReadStatusPermissionEvaluator.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/EditorToolbar/EditorToolbarTypes.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/EditorToolbar/EditorToolbarViewModel+FormattingHelpers.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/EditorToolbar/EditorToolbarViewModel+RangeHelpers.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/EditorToolbar/EditorToolbarViewModel.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+AI.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+Submit.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+Targeting.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+VoteAttachment.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeList/NoticeViewModel+Context.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeList/NoticeViewModel+Fetch.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeList/NoticeViewModel.swift` | NoticePresentation |
| `Presentation/ViewModels/NoticeViewModelSupport.swift` | NoticePresentation |
| `Presentation/ViewModels/StaffNotice/StaffNoticeViewModel.swift` | NoticePresentation |
| `Presentation/Views/Components/NoAccessContentView.swift` | NoticePresentation |
| `Presentation/Views/NoticeDetail/MarkdownRenderedView.swift` | NoticePresentation |
| `Presentation/Views/NoticeDetail/NoticeDetailView.swift` | NoticePresentation |
| `Presentation/Views/NoticeDetail/NoticeReadStatusSheet.swift` | NoticePresentation |
| `Presentation/Views/NoticeDetail/NoticeReadingSummarySheet.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/AttachmentToolbar/AttachmentMenuButton.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/AttachmentToolbar/HighlightMenuButton.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/AttachmentToolbar/ListMenuButton.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/AttachmentToolbar/NoticeEditorAttachmentToolbar.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/AttachmentToolbar/ToolbarButtonStyles.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/NoticeEditorBindings.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/NoticeEditorPresentations.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/NoticeEditorView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Overlay/AIConfirmationOverlay.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Overlay/AILoadingOverlay.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Overlay/AISummaryDraftOverlay.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Overlay/AISummaryInputSheet.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/BlockquoteTextView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/FormatPanel/FormatPanelView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextCoordinator+Blockquote.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextCoordinator+List.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextCoordinator+MarkdownAutoformat.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextCoordinator+Placeholder.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextCoordinator+Scroll.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextCoordinator.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/RichTextViewRepresentable.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichText/UITextView+MinimumHeight.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichTextView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownAttributeBuilder.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownAutoformat.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownBlockParser.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownBlockSerializer.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownEscaping.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownHTMLDetector.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownInlineParser.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownInlineSerializer.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownRegex.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownSerializer.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownSerializerTypes.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Toolbar/DefaultToolbarView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Toolbar/TableCellToolbarView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/RichTextEditor/Toolbar/TextSelectedToolbarView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sections/NoticeEditorImageSection.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sections/NoticeEditorLinkSection.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sections/NoticeEditorSubCategorySection.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sections/NoticeEditorTextFieldSection.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sections/NoticeEditorVoteSection.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sheets/TargetSheetView.swift` | NoticePresentation |
| `Presentation/Views/NoticeEditor/Sheets/VotingFormSheetView.swift` | NoticePresentation |
| `Presentation/Views/NoticeView.swift` | NoticePresentation |
| `Presentation/Views/StaffNoticeView.swift` | NoticePresentation |

### Features/Tab

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Presentation/Enum/TabCase.swift` | App(UMCApp) — 루트 탭 셸 #910 (`NavigationTab` 으로 개명) |
| `Presentation/Views/UmcBottonAccessoryView.swift` | App(UMCApp) — `RootTabView.tabViewBottomAccessory` **부분 이식**. Activity 모드 토글(`AdminModeToggle`)만 남기고, Home 일정 생성·Notice 공지 작성은 각 화면 툴바(`ToolBarCollection.AddBtn`)로 **대체**. Community 액세서리는 Community 탭 실연결(#591)에서 처리 |
| `Presentation/Views/UmcTab.swift` | App(UMCApp) — 루트 탭 셸 #910 (`RootTabView` 로 개명) |

### App

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `AppDelegate.swift` | App(UMCApp) 진입점 |
| `AppProductApp.swift` | App(UMCApp) 진입점 |

### Core

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Alert/AlertPromprt.swift` | CoreFoundation (Alert) |
| `Common/Authorization/DTOs/ResourcePermissionDTO.swift` | CoreNetwork (Authorization) — 이미 이관됨 |
| `Common/Authorization/Models/ResourcePermission.swift` | CoreDomain (Authorization) — 이미 이관됨 |
| `Common/Authorization/Repositories/AuthorizationRepository.swift` | CoreNetwork (Authorization) — 이미 이관됨 |
| `Common/Authorization/Repositories/AuthorizationRepositoryProtocol.swift` | CoreDomain (Authorization) — 이미 이관됨 |
| `Common/Authorization/Router/AuthorizationRouter.swift` | CoreNetwork (Authorization) — 이미 이관됨 |
| `Common/Authorization/UseCases/AuthorizationUseCase.swift` | CoreDomain (Authorization) — 이미 이관됨 |
| `Common/Authorization/UseCases/AuthorizationUseCaseProtocol.swift` | CoreDomain (Authorization) — 이미 이관됨 |
| `Common/DesignSystem/Styles/ButtonStyles.swift` | CoreDesignSystem |
| `Common/DesignSystem/Tokens/TypographyTokens.swift` | CoreDesignSystem |
| `Common/Enum/AppStorageKey.swift` | CoreFoundation (Enums) — 이미 이관됨 |
| `Common/Enum/DefaultConstant.swift` | CoreDesignSystem (Layout) — 이미 이관됨 |
| `Common/Enum/DefaultSpacing.swift` | CoreDesignSystem (Layout) — 이미 이관됨 |
| `Common/Enum/GeofenceEvent.swift` | ActivityDomain (Enums) |
| `Common/Enum/ManagementTeam.swift` | CoreFoundation (Enums) — 이미 이관됨 |
| `Common/Enum/OrganizationType.swift` | CoreFoundation (Enums) — 이미 이관됨 |
| `Common/Enum/SocialType.swift` | CoreFoundation (Enums) — 이미 이관됨(UI프로퍼티는 Presentation ext) |
| `Common/Enum/UMCPartType.swift` | CoreFoundation (Enums) — 이미 이관됨 |
| `Common/Error/Handler/ErrorContext.swift` | CoreFoundation (Error) |
| `Common/Error/Handler/ErrorHandler.swift` | CoreFoundation (Error) |
| `Common/Error/Handler/PresentableError.swift` | CoreFoundation (Error) |
| `Common/Error/Loadable/Loadable.swift` | CoreFoundation (Error) |
| `Common/Error/LocationError.swift` | CoreFoundation (Error) |
| `Common/Error/Types/AppError.swift` | CoreFoundation (Error) |
| `Common/Error/Types/AuthError.swift` | CoreFoundation (Error) |
| `Common/Error/Types/DomainError.swift` | CoreFoundation (Error) |
| `Common/Error/Types/Error+Cancellation.swift` | CoreFoundation (Error) |
| `Common/Error/Types/ErrorSeverity.swift` | CoreFoundation (Error) |
| `Common/Error/Types/NetworkError.swift` | CoreFoundation (Error) |
| `Common/Error/Types/RepositoryError.swift` | CoreFoundation (Error) |
| `Common/Error/Types/ValidationError.swift` | CoreFoundation (Error) |
| `Common/Protocol/MultiplePhotoPickerManageable.swift` | CoreUIComponents (Utilities) |
| `Common/Protocol/SinglePhotoPickerManageable.swift` | CoreUIComponents (Utilities) |
| `Common/Storage/DTOs/StorageUploadDTO.swift` | CoreFoundation (Storage) |
| `Common/Storage/Repositories/StorageRepository.swift` | CoreFoundation (Storage) |
| `Common/Storage/Repositories/StorageRepositoryProtocol.swift` | CoreFoundation (Storage) |
| `Common/Storage/Router/StorageRouter.swift` | CoreFoundation (Storage) |
| `Common/UIComponents/ArticleTextField/ArticleTextField.swift` | CoreUIComponents |
| `Common/UIComponents/ArticleTextField/ArticleTextFieldType.swift` | CoreUIComponents |
| `Common/UIComponents/Auth/LoginActionStack.swift` | CoreUIComponents |
| `Common/UIComponents/Auth/SocialLoginLabel.swift` | CoreUIComponents |
| `Common/UIComponents/Badge/AttendanceStatusBadge.swift` | CoreUIComponents |
| `Common/UIComponents/Badge/InfoBadge.swift` | CoreUIComponents |
| `Common/UIComponents/ChipButton/ChipButton.swift` | CoreUIComponents |
| `Common/UIComponents/ChipButton/ChipButtonEnvironment.swift` | CoreUIComponents |
| `Common/UIComponents/ChipButton/ChipButtonModifiers.swift` | CoreUIComponents |
| `Common/UIComponents/ChipButton/ChipButtonSize.swift` | CoreUIComponents |
| `Common/UIComponents/ChipButton/ChipButtonStyle.swift` | CoreUIComponents |
| `Common/UIComponents/ChromaticLens/ChromaticLens.swift` | CoreUIComponents |
| `Common/UIComponents/ChromaticLens/RefractiveCinematic.swift` | CoreUIComponents |
| `Common/UIComponents/Icon/CardIconImage.swift` | CoreUIComponents |
| `Common/UIComponents/Loading/LoadingView.swift` | CoreUIComponents |
| `Common/UIComponents/Logo/AuthLogoBlock.swift` | CoreUIComponents |
| `Common/UIComponents/Logo/Logo.swift` | CoreUIComponents |
| `Common/UIComponents/MainButton/MainButton.swift` | CoreUIComponents |
| `Common/UIComponents/MainButton/MainButtonEnvironment.swift` | CoreUIComponents |
| `Common/UIComponents/MainButton/MainButtonModifiers.swift` | CoreUIComponents |
| `Common/UIComponents/MainButton/MainButtonSize.swift` | CoreUIComponents |
| `Common/UIComponents/PlaceSelectView/MapPlacePickerView.swift` | CoreUIComponents |
| `Common/UIComponents/PlaceSelectView/POILongPressTip.swift` | CoreUIComponents |
| `Common/UIComponents/PlaceSelectView/PlaceSelectView.swift` | CoreUIComponents |
| `Common/UIComponents/Progress/Progress.swift` | CoreUIComponents |
| `Common/UIComponents/Progress/ProgressSize.swift` | CoreUIComponents |
| `Common/UIComponents/Section/SectionHeaderView.swift` | CoreUIComponents |
| `Common/UIComponents/Section/SectionRightImage.swift` | CoreUIComponents |
| `Common/UIComponents/SectionErrorCard/SectionErrorCard.swift` | CoreUIComponents |
| `Common/UIComponents/State/RetryContentUnavailableView.swift` | CoreUIComponents |
| `DIContainer/DIContainer.swift` | CoreDI |
| `DIContainer/UsecaseProvider.swift` | CoreDI |
| `Manager/Auth/AppleLoginManager.swift` | CoreNetwork (Auth) |
| `Manager/Auth/GoogleLoginManager.swift` | CoreNetwork (Auth) |
| `Manager/Auth/KakaoLoginManager.swift` | CoreNetwork (Auth) |
| `Manager/Auth/KakaoPlusManager.swift` | CoreNetwork (Auth) |
| `Manager/Auth/SocialLoginError.swift` | CoreNetwork (Auth) |
| `Manager/Location/LocationManager.swift` | 신규 CoreLocation 모듈 |
| `Manager/User/UserSessionManager.swift` | CoreDomain (또는 App 소유 세션) |
| `Mock/ActivityStudyTestView.swift` | ActivityPresentation/Sources/Mock |
| `Mock/AttendancePreviewData.swift` | ActivityDomain/Sources/Mock |
| `Mock/AttendanceTestWrapper.swift` | ActivityPresentation/Sources/Mock |
| `Mock/CurriculumPreviewData.swift` | ActivityDomain/Sources/Mock |
| `Mock/DesignPreview/ChromaticLens.metal` | App (UMCApp/UMCApp/Sources/Shaders) — staticFramework 는 metallib 이 앱 번들에 실리지 않으므로 앱 타겟 소유 |
| `Mock/DesignPreview/ChromaticLensPreview.swift` | CoreDesignSystem/Sources/Mock |
| `Mock/DesignPreview/LiquidIntroPreview.swift` | CoreDesignSystem/Sources/Mock |
| `Mock/DesignPreview/LoginPreview.swift` | AuthPresentation/Sources/Mock (Home부는 HomePresentation) |
| `Mock/MissionPreviewData.swift` | ActivityDomain/Sources/Mock |
| `Mock/MockChallengerAttendanceUseCase.swift` | ActivityDomain/Sources/Mock |
| `Mock/MyAttendanceHistoryTestView.swift` | ActivityPresentation/Sources/Mock |
| `Mock/MyPageMockData.swift` | MyPageDomain/Sources/Mock (CommunityItemModel부는 CoreDomain) |
| `Mock/NoticeMockData.swift` | NoticeDomain/Sources/Mock |
| `Mock/StudyGroupPreviewData.swift` | ActivityDomain/Sources/Mock |
| `Navigation/NavigationDestination.swift` | App (UMCApp/UMCApp/Sources) |
| `Navigation/NavigationRoutable.swift` | App (UMCApp/UMCApp/Sources) |
| `Navigation/NavigationRoutingView.swift` | App (UMCApp/UMCApp/Sources) |
| `Navigation/PathStore.swift` | App (UMCApp/UMCApp/Sources) |
| `NetworkAdapter/Authdependencies.swift` | CoreNetwork (Client) |
| `NetworkAdapter/Base/APIResponse.swift` | CoreNetwork (Client) |
| `NetworkAdapter/Base/BaseTargetType.swift` | CoreNetwork (Client) |
| `NetworkAdapter/NetworkClient/DefaultAuthenticationPolicy.swift` | CoreNetwork (Client) |
| `NetworkAdapter/NetworkClient/NetworkClient.swift` | CoreNetwork (Client) |
| `NetworkAdapter/NetworkClient/TokenPair.swift` | CoreNetwork (Client) |
| `NetworkAdapter/NetworkClient/TokenStoreProtocol.swift` | CoreNetwork (Client) |
| `NetworkAdapter/TokenRefreshService/MoyaNetworkAdapter.swift` | CoreNetwork (Client) |
| `NetworkAdapter/TokenRefreshService/TokenRefreshServiceImpl.swift` | CoreNetwork (Client) |
| `Secret/Config.swift` | UMCApp/Secret (앱, 미커밋) |

### Resource

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `EnvrionmentKey/AppFlowEnvironmentKey.swift` | App (UMCApp/UMCApp/Sources) |
| `EnvrionmentKey/AppSessionModeEnvironmentKey.swift` | App — dead code 정리 후보 |
| `EnvrionmentKey/DIEnvrionmentKey.swift` | CoreDI (\.di 키, 신규 파일) |
| `EnvrionmentKey/LogoutEnvironmentKey.swift` | App (UMCApp/UMCApp/Sources) |

### Utilities

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Extensions/Date+Calendar.swift` | CoreFoundation (Extensions) |
| `Extensions/Date+KST.swift` | CoreFoundation (Extensions) |
| `Extensions/Date+ScheduleDisplay.swift` | CoreFoundation (Extensions) |
| `Extensions/DateFormatter.swift` | CoreFoundation (Extensions) |
| `Extensions/Map+Category.swift` | CoreFoundation (Extensions) |
| `Extensions/Notification+Error.swift` | CoreFoundation (Extensions) |
| `Extensions/ServerDateTimeConverter.swift` | CoreFoundation (Extensions) |
| `Extensions/String.swift` | CoreFoundation (Extensions) |
| `Extensions/View+Alert.swift` | CoreFoundation (Extensions) |
| `Keychain/KeychainStored.swift` | CoreNetwork (Auth) |
| `Modifier/CapsuleModifier.swift` | CoreDesignSystem |
| `Modifier/DefaultBackgroundModifier.swift` | CoreUIComponents — 이미 이관됨 |
| `Modifier/KeyboardToolbarModifier.swift` | CoreUIComponents |
| `Modifier/NavigationModifier.swift` | CoreUIComponents — 이미 이관됨 |
| `Modifier/RainbowBorderModifier.swift` | CoreDesignSystem |
| `Modifier/SymbolDrawOnModifier.swift` | CoreDesignSystem (Modifiers) — 이미 이관됨 |
| `RemoteImage/RemoteImage.swift` | CoreUIComponents (Utilities) |
| `Shadow/ShadowReuse.swift` | CoreDesignSystem |
| `ToolBar/ToolBarCollection.swift` | CoreUIComponents (ToolBar) |
