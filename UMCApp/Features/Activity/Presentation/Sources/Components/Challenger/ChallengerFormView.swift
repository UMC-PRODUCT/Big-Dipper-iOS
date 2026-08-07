//
//  ChallengerFormView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDesignSystem
import CoreDomain
import SwiftUI
import UMCFoundation

/// 챌린저 목록을 파트별 섹션으로 묶어 보여주는 폼.
///
/// 검색 결과 선택(체크박스), 선택된 인원 확인·삭제 두 상황에서 함께 씁니다.
struct ChallengerFormView: View {

    // MARK: - Property

    /// 표시할 챌린저 목록
    @Binding var challengers: [ChallengerInfo]

    /// 선택된 행 식별 키 집합 (선택 모드일 때만 사용)
    @Binding var selectedKeys: Set<String>

    /// 스와이프 삭제 허용 여부
    let isDeleteEnabled: Bool

    /// 선택 상태 체크 아이콘 표시 여부
    let showCheckBox: Bool

    /// 행 탭 액션
    let onTap: ((ChallengerInfo) -> Void)?

    /// 마지막 행이 나타났을 때 호출 (페이지네이션)
    let onBottomReached: (() -> Void)?

    /// 삭제할 수 없는 멤버 ID 집합 (본인 보호 등)
    let nonDeletableMemberIds: Set<String>

    // MARK: - Init

    init(
        challengers: Binding<[ChallengerInfo]>,
        selectedKeys: Binding<Set<String>> = .constant([]),
        isDeleteEnabled: Bool = false,
        showCheckBox: Bool = false,
        onTap: ((ChallengerInfo) -> Void)? = nil,
        onBottomReached: (() -> Void)? = nil,
        nonDeletableMemberIds: Set<String> = []
    ) {
        self._challengers = challengers
        self._selectedKeys = selectedKeys
        self.isDeleteEnabled = isDeleteEnabled
        self.showCheckBox = showCheckBox
        self.onTap = onTap
        self.onBottomReached = onBottomReached
        self.nonDeletableMemberIds = nonDeletableMemberIds
    }

    // MARK: - Body

    var body: some View {
        Form {
            ForEach(sortedParts, id: \.self) { part in
                section(part: part)
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func section(part: UMCPartType) -> some View {
        Section {
            let rows = ForEach(groupedByPart[part] ?? [], id: \.selectionKey) { challenger in
                row(challenger)
            }

            if isDeleteEnabled {
                rows.onDelete(perform: deleteRows)
            } else {
                rows
            }
        } header: {
            Text(part.name)
                .appFont(.subheadline, weight: .medium, color: .grey500)
        }
    }

    private func row(_ challenger: ChallengerInfo) -> some View {
        ChallengerSearchCard(
            challenger: challenger,
            showCheck: showCheckBox,
            isSelected: selectedKeys.contains(challenger.selectionKey)
        )
        .equatable()
        .contentShape(Rectangle())  // 여백까지 탭 영역으로 확장
        .deleteDisabled(nonDeletableMemberIds.contains(challenger.memberId))
        .onTapGesture {
            onTap?(challenger)
        }
        .task {
            guard challenger.selectionKey == challengers.last?.selectionKey else { return }
            onBottomReached?()
        }
    }

    // MARK: - Function

    private func deleteRows(at offsets: IndexSet) {
        challengers.remove(atOffsets: offsets)
    }

    /// 파트별로 묶고, 각 파트 안에서는 최신 기수 → 이름 순으로 정렬합니다.
    private var groupedByPart: [UMCPartType: [ChallengerInfo]] {
        Dictionary(grouping: challengers) { $0.part }
            .mapValues { challengers in
                challengers.sorted { lhs, rhs in
                    // 기수는 서버 응답 String 이라 비교 시점에만 Int 로 변환한다.
                    let lhsGen = Int(lhs.gen) ?? 0
                    let rhsGen = Int(rhs.gen) ?? 0
                    if lhsGen != rhsGen {
                        return lhsGen > rhsGen
                    }
                    return lhs.name < rhs.name
                }
            }
    }

    /// 파트 섹션 순서 — 도메인 표준 정렬(`UMCPartType.sortOrder`)을 따릅니다.
    private var sortedParts: [UMCPartType] {
        groupedByPart.keys.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerFormView · 선택 모드") {
    @Previewable @State var challengers = OperatorStudyPreviewData.challengers
    @Previewable @State var selectedKeys: Set<String> = []

    ChallengerFormView(
        challengers: $challengers,
        selectedKeys: $selectedKeys,
        showCheckBox: true,
        onTap: { challenger in
            if selectedKeys.contains(challenger.selectionKey) {
                selectedKeys.remove(challenger.selectionKey)
            } else {
                selectedKeys.insert(challenger.selectionKey)
            }
        }
    )
}

#Preview("ChallengerFormView · 삭제 모드") {
    @Previewable @State var challengers = OperatorStudyPreviewData.challengers

    ChallengerFormView(
        challengers: $challengers,
        isDeleteEnabled: true
    )
}
#endif
