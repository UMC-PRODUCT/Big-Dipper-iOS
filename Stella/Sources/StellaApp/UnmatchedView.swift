import SwiftUI
import StellaCore

struct UnmatchedRow: Identifiable {
    let id: String
    let entry: CoverageSnapshot.UnmatchedEntry

    init(entry: CoverageSnapshot.UnmatchedEntry) {
        self.id = "\(entry.project).\(entry.routerEnum).\(entry.caseName).\(entry.filePath):\(entry.line)"
        self.entry = entry
    }
}

struct UnmatchedView: View {
    @Bindable var model: ScanModel
    @State private var query = ""

    var body: some View {
        if let snapshot = model.snapshot {
            VStack(spacing: 0) {
                HStack {
                    TextField("검색", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                    Spacer()
                    Text("매치 안됨 \(filtered(snapshot).count)개")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(12)
                Divider()
                Table(filtered(snapshot).map(UnmatchedRow.init)) {
                    TableColumn("프로젝트") { row in
                        Text(projectDisplayName(row.entry.project, in: snapshot))
                            .font(.callout)
                    }
                    .width(120)

                    TableColumn("라우터 케이스") { row in
                        Text("\(row.entry.routerEnum).\(row.entry.caseName)")
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(280)

                    TableColumn("사유") { row in
                        Text(row.entry.reason)
                            .foregroundStyle(.orange)
                            .font(.callout)
                            .lineLimit(2)
                    }

                    TableColumn("위치") { row in
                        Text("\(row.entry.filePath):\(row.entry.line)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "아직 스냅샷이 없어요",
                systemImage: "questionmark.circle",
                description: Text("스캔을 실행해 매치되지 않은 라우터 케이스를 확인하세요.")
            )
        }
    }

    private func filtered(_ snapshot: CoverageSnapshot) -> [CoverageSnapshot.UnmatchedEntry] {
        guard !query.isEmpty else { return snapshot.unmatchedRouterCases }
        let q = query.lowercased()
        return snapshot.unmatchedRouterCases.filter {
            $0.routerEnum.lowercased().contains(q)
                || $0.caseName.lowercased().contains(q)
                || $0.reason.lowercased().contains(q)
                || $0.filePath.lowercased().contains(q)
        }
    }

    private func projectDisplayName(_ key: String, in snapshot: CoverageSnapshot) -> String {
        snapshot.projects.first { $0.key == key }?.displayName ?? key
    }
}
