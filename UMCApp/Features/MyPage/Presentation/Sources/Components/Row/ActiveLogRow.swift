//
//  ActiveLogRow.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreDomain
import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// 활동 이력 한 건(기수 · 파트 · 역할)을 한 줄로 보여주는 행.
struct ActiveLogRow: View, Equatable {

    // MARK: - Property

    private let row: ActivityLog

    private enum Constants {
        static let badgePadding = EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
    }

    // MARK: - Init

    init(row: ActivityLog) {
        self.row = row
    }

    // MARK: - Computed Property

    /// Admin은 파트 개념이 없어 이름을 비운다.
    private var partName: String {
        row.part == .admin ? "" : row.part.name
    }

    /// 같은 기수에 운영진 역할이 여러 개일 수 있어 모두 나열한다. 챌린저는 배지를 달지 않는다.
    private var displayRoles: [ManagementTeam] {
        row.roles.filter { $0 != .challenger }
    }

    /// 「11기, iOS, 파트장」. 기수·파트·역할이 따로 읽히면 한 줄을 세 번 스와이프해야 한다.
    private var accessibilityLabel: String {
        (["\(row.generation)기", partName] + displayRoles.map(\.displayName))
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            generationTag
            part
            Spacer()
            roles
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - View Component

    private var generationTag: some View {
        Text("\(row.generation)기")
            .appFont(.footnote, color: .black)
            .padding(Constants.badgePadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(.clear)
                    .stroke(Color.grey300, style: .init())
            }
    }

    @ViewBuilder
    private var part: some View {
        if !partName.isEmpty {
            Text(partName)
                .appFont(.subheadline, color: .black)
        }
    }

    @ViewBuilder
    private var roles: some View {
        if !displayRoles.isEmpty {
            HStack(spacing: DefaultSpacing.spacing4) {
                ForEach(displayRoles, id: \.self) { role in
                    Text(role.displayName)
                        .appFont(.footnote, weight: .medium, color: role.textColor)
                        .padding(Constants.badgePadding)
                        .glassEffect(
                            .clear.tint(role.backgroundColor),
                            in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
                        )
                }
            }
        }
    }
}
