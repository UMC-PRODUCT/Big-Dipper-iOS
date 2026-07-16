//
//  HighlightMenuButton.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import UIKit
import CoreDesignSystem

// MARK: - HighlightColor

/// 리치 텍스트 에디터의 형광펜 색상 옵션입니다.
enum HighlightColor: CaseIterable {
    case none, purple, pink, orange, mint, blue

    /// 팔레트에 표시할 색상 케이스 (없음 제외)
    static var colorCases: [HighlightColor] { [.purple, .pink, .orange, .mint, .blue] }

    var name: String {
        switch self {
        case .none:   return "없음"
        case .purple: return "보라색"
        case .pink:   return "분홍색"
        case .orange: return "주황색"
        case .mint:   return "민트색"
        case .blue:   return "파란색"
        }
    }

    /// 텍스트에 적용되는 반투명 배경 색상 (none이면 nil)
    var swiftUIColor: Color? {
        switch self {
        case .none:   return nil
        case .purple: return .purple.opacity(0.35)
        case .pink:   return .pink.opacity(0.35)
        case .orange: return .orange.opacity(0.35)
        case .mint:   return .mint.opacity(0.35)
        case .blue:   return .blue.opacity(0.35)
        }
    }

    /// 메뉴 아이콘에 표시되는 진한 색상
    var displayColor: Color {
        switch self {
        case .none:   return .black
        case .purple: return .purple
        case .pink:   return .pink
        case .orange: return .orange
        case .mint:   return .mint
        case .blue:   return .blue
        }
    }

    /// Menu 아이콘용 컬러 원형 UIImage (template 렌더링 무시)
    var circleImage: UIImage {
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(displayColor).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - HighlightMenuButton

/// 공지 에디터 첨부 툴바의 형광펜 색상 선택 메뉴입니다.
struct HighlightMenuButton: View {

    // MARK: - Property

    @Binding var selectedHighlightColor: HighlightColor

    // MARK: - Constants

    private enum Constants {
        static let iconSize: CGFloat = 20
        static let frame: CGSize = .init(width: 30, height: 30)
    }

    // MARK: - Body

    var body: some View {
        Menu {
            Section {
                Button {
                    selectedHighlightColor = .none
                } label: {
                    Label("없음", systemImage: selectedHighlightColor == .none ? "checkmark" : "xmark")
                }
            }

            Section {
                ForEach(HighlightColor.colorCases, id: \.self) { option in
                    Button {
                        selectedHighlightColor = option
                    } label: {
                        Label {
                            Text(option.name)
                        } icon: {
                            Image(uiImage: option.circleImage)
                        }
                        if selectedHighlightColor == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(selectedHighlightColor.displayColor)
                .frame(width: Constants.frame.width, height: Constants.frame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }
}
