//
//  AuthType.swift
//  AppProduct
//
//  Created by euijjang97 on 1/31/26.
//

import Foundation
import SwiftUI

/// 마이페이지 인증 관련 액션 타입
///
/// 사용자 인증과 관련된 작업(비밀번호 변경, 로그아웃, 회원탈퇴)을 정의합니다.
enum AuthType: String, CaseIterable {
    /// 비밀번호 변경
    case changePassword = "비밀번호 변경"
    /// 로그아웃
    case logout = "로그아웃"
    /// 회원 탈퇴
    case accountDelete = "회원탈퇴"

    /// 인증 타입별 SF Symbol 아이콘 이름
    var icon: String {
        switch self {
        case .changePassword:
            return "lock.rotation"
        case .logout:
            return "rectangle.portrait.and.arrow.right"
        case .accountDelete:
            return "person.fill.xmark"
        }
    }

    /// 인증 타입별 아이콘 배경 색상
    var color: Color {
        switch self {
        case .changePassword:
            return .primary
        case .logout:
            return .primary
        case .accountDelete:
            return .red
        }
    }
}
