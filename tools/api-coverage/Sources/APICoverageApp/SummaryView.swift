import SwiftUI
import APICoverageCore

struct SummaryView: View {
    @Bindable var model: ScanModel

    var body: some View {
        if let snapshot = model.snapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(snapshot)
                    statsGrid(snapshot)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "아직 스냅샷이 없어요",
                systemImage: "chart.bar",
                description: Text("스캔을 실행하거나 기존 스냅샷을 열어 결과를 확인하세요.")
            )
        }
    }

    private func header(_ snapshot: CoverageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.openAPI.title).font(.title).bold()
            HStack(spacing: 12) {
                Text("v\(snapshot.openAPI.version)").foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text("오퍼레이션 \(snapshot.openAPI.totalPaths)개").foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text("생성: \(model.formattedTimestamp(snapshot.generatedAt))")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }

    private func statsGrid(_ snapshot: CoverageSnapshot) -> some View {
        let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(snapshot.projects, id: \.key) { project in
                let stats = snapshot.summary[project.key]
                ProjectStatsCard(
                    title: project.displayName,
                    rootPath: project.rootPath,
                    matched: stats?.matched ?? 0,
                    total: snapshot.openAPI.totalPaths,
                    unmatched: stats?.unmatched ?? 0
                )
            }
        }
    }
}

private struct ProjectStatsCard: View {
    let title: String
    let rootPath: String
    let matched: Int
    let total: Int
    let unmatched: Int

    private var coverage: Double {
        guard total > 0 else { return 0 }
        return Double(matched) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(rootPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(Int((coverage * 100).rounded()))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(coverageColor)
                Text("커버리지").foregroundStyle(.secondary)
            }

            ProgressView(value: coverage)
                .progressViewStyle(.linear)
                .tint(coverageColor)

            HStack {
                Label("\(matched)", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Spacer()
                Label("누락 \(total - matched)개", systemImage: "circle.dashed")
                    .foregroundStyle(.secondary)
                Spacer()
                Label("매치 안됨 \(unmatched)개", systemImage: "questionmark.circle")
                    .foregroundStyle(.orange)
            }
            .font(.callout)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 1)
        )
    }

    private var coverageColor: Color {
        switch coverage {
        case 0.85...: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }
}
