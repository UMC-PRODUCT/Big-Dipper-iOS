//
//  ModifyMyPageView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/26/26.
//

import SwiftUI
import PhotosUI

/// 마이페이지 정보 Write & Read 화면입니다.
///
/// 사용자의 프로필 이미지, 닉네임, 학교, 활동 로그, 소셜 링크 등을 확인하고 수정할 수 있습니다.
struct MyPageProfileView: View {
    /// 뷰모델 상태 객체
    @State var viewModel: MyPageProfileViewModel
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFlow) private var appFlow
    @Environment(\.appSessionMode) private var sessionMode
    @State private var showAddActivityLogAlert: Bool = false
    @State private var challengerCode: String = ""
    @State private var alertPrompt: AlertPrompt?
    @State private var showGuestToast: Bool = false

    init(container: DIContainer, profileData: ProfileData) {
        let provider = container.resolve(MyPageUseCaseProviding.self)
        let authProvider = container.resolve(AuthUseCaseProviding.self)
        self._viewModel = .init(
            initialValue: .init(
                profileData: profileData,
                useCaseProvider: provider,
                authUseCaseProvider: authProvider
            )
        )
    }
    
    var body: some View {
        Form {
            sectionContentImpl($viewModel.profileData)
        }
        .navigation(naviTitle: .myProfile, displayMode: .inline)
        .toolbar(content: {
            // 완료 버튼
            ToolBarCollection.ConfirmBtn(
                action: { submitProfileUpdate() },
                disable: !viewModel.canSubmit,
                isLoading: viewModel.isUpdatingProfileImage,
                dismissOnTap: false
            )
        })
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task {
                await viewModel.loadSelectedImage()
            }
        }
        .alert(
            "챌린저 코드 입력",
            isPresented: $showAddActivityLogAlert,
            actions: challengerCodeAlertActions,
            message: challengerCodeAlertMessage
        )
        .alertPrompt(item: $alertPrompt)
        .guestActionToast(isPresented: $showGuestToast) {
            appFlow.showLogin()
        }
    }
    
    /// 섹션 구현부
    /// - Parameter profile: 프로필 데이터 바인딩
    @ViewBuilder
    private func sectionContentImpl(_ profile: Binding<ProfileData>) -> some View {
        // 프로필 이미지 수정
        ProfileImagePicker(selectedPhotoItem: $viewModel.selectedPhotoItem, selectedImage: viewModel.selectedImage, profileImage: viewModel.profileData.challangerInfo.profileImage)
        // 연동된 소셜 계정 정보
        ConnectionSocial(
            socialConnections: profile.socialConnections.wrappedValue,
            disconnectingSocialType: viewModel.disconnectingSocialType,
            header: "연동된 계정",
            onDisconnect: presentDisconnectPrompt
        )
        // 이름 및 닉네임 (읽기 전용)
        NameAndNickname(
            name: profile.challangerInfo.wrappedValue.name,
            nickaname: profile.challangerInfo.wrappedValue.nickname
        )
        // 학교 (읽기 전용)
        SchoolSection(univ: profile.challangerInfo.wrappedValue.schoolName, header: "학교")
        // 활동 이력 목록
        ActiveLogs(
            rows: profile.activityLogs.wrappedValue,
            header: "활동 이력",
            onAddTap: { showAddActivityLogAlert = true },
            isAdding: viewModel.isAddingActivityLog,
            didRecentlyAdd: viewModel.didRecentlyAddActivityLog
        )
        // 외부 프로필 링크 수정
        ProfileLinkSection(profileLink: profile.profileLink, header: "외부 프로링크")
    }

    @ViewBuilder
    private func challengerCodeAlertActions() -> some View {
        TextField("6자리 코드", text: $challengerCode)
            .keyboardType(.asciiCapable)

        Button("닫기", role: .cancel) {
            challengerCode = ""
        }

        Button("전송") {
            submitChallengerCode()
        }
    }

    @ViewBuilder
    private func challengerCodeAlertMessage() -> some View {
        Text("운영진에게 발급받은 6자리 코드를 입력해주세요.")
    }

    /// 프로필 이미지 업데이트를 서버에 제출하고 완료 시 화면을 dismiss합니다.
    ///
    /// 실패 시 ErrorHandler를 통해 Alert를 표시합니다.
    private func submitProfileUpdate() {
        Task {
            do {
                try await viewModel.submitProfileUpdate()
                if sessionMode.isGuest {
                    showGuestToast = true
                }
                dismiss()
            } catch {
                errorHandler.handle(
                    error,
                    context: .init(
                        feature: "MyPage",
                        action: "submitProfileUpdate"
                    )
                )
            }
        }
    }

    /// 활동 이력 추가 코드를 서버에 전송하고, 성공 시 프로필을 갱신합니다.
    private func submitChallengerCode() {
        let trimmedCode = challengerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAlphanumeric = trimmedCode.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        guard trimmedCode.count == 6, isAlphanumeric else {
            errorHandler.handle(
                AppError.validation(
                    .invalidFormat(field: "challengerCode", expected: "6자리 영숫자 코드")
                ),
                context: .init(feature: "MyPage", action: "submitChallengerCode")
            )
            return
        }

        Task {
            do {
                try await viewModel.addActivityLog(code: trimmedCode)
                await MainActor.run {
                    challengerCode = ""
                }
                let profile = try await di.resolve(HomeUseCaseProviding.self)
                    .fetchMyProfileUseCase
                    .execute()
                await MainActor.run {
                    syncProfileToStorage(profile)
                }
            } catch let error as RepositoryError {
                await MainActor.run {
                    challengerCode = ""
                    presentCodeFailurePrompt(for: error)
                }
            } catch {
                await MainActor.run {
                    challengerCode = ""
                }
                errorHandler.handle(
                    error,
                    context: .init(feature: "MyPage", action: "addActivityLog")
                )
            }
        }
    }

    private func presentCodeFailurePrompt(for error: RepositoryError) {
        let message: String

        switch error.code {
        case "CHALLENGER-0002":
            message = "이미 등록된 사용자입니다."
        case "CHALLENGER-0012":
            message = "이미 사용된 챌린저 기록 추가용 코드입니다."
        case "CHALLENGER-0013":
            message = "코드에 등록된 사용자 이름이 요청자와 일치하지 않습니다."
        case "CHALLENGER-0014":
            message = "코드에 등록된 학교가 요청자 소속과 일치하지 않습니다."
        case "CHALLENGER-0016":
            message = "챌린저 기록 코드를 먼저 입력해주세요."
        default:
            message = sanitizedErrorMessage(from: error.userMessage)
        }

        alertPrompt = AlertPrompt(
            title: "인증 실패",
            message: message,
            positiveBtnTitle: "확인"
        )
    }

    private func syncProfileToStorage(_ profile: HomeProfileResult) {
        let defaults = UserDefaults.standard
        let latestRole = latestHighestPriorityRole(in: profile.roles)
        let resolvedRole = ManagementTeam.highestPriority(
            in: profile.roles.map(\.roleType)
        ) ?? latestRole?.roleType ?? .challenger

        defaults.set(profile.memberId, forKey: AppStorageKey.memberId)
        defaults.set(profile.schoolId, forKey: AppStorageKey.schoolId)
        defaults.set(profile.schoolName, forKey: AppStorageKey.schoolName)
        defaults.set(profile.latestGisuId ?? 0, forKey: AppStorageKey.gisuId)
        defaults.set(profile.latestChallengerId ?? 0, forKey: AppStorageKey.challengerId)
        defaults.set(profile.chapterId ?? 0, forKey: AppStorageKey.chapterId)
        defaults.set(profile.chapterName, forKey: AppStorageKey.chapterName)
        defaults.set(profile.part?.apiValue ?? "", forKey: AppStorageKey.responsiblePart)
        defaults.set(
            latestRole?.organizationType.rawValue ?? OrganizationType.chapter.rawValue,
            forKey: AppStorageKey.organizationType
        )
        defaults.set(
            latestRole?.organizationId ?? (profile.chapterId ?? 0),
            forKey: AppStorageKey.organizationId
        )
        defaults.set(resolvedRole.rawValue, forKey: AppStorageKey.memberRole)
        defaults.set(
            profile.roles.map(\.roleType.rawValue),
            forKey: AppStorageKey.memberRoles
        )
        defaults.set(
            encodeGenerationOrganizations(profile.generationOrganizations),
            forKey: AppStorageKey.generationOrganizations
        )
        defaults.set(isApprovedProfile(profile), forKey: AppStorageKey.canAutoLogin)
        syncGenerationMappings(profile.generations)

        di.resolve(UserSessionManager.self).updateRole(
            resolvedRole,
            allRoles: profile.roles.map(\.roleType)
        )
        NotificationCenter.default.post(name: .memberProfileUpdated, object: nil)
    }

    private func encodeGenerationOrganizations(_ contexts: [GenerationOrganizationContext]) -> String {
        guard let data = try? JSONEncoder().encode(contexts),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func syncGenerationMappings(_ generations: [GenerationData]) {
        let pairs = generations.map { (gen: $0.gen, gisuId: $0.gisuId) }

        do {
            let repository = di.resolve(ChallengerGenRepositoryProtocol.self)
            try repository.replaceMappings(pairs)
            NotificationCenter.default.post(name: .generationMappingsUpdated, object: nil)
        } catch {
            print("[MyPage] failed to sync generation mappings: \(error)")
        }
    }

    private func isApprovedProfile(_ profile: HomeProfileResult) -> Bool {
        if !profile.generations.isEmpty {
            return true
        }

        for seasonType in profile.seasonTypes {
            if case .gens(let generations) = seasonType, !generations.isEmpty {
                return true
            }
        }

        return false
    }

    private func latestHighestPriorityRole(
        in roles: [ChallengerRole]
    ) -> ChallengerRole? {
        guard let latestGisu = roles.map(\.gisu).max() else {
            return nil
        }

        return roles
            .filter { $0.gisu == latestGisu }
            .max { lhs, rhs in
                lhs.roleType < rhs.roleType
            }
    }

    private func sanitizedErrorMessage(from message: String) -> String {
        let pattern = #"^[A-Z]+-\d{4}\s*[:\-]?\s*"#
        let sanitized = message.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "인증에 실패했습니다. 다시 시도해주세요." : trimmed
    }

    private func presentDisconnectPrompt(_ connection: SocialConnection) {
        alertPrompt = AlertPrompt(
            title: "연동 해제",
            message: "\(connection.socialType.rawValue) 계정 연동을 해제할까요?",
            positiveBtnTitle: "해제",
            positiveBtnAction: { disconnectSocial(connection) },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    private func disconnectSocial(_ connection: SocialConnection) {
        Task {
            do {
                try await viewModel.disconnectSocial(connection)
            } catch let error as RepositoryError {
                await MainActor.run {
                    presentDisconnectFailurePrompt(for: error)
                }
            } catch let error as NetworkError {
                if let disconnectError = parseDisconnectNetworkError(error) {
                    await MainActor.run {
                        presentDisconnectFailurePrompt(
                            code: disconnectError.code,
                            message: disconnectError.message
                        )
                    }
                } else {
                    errorHandler.handle(
                        error,
                        context: .init(feature: "MyPage", action: "disconnectSocial")
                    )
                }
            } catch {
                errorHandler.handle(
                    error,
                    context: .init(feature: "MyPage", action: "disconnectSocial")
                )
            }
        }
    }

    private func presentDisconnectFailurePrompt(for error: RepositoryError) {
        presentDisconnectFailurePrompt(
            code: error.code,
            message: error.userMessage
        )
    }

    private func presentDisconnectFailurePrompt(code: String?, message: String) {
        let resolvedMessage: String

        switch code {
        case "AUTHENTICATION-0016":
            resolvedMessage = "연동된 계정이 하나뿐이면 연동을 해제할 수 없습니다. 회원 탈퇴를 이용해주세요."
        default:
            resolvedMessage = sanitizedErrorMessage(from: message)
        }

        alertPrompt = AlertPrompt(
            title: "연동 해제 불가",
            message: resolvedMessage,
            positiveBtnTitle: "확인"
        )
    }

    private func parseDisconnectNetworkError(
        _ error: NetworkError
    ) -> (code: String?, message: String)? {
        guard case .requestFailed(_, let data) = error,
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return (
            code: json["code"] as? String,
            message: (json["message"] as? String) ?? error.userMessage
        )
    }
}

#if DEBUG
// MARK: - Preview

private var myPageProfilePreviewContainer: DIContainer {
    let container = DIContainer()
    container.register(PathStore.self) { PathStore() }
    container.register(MyPageUseCaseProviding.self) {
        MyPageUseCaseProvider(repository: MockMyPageRepository())
    }
    container.register(AuthUseCaseProviding.self) {
        AuthUseCaseProvider(
            repositoryProvider: AuthRepositoryProvider.mock(),
            tokenStore: KeychainTokenStore()
        )
    }
    return container
}

#Preview("MyPage Profile") {
    let container = myPageProfilePreviewContainer
    return NavigationStack {
        MyPageProfileView(
            container: container,
            profileData: MyPageMockData.profile
        )
    }
    .environment(\.di, container)
    .environment(ErrorHandler())
}
#endif
