import SwiftUI
import APICoverageCore

enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case settings, summary, endpoints, unmatched
    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings: return "설정"
        case .summary: return "요약"
        case .endpoints: return "엔드포인트"
        case .unmatched: return "매치 안됨"
        }
    }

    var systemImage: String {
        switch self {
        case .settings: return "gearshape"
        case .summary: return "chart.bar"
        case .endpoints: return "list.bullet"
        case .unmatched: return "questionmark.circle"
        }
    }
}

struct ContentView: View {
    @Bindable var model: ScanModel
    @State private var selection: SidebarItem = .settings

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailView
                .toolbar { toolbarContent }
                .navigationTitle(selection.title)
                .safeAreaInset(edge: .bottom) {
                    if shouldShowStatusBar {
                        statusBar
                    }
                }
        }
        .onChange(of: model.snapshot != nil) { _, hasSnapshot in
            if hasSnapshot, selection == .settings { selection = .summary }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .settings: ScanFormView(model: model)
        case .summary: SummaryView(model: model)
        case .endpoints: EndpointsView(model: model)
        case .unmatched: UnmatchedView(model: model)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isRunning {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await model.runScan() }
            } label: {
                Label("스캔", systemImage: "play.fill")
            }
            .disabled(model.isRunning)

            Menu {
                Button("스냅샷 열기…") { model.openSnapshot() }
                Button("스냅샷 저장…") { model.saveSnapshot() }
                    .disabled(model.snapshot == nil)
            } label: {
                Label("스냅샷", systemImage: "doc.badge.gearshape")
            }
        }
    }

    private var statusBar: some View {
        HStack {
            statusIcon
            Text(model.statusMessage.isEmpty ? "준비" : model.statusMessage)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let snapshot = model.snapshot {
                Text("엔드포인트 \(snapshot.endpoints.count)개 · 매치 안됨 \(snapshot.unmatchedRouterCases.count)개")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var shouldShowStatusBar: Bool {
        model.state != .idle || model.snapshot != nil || !model.statusMessage.isEmpty
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch model.state {
        case .idle: Image(systemName: "circle").foregroundStyle(.secondary)
        case .running: Image(systemName: "hourglass").foregroundStyle(.blue)
        case .loaded: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}

#Preview {
    ContentView(model: ScanModel())
}
