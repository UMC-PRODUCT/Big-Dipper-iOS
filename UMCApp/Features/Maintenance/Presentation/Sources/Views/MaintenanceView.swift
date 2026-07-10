import CoreDesignSystem
import MaintenanceDomain
import SwiftUI

/// 원격 킬스위치(점검) 및 강제 업데이트 전체화면 오버레이.
///
/// 닫기 버튼/제스처가 없는 화면입니다. 점검은 서버가 해제하면, 강제 업데이트는 앱이
/// 최소 지원 버전 이상으로 갱신되면 앱 루트의 ViewModel이 재확인 후 자동으로 dismiss합니다.
public struct MaintenanceView: View {

    // MARK: - Property

    let kind: MaintenanceOverlayKind

    @Environment(\.openURL) private var openURL

    // MARK: - Constant

    fileprivate enum Constants {
        static let maintenanceIconName = "wrench.and.screwdriver.fill"
        static let forceUpdateIconName = "arrow.up.circle.fill"
        static let iconSize: CGFloat = 56
        static let maxContentWidth: CGFloat = 360
        static let updateButtonTopPadding: CGFloat = 8

        static let forceUpdateTitle = "업데이트가 필요해요"
        static let forceUpdateMessage =
            "새로운 버전이 출시되었습니다.\n계속 이용하려면 앱을 업데이트해 주세요."
        static let updateButtonTitle = "업데이트"
        static let appStoreURLString = "https://apps.apple.com/us/app/umc/id6759412446"
    }

    // MARK: - Init

    public init(kind: MaintenanceOverlayKind) {
        self.kind = kind
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.grey000
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing24) {
                Image(systemName: iconName)
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(Color.orange500)
                    .padding(.bottom, DefaultSpacing.spacing8)

                Text(title)
                    .appFont(.title2, weight: .semibold, color: .grey900)
                    .multilineTextAlignment(.center)

                Text(message)
                    .appFont(.body, color: .grey600)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if case .forceUpdate = kind {
                    updateButton
                }
            }
            .frame(maxWidth: Constants.maxContentWidth)
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        // 스와이프/제스처로 빠져나갈 수 없도록 차단.
        .interactiveDismissDisabled(true)
    }

    // MARK: - Subviews

    private var updateButton: some View {
        Button {
            guard let url = URL(string: Constants.appStoreURLString) else { return }
            openURL(url)
        } label: {
            Text(Constants.updateButtonTitle)
                .appFont(.callout, weight: .semibold, color: .white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .buttonStyle(.glassProminent)
        .padding(.top, Constants.updateButtonTopPadding)
    }
}

// MARK: - Private Helper

extension MaintenanceView {
    private var iconName: String {
        switch kind {
        case .maintenance:
            Constants.maintenanceIconName
        case .forceUpdate:
            Constants.forceUpdateIconName
        }
    }

    private var title: String {
        switch kind {
        case .maintenance(let info):
            info.title
        case .forceUpdate:
            Constants.forceUpdateTitle
        }
    }

    private var message: String {
        switch kind {
        case .maintenance(let info):
            info.message
        case .forceUpdate:
            Constants.forceUpdateMessage
        }
    }
}

#if DEBUG
#Preview("점검") {
    MaintenanceView(
        kind: .maintenance(
            MaintenanceInfo(
                isActive: true,
                title: "서비스 점검 안내",
                message: "보다 나은 서비스 제공을 위해 점검 중입니다.\n잠시 후 다시 이용해 주세요."
            )
        )
    )
}

#Preview("강제 업데이트") {
    MaintenanceView(kind: .forceUpdate)
}
#endif
