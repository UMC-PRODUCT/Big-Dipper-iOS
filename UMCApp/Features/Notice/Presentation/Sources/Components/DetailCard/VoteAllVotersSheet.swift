//
//  VoteAllVotersSheet.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI
import CoreDI
import CoreDesignSystem
import CoreDomain
import CoreUIComponents
import MyPageDomain
import NoticeDomain

/// 실명 투표 시 옵션별 투표자 명단을 그룹으로 표시하는 시트
public struct VoteAllVotersSheet: View {

    // MARK: - Property

    public let options: [VoteOption]
    public let container: DIContainer
    @State private var profileCache: [String: MemberProfileSummary] = [:]
    @State private var isLoading: Bool = true

    // MARK: - Constants

    fileprivate enum Constants {
        static let profileSize: CGSize = .init(width: 36, height: 36)
        static let itemSpacing: CGFloat = 10
        static let itemPadding: CGFloat = 10
        static let defaultProfileImageName: String = "defaultProfile"
        static let nameSpacing: CGFloat = 4
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    voterGroupedList
                }
            }
            .navigationTitle("투표 현황")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await fetchAllVoterProfiles()
        }
    }

    // MARK: - Subviews

    private var voterGroupedList: some View {
        List {
            ForEach(options) { option in
                Section {
                    if option.selectedMemberIds.isEmpty {
                        Text("투표자 없음")
                            .appFont(.footnote, color: .grey500)
                            .listRowInsets(.init(
                                top: Constants.itemPadding,
                                leading: Constants.itemPadding,
                                bottom: Constants.itemPadding,
                                trailing: Constants.itemPadding
                            ))
                    } else {
                        ForEach(option.selectedMemberIds, id: \.self) { memberId in
                            voterRow(for: memberId)
                                .listRowInsets(.init(
                                    top: Constants.itemPadding,
                                    leading: Constants.itemPadding,
                                    bottom: Constants.itemPadding,
                                    trailing: Constants.itemPadding
                                ))
                        }
                    }
                } header: {
                    HStack {
                        Text(option.title)
                            .appFont(.subheadline, weight: .semibold, color: .grey900)

                        Spacer()

                        Text("\(option.voteCount)명")
                            .appFont(.footnote, color: .grey600)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func voterRow(for memberId: String) -> some View {
        HStack(spacing: Constants.itemSpacing) {
            if let voter = profileCache[memberId] {
                RemoteImage(
                    urlString: voter.profileImageURL ?? "",
                    size: Constants.profileSize,
                    cornerRadius: Constants.profileSize.width / 2,
                    placeholderImage: Constants.defaultProfileImageName
                )

                VStack(alignment: .leading, spacing: Constants.nameSpacing) {
                    Text(voterDisplayName(voter))
                        .appFont(.subheadline, color: .grey900)

                    if let org = voter.organizationName,
                       !org.trimmingCharacters(
                           in: .whitespacesAndNewlines
                       ).isEmpty {
                        Text(org)
                            .appFont(.caption1, color: .grey600)
                    }
                }
            } else {
                RemoteImage(
                    urlString: "",
                    size: Constants.profileSize,
                    cornerRadius: Constants.profileSize.width / 2,
                    placeholderImage: Constants.defaultProfileImageName
                )

                Text("ID: \(memberId)")
                    .appFont(.subheadline, color: .grey600)
            }

            Spacer()
        }
    }

    // MARK: - Function

    private func voterDisplayName(
        _ voter: MemberProfileSummary
    ) -> String {
        let name = voter.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = voter.nickname.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !nickname.isEmpty && !name.isEmpty && nickname != name {
            return "\(nickname)/\(name)"
        }
        return !nickname.isEmpty ? nickname : name
    }

    @MainActor
    private func fetchAllVoterProfiles() async {
        isLoading = true
        defer { isLoading = false }

        let allMemberIds = Set(options.flatMap(\.selectedMemberIds))
        guard !allMemberIds.isEmpty else { return }

        let repository = container.resolve(MyPageRepositoryProtocol.self)

        await withTaskGroup(
            of: (String, MemberProfileSummary?).self
        ) { group in
            for memberId in allMemberIds {
                guard let memberIdValue = Int(memberId) else { continue }
                group.addTask {
                    let profile = try? await repository.fetchMemberProfile(
                        memberId: memberIdValue
                    )
                    return (memberId, profile)
                }
            }

            for await (memberId, profile) in group {
                if let profile {
                    profileCache[memberId] = profile
                }
            }
        }
    }
}
