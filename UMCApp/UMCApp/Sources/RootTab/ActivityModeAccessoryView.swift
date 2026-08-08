//
//  ActivityModeAccessoryView.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/9/26.
//

import SwiftUI

import CoreDesignSystem
import CoreDomain

/// Activity 탭 하단 액세서리 — 챌린저/운영진 모드 전환 토글.
///
/// 레거시 `AppProduct`의 `ActivityAccessoryView` 이식. 노출 여부는 호출부
/// (`RootTabView` + ``ActivityAccessoryVisibility``)가 결정하고, 이 뷰는 표시와 토글
/// 동작만 담당한다.
struct ActivityModeAccessoryView: View {

    // MARK: - Property

    let userSession: UserSessionManager

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    // MARK: - Body

    var body: some View {
        Button {
            // withAnimation으로 감싸면 ActivityView의 무거운 콘텐츠 교체(출석 체크 ↔ 출석 현황)까지
            // 함께 애니메이션돼 두 화면이 겹쳐 보이는 잔상이 생긴다. 모드 전환은 즉시 처리한다.
            userSession.toggleAdminMode()
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(
                    systemName: userSession.isAdminModeEnabled ? "gearshape.fill" : "gearshape"
                )
                .foregroundStyle(userSession.isAdminModeEnabled ? Color.indigo500 : Color.grey600)

                Text(userSession.isAdminModeEnabled ? "운영진 모드" : "챌린저 모드")
                    .appFont(.subheadline, color: .grey900)

                if placement == .expanded {
                    Spacer()

                    Text(userSession.currentRole.displayName)
                        .appFont(.subheadline, color: .indigo500)
                }
            }
            .padding(.horizontal, placement == .expanded ? DefaultConstant.defaultSafeHorizon : 0)
        }
    }
}
