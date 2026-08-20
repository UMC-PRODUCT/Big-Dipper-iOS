//
//  SettingSection.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI
import CoreUIComponents

/// 마이페이지 설정 섹션
///
/// 알림 설정, 위치 설정 등 iOS 시스템 설정으로 이동하는 버튼들을 표시합니다.
public struct SettingSection: View {
    // MARK: - Property
    
    private let sectionType: MyPageSectionType

    // MARK: - Init

    public init(sectionType: MyPageSectionType = .settings) {
        self.sectionType = sectionType
    }

    // MARK: - Body
    
    public var body: some View {
        Section(content: {
            sectionRow
        }, header: {
            SectionHeaderView(title: sectionType.rawValue, weight: .semibold)
        })
    }
    
    // MARK: - Function
    
    @ViewBuilder
    private var sectionRow: some View {
        ForEach(SettingType.allCases, id: \.hashValue) { setting in
            sectionContent(setting)
        }
    }
    
    private func sectionContent(_ setting: SettingType) -> some View {
        Button(action: {
            settingAction(setting)
        }, label: {
            MyPageSectionRow(
                systemIcon: setting.icon,
                title: setting.rawValue,
                rightImage: "arrow.up.right",
                iconBackgroundColor: setting.color
            )
        })
    }
    
    /// 설정 타입에 따라 적절한 iOS 설정 화면으로 이동
    ///
    /// - Parameter setting: 이동할 설정 타입 (알림/위치)
    private func settingAction(_ setting: SettingType) {
        switch setting {
        case .alarmSetting:
            // iOS 알림 설정 화면으로 이동
            openAppSettings(UIApplication.openNotificationSettingsURLString)
        case .locationSetting:
            // iOS 앱 설정 화면으로 이동 (위치 권한 포함)
            openAppSettings(UIApplication.openSettingsURLString)
        }
    }
    
    /// iOS 설정 앱의 해당 앱 설정 화면으로 이동
    ///
    /// - Parameter url: 설정 화면 URL String (`UIApplication.openSettingsURLString` 또는 `openNotificationSettingsURLString`)
    ///
    /// - Note: 시뮬레이터에서는 "unable to make sandbox extension" 경고가 발생할 수 있으나, 실제 기기에서는 정상 작동합니다.
    private func openAppSettings(_ url: String) {
        guard let settingsURL = URL(string: url) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
