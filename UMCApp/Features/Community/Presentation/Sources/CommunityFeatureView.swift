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
import UMCFoundation

/// 커뮤니티 탭 진입점.
///
/// 자체 `NavigationStack` 을 만들지 않는다 — 탭별 스택은 상위 탭 셸이 소유한다.
/// 대신 자기 목적지(``CommunityDestination``) 등록을 여기서 해, App 이 커뮤니티 화면 구성을
/// 알지 못한 채로도 스택이 동작하게 한다.
public struct CommunityFeatureView: View {

    // MARK: - Property

    @Environment(PathStore.self) private var pathStore
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Init

    public init() {}

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
        .navigationDestination(for: CommunityDestination.self) { destination in
            CommunityRoutingView(
                destination: destination,
                container: di,
                errorHandler: errorHandler
            )
        }
    }
}
