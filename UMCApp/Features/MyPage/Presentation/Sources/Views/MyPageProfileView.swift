//
//  MyPageProfileView.swift
//  MyPage
//
//  Created by 김동민 on 7/8/26.
//

import AuthDomain
import CoreDI
import CoreDomain
import CoreUIComponents
import MyPageDomain
import PhotosUI
import SwiftUI
import UMCFoundation

/// 마이페이지 정보 Write & Read 화면입니다.
///
/// 사용자의 프로필 이미지, 닉네임, 학교, 활동 로그, 소셜 링크 등을 확인하고 수정할 수 있습니다.
public struct MyPageProfileView: View {

    // MARK: - Property

    @State private var viewModel: MyPageProfileViewModel
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler
    @Environment(\.dismiss) private var dismiss
    @State private var showAddActivityLogAlert: Bool = false
    @State private var challengerCode: String = ""
    @State private var alertPrompt: AlertPrompt?

    private enum Constants {
        static let schoolHeader = "학교"
        static let activityLogHeader = "활동 이력"
        static let profileLinkHeader = "외부 프로필 링크"

        static let codeAlertTitle = "챌린저 코드 입력"
        static let codeAlertMessage = "운영진에게 발급받은 6자리 코드를 입력해주세요."
        static let codeFieldPlaceholder = "6자리 코드"
        static let codeLength = 6
    }

    // MARK: - Init

    public init(container: DIContainer, profileData: ProfileData) {
        self._viewModel = .init(
            initialValue: .init(
                profileData: profileData,
                useCaseProvider: container.resolve(MyPageUseCaseProviding.self),
                fetchMyOAuthUseCase: container.resolve(FetchMyOAuthUseCaseProtocol.self),
                deleteMemberOAuthUseCase: container.resolve(DeleteMemberOAuthUseCaseProtocol.self)
            )
        )
    }

    // MARK: - Body

    public var body: some View {
        Form {
            sectionContent($viewModel.profileData)
        }
        .navigation(naviTitle: NavigationTitle.MyPage.profile, displayMode: .inline)
        .umcDefaultBackground()
        .toolbar {
            ToolBarCollection.ConfirmBtn(
                action: submitProfileUpdate,
                disable: !viewModel.canSubmit,
                isLoading: viewModel.isUpdatingProfileImage,
                dismissOnTap: false
            )
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { await viewModel.loadSelectedImage() }
        }
        .alert(
            Constants.codeAlertTitle,
            isPresented: $showAddActivityLogAlert,
            actions: challengerCodeAlertActions,
            message: challengerCodeAlertMessage
        )
        .alertPrompt(item: $alertPrompt)
    }

    // MARK: - View Component

    /// 섹션 구현부
    /// - Parameter profile: 프로필 데이터 바인딩
    @ViewBuilder
    private func sectionContent(_ profile: Binding<ProfileData>) -> some View {
        ProfileImagePicker(
            selectedPhotoItem: $viewModel.selectedPhotoItem,
            selectedImage: viewModel.selectedImage,
            profileImage: profile.wrappedValue.challengerInfo.profileImage
        )

        ConnectionSocial(
            socialConnections: profile.wrappedValue.socialConnections,
            disconnectingSocialType: viewModel.disconnectingSocialType,
            onDisconnect: presentDisconnectPrompt
        )

        NameAndNickname(
            name: profile.wrappedValue.challengerInfo.name,
            nickname: profile.wrappedValue.challengerInfo.nickname
        )

        SchoolSection(
            univ: profile.wrappedValue.challengerInfo.schoolName,
            header: Constants.schoolHeader
        )

        ActiveLogs(
            rows: profile.wrappedValue.activityLogs,
            header: Constants.activityLogHeader,
            onAddTap: { showAddActivityLogAlert = true },
            isAdding: viewModel.isAddingActivityLog,
            didRecentlyAdd: viewModel.didRecentlyAddActivityLog
        )

        ProfileLinkEditSection(
            profileLink: profile.profileLink,
            header: Constants.profileLinkHeader
        )
    }

    @ViewBuilder
    private func challengerCodeAlertActions() -> some View {
        TextField(Constants.codeFieldPlaceholder, text: $challengerCode)
            .keyboardType(.asciiCapable)

        Button("닫기", role: .cancel) {
            challengerCode = ""
        }

        Button("전송", action: submitChallengerCode)
    }

    private func challengerCodeAlertMessage() -> some View {
        Text(Constants.codeAlertMessage)
    }

    // MARK: - Function

    /// 프로필 수정(이미지·링크)을 서버에 제출하고 완료 시 화면을 닫습니다.
    private func submitProfileUpdate() {
        Task {
            do {
                try await viewModel.submitProfileUpdate()
                dismiss()
            } catch {
                errorHandler.handle(
                    error,
                    context: ErrorContext(feature: "MyPage", action: "submitProfileUpdate")
                )
            }
        }
    }

