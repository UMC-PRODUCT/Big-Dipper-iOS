//
//  SelectedChallenger.swift
//  AppProduct
//
//  Created by euijjang97 on 1/25/26.
//

import SwiftUI

/// 일정 등록 화면에서 챌린저 추가 화면 클릭 시 보여지는 뷰입니다.
///
/// 선택된 챌린저 목록을 확인하고, 새로운 챌린저를 검색하여 추가하거나 삭제할 수 있는 기능을 제공합니다.
struct SelectedChallengerView: View {
    
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    /// DI 컨테이너
    @Environment(\.di) private var container

    /// 외부에서 주입받는 선택된 챌린저 목록 (Binding)
    ///
    /// 이 배열은 상위 뷰와 공유되며, 챌린저 추가 및 삭제 시 실시간으로 업데이트됩니다.
    @Binding var challenger: [ChallengerInfo]

    /// 챌린저 검색 화면으로의 네비게이션 활성화 여부
    @State var searchNavi: Bool = false

    /// 현재 사용자의 memberId (삭제 방지용)
    private var myMemberIdSet: Set<String> {
        guard let id = AppStorageKey.memberIdString() else { return [] }
        return [id]
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            content
                .navigation(naviTitle: .participant, displayMode: .inline)
                .navigationSubtitle("총 \(challenger.count)명")
                .toolbar(content: {
                    ToolBarCollection.LeadingButton(
                        image: "chevron.left",
                        action: { dismiss() }
                    )
                    
                    // 챌린저 추가 버튼 (검색 화면으로 이동)
                    ToolBarCollection.AddBtn(action: {
                        searchNavi = true
                    })
                })
                // 검색 화면으로 네비게이션 이동
                .navigationDestination(isPresented: $searchNavi, destination: {
                    SearchChallengerView(
                        container: container,
                        selectedChallengers: $challenger
                    )
                })
        }
    }
    
    // MARK: - Private Views
    
    /// 챌린저 목록의 존재 여부에 따라 보여질 뷰를 결정하는 메인 컨텐츠 뷰
    @ViewBuilder
    private var content: some View {
        if challenger.isEmpty {
            // 선택된 인원이 없으면 빈 상태 뷰 표시
            unSelectedContent
        } else {
            // 선택된 인원이 있으면 리스트 폼 표시 (삭제 가능 모드)
            ChallengerFormView(
                challenger: $challenger,
                isDeletAction: true,
                nonDeletableMemberIds: myMemberIdSet
            )
        }
    }
    
    /// 선택된 챌린저가 없을 때 나타나는 안내 뷰
    private var unSelectedContent: some View {
        ContentUnavailableView(
            "선택된 챌린저가 없습니다",
            systemImage: "person.3.fill",
            description: Text("새로운 챌린저를 초대하여 함께 도전해보세요.")
        )
    }
}
