//
//  CardGlassCircleButton.swift
//  BusinessCardPresentation
//

import CoreDesignSystem
import SwiftUI

/// 명함 카드 위에 얹는 원형 글래스 아이콘 버튼.
///
/// 2D 카드(``BusinessCardFaceView``)의 플립 버튼과 3D 카드(``BusinessCard3DView``)의
/// 컨트롤 오버레이가 같은 레시피를 쓴다 — 두 경로에서 버튼이 다르게 보이면 로딩 타이밍에
/// 따라 UI 가 바뀐 것처럼 읽힌다. 반경·지름을 고칠 자리가 하나여야 그 어긋남이 안 생긴다.
///
/// 시각 지름은 시안값 32pt 로 두고 **히트 영역만 HIG 44pt** 로 넓힌다. 카드 모서리에
/// 버튼이 둘(자이로·플립) 붙는 3D 경로에서 32pt 히트 영역은 오탭을 부른다.
struct CardGlassCircleButton: View {

    // MARK: - Property

    private let systemName: String
    private let label: String
    private let isOn: Bool?
    private let action: () -> Void

    private enum Metrics {
        /// 시안 실측 지름·아이콘 크기 (`Figma 12639:33234` 플립 버튼).
        static let diameter: CGFloat = 32
        static let iconSize: CGFloat = 15
        /// 꺼진 토글의 심볼 불투명도. SF Symbols 에 `gyroscope.slash` 가 없어
        /// 켜짐/꺼짐을 슬래시 심볼로 구분하지 못한다 — 불투명도와 라벨로 전달한다.
        static let dimmedOpacity: Double = 0.45
    }

    // MARK: - Init

    /// - Parameter isOn: 켜짐/꺼짐이 있는 토글만 넘긴다. `nil` 이면 평범한 버튼이라
    ///   `.isSelected` 특성도, 흐린 심볼도 붙지 않는다 — 플립처럼 상태가 없는 동작에
    ///   「선택됨」이 읽히면 VoiceOver 사용자에게 없는 상태를 알리는 셈이 된다.
    init(
        systemName: String,
        label: String,
        isOn: Bool? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.label = label
        self.isOn = isOn
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: Metrics.iconSize))
                .foregroundStyle(Color.white.opacity(isOn == false ? Metrics.dimmedOpacity : 1))
                .frame(minWidth: Metrics.diameter, minHeight: Metrics.diameter)
                .glassEffect(.clear, in: Circle())
                .frame(
                    minWidth: DefaultConstant.minimumTouchTarget,
                    minHeight: DefaultConstant.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn == true ? .isSelected : [])
    }
}
