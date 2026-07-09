import CoreDI
import SwiftUI

/// 홈 탭 진입점 — 루트 탭 셸의 `NavigationStack` 안에서 홈 대시보드를 표시한다.
public struct HomeFeatureView: View {

    // MARK: - Property

    @Environment(\.di) private var di

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some View {
        HomeView(container: di)
    }
}
