//
//  KakaoPlusManager.swift
//  AppProduct
//
//  Created by euijjang97 on 1/13/26.
//

import Foundation
import KakaoSDKTalk
import UIKit

/// 카카오톡 채널(플러스친구)과의 상호작용을 처리하는 매니저입니다.
///
/// UMC 동아리의 카카오톡 채널 채팅방을 여는 기능을 제공합니다.
/// 카카오톡 앱이 설치되어 있지 않은 환경(예: App Store 심사)에서는
/// 웹 채팅 URL(`https://pf.kakao.com/{channelId}/chat`)로 자동 폴백합니다.
///
/// - Usage:
/// ```swift
/// let manager = KakaoPlusManager()
/// manager.openKakaoChannel(errorHandler: errorHandler)
/// ```
class KakaoPlusManager {
    // MARK: - Property

    /// UMC 동아리 카카오톡 채널 ID
    ///
    /// - Note: 채널 관리자 페이지에서 확인 가능한 고유 ID입니다.
    let channelId = "_MDxhqX"

    /// 카카오톡 미설치 시 사용할 웹 채팅 URL
    private var webChatURL: URL? {
        URL(string: "https://pf.kakao.com/\(channelId)/chat")
    }

    // MARK: - Function

    /// UMC 카카오톡 채널 채팅방을 엽니다.
    ///
    /// 다음 순서로 채널을 엽니다:
    /// 1. ``TalkApi/isKakaoTalkChannelAvailable(path:)`` 로 카카오톡 채널 연결 가능 여부를 확인합니다.
    /// 2. 사용 가능하면 ``TalkApi/chatChannel(channelPublicId:completion:)`` 로 카카오톡 채팅방을 엽니다.
    /// 3. 카카오톡 미설치이거나 SDK 호출이 실패하면 웹 채팅 URL을 외부 브라우저로 엽니다.
    /// 4. 웹 URL 마저 열 수 없는 극한 케이스에서는 ``ErrorHandler`` 로 사용자 Alert 을 표시합니다.
    ///
    /// - Parameter errorHandler: 모든 폴백이 실패했을 때 사용자에게 안내할 핸들러.
    ///   `nil` 이면 안내 없이 로그만 남깁니다.
    ///
    /// - Important: SDK 의 채널 가용성 검사는 `kakaoplus://` 스킴에 대한 `canOpenURL` 호출을 포함하므로,
    ///   Info.plist 의 `LSApplicationQueriesSchemes` 에 `kakaoplus` 가 등록되어 있어야 합니다.
    @MainActor
    func openKakaoChannel(errorHandler: ErrorHandler? = nil) {
        let chatPath = "plusfriend/talk/chat/\(channelId)"

        guard TalkApi.isKakaoTalkChannelAvailable(path: chatPath) else {
            openWebChat(errorHandler: errorHandler)
            return
        }

        TalkApi.shared.chatChannel(channelPublicId: channelId) { [weak self] error in
            guard let self else { return }
            if let error {
                print("카카오톡 채널 열기 에러: \(error). 웹으로 폴백합니다.")
                Task { @MainActor in
                    self.openWebChat(errorHandler: errorHandler)
                }
            }
        }
    }

    // MARK: - Private

    /// 웹 채팅 URL을 외부 브라우저로 엽니다.
    ///
    /// URL을 만들 수 없거나 시스템이 열기를 거부하면 ``reportFailure(errorHandler:)``로 안내합니다.
    @MainActor
    private func openWebChat(errorHandler: ErrorHandler?) {
        guard let url = webChatURL else {
            reportFailure(errorHandler: errorHandler)
            return
        }

        UIApplication.shared.open(url) { [weak self] success in
            guard !success else { return }
            Task { @MainActor in
                self?.reportFailure(errorHandler: errorHandler)
            }
        }
    }

    /// 카카오톡 / 웹 폴백이 모두 실패한 경우 ``ErrorHandler``로 안내합니다.
    @MainActor
    private func reportFailure(errorHandler: ErrorHandler?) {
        guard let errorHandler else {
            print("카카오톡 채널/웹 모두 열기 실패")
            return
        }
        errorHandler.handle(
            DomainError.custom(message: "카카오톡 문의 채널을 열 수 없습니다. 잠시 후 다시 시도해주세요."),
            context: ErrorContext(
                feature: "KakaoPlusManager",
                action: "openKakaoChannel"
            )
        )
    }
}
