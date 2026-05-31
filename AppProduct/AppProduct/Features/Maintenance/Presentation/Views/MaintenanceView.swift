//
//  MaintenanceView.swift
//  AppProduct
//
//  원격 점검 중일 때 앱 전체를 덮는 전체화면 안내. 닫을 수 없습니다.
//

import SwiftUI

/// 점검 중 전체화면 안내.
///
/// 닫기 버튼/제스처가 없는 순수 킬스위치 화면입니다. 서버가 점검을 해제하면
/// 앱 루트의 ViewModel 이 재확인 후 자동으로 dismiss 합니다.
struct MaintenanceView: View {

    // MARK: - Property

    let info: MaintenanceInfo

    // MARK: - Constants

    fileprivate enum Constants {
        static let iconName = "wrench.and.screwdriver.fill"
        static let iconSize: CGFloat = 56
        static let maxContentWidth: CGFloat = 360
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.grey000
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing24) {
                Image(systemName: Constants.iconName)
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(Color.orange500)
                    .padding(.bottom, DefaultSpacing.spacing8)

                Text(info.title)
                    .appFont(.title2Emphasis, color: .grey900)
                    .multilineTextAlignment(.center)

                Text(info.message)
                    .appFont(.body, color: .grey600)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: Constants.maxContentWidth)
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        // 스와이프/제스처로 빠져나갈 수 없도록 차단.
        .interactiveDismissDisabled(true)
    }
}

#if DEBUG
#Preview {
    MaintenanceView(
        info: MaintenanceInfo(
            isActive: true,
            title: "서비스 점검 안내",
            message: "보다 나은 서비스 제공을 위해 점검 중입니다.\n잠시 후 다시 이용해 주세요."
        )
    )
}
#endif
