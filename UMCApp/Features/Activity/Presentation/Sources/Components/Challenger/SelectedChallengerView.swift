//
//  SelectedChallengerView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import CoreDesignSystem
import CoreDomain
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 선택된 챌린저(멘토/스터디원) 목록을 확인·삭제하는 최소 스텁 뷰.
///
/// 원본(`AppProduct`)의 `SelectedChallengerView` 는 `SearchChallengerView` 검색 서브시스템에
/// 의존하는데, 해당 Home 서브시스템(검색 API 포함)이 아직 UMCApp 으로 이식되지 않았다.
/// 그래서 이 스텁은 **이미 선택된 목록의 확인·삭제** 까지만 담당하고, "검색으로 추가" 진입은
/// 검색 서브시스템 이식 시점에 결선한다(#894 범위 밖, 사용자 결정으로 최소 스텁 채택).
/// // TODO: SearchChallengerView(챌린저 검색 서브시스템) 이식 후 검색-추가 결선 - [26.07.15] 이재원
struct SelectedChallengerView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    /// 상위 뷰와 공유하는 선택된 챌린저 목록
    @Binding var challenger: [ChallengerInfo]

    /// 검색-추가 미이식 안내 표시 여부
    @State private var showSearchUnavailable = false

    /// 현재 사용자의 memberId (본인은 삭제 방지)
    private var myMemberIdSet: Set<String> {
        guard let id = AppStorageKey.memberIdString() else { return [] }
        return [id]
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(NavigationTitle.Activity.participant.rawValue)
                .navigationBarTitleDisplayMode(.inline)
                .navigationSubtitle("총 \(challenger.count)명")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }

                    ToolBarCollection.AddBtn(action: {
                        // 검색-추가는 검색 서브시스템 미이식으로 아직 결선되지 않았다.
                        showSearchUnavailable = true
                    })
                }
                .alert("준비 중", isPresented: $showSearchUnavailable) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text("챌린저 검색·추가 기능은 검색 화면 이식 후 연결됩니다.")
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if challenger.isEmpty {
            ContentUnavailableView(
                "선택된 챌린저가 없습니다",
                systemImage: "person.3.fill",
                description: Text("새로운 챌린저를 초대하여 함께 도전해보세요.")
            )
        } else {
            List {
                ForEach(challenger) { info in
                    challengerRow(info)
                }
            }
        }
    }

    private func challengerRow(_ info: ChallengerInfo) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(
                urlString: info.profileImage ?? "",
                size: CGSize(width: 40, height: 40),
                cornerRadius: 0,
                placeholderImage: "person.fill"
            )
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text("\(info.nickname)/\(info.name)")
                    .appFont(.subheadline, weight: .semibold, color: .grey900)
                Text(info.schoolName)
                    .appFont(.footnote, color: .grey500)
            }

            Spacer()

            if !myMemberIdSet.contains(info.memberId) {
                Button(role: .destructive) {
                    removeChallenger(info)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Function

    private func removeChallenger(_ info: ChallengerInfo) {
        challenger.removeAll { $0.id == info.id }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SelectedChallengerView") {
    @Previewable @State var challengers = OperatorStudyPreviewData.challengers
    SelectedChallengerView(challenger: $challengers)
}
#endif
