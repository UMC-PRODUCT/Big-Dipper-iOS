//
//  MyPageFeatureView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 3/6/26.
//

import CoreDI
import SwiftUI

/// 마이페이지가 요청하는 명함 진입 지점.
///
/// MyPage는 ``BusinessCardDestination``(BusinessCardPresentation 소유 목적지 enum)을 직접
/// 참조하지 않는다 — 목적지 타입까지 그 모듈에 결합시키면 App 셸의 중개 없이 Feature가
/// 서로의 네비게이션을 직접 다루게 된다. 그래서 이 중립 enum을 MyPage가 소유하고,
/// App 셸이 이를 `BusinessCardDestination`으로 번역해 탭 스택에 쌓는다.
/// (명함 카드 UI 자체는 `BusinessCardFaceView`를 재사용하므로 BusinessCardPresentation을
/// import하지만, 그건 화면 조립이지 네비게이션 결합이 아니다.)
///
/// 명함 편집은 여기 없다 — 프로필 스냅샷이 필요해 App 셸 번역이 부적합하므로, MyPage 내부에서
/// 기존 `MyPageDestination.profile(profileData:)`로 직접 push한다.
public enum BusinessCardEntry: Hashable, Sendable {
    /// 명함첩 — 받은 명함 그리드.
    case receivedCards
    /// 내 명함 QR.
    case cardQR
    /// 근거리 명함 교환 세션.
    case exchange
}

/// MyPage 탭의 공개 진입점.
///
/// 탭 셸이 이 타입만 알면 되도록 DI 컨테이너·에러 핸들러 확보를 여기서 끝내고,
/// 실제 화면 조립은 모듈 내부의 ``MyPageView``가 맡는다.
public struct MyPageFeatureView: View {

    // MARK: - Property

    @Environment(\.di) private var di

    private let onOpenBusinessCard: (BusinessCardEntry) -> Void

    // MARK: - Init

    /// - Parameter onOpenBusinessCard: 명함 카드·「받은 명함」 행 탭 시 App 셸에 명함 진입을
    ///   요청한다. App 셸이 ``BusinessCardEntry``를 `BusinessCardDestination`으로 번역해
    ///   push한다.
    public init(onOpenBusinessCard: @escaping (BusinessCardEntry) -> Void) {
        self.onOpenBusinessCard = onOpenBusinessCard
    }

    // MARK: - Body

    public var body: some View {
        MyPageView(container: di, onOpenBusinessCard: onOpenBusinessCard)
    }
}
