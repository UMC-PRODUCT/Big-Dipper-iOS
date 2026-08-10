//
//  StudyGroupPermissionGuideView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/10/26.
//

import CoreDesignSystem
import SwiftUI

// MARK: - StudyGroupPermissionGuideView

/// 스터디 그룹 생성 권한이 없는 사용자에게 보여주는 역할 안내
///
/// 그룹 관리 섹션의 빈 상태와 에러 상태 두 곳에서 같은 화면을 쓰기 때문에 별도 컴포넌트로
/// 분리했습니다. 바깥 여백은 호출부가 상황에 맞게 붙입니다.
struct StudyGroupPermissionGuideView: View {

    // MARK: - Constants

    private enum Constants {
        static let title: String = "스터디 그룹 관리"
        static let description: String = "등록된 스터디 그룹이 없습니다\n스터디 그룹 생성에는 별도 권한이 필요해요"
        static let guideTitle: String = "스터디 관리가 가능한 역할"
        static let iconWidth: CGFloat = 32
        static let roleTextSpacing: CGFloat = 2
    }

    // MARK: - Role

    /// 스터디 관리 권한을 가진 역할과 그 설명
    private enum ManageableRole: String, CaseIterable, Identifiable {
        case chapterLeader = "지부장"
        case president = "회장 / 부회장"
        case operatorStaff = "운영진"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chapterLeader: "building.columns.fill"
            case .president: "star.fill"
            case .operatorStaff: "person.badge.key.fill"
            }
        }

        var description: String {
            switch self {
            case .chapterLeader: "지부 내 전체 학교의 스터디를 관리할 수 있어요"
            case .president: "소속 학교의 스터디 그룹을 생성·관리할 수 있어요"
            case .operatorStaff: "담당 파트의 스터디를 조회할 수 있어요"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DefaultSpacing.spacing32) {
                ContentUnavailableView {
                    Label(Constants.title, systemImage: "person.3")
                } description: {
                    Text(Constants.description)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                    Text(Constants.guideTitle)
                        .appFont(.callout, weight: .semibold)

                    ForEach(ManageableRole.allCases) { role in
                        roleRow(role)
                    }
                }
                .padding(DefaultSpacing.spacing16)
                .background(
                    .regularMaterial,
                    in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
                )
            }
            .padding(.top, DefaultSpacing.spacing32)
        }
    }

    // MARK: - Function

    private func roleRow(_ role: ManageableRole) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: role.icon)
                .font(.app(.title3))
                .foregroundStyle(Color.grey600)
                .frame(width: Constants.iconWidth, alignment: .center)

            VStack(alignment: .leading, spacing: Constants.roleTextSpacing) {
                Text(role.rawValue)
                    .appFont(.subheadline)
                Text(role.description)
                    .appFont(.footnote)
                    .foregroundStyle(Color.grey500)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("스터디 그룹 권한 안내") {
    StudyGroupPermissionGuideView()
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
}
#endif
