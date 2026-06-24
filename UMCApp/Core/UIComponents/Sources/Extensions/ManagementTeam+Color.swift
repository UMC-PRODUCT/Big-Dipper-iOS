//
//  ManagementTeam+Color.swift
//  CoreUIComponents
//
//  Created by 이예지 on 5/27/26.
//

import Foundation
import UMCFoundation
import SwiftUI

extension ManagementTeam {
    public var textColor: Color {
        switch self {
        case .superAdmin:
            return .red100
        case .centralPresident, .centralVicePresident,
             .centralOperatingTeamMember, .centralEducationTeamMember:
            return .indigo100
        case .chapterPresident, .schoolPresident, .schoolVicePresident:
            return .orange500
        case .schoolPartLeader, .schoolEtcAdmin:
            return .green500
        case .challenger:
            return .clear
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .superAdmin:
            return .red300
        case .centralPresident, .centralVicePresident,
             .centralOperatingTeamMember, .centralEducationTeamMember:
            return .indigo400
        case .chapterPresident, .schoolPresident, .schoolVicePresident:
            return .orange100
        case .schoolPartLeader, .schoolEtcAdmin:
            return .green100
        case .challenger:
            return .clear
        }
    }

    public var borderColor: Color {
        switch self {
        case .superAdmin:
            return .red500
        case .centralPresident, .centralVicePresident,
             .centralOperatingTeamMember, .centralEducationTeamMember:
            return .indigo700
        case .chapterPresident, .schoolPresident, .schoolVicePresident:
            return .orange300
        case .schoolPartLeader, .schoolEtcAdmin:
            return .green300
        case .challenger:
            return .clear
        }
    }
}
