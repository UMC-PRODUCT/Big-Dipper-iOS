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

    /// 편집 결과를 리스트에 알린다. `thread.updated` 는 다른 참여자에게만 가므로(생성과 같은
    /// 이유) 이 통로가 없으면 방금 내가 고친 제목이 목록에서 옛 값으로 남는다.
    let onThreadUpdated: (CommunityThread) -> Void

    /// 나가기·삭제로 스레드가 내 목록에서 빠졌음을 알린다. 실시간 `member.left`/`thread.deleted`
    /// 로도 행이 지워지지만, 그걸 기다리면 루트로 되돌아온 직후 잠깐 남아 있는 행이 보인다.
    let onThreadRemoved: (String) -> Void

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

        case .threadEdit(let thread):
            CommunityThreadEditView(
                viewModel: CommunityThreadEditViewModel(
                    thread: thread,
                    useCase: container.resolve(CommunityThreadEditUseCaseProtocol.self),
                    classifier: container.resolve(ThreadClassifying.self),
                    errorHandler: errorHandler
                ),
                onUpdated: onThreadUpdated,
                onDeleted: onThreadRemoved
            )

        case .threadMembers(let threadId):
            ThreadMemberListView(
                viewModel: ThreadMemberListViewModel(
                    threadId: threadId,
                    useCase: container.resolve(CommunityThreadMemberUseCaseProtocol.self),
                    errorHandler: errorHandler
                ),
                onRemoved: { onThreadRemoved(threadId) }
            )
        }
    }
}
