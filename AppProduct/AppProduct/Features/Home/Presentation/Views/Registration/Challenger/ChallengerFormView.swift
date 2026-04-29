//
//  ChallengerFormView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/25/26.
//

import SwiftUI

/// 챌린저 목록을 파트별로 그룹화하여 표시하는 폼 뷰입니다.
///
/// 챌린저 추가, 조회, 삭제 등의 다양한 상황에서 재사용됩니다.
struct ChallengerFormView: View {
    
    // MARK: - Properties
    
    /// 표시할 챌린저 목록 바인딩
    @Binding var challenger: [ChallengerInfo]
    
    /// 현재 선택된 챌린저들의 행 식별 키 집합 (체크박스 모드일 때 사용)
    @Binding var selectedIds: Set<String>
    
    /// 삭제 기능 활성화 여부 (true일 경우 스와이프로 삭제 가능)
    let isDeletAction: Bool
    
    /// 체크박스 표시 여부 (선택 모드일 경우 true)
    let showCheckBox: Bool
    
    /// 챌린저 항목 탭 액션 클로저
    let tap: ((ChallengerInfo) -> Void)?

    /// 마지막 아이템이 화면에 나타났을 때 호출 (페이지네이션용)
    let onBottomReached: (() -> Void)?

    /// 삭제 불가능한 멤버 ID 집합 (생성자 보호 등)
    let nonDeletableMemberIds: Set<String>
    
    // MARK: - Init
    
    /// 초기화 메서드
    /// - Parameters:
    ///   - challenger: 챌린저 목록 바인딩
    ///   - isDeletAction: 삭제 기능 활성화 여부 (기본값: false)
    ///   - showCheckBox: 체크박스 표시 여부 (기본값: false)
    ///   - selectedIds: 선택된 행 식별 키 집합 바인딩 (기본값: 빈 집합)
    ///   - tap: 탭 액션 클로저 (기본값: nil)
    ///   - onBottomReached: 리스트 마지막 아이템 도달 시 호출되는 클로저 (페이지네이션용, 기본값: nil)
    init(
        challenger: Binding<[ChallengerInfo]>,
        isDeletAction: Bool = false,
        showCheckBox: Bool = false,
        selectedIds: Binding<Set<String>> = .constant([]),
        tap: ((ChallengerInfo) -> Void)? = nil,
        onBottomReached: (() -> Void)? = nil,
        nonDeletableMemberIds: Set<String> = []
    ) {
        self._challenger = challenger
        self.isDeletAction = isDeletAction
        self.showCheckBox = showCheckBox
        self._selectedIds = selectedIds
        self.tap = tap
        self.onBottomReached = onBottomReached
        self.nonDeletableMemberIds = nonDeletableMemberIds
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // 파트별로 그룹화된 순서대로 섹션 생성
            ForEach(groupedByPart.keys.sorted(by: sortParts), id: \.self) { part in
                section(part: part)
            }
        }
    }
    
    /// 특정 파트에 해당하는 챌린저 목록을 보여주는 섹션 뷰입니다.
    ///
    /// - Parameter part: 표시할 UMC 파트 타입
    @ViewBuilder
    private func section(part: UMCPartType) -> some View {
        Section(content: {
            let forEach = ForEach(groupedByPart[part] ?? [], id: \.selectionKey) { participant in
                ChallengerSearchCard(
                    participant: participant,
                    showCheck: showCheckBox,
                    isSelected: selectedIds.contains(participant.selectionKey)
                )
                .equatable()
                .contentShape(Rectangle()) // 터치 영역 확장
                .deleteDisabled(nonDeletableMemberIds.contains(participant.memberId))
                .onTapGesture {
                    tap?(participant)
                }
                .task {
                    // 마지막 아이템 도달 시 페이지네이션 트리거
                    if participant.selectionKey == challenger.last?.selectionKey {
                        onBottomReached?()
                    }
                }
            }
            
            // 삭제 액션 활성화 여부에 따른 리스트 처리
            if isDeletAction {
                forEach.onDelete(perform: onDeleteAction)
            } else {
                forEach
            }
        }, header: {
            // 섹션 헤더 (파트 이름)
            Text(part.name)
                .appFont(.subheadline, weight: .medium, color: .grey500)
        })
    }
    
    // MARK: - Actions & Helpers
    
    /// 리스트에서 스와이프하여 항목을 삭제할 때 호출되는 메서드
    private func onDeleteAction(index: IndexSet) {
        challenger.remove(atOffsets: index)
    }
    
    /// 챌린저 목록을 파트별로 그룹화하고, 내부에서 기수(Gen)와 이름 순으로 정렬하는 계산 프로퍼티
    private var groupedByPart: [UMCPartType: [ChallengerInfo]] {
        // 1. 파트별로 딕셔너리 그룹화
        let grouped = Dictionary(grouping: challenger) { $0.part }
        
        // 2. 각 파트 내의 리스트를 정렬
        return grouped.mapValues { participants in
            participants.sorted { lhs, rhs in
                // 우선순위 1: 기수 (내림차순 - 최신 기수가 위로)
                if lhs.gen != rhs.gen {
                    return lhs.gen > rhs.gen
                }
                // 우선순위 2: 이름 (오름차순 - 가나다순)
                return lhs.name < rhs.name
            }
        }
    }
    
    /// 파트 간의 정렬 순서를 정의하는 메서드
    /// (PM -> Design -> Spring -> NodeJS -> Web -> Android -> iOS 순)
    private func sortParts(_ lhs: UMCPartType, _ rhs: UMCPartType) -> Bool {
        let order: [String] = ["PM", "Design", "Spring", "NodeJS", "Web", "Android", "iOS"]
        let lhsIndex = order.firstIndex(of: lhs.name) ?? Int.max
        let rhsIndex = order.firstIndex(of: rhs.name) ?? Int.max
        return lhsIndex < rhsIndex
    }
}
