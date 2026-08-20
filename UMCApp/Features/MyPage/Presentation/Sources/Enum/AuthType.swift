//
//  AuthType.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI

/// 마이페이지 인증 관련 액션 타입
///
/// 사용자 인증과 관련된 작업(로그아웃, 회원탈퇴)을 정의합니다.
public enum AuthType: String, CaseIterable {
    /// 로그아웃
    case logout = "로그아웃"
    /// 회원탈퇴
    case accountDelete = "회원탈퇴"

    /// 인증 타입별 SF Symbol 아이콘 이름
    public var icon: String {
        switch self {
        case .logout:
            return "rectangle.portrait.and.arrow.right"
        case .accountDelete:
            return "person.fill.xmark"
        }
    }

    ///인증 타입별 아이콘 배경 색상
    public var color: Color {
        switch self {
        case .logout:
            return .primary
        case .accountDelete:
            return .red
        }
    }
}
