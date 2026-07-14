//
//  FailedVerificationUMCViewModel.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/10/26.
//

import AuthDomain
import CoreDI
import CoreDomain
import CoreNetwork
import Foundation
import MyPageDomain
import UMCFoundation

/// 승인 대기 화면(`FailedVerificationUMC`)에서 완료된 액션이 향할 다음 화면.
///
/// 절대규칙에 따라 ViewModel은 `AppFlow`를 직접 들고 있지 않는다. `FailedVerificationUMC`가
/// 이 값을 관찰해 실제 전환 클로저(`appFlow.showLogin()`/`appFlow.showMain()`)를 호출한다
/// (`LoginViewModel.signUpDestination`과 동일한 패턴).
enum FailedVerificationDestination: Equatable {
    case login
    case main
}

/// 승인 대기(#945) 화면의 상태와 액션을 관리하는 ViewModel.
///
/// 기존 챌린저 코드 재인증, 로그아웃, 회원 탈퇴 흐름을 조율하며 화면에 필요한
/// 얼럿 상태도 함께 제공한다.
@Observable
final class FailedVerificationUMCViewModel {

    // MARK: - Property

    private let registerExistingChallengerUseCase: RegisterExistingChallengerUseCaseProtocol
    private let fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol
    private let deleteMemberUseCase: DeleteMemberUseCaseProtocol
    private let syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol
    private let userSessionManager: UserSessionManager
    private let networkClient: NetworkClient
    private let container: DIContainer
    private let errorHandler: ErrorHandler

    /// 상단 경고 아이콘의 pulse 애니메이션 활성화 상태.
    var showWarning: Bool = false

    /// 기존 챌린저 코드 입력 얼럿 표시 상태.
    var showCodeAlert: Bool = false

    /// 화면 전반에서 재사용하는 `AlertPrompt` 상태.
    var alertPrompt: AlertPrompt?

    /// 기존 챌린저 코드 인증 요청 진행 상태.
    var isSubmitting: Bool = false

    /// 회원 탈퇴 요청 진행 상태.
    var isDeletingAccount: Bool = false

    /// 로그아웃 요청 진행 상태.
    var isLoggingOut: Bool = false

    /// 사용자가 입력한 기존 챌린저 코드.
    var challengerCode: String = ""

    /// 로그아웃/탈퇴/승인 완료 후 전환할 화면. `FailedVerificationUMC`가 관찰한다.
    private(set) var destination: FailedVerificationDestination?

    // MARK: - Init

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.registerExistingChallengerUseCase = container.resolve(
            RegisterExistingChallengerUseCaseProtocol.self
        )
        self.fetchMemberProfileUseCase = container.resolve(FetchMemberProfileUseCaseProtocol.self)
        self.deleteMemberUseCase = container.resolve(DeleteMemberUseCaseProtocol.self)
        self.syncProfileStorageUseCase = container.resolve(SyncProfileStorageUseCaseProtocol.self)
        self.userSessionManager = container.resolve(UserSessionManager.self)
        self.networkClient = container.resolve(NetworkClient.self)
        self.container = container
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    /// 기존 챌린저 코드 입력 얼럿을 표시한다.
    func presentCodeAlert() {
        showCodeAlert = true
    }

    /// 코드 입력 얼럿을 닫기 전 입력값을 초기화한다.
    func dismissCodeAlert() {
        challengerCode = ""
    }

    /// 입력된 기존 챌린저 코드를 검증하고 재인증을 수행한다.
    ///
    /// 성공 후 프로필을 다시 조회해 승인 여부를 확인하고, 승인된 경우에만 메인 화면
    /// 전환을 준비한다. 아직 승인되지 않았다면 화면에 머무른다.
    @MainActor
    func submitChallengerCode() async {
        guard !isSubmitting else { return }

        let trimmedCode = challengerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAlphanumeric = trimmedCode.unicodeScalars.allSatisfy(
            CharacterSet.alphanumerics.contains
        )

        guard trimmedCode.count == 6, isAlphanumeric else {
            presentInvalidCodePrompt()
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await registerExistingChallengerUseCase.execute(code: trimmedCode)
            let profile = try await fetchMemberProfileUseCase.execute()
            challengerCode = ""
            presentSuccessPrompt(profile: profile)
        } catch let error as RepositoryError {
            challengerCode = ""
            presentCodeFailurePrompt(for: error)
        } catch {
            challengerCode = ""
            presentInvalidCodePrompt()
        }
    }

    /// 회원 탈퇴 확인 프롬프트를 구성한다.
    func presentDeleteAccountPrompt() {
        alertPrompt = AlertPrompt(
            title: "계정 삭제",
            message: "계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다. 정말 삭제하시겠습니까?",
            positiveBtnTitle: "삭제",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in
                    await self?.deleteAccount()
                }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 로그아웃 확인 프롬프트를 구성한다.
    func presentLogoutPrompt() {
        alertPrompt = AlertPrompt(
            title: "로그아웃",
            message: "로그아웃하시겠습니까?",
            positiveBtnTitle: "로그아웃",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in
                    await self?.logout()
                }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Private Function

    /// 기존 챌린저 재인증 성공 프롬프트를 표시한다.
    ///
    /// 승인된 경우에만 확인 버튼에서 프로필을 로컬 저장소에 동기화하고 메인 화면으로 이동한다.
    private func presentSuccessPrompt(profile: Profile) {
        guard profile.isApproved else {
            alertPrompt = AlertPrompt(
                title: "인증 완료",
                message: "코드가 등록되었습니다. 운영진의 최종 승인을 기다려주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        alertPrompt = AlertPrompt(
            title: "인증 완료",
            message: "기존 챌린저로 인증되었습니다.",
            positiveBtnTitle: "확인",
            positiveBtnAction: { [weak self] in
                self?.syncProfileStorageUseCase.execute(profile: profile)
                self?.destination = .main
            }
        )
    }

    /// 코드 형식이 유효하지 않거나 조회되지 않을 때의 실패 프롬프트를 표시한다.
    private func presentInvalidCodePrompt() {
        alertPrompt = AlertPrompt(
            title: "인증 실패",
            message: "입력 코드가 존재하지 않습니다.",
            positiveBtnTitle: "확인"
        )
    }

    /// 서버 비즈니스 에러를 사용자 메시지로 변환해 실패 프롬프트를 표시한다.
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

    /// 승인 대기 상태 화면에서 로그아웃을 수행한다.
    @MainActor
    private func logout() async {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        defer { isLoggingOut = false }

        UserDefaults.standard.set(false, forKey: AppStorageKey.canAutoLogin)

        do {
            try await networkClient.logout()
            userSessionManager.reset()
            await container.resolveIfRegistered(MemberProfileRepositoryProtocol.self)?
                .invalidateCache()
            container.resetCache()
            destination = .login
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Auth", action: "logoutFromPendingApproval")
            )
        }
    }

    /// 승인 대기 상태 화면에서 회원 탈퇴를 수행한다.
    @MainActor
    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await deleteMemberUseCase.execute()
            UserDefaults.standard.set(false, forKey: AppStorageKey.canAutoLogin)
            try await networkClient.logout()
            userSessionManager.reset()
            await container.resolveIfRegistered(MemberProfileRepositoryProtocol.self)?
                .invalidateCache()
            container.resetCache()
            destination = .login
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Auth", action: "deleteMemberFromPendingApproval")
            )
        }
    }

    /// 서버 메시지 앞에 붙은 에러 코드를 제거해 사용자 노출 문구를 정리한다.
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
}
