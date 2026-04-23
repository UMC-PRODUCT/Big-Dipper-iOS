import WidgetKit
import Foundation

public struct WidgetAttendanceEntry: TimelineEntry {

    // MARK: - Property

    public let date: Date
    public let status: AttendanceStatus
    public let sessionTitle: String

    // MARK: - Init

    public init(
        date: Date,
        status: AttendanceStatus,
        sessionTitle: String
    ) {
        self.date = date
        self.status = status
        self.sessionTitle = sessionTitle
    }

    public static var placeholder: WidgetAttendanceEntry {
        WidgetAttendanceEntry(
            date: .now,
            status: .pending,
            sessionTitle: "정기 세션"
        )
    }
}

// MARK: - AttendanceStatus

public enum AttendanceStatus: String, Codable, Sendable {
    case attended
    case absent
    case late
    case pending
}
