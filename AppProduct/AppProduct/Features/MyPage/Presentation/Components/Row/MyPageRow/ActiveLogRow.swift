//
//  ActiveLogRow.swift
//  AppProduct
//
//  Created by euijjang97 on 1/26/26.
//

import SwiftUI

/// 마이페이지에서 사용자의 활동 이력을 한 줄로 보여주는 뷰입니다.
///
/// 기수, 파트, 역할 정보를 가로로 배치하여 표시합니다.
struct ActiveLogRow: View, Equatable {

    // MARK: - Property

    /// 표시할 활동 로그 데이터
    let row: ActivityLog

    // MARK: - Initializer

    init(row: ActivityLog) {
        self.row = row
    }

    // MARK: - Constants

    private enum Constants {
        /// 뱃지 내부 패딩 값
        static let padding: EdgeInsets = .init(top: 5, leading: 8, bottom: 5, trailing: 8)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8, content: {
            genTag // 기수 표시 태그
            part   // 파트 이름 텍스트
            Spacer()
            role   // 역할(직책) 뱃지
        })
    }

    // MARK: - UI Components

    /// 기수를 표시하는 태그 뷰
    private var genTag: some View {
        Text("\(row.generation)기")
            .appFont(.footnote, color: .black)
            .padding(Constants.padding)
            .background {
                // 둥근 테두리 배경
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(.clear)
                    .stroke(Color.grey300, style: .init())
            }
    }
    
    /// 파트 이름을 표시하는 텍스트 뷰
    /// Admin 파트는 표시하지 않습니다.
    @ViewBuilder
    private var part: some View {
        if row.part != .admin {
            Text(row.part.name)
                .appFont(.subheadline, color: .black)
        }
    }
    
    /// 직책(역할)을 표시하는 뱃지 뷰
    /// 역할별 고유 색상을 배경색으로 사용합니다.
    @ViewBuilder
    private var role: some View {
        if row.role != .challenger {
            Text(row.role.displayName)
                .appFont(.footnote, weight: .medium, color: row.role.textColor)
                .padding(Constants.padding)
                .glassEffect(
                    .clear.tint(row.role.backgroundColor),
                    in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
                )
        }
    }
}
