import Foundation
import KakaoSDKTalk
import UIKit
import UMCFoundation

/// 카카오톡 채널(플러스친구) 인앱 문의 채팅을 여는 매니저입니다.
///
/// 카카오톡 앱이 설치되어 있고 채널 채팅 딥링크가 가능하면 인앱 채팅방으로 바로
/// 전환하고, 그렇지 않거나 SDK 호출이 실패하면 웹 채팅 URL로 폴백합니다.
///
/// - Important: `Info.plist`의 `LSApplicationQueriesSchemes`에 `kakaoplus` 스킴이
///   등록되어 있어야 `TalkApi.isKakaoTalkChannelAvailable(path:)`가 정상 동작합니다.
public final class KakaoPlusManager {

    // MARK: - Property

    /// UMC 동아리 카카오톡 채널 ID (카카오톡 채널 관리자 페이지에서 확인 가능).
    let channelId = "_MDxhqX"

    private var webChatURL: URL? { URL(string: "https://pf.kakao.com/\(channelId)/chat") }

    // MARK: - Init

    public init() {}

    // MARK: - Function

    /// 카카오톡 채널 문의 채팅을 엽니다.
    ///
    /// 카카오톡에 채널 채팅 딥링크가 가능하면 인앱으로 전환하고, 그렇지 않거나 SDK
    /// 호출이 실패하면 웹 채팅 URL로 폴백합니다. 웹 폴백마저 실패하면 `errorHandler`로
    /// 실패를 보고합니다(`errorHandler`가 없으면 콘솔 로그만 남깁니다).
    @MainActor
    public func openKakaoChannel(errorHandler: ErrorHandler? = nil) {
        let chatPath = "plusfriend/talk/chat/\(channelId)"
        guard TalkApi.isKakaoTalkChannelAvailable(path: chatPath) else {
            openWebChat(errorHandler: errorHandler)
            return
        }
        TalkApi.shared.chatChannel(channelPublicId: channelId) { [weak self] error in
            guard let self else { return }
            if let error {
                print("카카오톡 채널 열기 에러: \(error). 웹으로 폴백합니다.")
                Task { @MainActor in self.openWebChat(errorHandler: errorHandler) }
            }
        }
    }

    // MARK: - Private Function

    @MainActor
    private func openWebChat(errorHandler: ErrorHandler?) {
        guard let url = webChatURL else { reportFailure(errorHandler: errorHandler); return }
        UIApplication.shared.open(url) { [weak self] success in
            guard !success else { return }
            Task { @MainActor in self?.reportFailure(errorHandler: errorHandler) }
        }
    }

    @MainActor
    private func reportFailure(errorHandler: ErrorHandler?) {
        guard let errorHandler else { print("카카오톡 채널/웹 모두 열기 실패"); return }
        errorHandler.handle(
            DomainError.custom(message: "카카오톡 문의 채널을 열 수 없습니다. 잠시 후 다시 시도해주세요."),
            context: ErrorContext(feature: "KakaoPlusManager", action: "openKakaoChannel")
        )
    }
}
