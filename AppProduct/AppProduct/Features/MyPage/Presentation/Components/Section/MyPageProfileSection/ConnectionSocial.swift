//
//  ConnectionSocial.swift
//  AppProduct
//
//  Created by euijjang97 on 1/31/26.
//

import SwiftUI

/// 연동된 소셜 계정 목록을 보여주는 섹션
///
/// 사용자가 연동한 소셜 로그인 서비스(Google, Kakao, Apple 등)를
/// 태그 형태로 표시합니다.
struct ConnectionSocial: View {

    // MARK: - Property

    /// 연동된 소셜 계정 타입 배열
    let socialConnections: [SocialConnection]

    /// 현재 해제 진행 중인 소셜 타입
    let disconnectingSocialType: SocialType?

    /// 섹션 헤더 타이틀
    let header: String

    /// 연동 해제 버튼 탭 시 호출되는 클로저
    let onDisconnect: (SocialConnection) -> Void

    // MARK: - Body

    var body: some View {
        if !socialConnections.isEmpty {
            Section {
                socialTagView
            } header: {
                SectionHeaderView(title: header)
            }
        }
    }

    /// 소셜 계정 태그들을 가로로 나열하는 컨테이너
    private var socialTagView: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            ForEach(socialConnections) { connection in
                socialType(connection)
            }
        }
    }

    /// 개별 소셜 타입 태그 뷰
    ///
    /// 각 소셜 서비스별 브랜드 컬러와 아이콘을 적용한 태그를 생성합니다.
    ///
    /// - Parameter connection: 소셜 연동 정보
    /// - Returns: 스타일이 적용된 태그 뷰
    private func socialType(_ connection: SocialConnection) -> some View {
        let social = connection.socialType

        return Button {
            onDisconnect(connection)
        } label: {
            HStack(spacing: DefaultSpacing.spacing4) {
                Text(social.displayName)
                Image(systemName: disconnectingSocialType == social ? "hourglass" : "minus.circle.fill")
                    .font(.caption)
            }
            .appFont(.caption1Emphasis, color: social.fontColor)
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .glassEffect(.clear.tint(social.color), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(disconnectingSocialType != nil)
    }
}
