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

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            generationTag
            part
            Spacer()
            roles
        }
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

    /// Admin은 파트 개념이 없어 이름을 비운다.
    @ViewBuilder
    private var part: some View {
        if row.part != .admin {
            Text(row.part.name)
                .appFont(.subheadline, color: .black)
        }
    }

    /// 같은 기수에 운영진 역할이 여러 개일 수 있어 모두 나열한다. 챌린저는 배지를 달지 않는다.
    @ViewBuilder
    private var roles: some View {
        let displayRoles = row.roles.filter { $0 != .challenger }

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
