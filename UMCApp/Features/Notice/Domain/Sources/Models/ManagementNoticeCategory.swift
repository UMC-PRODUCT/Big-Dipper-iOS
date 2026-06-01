//
//  ManagementNoticeCategory.swift
//  NoticeData
//
//  Created by 이예지 on 6/1/26.
//

// MARK: - ManagementNoticeCategory

/// 운영진 공지 시나리오
public enum ManagementNoticeCategory: Identifiable, Equatable, Hashable, CaseIterable {
    case centralAll
    case schoolCore
    case schoolPartLeader

    public var id: String {
        switch self {
        case .centralAll: return "centralAll"
        case .schoolCore: return "schoolCore"
        case .schoolPartLeader: return "schoolPartLeader"
        }
    }

    public var labelText: String {
        switch self {
        case .centralAll: return "중앙운영진"
        case .schoolCore: return "학교 회장단"
        case .schoolPartLeader: return "학교 파트장"
        }
    }

    public var labelIcon: String {
        switch self {
        case .centralAll: return "person.3.sequence.fill"
        case .schoolCore: return "person.2.badge.gearshape"
        case .schoolPartLeader: return "person.crop.rectangle.stack"
        }
    }

    public var serverNoticeTab: String {
        switch self {
        case .centralAll: return "CENTRAL_MEMBER"
        case .schoolCore: return "SCHOOL_CORE"
        case .schoolPartLeader: return "SCHOOL_PART_LEADER"
        }
    }
}
