//
//  VoteVoterListSheet.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI
import CoreDI
import CoreDesignSystem
import CoreUIComponents

/// 실명 투표 시 특정 옵션에 투표한 사용자 명단을 표시하는 시트
public struct VoteVoterListSheet: View {

    // MARK: - Property

    public let optionTitle: String
    public let memberIds: [String]
    public let container: DIContainer
    @State private var voters: [MemberProfileSummary] = []
    @State private var isLoading: Bool = true

    // MARK: - Constants

    fileprivate enum Constants {
        static let profileSize: CGSize = .init(width: 40, height: 40)
        static let itemSpacing: CGFloat = 12
        static let itemPadding: CGFloat = 12
        static let sheetDetents: Set<PresentationDetent> = [.medium]
        static let defaultProfileImageName: String = "defaultProfile"
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if voters.isEmpty {
                    ContentUnavailableView(
                        "투표자가 없습니다",
                        systemImage: "person.slash"
                    )
                } else {
                    voterList
                }
            }
            .navigationTitle(optionTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await fetchVoterProfiles()
        }
    }

    // MARK: - Subviews

    private var voterList: some View {
        List(voters, id: \.memberId) { voter in
            HStack(spacing: Constants.itemSpacing) {
                RemoteImage(
                    urlString: voter.profileImageURL ?? "",
                    size: Constants.profileSize,
                    cornerRadius: Constants.profileSize.width / 2,
                    placeholderImage: Constants.defaultProfileImageName
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(voterDisplayName(voter))
                        .appFont(.subheadline, weight: .semibold, color: .grey900)

                    if let org = voter.organizationName,
                       !org.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(org)
                            .appFont(.caption1, color: .grey600)
                    }
                }

                Spacer()
            }
            .listRowInsets(.init(
                top: Constants.itemPadding,
                leading: Constants.itemPadding,
                bottom: Constants.itemPadding,
                trailing: Constants.itemPadding
            ))
        }
        .listStyle(.plain)
    }

    // MARK: - Function

    private func voterDisplayName(_ voter: MemberProfileSummary) -> String {
        let name = voter.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = voter.nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        if !nickname.isEmpty && !name.isEmpty && nickname != name {
            return "\(nickname)/\(name)"
        }
        return !nickname.isEmpty ? nickname : name
    }

    @MainActor
    private func fetchVoterProfiles() async {
        isLoading = true
        defer { isLoading = false }

        let repository = container.resolve(MyPageRepositoryProtocol.self)

        await withTaskGroup(of: MemberProfileSummary?.self) { group in
            for memberId in memberIds {
                guard !memberId.isEmpty else { continue }
                group.addTask {
                    try? await repository.fetchMemberProfile(memberId: memberId)
                }
            }

            var results: [MemberProfileSummary] = []
            for await profile in group {
                if let profile {
                    results.append(profile)
                }
            }
            voters = results
        }
    }
}