    /// 활동 이력 추가 코드를 서버에 전송하고, 성공 시 프로필과 로컬 세션 저장소를 갱신합니다.
    private func submitChallengerCode() {
        let trimmedCode = challengerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidChallengerCode(trimmedCode) else {
            errorHandler.handle(
                AppError.validation(
                    .invalidFormat(
                        field: "challengerCode",
                        expected: "\(Constants.codeLength)자리 영숫자 코드"
                    )
                ),
                context: ErrorContext(feature: "MyPage", action: "submitChallengerCode")
            )
            return
        }

        Task {
            defer { challengerCode = "" }

            do {
                try await viewModel.addActivityLog(code: trimmedCode)
                await syncProfileStorage()
            } catch let error as RepositoryError {
                presentCodeFailurePrompt(code: error.code, message: error.userMessage)
            } catch {
                errorHandler.handle(
                    error,
                    context: ErrorContext(feature: "MyPage", action: "addActivityLog")
                )
            }
        }
    }

    private func isValidChallengerCode(_ code: String) -> Bool {
        code.count == Constants.codeLength
            && code.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
    }

    /// 활동 이력이 추가되면 역할·기수가 바뀌므로 `AppStorageKey` 기반 로컬 세션 값도 맞춘다.
    ///
    /// 동기화 실패는 이력 추가 자체를 되돌리지 않으므로 화면 흐름을 끊지 않는다.
    private func syncProfileStorage() async {
        let fetchProfile = di.resolve(FetchMemberProfileUseCaseProtocol.self)

        guard let profile = try? await fetchProfile.execute() else { return }

        di.resolve(SyncProfileStorageUseCaseProtocol.self).execute(profile: profile)
    }

    private func presentCodeFailurePrompt(code: String?, message: String) {
        let resolvedMessage: String

        switch code {
        case "CHALLENGER-0002":
            resolvedMessage = "이미 등록된 사용자입니다."
        case "CHALLENGER-0012":
            resolvedMessage = "이미 사용된 챌린저 기록 추가용 코드입니다."
        case "CHALLENGER-0013":
            resolvedMessage = "코드에 등록된 사용자 이름이 요청자와 일치하지 않습니다."
        case "CHALLENGER-0014":
            resolvedMessage = "코드에 등록된 학교가 요청자 소속과 일치하지 않습니다."
        case "CHALLENGER-0016":
            resolvedMessage = "챌린저 기록 코드를 먼저 입력해주세요."
        default:
            resolvedMessage = Self.sanitizedErrorMessage(from: message)
        }

        alertPrompt = AlertPrompt(
            title: "인증 실패",
            message: resolvedMessage,
            positiveBtnTitle: "확인"
        )
    }

    private func presentDisconnectPrompt(_ connection: SocialConnection) {
        alertPrompt = AlertPrompt(
            title: "연동 해제",
            message: "\(connection.socialType.displayName) 계정 연동을 해제할까요?",
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
                presentDisconnectFailurePrompt(code: error.code, message: error.userMessage)
            } catch let error as NetworkError {
                // 연동 해제 거부는 서버가 본문 code로만 구분해 주므로 응답을 직접 열어본다.
                guard let serverError = Self.parseServerError(error) else {
                    errorHandler.handle(
                        error,
                        context: ErrorContext(feature: "MyPage", action: "disconnectSocial")
                    )
                    return
                }

                presentDisconnectFailurePrompt(
                    code: serverError.code,
                    message: serverError.message
                )
            } catch {
                errorHandler.handle(
                    error,
                    context: ErrorContext(feature: "MyPage", action: "disconnectSocial")
                )
            }
        }
    }

    private func presentDisconnectFailurePrompt(code: String?, message: String) {
        let resolvedMessage: String

        switch code {
        case "AUTHENTICATION-0016":
            resolvedMessage = "연동된 계정이 하나뿐이면 연동을 해제할 수 없습니다. 회원 탈퇴를 이용해주세요."
        default:
            resolvedMessage = Self.sanitizedErrorMessage(from: message)
        }

        alertPrompt = AlertPrompt(
            title: "연동 해제 불가",
            message: resolvedMessage,
            positiveBtnTitle: "확인"
        )
    }

    private static func parseServerError(
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

    /// 사용자에게 노출할 문구에서 `CHALLENGER-0012:` 같은 서버 코드 접두사를 걷어낸다.
    private static func sanitizedErrorMessage(from message: String) -> String {
        let trimmed = message
            .replacingOccurrences(
                of: #"^[A-Z]+-\d{4}\s*[:\-]?\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? "인증에 실패했습니다. 다시 시도해주세요." : trimmed
    }
}
