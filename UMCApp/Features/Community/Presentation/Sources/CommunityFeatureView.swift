//
//  CommunityFeatureView.swift
//  CommunityPresentation
//
//  Created by euijjang97 on 3/6/26.
//

import SwiftUI

import CommunityDomain
import CoreDI
import CoreRouting
import NoticeDomain
import UMCFoundation

/// 커뮤니티 탭 진입점.
///
/// 자체 `NavigationStack` 을 만들지 않는다 — 탭별 스택은 상위 탭 셸이 소유한다.
/// 자기 목적지(``CommunityDestination``) 등록은 리스트 화면이 하므로(생성 결과를 리스트
/// ViewModel 에 바로 반영해야 한다) App 은 여전히 커뮤니티 화면 구성을 알 필요가 없다.
public struct CommunityFeatureView: View {

    // MARK: - Property

    /// 공지 링크 카드 탭. 공지 상세 목적지는 App 소유(`NavigationDestination`)라 Feature 가
    /// 직접 push 할 수 없다 — 홈 탭이 쓰는 콜백 방식을 그대로 따른다 (#1027).
    private let onNoticeSelected: (NoticeDetail) -> Void

    @Environment(PathStore.self) private var pathStore
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Init

    public init(onNoticeSelected: @escaping (NoticeDetail) -> Void) {
        self.onNoticeSelected = onNoticeSelected
    }

    // MARK: - Body

    public var body: some View {
        CommunityThreadListView(
            viewModel: CommunityThreadListViewModel(
                listUseCase: di.resolve(CommunityThreadListUseCaseProtocol.self),
                roomUseCase: di.resolve(CommunityThreadRoomUseCaseProtocol.self),
                errorHandler: errorHandler
            ),
            onThreadSelected: { thread in
                pathStore.push(
                    CommunityDestination.threadRoom(threadId: thread.id, title: thread.title),
                    on: .community
                )
            }
        )
        // 메시지 본문의 텍스트 링크와 링크 카드가 모두 `openURL` 로 들어온다. 여기 한 번만
        // 가로채면 두 경로가 같은 규칙을 타고, 외부 URL 은 손대지 않은 채 사파리로 나간다.
        .environment(\.openURL, OpenURLAction(handler: handle))
    }

    // MARK: - Function

    private func handle(_ url: URL) -> OpenURLAction.Result {
        guard let link = MessageLink.parse(url) else { return .systemAction }
        open(link)
        return .handled
    }

    /// - Note: 스레드는 제목을 모른 채 push 한다. 채팅방이 헤더를 받으면 principal 툴바가
    ///   `navigationTitle` 을 덮으므로, 비어 있는 건 로딩 동안뿐이다.
    /// - Note: 비멤버 차단은 여기서 하지 않는다. 리스트 탭·딥링크·링크 카드가 모두 같은
    ///   채팅방으로 모이므로 게이트는 그 안(`CommunityThreadRoomViewModel.load()`)에 둔다.
    private func open(_ link: MessageLink) {
        switch link {
        case .thread(let id):
            pathStore.push(
                CommunityDestination.threadRoom(threadId: id, title: ""),
                on: .community
            )

        case .notice:
            Task { await openNotice(link) }
        }
    }

    /// 공지 상세 목적지가 모델을 통째로 받으므로, 카드가 이미 받아 둔 메타를 다시 꺼내 쓴다.
    /// UseCase 가 링크별로 캐시하고 있어 카드가 떠 있는 상태에서의 탭은 네트워크를 타지 않는다.
    private func openNotice(_ link: MessageLink) async {
        do {
            let preview = try await di
                .resolve(MessageLinkPreviewUseCaseProtocol.self)
                .preview(for: link)
            guard let notice = preview.notice else { return }
            onNoticeSelected(notice)
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "openNoticeLink"
            ))
        }
    }
}
