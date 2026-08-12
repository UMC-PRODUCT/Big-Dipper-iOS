//
//  CommunityRoutingView.swift
//  CommunityPresentation
//

import SwiftUI

import CommunityDomain
import CoreDI
import UMCFoundation

/// `CommunityDestination` → 실제 화면.
///
/// ViewModel 생성이 여기 모여 있어 리스트 화면이 채팅방 구성 방법을 알 필요가 없다.
///
/// 상위가 탭별 `NavigationStack` 을 제공하므로 여기서 스택을 만들지 않는다.
///
/// - Note: 내 메시지 판별용 memberId 는 `CommunityThreadRoomViewModel` 이 기본 인자로
///   직접 읽는다. 라우팅이 다시 조회해 넘기면 같은 값을 읽는 지점이 둘이 된다.
struct CommunityRoutingView: View {

    // MARK: - Property

    let destination: CommunityDestination
    let container: DIContainer
    let errorHandler: ErrorHandler

    // MARK: - Body

    var body: some View {
        switch destination {
        case .threadRoom(let threadId, let title):
            CommunityThreadRoomView(
                viewModel: CommunityThreadRoomViewModel(
                    threadId: threadId,
                    useCase: container.resolve(CommunityThreadRoomUseCaseProtocol.self),
                    errorHandler: errorHandler
                )
            )
            .navigationTitle(title)
        }
    }
}
