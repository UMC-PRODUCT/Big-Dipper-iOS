import AuthenticationServices
import UIKit

/// Apple 로그인 및 회원 탈퇴를 처리하는 매니저입니다.
///
/// Sign in with Apple 기능을 사용하여 사용자 인증 및 계정 삭제 인증을 처리합니다.
///
/// - Important:
///   - 로그인과 회원 탈퇴는 동일한 ASAuthorizationController를 사용하지만, Flow로 구분됩니다.
///   - 콜백 기반으로 동작하므로 사용 전 `onAuthorizationCompleted` 또는 `onAccountDeleteAuthorized`를 설정해야 합니다.
///
/// - Usage:
/// ```swift
/// let appleManager = AppleLoginManager()
///
/// // 로그인
/// appleManager.onAuthorizationCompleted = { code, email, fullName in
///     print("Authorization Code: \(code)")
/// }
/// appleManager.signWithApple()
///
/// // 회원 탈퇴
/// appleManager.onAccountDeleteAuthorized = { code in
///     print("Delete Authorization Code: \(code)")
/// }
/// appleManager.accountDelete()
/// ```
public final class AppleLoginManager: NSObject {

    // MARK: - Nested Types

    /// Apple 인증 흐름 타입을 구분하는 열거형입니다.
    public enum Flow {
        /// 로그인 흐름 (이메일, 이름 요청)
        case login

        /// 계정 삭제 흐름 (추가 정보 요청 없음)
        case accountDeletion
    }

    // MARK: - Property

    /// 현재 진행 중인 인증 흐름
    ///
    /// - Note: 인증 완료 후 nil로 초기화됩니다.
    private var flow: Flow?

    /// 로그인 인증 완료 시 호출되는 콜백
    ///
    /// - Parameters:
    ///   - authorizationCode: 서버로 전송할 인증 코드
    ///   - email: 사용자 이메일 (최초 로그인 시에만 제공)
    ///   - fullName: 사용자 전체 이름 (최초 로그인 시에만 제공)
    public var onAuthorizationCompleted: ((String, String?, String?) -> Void)?

    /// 회원 탈퇴 인증 완료 시 호출되는 콜백
    ///
    /// - Parameter authorizationCode: 서버로 전송할 인증 코드
    public var onAccountDeleteAuthorized: ((String) -> Void)?

    /// 인증 실패(또는 사용자 취소) 시 호출되는 콜백
    ///
    /// 사용자가 취소(X)한 경우 `SocialLoginError.cancelled` 로 정규화해 전달하므로,
    /// 상위 레이어에서 취소와 실제 에러를 구분해 처리할 수 있습니다.
    public var onAuthorizationFailed: ((Error) -> Void)?

    // MARK: - Init

    override public init() {
        super.init()
    }

    // MARK: - Function

    /// Apple 로그인을 시작합니다.
    ///
    /// 사용자의 이메일과 전체 이름을 요청하며, 성공 시 `onAuthorizationCompleted` 콜백이 호출됩니다.
    ///
    /// - Important:
    ///   - 이메일과 이름은 **최초 로그인 시에만** 제공됩니다.
    ///   - 이후 로그인에서는 authorizationCode만 제공되므로, 서버에 사용자 정보를 저장해야 합니다.
    public func signWithApple() {
        flow = .login
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    /// Apple 계정 삭제 인증을 시작합니다.
    ///
    /// 추가 정보(이메일, 이름) 없이 인증 코드만 요청하며, 성공 시 `onAccountDeleteAuthorized` 콜백이 호출됩니다.
    ///
    /// - Note: 서버에서 이 인증 코드로 Apple에 회원 탈퇴 요청을 보내야 합니다.
    public func accountDelete() {
        flow = .accountDeletion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleLoginManager: ASAuthorizationControllerDelegate {
    /// Apple 인증이 성공적으로 완료되었을 때 호출됩니다.
    ///
    /// Flow 타입에 따라 로그인 또는 회원 탈퇴 처리를 수행합니다.
    ///
    /// - Parameters:
    ///   - controller: ASAuthorizationController 인스턴스
    ///   - authorization: 인증 결과 객체
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { flow = nil }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            #if DEBUG
            print("Apple 인증 실패: credential 형변환 실패")
            #endif
            return
        }

        switch flow {
        case .login:
            // 로그인 흐름: authorizationCode, 이메일, 이름 추출
            guard let tokenData = credential.authorizationCode,
                  let authorizationCode = String(data: tokenData, encoding: .utf8) else {
                print("identityToken 없음")
                return
            }

            let formatter = PersonNameComponentsFormatter()
            let fullName = credential.fullName.flatMap { formatter.string(from: $0) }
            let email = credential.email

            onAuthorizationCompleted?(authorizationCode, email, fullName)

            #if DEBUG
            print("Apple 로그인 성공")
            print("토큰: \(authorizationCode)")
            print("이메일: \(email ?? "없음")")
            print("이름: \(fullName ?? "없음")")
            #endif

        case .accountDeletion:
            // 회원 탈퇴 흐름: authorizationCode만 추출
            guard let codeData = credential.authorizationCode,
                  let code = String(data: codeData, encoding: .utf8) else {
                #if DEBUG
                print("authorizationCode 없음")
                #endif
                return
            }

            onAccountDeleteAuthorized?(code)

            #if DEBUG
            print("Apple 회원 탈퇴용 인증 성공")
            print("authorizationCode: \(code)")
            #endif

        case .none:
            print("경고: flow 미설정 상태에서 응답 수신")
        }
    }

    /// Apple 인증이 실패했을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - controller: ASAuthorizationController 인스턴스
    ///   - error: 발생한 에러
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        defer { flow = nil }
        #if DEBUG
        print("Apple 인증 실패: \(error.localizedDescription)")
        #endif

        // 사용자가 취소(X)한 경우 공통 SocialLoginError로 정규화해 전달합니다.
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            onAuthorizationFailed?(SocialLoginError.cancelled)
        } else {
            onAuthorizationFailed?(error)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleLoginManager: ASAuthorizationControllerPresentationContextProviding {
    /// Apple 인증 UI를 표시할 윈도우 앵커를 제공합니다.
    ///
    /// 현재 활성화된 keyWindow를 반환하며, 없을 경우 첫 번째 UIWindowScene으로 새 윈도우를 생성합니다.
    ///
    /// - Parameter controller: ASAuthorizationController 인스턴스
    /// - Returns: Apple 인증 UI를 표시할 윈도우
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            // keyWindow가 없을 경우 첫 번째 UIWindowScene으로 새 윈도우 생성
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return UIWindow(windowScene: scene)
            }
            fatalError("No UIWindowScene available to create a presentation anchor.")
        }
        return window
    }
}
