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

    /// 생성 성공을 리스트에 알린다. 서버는 개설자에게 실시간 이벤트를 보내지 않으므로
    /// (초대된 멤버에게만 `thread.invited` 를 쏜다) 이 통로가 없으면 새 스레드가 다음 수동
    /// 새로고침까지 목록에 나타나지 않는다.
    let onThreadCreated: (CommunityThread) -> Void

    // MARK: - Body

    var body: some View {
        switch destination {
        case .threadRoom(let threadId, let title):
            CommunityThreadRoomView(
                viewModel: CommunityThreadRoomViewModel(
                    threadId: threadId,
                    useCase: container.resolve(CommunityThreadRoomUseCaseProtocol.self),
                    errorHandler: errorHandler,
                    summarizer: container.resolve(ThreadSummarizing.self)
                )
            )
            .navigationTitle(title)

        case .threadCreate:
            CommunityThreadCreateView(
                viewModel: CommunityThreadCreateViewModel(
                    useCase: container.resolve(CommunityThreadCreateUseCaseProtocol.self),
                    classifier: container.resolve(ThreadClassifying.self)
                ),
                onCreated: onThreadCreated
            )
        }
    }
}
