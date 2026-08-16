//
//  DebugReceivedCardsView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import SwiftUI
import UMCFoundation

/// 「명함 관리 › 받은 명함」이 여는 명함첩 (시안 MP-F05 자리).
///
/// 검증 포인트는 두 가지다 — 같은 memberId 재교환 시 새 행이 아니라 갱신되는가(upsert),
/// 앱을 껐다 켜도 남는가(SwiftData 영속).
struct DebugReceivedCardsView: View {

    // MARK: - Property

    @Bindable var viewModel: BusinessCardDebugViewModel

    // MARK: - Body

    var body: some View {
        List {
            Section {
                TextField("검색 (이름·닉네임·파트·학교)", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await viewModel.reloadReceivedCards() } }

                HStack {
                    Button("샘플 명함 저장") {
                        Task { await viewModel.saveSampleCard() }
                    }
                    Spacer()
                    Text("count: \(viewModel.receivedCardCount)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                switch viewModel.receivedCards {
                case .idle, .loading:
                    ProgressView()
                case .loaded(let cards) where cards.isEmpty:
                    Text("빈 명함첩").foregroundStyle(.secondary)
                case .loaded(let cards):
                    ForEach(cards) { card in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(card.profile.name) / \(card.profile.nickname)")
                            Text("\(card.profile.part.name) · \(card.profile.generation)기 · \(card.profile.university)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("id=\(card.id) memberId=\(card.profile.memberId)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .swipeActions {
                            Button("삭제", role: .destructive) {
                                Task { await viewModel.delete(id: card.id) }
                            }
                        }
                    }
                case .failed(let error):
                    Text("실패: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("같은 memberId로 다시 저장하면 새 행이 아니라 갱신되어야 한다(upsert). 앱을 껐다 켜도 남아야 한다.")
            }
        }
        .navigationTitle("받은 명함")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.reloadReceivedCards() }
    }
}
#endif
