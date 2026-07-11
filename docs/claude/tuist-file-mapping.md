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
| `Data/DTOs/ScheduleListDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupCreateRequestDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupDetailDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupNameItemDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupScheduleCreateRequestDTO.swift` | ActivityData |
| `Data/DTOs/StudyGroupUpdateRequestDTO.swift` | ActivityData |
| `Data/DTOs/V2AttendanceParticipantDTO.swift` | ActivityData |
| `Data/Provider/ActivityRepositoryProvider.swift` | ActivityData |
| `Data/Repositories/ActivityRepository.swift` | ActivityData |
| `Data/Repositories/AttendanceRepository.swift` | ActivityData |
| `Data/Repositories/MemberRepository.swift` | ActivityData |
| `Data/Repositories/Mock/MockActivityRepository.swift` | ActivityData |
| `Data/Repositories/Mock/MockAttendanceRepository.swift` | ActivityData |
| `Data/Repositories/Mock/MockMemberRepository.swift` | ActivityData |
| `Data/Repositories/Mock/MockStudyRepository.swift` | ActivityData |
| `Data/Repositories/StudyRepository.swift` | ActivityData |
| `Data/Router/StudyRouter.swift` | ActivityData |
| `Domain/Enum/ActivityConstants.swift` | ActivityDomain |
| `Domain/Enum/ActivitySection.swift` | ActivityDomain |
| `Domain/Enum/Attendance/AttendanceStatus.swift` | ActivityDomain |
| `Domain/Enum/Attendance/AttendanceStatusV2.swift` | ActivityDomain |
| `Domain/Enum/Attendance/AttendanceTimeWindow.swift` | ActivityDomain |
| `Domain/Enum/Attendance/MyAttendanceItemStatus.swift` | ActivityDomain |
| `Domain/Enum/Session/SessionStatus.swift` | ActivityDomain |
| `Domain/Enum/Study/MissionStatus.swift` | ActivityDomain |
| `Domain/Enum/Study/MissionSubmissionType.swift` | ActivityDomain |
| `Domain/Enum/Study/MissionType.swift` | ActivityDomain |
| `Domain/Interfaces/ActivityRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/ChallengerAttendanceRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/MemberRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/OperatorAttendanceRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Interfaces/StudyRepositoryProtocol.swift` | ActivityDomain |
| `Domain/Models/Attendance/Attendance.swift` | ActivityDomain |
| `Domain/Models/Attendance/AttendanceDecisionResult.swift` | ActivityDomain |
| `Domain/Models/Attendance/AttendanceGeofenceConstants.swift` | ActivityDomain |
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
| `Domain/Models/Operator/ScheduleAttendanceStats.swift` | ActivityDomain |
| `Domain/Models/Session/Session.swift` | ActivityDomain |
| `Domain/Models/Session/SessionInfo.swift` | ActivityDomain |
| `Domain/Models/Study/CurriculumProgressModel.swift` | ActivityDomain |
| `Domain/Models/Study/MissionCardModel.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupDetailsPage.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupInfo.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupItem.swift` | ActivityDomain |
| `Domain/Models/Study/StudyGroupMember.swift` | ActivityDomain |
| `Domain/Models/Study/WeeklyCurriculumOption.swift` | ActivityDomain |
| `Domain/Models/StudyManagement/StudyManagementItem.swift` | ActivityDomain |
| `Domain/UseCases/ChallengerAttendanceUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchCurriculumUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchMembersUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchSessionsUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchStudyMembersUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/FetchUserIdUseCaseProtocol.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/ChallengerAttendanceUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/FetchCurriculumUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/FetchMembersUseCase.swift` | ActivityDomain |
| `Domain/UseCases/Implementations/FetchSessionsUseCase.swift` | ActivityDomain |
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
| `Presentation/Components/CoreStudyManagementList.swift` | ActivityPresentation |
| `Presentation/Components/Map/ActivityCompactMapView.swift` | ActivityPresentation |
| `Presentation/Components/Map/BaseMapComponent.swift` | ActivityPresentation |
| `Presentation/Components/Member/CoreMemberManagementList.swift` | ActivityPresentation |
| `Presentation/Components/Member/MemberManagementCard.swift` | ActivityPresentation |
| `Presentation/Components/Member/PointGrantFormSheet.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Attendance/OperatorLocationChangeSheetView.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Attendance/OperatorSessionStatusIcon.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Attendance/OperatorStatusSectionStyle.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/OperatorStudyGroupEditSheet.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/StudyGroupCard.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/StudyGroupLeaderRow.swift` | ActivityPresentation |
| `Presentation/Components/Operation/Study/StudyGroupMemberChip.swift` | ActivityPresentation |
| `Presentation/Components/StudyManagementCard.swift` | ActivityPresentation |
| `Presentation/Enum/AttendancePeriodPreset.swift` | ActivityPresentation |
| `Presentation/Extensions/OperatorSessionStatus+UI.swift` | ActivityPresentation |
| `Presentation/Provider/ActivityUseCaseProvider.swift` | ActivityPresentation |
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
| `Presentation/Views/Operation/AttendanceListView.swift` | ActivityPresentation |
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
| `Data/DTOs/LoginByIdPwResponseDTO.swift` | AuthData |
| `Data/DTOs/LoginGoogleRequestDTO.swift` | AuthData |
| `Data/DTOs/LoginKakaoRequestDTO.swift` | AuthData |
| `Data/DTOs/MemberOAuthDTO.swift` | AuthData |
| `Data/DTOs/OAuthLoginResponseDTO.swift` | AuthData |
| `Data/DTOs/RegisterByIdPwResponseDTO.swift` | AuthData |
| `Data/DTOs/RegisterCredentialRequestDTO.swift` | AuthData |
| `Data/DTOs/RegisterExistingChallengerRequestDTO.swift` | AuthData |
| `Data/DTOs/RegisterRequestDTO.swift` | AuthData |
| `Data/DTOs/RegisterResponseDTO.swift` | AuthData |
| `Data/DTOs/RenewTokenRequestDTO.swift` | AuthData |
| `Data/DTOs/ResendEmailVerificationRequestDTO.swift` | AuthData |
| `Data/DTOs/ResetPasswordRequestDTO.swift` | AuthData |
| `Data/DTOs/SchoolDTO.swift` | AuthData |
| `Data/DTOs/SendEmailVerificationRequestDTO.swift` | AuthData |
| `Data/DTOs/TermsDTO.swift` | AuthData |
| `Data/DTOs/TokenRenewResponseDTO.swift` | AuthData |
| `Data/DTOs/VerifyEmailCodeRequestDTO.swift` | AuthData |
| `Data/DTOs/VerifyEmailCodeResponseDTO.swift` | AuthData |
| `Data/Provider/AuthRepositoryProvider.swift` | AuthData |
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
| `Presentation/Components/UnderlineTextField.swift` | AuthPresentation |
| `Presentation/Enum/SignUpByIdPwField.swift` | AuthPresentation |
| `Presentation/Enum/SignUpFieldType.swift` | AuthPresentation |
| `Presentation/Models/PostRegisterLoginContext.swift` | CoreFoundation (AppFlow) — `AppFlow.showSignUp`가 Core에서 이 타입을 요구해 이관(#944 Q6, `SocialType`과 동일 사유) |
| `Presentation/Provider/AuthUseCaseProvider.swift` | AuthPresentation |
| `Presentation/ViewModels/ChangePasswordViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/FailedVerificationUMCViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/LoginByIdPwViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/LoginViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/ResetPasswordViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/SignUpByIdPwViewModel.swift` | AuthPresentation |
| `Presentation/ViewModels/SignUpViewModel.swift` | AuthPresentation |
| `Presentation/Views/ChangePasswordView.swift` | AuthPresentation |
| `Presentation/Views/FailedVerificationUMC.swift` | AuthPresentation |
| `Presentation/Views/LoginByIdPwView.swift` | AuthPresentation |
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
| `Data/DTO/AttendanceDetailQuery.swift` | HomeData |
| `Data/DTO/AttendanceListQuery.swift` | HomeData |
| `Data/DTO/ChallengerMemeberDTO.swift` | HomeData |
| `Data/DTO/ChallengerSearchDTO.swift` | HomeData |
| `Data/DTO/GenerateScheduleRequetDTO.swift` | HomeData |
| `Data/DTO/GisuDetailDTO.swift` | HomeData |
| `Data/DTO/HomeScheduleDTO.swift` | HomeData |
| `Data/DTO/MyProfileDTO.swift` | CoreNetwork (Member — MemberProfileResponseDTO로 통합, #961) |
| `Data/DTO/MySchedulesQuery.swift` | HomeData |
| `Data/DTO/NoticeListDTO.swift` | HomeData |
| `Data/DTO/RegisterFCMTokenRequestDTO.swift` | HomeData |
| `Data/DTO/ScheduleCapabilitiesDTO.swift` | HomeData |
| `Data/DTO/ScheduleDetailDTO.swift` | HomeData |
| `Data/DTO/ScheduleParticipantDTO.swift` | HomeData |
| `Data/DTO/UpdateScheduleRequestDTO.swift` | HomeData |
| `Data/DTO/V2AttendancePolicyDTO.swift` | HomeData |
| `Data/DTO/V2LocationDTO.swift` | HomeData |
| `Data/GenerationMappingRecord.swift` | HomeData |
| `Data/Repository/ChallengerGenRepository.swift` | HomeData |
| `Data/Repository/ChallengerSearchRepository.swift` | HomeData |
| `Data/Repository/HomeRepository.swift` | HomeData |
| `Data/Repository/MockHomeRepository.swift` | HomeData |
| `Data/Repository/ScheduleCapabilitiesRepository.swift` | HomeData |
| `Data/Repository/ScheduleRepository.swift` | HomeData |
| `Data/Router/ChallengerSearchRouter.swift` | HomeData |
| `Data/Router/HomeRouter.swift` | HomeData |
| `Data/Router/ScheduleV2Router.swift` | HomeData |
| `Domain/Impl/Notice/NoticeClassifierRepositoryImpl.swift` | HomeDomain |
| `Domain/Impl/Notice/NoticeClassifierUseCaseImpl.swift` | HomeDomain |
| `Domain/Impl/Schedule/ScheduleClassifierRepositoryImpl.swift` | HomeDomain |
| `Domain/Impl/Schedule/ScheduleClassifierUseCaseImpl.swift` | HomeDomain |
| `Domain/Interface/ChallengerGenRepositoryProtocol.swift` | HomeDomain |
| `Domain/Interface/ChallengerSearchRepositoryProtocol.swift` | HomeDomain |
| `Domain/Interface/HomeRepositoryProtocol.swift` | HomeDomain |
| `Domain/Interface/Notice/NoticeClassifierRepository.swift` | HomeDomain |
| `Domain/Interface/Notice/NoticeClassifierUseCase.swift` | HomeDomain |
| `Domain/Interface/Schedule/ScheduleClassifierRepository.swift` | HomeDomain |
| `Domain/Interface/Schedule/ScheduleClassifierUseCase.swift` | HomeDomain |
| `Domain/Interface/ScheduleCapabilitiesRepositoryProtocol.swift` | HomeDomain |
| `Domain/Interface/ScheduleRepositoryProtocol.swift` | HomeDomain |
| `Domain/Models/Home/ChallengerRole.swift` | HomeDomain |
| `Domain/Models/Home/GenerationData.swift` | HomeDomain |
| `Domain/Models/Home/RecentNoticeData.swift` | HomeDomain |
| `Domain/Models/Home/ScheduleData.swift` | HomeDomain |
| `Domain/Models/Home/ScheduleDetailData.swift` | HomeDomain |
| `Domain/Models/NoticeHistory/NoticeHistoryData.swift` | HomeDomain |
| `Domain/Models/Schedule/AttendancePolicy.swift` | HomeDomain |
| `Domain/Models/Schedule/AttendancePolicyError.swift` | HomeDomain |
| `Domain/Models/Schedule/ScheduleCapabilities.swift` | HomeDomain |
| `Domain/Models/Schedule/ScheduleLocation.swift` | HomeDomain |
| `Domain/Models/Schedule/ScheduleParticipant.swift` | HomeDomain |
| `Domain/Models/ScheduleGeneration/CSVImportResult.swift` | HomeDomain |
| `Domain/Models/ScheduleGeneration/PlaceSearchResult.swift` | HomeDomain |
| `Domain/Models/ScheduleGeneration/RecentPlace.swift` | HomeDomain |
| `Domain/Models/ScheduleGeneration/ScheduleRegistrationData.swift` | HomeDomain |
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
| `Domain/UseCases/Implementations/SearchChallengersUseCase.swift` | HomeDomain |
| `Domain/UseCases/Implementations/UpdateScheduleUseCase.swift` | HomeDomain |
| `Domain/UseCases/RegisterFCMTokenUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/SearchChallengersUseCaseProtocol.swift` | HomeDomain |
| `Domain/UseCases/UpdateScheduleUseCaseProtocol.swift` | HomeDomain |
| `Presentation/Components/Card/ChallengerSearchCard.swift` | HomePresentation |
| `Presentation/Components/Card/NoticeAlarmCard.swift` | HomePresentation |
| `Presentation/Components/Card/PenaltyCard.swift` | HomePresentation |
| `Presentation/Components/Card/RecentNoticeCard.swift` | HomePresentation |
| `Presentation/Components/Card/ScheduleCard.swift` | HomePresentation |
| `Presentation/Components/Card/ScheduleListCard.swift` | HomePresentation |
| `Presentation/Components/Card/SeasonCard.swift` | HomePresentation |
| `Presentation/Components/Map/SelectedPlaceAnnotation.swift` | HomePresentation |
| `Presentation/Components/Row/DatePickerRow.swift` | HomePresentation |
| `Presentation/Components/Row/DateTimeRow.swift` | HomePresentation |
| `Presentation/Components/Row/TimePickerRow.swift` | HomePresentation |
| `Presentation/Components/Schedule/AttendancePolicyDisplaySection.swift` | HomePresentation |
| `Presentation/Components/Schedule/AttendancePolicyTimeSection.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/CalendarGridCard.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/CalendarHorizonCard.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/DateCell.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/DatePill.swift` | HomePresentation |
| `Presentation/Components/Schedule/Calendar/ScheduleHeader.swift` | HomePresentation |
| `Presentation/Components/Schedule/InPersonToggle.swift` | HomePresentation |
| `Presentation/Enum/NoticeAlarmType.swift` | HomePresentation |
| `Presentation/Enum/PenalyInfoType.swift` | HomePresentation |
| `Presentation/Enum/RecentCategory.swift` | HomePresentation |
| `Presentation/Enum/ScheduleCategory.swift` | HomePresentation |
| `Presentation/Enum/ScheduleGenerationType.swift` | HomePresentation |
| `Presentation/Enum/ScheduleMode.swift` | HomePresentation |
| `Presentation/Enum/SeasonType.swift` | HomePresentation |
| `Presentation/Provider/HomeUseCaseProvider.swift` | HomePresentation |
| `Presentation/ViewModels/HomeViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/InlineMapPickerState.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleDetailViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleDraft.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleRegistrationViewModel+AI.swift` | HomePresentation |
| `Presentation/ViewModels/ScheduleRegistrationViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/SearchChallengerViewModel.swift` | HomePresentation |
| `Presentation/ViewModels/SearchPlaceViewModel.swift` | HomePresentation |
| `Presentation/Views/HomeView.swift` | HomePresentation |
| `Presentation/Views/NoticeAlarmView.swift` | HomePresentation |
| `Presentation/Views/Registration/Challenger/ChallengerFormView.swift` | HomePresentation |
| `Presentation/Views/Registration/Challenger/SearchChallengerView.swift` | HomePresentation |
| `Presentation/Views/Registration/Challenger/SelectedChallengerView.swift` | HomePresentation |
| `Presentation/Views/Registration/InlineMapPlacePicker.swift` | HomePresentation |
| `Presentation/Views/Registration/ScheduleDetailView.swift` | HomePresentation |
| `Presentation/Views/Registration/ScheduleRegistrationView.swift` | HomePresentation |
| `Presentation/Views/Registration/SearchPlaceResultRow.swift` | HomePresentation |
| `Presentation/Views/Registration/SearchPlaceView.swift` | HomePresentation |
| `Presentation/Views/Registration/TagListView.swift` | HomePresentation |

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
| `Presentation/Components/Section/MypageSection/FollowsSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/HelpSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/LawSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/LinkSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/MyActiveLogSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/ProfileCardSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/SettingSection.swift` | MyPagePresentation |
| `Presentation/Components/Section/MypageSection/SocialSection.swift` | MyPagePresentation |
| `Presentation/Enum/AuthType.swift` | MyPagePresentation |
| `Presentation/Enum/FollowType.swift` | MyPagePresentation |
| `Presentation/Enum/HelpType.swift` | MyPagePresentation |
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
| `Data/AITokenDailyUsageRecord.swift` | NoticeData |
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
| `Domain/Enums/NoticeItemTag.swift` | NoticeDomain |
| `Domain/Enums/NoticeRequestFactory.swift` | NoticeDomain |
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
| `Presentation/Enum/TabCase.swift` | App(UMCApp) — 루트 탭 셸 #910 |
| `Presentation/Views/UmcBottonAccessoryView.swift` | App(UMCApp) — 루트 탭 셸 #910 |
| `Presentation/Views/UmcTab.swift` | App(UMCApp) — 루트 탭 셸 #910 |

### App

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `AppDelegate.swift` | App(UMCApp) 진입점 |
| `AppProductApp.swift` | App(UMCApp) 진입점 |

### Core

| 레거시 파일 | → Tuist 목적지 |
|---|---|
| `Alert/AlertPromprt.swift` | CoreFoundation (Alert) |
| `Common/Authorization/DTOs/ResourcePermissionDTO.swift` | CoreNetwork (Authorization/DTOs) |
| `Common/Authorization/Models/ResourcePermission.swift` | CoreFoundation (Model) |
| `Common/Authorization/Repositories/AuthorizationRepository.swift` | CoreNetwork (Authorization) |
| `Common/Authorization/Repositories/AuthorizationRepositoryProtocol.swift` | CoreFoundation (Model) |
| `Common/Authorization/Router/AuthorizationRouter.swift` | CoreNetwork (Authorization) |
| `Common/Authorization/UseCases/AuthorizationUseCase.swift` | CoreFoundation (Model) |
| `Common/Authorization/UseCases/AuthorizationUseCaseProtocol.swift` | CoreFoundation (Model) |
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
| `Manager/Auth/KakaoPlusManager.swift` | CoreFoundation (신규 Support 서브폴더) |
| `Manager/Auth/SocialLoginError.swift` | CoreNetwork (Auth) |
| `Manager/Location/LocationManager.swift` | 신규 CoreLocation 모듈 |
| `Manager/User/UserSessionManager.swift` | CoreDomain (또는 App 소유 세션) |
| `Mock/ActivityStudyTestView.swift` | ActivityPresentation/Sources/Mock |
| `Mock/AttendancePreviewData.swift` | ActivityDomain/Sources/Mock |
| `Mock/AttendanceTestWrapper.swift` | ActivityPresentation/Sources/Mock |
| `Mock/CurriculumPreviewData.swift` | ActivityDomain/Sources/Mock |
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
| `Modifier/SymbolDrawOnModifier.swift` | CoreDesignSystem |
| `RemoteImage/RemoteImage.swift` | CoreUIComponents (Utilities) |
| `Shadow/ShadowReuse.swift` | CoreDesignSystem |
| `ToolBar/ToolBarCollection.swift` | CoreUIComponents (ToolBar) |
