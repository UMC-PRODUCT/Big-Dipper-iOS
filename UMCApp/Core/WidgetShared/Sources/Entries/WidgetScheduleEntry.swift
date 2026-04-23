import WidgetKit
import Foundation

public struct WidgetScheduleEntry: TimelineEntry {

    // MARK: - Property

    public let date: Date
    public let scheduleTitle: String
    public let scheduleTime: Date?
    public let location: String?

    // MARK: - Init

    public init(
        date: Date,
        scheduleTitle: String,
        scheduleTime: Date? = nil,
        location: String? = nil
    ) {
        self.date = date
        self.scheduleTitle = scheduleTitle
        self.scheduleTime = scheduleTime
        self.location = location
    }

    public static var placeholder: WidgetScheduleEntry {
        WidgetScheduleEntry(
            date: .now,
            scheduleTitle: "오늘의 일정",
            scheduleTime: .now,
            location: nil
        )
    }
}
