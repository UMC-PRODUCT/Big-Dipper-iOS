import WidgetKit

struct UMCHomeWidgetEntry: TimelineEntry {
    let date: Date
}

struct UMCHomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> UMCHomeWidgetEntry {
        UMCHomeWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (UMCHomeWidgetEntry) -> Void) {
        completion(UMCHomeWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UMCHomeWidgetEntry>) -> Void) {
        let entry = UMCHomeWidgetEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}
