//
//  AuthSection.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import CoreUIComponents
import Foundation
import SwiftUI
import UMCFoundation

/// 마이페이지의 인증 관련 섹션 (로그아웃, 회원탈퇴)
///
/// 사용자 인증 관련 작업을 처리하는 섹션으로, AlertPrompt를 통해 확인 다이얼로그를 표시합니다.
/// 실제 세션 종료·탈퇴 수행은 상위(``MyPageView``)가 주입한 액션이 담당합니다.
public struct AuthSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    @Binding private var alertPrompt: AlertPrompt?
    private let onLogout: () -> Void
    private let onDeleteAccount: () -> Void

    /// 노출할 인증 항목.
    ///
    /// 비밀번호 변경 화면은 아직 이식 전이라 행을 숨긴다. 화면이 들어오면 필터를 걷어내고
    /// ``AuthType/changePassword`` 분기에 진입점을 연결한다.
    private var visibleAuthTypes: [AuthType] {
        AuthType.allCases.filter { $0 != .changePassword }
    }

    // MARK: - Init

    public init(
        sectionType: MyPageSectionType = .auth,
        alertPrompt: Binding<AlertPrompt?>,
        onLogout: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) {
        self.sectionType = sectionType
        self._alertPrompt = alertPrompt
        self.onLogout = onLogout
        self.onDeleteAccount = onDeleteAccount
    }

    // MARK: - Body

    public var body: some View {
        Section(content: {
            sectionContent
        }, header: {
            SectionHeaderView(title: sectionType.rawValue)
        })
    }

    // MARK: - Function

    private var sectionContent: some View {
        ForEach(visibleAuthTypes, id: \.rawValue) { auth in
            content(auth)
        }
    }

    private func content(_ auth: AuthType) -> some View {
        Button(action: {
            typeAction(auth)
        }, label: {
            // 회원 탈퇴는 빨간색으로 표시
            MyPageSectionRow(
                systemIcon: auth.icon,
                title: auth.rawValue,
                rightText: "",
                iconBackgroundColor: auth.color,
                titleColor: auth == .accountDelete ? .red : .black
            )
        })
        .buttonStyle(.borderless)
    }

    /// 인증 타입에 따른 액션을 처리하고 AlertPrompt를 표시
    ///
    /// - Parameter auth: 처리할 인증 타입 (비밀번호 변경, 로그아웃 또는 회원탈퇴)
    private func typeAction(_ auth: AuthType) {
        switch auth {
        case .changePassword:
            break
        case .logout:
            alertPrompt = .init(
                title: "로그아웃",
                message: "정말 로그아웃 하시겠습니까?",
                positiveBtnTitle: "로그아웃",
                positiveBtnAction: onLogout,
                negativeBtnTitle: "취소",
                isPositiveBtnDestructive: true
            )
        case .accountDelete:
            alertPrompt = .init(
                title: "계정 삭제",
                message: "계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다. 정말 삭제하시겠습니까?",
                positiveBtnTitle: "삭제",
                positiveBtnAction: onDeleteAccount,
                negativeBtnTitle: "취소",
                isPositiveBtnDestructive: true
            )
        }
    }
}
