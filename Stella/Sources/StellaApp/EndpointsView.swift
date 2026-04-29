import SwiftUI
import UniformTypeIdentifiers
import StellaCore

struct EndpointRow: Identifiable {
    let id: String
    let entry: CoverageSnapshot.EndpointEntry

    init(entry: CoverageSnapshot.EndpointEntry) {
        self.id = "\(entry.key.method.rawValue) \(entry.key.path)"
        self.entry = entry
    }
}

struct EndpointsView: View {
    @Bindable var model: ScanModel
    @State private var selection: EndpointRow.ID?
    @State private var draggingColumn: EndpointColumn?
    @AppStorage("endpointColumnOrder") private var columnOrderRaw = EndpointColumn.defaultOrderRaw

    var body: some View {
        if model.snapshot == nil {
            ContentUnavailableView(
                "아직 스냅샷이 없어요",
                systemImage: "list.bullet",
                description: Text("스캔을 실행해 엔드포인트를 불러오세요.")
            )
        } else {
            VStack(spacing: 0) {
                filterBar
                Divider()
                VSplitView {
                    table
                        .frame(maxWidth: .infinity, minHeight: 220, idealHeight: 340, alignment: .topLeading)
                    if let detail = selectedDetail {
                        EndpointDetailView(entry: detail, snapshot: model.snapshot!, model: model)
                            .frame(minHeight: 460, idealHeight: 640, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView("엔드포인트를 선택하세요", systemImage: "cursorarrow.click")
                            .frame(minHeight: 360, idealHeight: 520, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { selectFirstRowIfNeeded() }
            .onChange(of: rows.map(\.id)) { _, _ in selectFirstRowIfNeeded() }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            TextField("경로 / 요약 / operationId 검색", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 380)

            Picker("메서드", selection: $model.methodFilter) {
                Text("모든 메서드").tag(Optional<HTTPMethod>.none)
                ForEach(HTTPMethod.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(Optional<HTTPMethod>.some(m))
                }
            }
            .frame(width: 160)

            Picker("상태", selection: $model.connectionFilter) {
                ForEach(ScanModel.ConnectionFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 160)

            Picker("태그", selection: $model.selectedTag) {
                Text("모든 태그").tag(Optional<String>.none)
                ForEach(model.availableTags, id: \.self) { t in
                    Text(t).tag(Optional<String>.some(t))
                }
            }
            .frame(width: 200)

            Picker("담당자", selection: $model.selectedOwner) {
                Text("모든 담당자").tag(Optional<String>.none)
                ForEach(model.availableOwners, id: \.self) { o in
                    Text(o).tag(Optional<String>.some(o))
                }
            }
            .frame(width: 200)

            Spacer()

            columnOrderMenu

            Text("\(model.filteredEndpoints.count)개 표시")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(12)
    }

    private var rows: [EndpointRow] {
        model.filteredEndpoints.map(EndpointRow.init)
    }

    private var table: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(rows) { row in
                        endpointRow(row)
                            .id(row.id)
                    }
                } header: {
                    endpointHeader
                }
            }
            .frame(minWidth: tableMinWidth, maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var endpointHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedColumns) { column in
                HStack(spacing: 6) {
                    Text(column.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .frame(width: column.width, alignment: .leading)
                .frame(height: 30)
                .background(.background)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(.separator)
                        .frame(width: 1)
                }
                .contextMenu {
                    Button("왼쪽으로 이동") { moveColumn(column, offset: -1) }
                        .disabled(isFirstColumn(column))
                    Button("오른쪽으로 이동") { moveColumn(column, offset: 1) }
                        .disabled(isLastColumn(column))
                    Divider()
                    Button("기본 순서로") { resetColumnOrder() }
                }
                .opacity(draggingColumn == column ? 0.45 : 1)
                .onDrag {
                    draggingColumn = column
                    return NSItemProvider(object: column.rawValue as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: EndpointColumnDropDelegate(
                        target: column,
                        draggingColumn: $draggingColumn,
                        reorder: reorderColumn
                    )
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
    }

    private func endpointRow(_ row: EndpointRow) -> some View {
        Button {
            selection = row.id
        } label: {
            HStack(spacing: 0) {
                ForEach(orderedColumns) { column in
                    columnCell(column, row: row)
                        .padding(.horizontal, 10)
                        .frame(width: column.width, alignment: .leading)
                        .frame(height: 30)
                }
            }
            .contentShape(Rectangle())
            .foregroundStyle(selection == row.id ? Color.white : Color.primary)
            .background(rowBackground(row))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.45))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func columnCell(_ column: EndpointColumn, row: EndpointRow) -> some View {
        switch column {
        case .method:
            MethodBadge(method: row.entry.key.method)
        case .path:
            Text(row.entry.key.path)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        case .summary:
            Text(row.entry.summary ?? row.entry.operationId ?? "—")
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
        case .tag:
            Text(row.entry.tag ?? "—")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        case .owner:
            if let owner = row.entry.owner {
                Text(owner.displayName)
                    .font(.callout)
                    .lineLimit(1)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        case .connections:
            ConnectionsCell(entry: row.entry, projects: model.snapshot?.projects ?? [])
        }
    }

    private func rowBackground(_ row: EndpointRow) -> some ShapeStyle {
        if selection == row.id {
            return AnyShapeStyle(Color.accentColor)
        }
        guard let index = rows.firstIndex(where: { $0.id == row.id }),
              index.isMultiple(of: 2) else {
            return AnyShapeStyle(Color.clear)
        }
        return AnyShapeStyle(Color.secondary.opacity(0.08))
    }

    private var columnOrderMenu: some View {
        Menu {
            ForEach(orderedColumns) { column in
                Menu(column.title) {
                    Button("왼쪽으로 이동") { moveColumn(column, offset: -1) }
                        .disabled(isFirstColumn(column))
                    Button("오른쪽으로 이동") { moveColumn(column, offset: 1) }
                        .disabled(isLastColumn(column))
                }
            }
            Divider()
            Button("기본 순서로 복원") { resetColumnOrder() }
        } label: {
            Label("열 순서", systemImage: "rectangle.split.3x1")
        }
        .menuStyle(.borderlessButton)
    }

    private var orderedColumns: [EndpointColumn] {
        let stored = columnOrderRaw
            .split(separator: ",")
            .compactMap { EndpointColumn(rawValue: String($0)) }
        let missing = EndpointColumn.allCases.filter { !stored.contains($0) }
        let resolved = stored + missing
        return resolved.isEmpty ? EndpointColumn.allCases : resolved
    }

    private var tableMinWidth: CGFloat {
        orderedColumns.reduce(CGFloat.zero) { $0 + $1.width }
    }

    private func persistColumnOrder(_ columns: [EndpointColumn]) {
        columnOrderRaw = columns.map(\.rawValue).joined(separator: ",")
    }

    private func moveColumn(_ column: EndpointColumn, offset: Int) {
        var columns = orderedColumns
        guard let current = columns.firstIndex(of: column) else { return }
        let target = current + offset
        guard columns.indices.contains(target) else { return }
        columns.swapAt(current, target)
        persistColumnOrder(columns)
    }

    private func reorderColumn(_ source: EndpointColumn, to target: EndpointColumn) {
        var columns = orderedColumns
        guard let sourceIndex = columns.firstIndex(of: source),
              let targetIndex = columns.firstIndex(of: target),
              sourceIndex != targetIndex else {
            return
        }
        columns.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
        )
        persistColumnOrder(columns)
    }

    private func resetColumnOrder() {
        columnOrderRaw = EndpointColumn.defaultOrderRaw
    }

    private func isFirstColumn(_ column: EndpointColumn) -> Bool {
        orderedColumns.first == column
    }

    private func isLastColumn(_ column: EndpointColumn) -> Bool {
        orderedColumns.last == column
    }

    private var selectedDetail: CoverageSnapshot.EndpointEntry? {
        guard let selection else { return nil }
        return rows.first { $0.id == selection }?.entry
    }

    private func selectFirstRowIfNeeded() {
        if selection == nil || !rows.contains(where: { $0.id == selection }) {
            selection = rows.first?.id
        }
    }
}

private struct EndpointColumnDropDelegate: DropDelegate {
    let target: EndpointColumn
    @Binding var draggingColumn: EndpointColumn?
    let reorder: (EndpointColumn, EndpointColumn) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingColumn, draggingColumn != target else { return }
        reorder(draggingColumn, target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingColumn = nil
        return true
    }
}

private enum EndpointColumn: String, CaseIterable, Identifiable {
    case method
    case path
    case summary
    case tag
    case owner
    case connections

    var id: String { rawValue }

    static var defaultOrderRaw: String {
        allCases.map(\.rawValue).joined(separator: ",")
    }

    var title: String {
        switch self {
        case .method: return "메서드"
        case .path: return "경로"
        case .summary: return "요약"
        case .tag: return "태그"
        case .owner: return "담당자"
        case .connections: return "연결"
        }
    }

    var width: CGFloat {
        switch self {
        case .method: return 90
        case .path: return 360
        case .summary: return 260
        case .tag: return 250
        case .owner: return 170
        case .connections: return 260
        }
    }
}

private struct MethodBadge: View {
    let method: HTTPMethod

    var body: some View {
        Text(method.rawValue)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
    }

    private var color: Color {
        switch method {
        case .get: return .blue
        case .post: return .green
        case .put: return .orange
        case .patch: return .purple
        case .delete: return .red
        }
    }
}

private struct ConnectionsCell: View {
    let entry: CoverageSnapshot.EndpointEntry
    let projects: [CoverageSnapshot.ProjectInfo]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(projects, id: \.key) { project in
                let connection = entry.connections[project.key] ?? nil
                Label {
                    Text(project.displayName).font(.caption)
                } icon: {
                    Image(systemName: connection != nil
                          ? "checkmark.circle.fill"
                          : "circle.dashed")
                    .foregroundStyle(connection != nil ? .green : .secondary)
                }
            }
        }
    }
}

private struct EndpointDetailView: View {
    let entry: CoverageSnapshot.EndpointEntry
    let snapshot: CoverageSnapshot
    @Bindable var model: ScanModel
    @State private var selectedTab: DetailTab = .overview
    @AppStorage("apiResponseFontSize") private var apiResponseFontSize = 12.0

    private enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "개요"
        case spec = "스펙"
        case test = "테스트"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()
            Picker("상세 탭", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
            Group {
                switch selectedTab {
                case .overview:
                    overviewPane
                case .spec:
                    specPane
                case .test:
                    testPane
                }
            }
        }
        .background(.regularMaterial)
        .onAppear { model.prepareAPITestTemplate(for: entry) }
        .onChange(of: entry.key) { _, _ in model.prepareAPITestTemplate(for: entry, overwrite: true) }
    }

    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            MethodBadge(method: entry.key.method)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.key.path)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    if let summary = entry.summary {
                        Text(summary)
                    }
                    if let opId = entry.operationId {
                        Text("operationId: \(opId)")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            if let tag = entry.tag {
                Text(tag)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tertiary, in: RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 280)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var overviewPane: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 14) {
                detailCard("담당자") {
                    ownerPicker
                }
                detailCard("연결 상태") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.projects, id: \.key) { project in
                            connectionRow(project: project, connection: entry.connections[project.key] ?? nil)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var specPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let description = entry.description, !description.isEmpty {
                    detailCard("설명") {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if !entry.parameters.isEmpty {
                    detailCard("Parameters") { parametersTable }
                }
                if entry.requestBody != nil || entry.requestBodyExample != nil {
                    detailCard("Request Body") { requestBodyBlock }
                }
                if !entry.responses.isEmpty {
                    detailCard("Responses") { responsesList }
                }
                if entry.description == nil && entry.parameters.isEmpty && entry.requestBody == nil && entry.responses.isEmpty {
                    ContentUnavailableView("상세 스펙이 없습니다", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var testPane: some View {
        ScrollView {
            apiTester
                .padding(16)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ownerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("담당자", selection: Binding<String?>(
                get: { model.assignedOwnerEmail(for: entry) },
                set: { model.assignOwner(email: $0, to: entry) }
            )) {
                Text("미지정").tag(Optional<String>.none)
                ForEach(model.manualOwners, id: \.email) { owner in
                    Text(owner.authorRef.displayName).tag(Optional<String>.some(owner.email))
                }
            }
            .frame(maxWidth: 260)
            if let owner = entry.owner, let github = owner.githubUsername {
                Label("@\(github)", systemImage: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var parametersTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                detailSectionTitle("위치")
                detailSectionTitle("이름")
                detailSectionTitle("타입")
                detailSectionTitle("설명")
            }
            Divider().gridCellColumns(4)
            ForEach(entry.parameters, id: \.name) { parameter in
                GridRow {
                    Text(parameter.location)
                    Text(parameter.name + (parameter.required ? " *" : ""))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                    Text(parameter.schema ?? "—")
                    Text(parameter.description ?? "—")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private var requestBodyBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let requestBody = entry.requestBody {
                Text(requestBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let example = entry.requestBodyExample {
                codeBlock(example, minHeight: 90, maxHeight: 220, highlightJSON: true)
            }
        }
    }

    private var responsesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.responses, id: \.statusCode) { response in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(response.statusCode)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    Text(response.description ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func detailSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private var apiTester: some View {
        HStack(alignment: .top, spacing: 14) {
            detailCard("요청") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Base URL") {
                        TextField("https://dev.api.umc.it.kr", text: $model.apiBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Bearer Token") {
                        SecureField("access token", text: $model.bearerToken)
                            .textFieldStyle(.roundedBorder)
                    }
                    parameterFields(
                        title: "Path params",
                        fields: model.pathFields(for: entry),
                        values: $model.apiPathValues
                    )
                    parameterFields(
                        title: "Query",
                        fields: model.queryFields(for: entry),
                        values: $model.apiQueryValues
                    )
                    LabeledContent("Body") {
                        VStack(alignment: .trailing, spacing: 4) {
                            TextEditor(text: $model.apiRequestBody)
                                .font(.system(.caption, design: .monospaced))
                                .frame(height: 120)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
                            Button("JSON 포맷") {
                                if let pretty = JSONHighlighter.prettyPrinted(model.apiRequestBody) {
                                    model.apiRequestBody = pretty
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .disabled(JSONHighlighter.prettyPrinted(model.apiRequestBody) == nil)
                        }
                    }
                    HStack {
                        Button("스펙으로 채우기") {
                            model.prepareAPITestTemplate(for: entry, overwrite: true)
                        }
                        Button {
                            Task { await model.runAPITest(entry: entry) }
                        } label: {
                            Label("요청 실행", systemImage: "play.fill")
                        }
                        .disabled(model.isAPITestRunning)
                        if model.isAPITestRunning {
                            ProgressView().controlSize(.small)
                        }
                        Spacer()
                        Text("필수값은 *")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 520)

            detailCard("응답") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("텍스트 크기")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $apiResponseFontSize, in: 10...22, step: 1)
                            .frame(maxWidth: 180)
                        Text("\(Int(apiResponseFontSize))pt")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }

                    if model.apiResponseText.isEmpty {
                        ContentUnavailableView("아직 응답 없음", systemImage: "network")
                            .frame(minHeight: 280)
                    } else {
                        codeBlock(
                            model.apiResponseText,
                            minHeight: 300,
                            fontSize: apiResponseFontSize,
                            highlightJSON: true
                        )
                    }
                }
            }
            .frame(minWidth: 360)
        }
    }

    private func detailCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func parameterFields(
        title: String,
        fields: [APIParameterField],
        values: Binding<[String: String]>
    ) -> some View {
        if fields.isEmpty {
            LabeledContent(title) {
                Text("없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            LabeledContent(title) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(fields) { field in
                        HStack(alignment: .center, spacing: 8) {
                            HStack(spacing: 4) {
                                Text(field.name)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                if field.required {
                                    Text("*")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.red)
                                }
                                if let type = field.type, !type.isEmpty {
                                    Text(type)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .frame(width: 180, alignment: .leading)

                            TextField(field.description ?? "", text: Binding(
                                get: { values.wrappedValue[field.name] ?? "" },
                                set: { values.wrappedValue[field.name] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
        }
    }

    private func codeBlock(
        _ text: String,
        minHeight: CGFloat,
        maxHeight: CGFloat? = nil,
        fontSize: CGFloat = 12,
        highlightJSON: Bool = false
    ) -> some View {
        ScrollView {
            Group {
                if highlightJSON {
                    Text(JSONHighlighter.attributed(text))
                } else {
                    Text(text)
                }
            }
            .font(.system(size: fontSize, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }

    private func connectionRow(
        project: CoverageSnapshot.ProjectInfo,
        connection: CoverageSnapshot.Connection?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: connection == nil ? "circle.dashed" : "checkmark.circle.fill")
                .foregroundStyle(connection == nil ? Color.secondary : Color.green)
                .padding(.top, 2)
            Text(project.displayName)
                .font(.subheadline.weight(.semibold))
                .frame(width: 96, alignment: .leading)
            if let connection {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(connection.routerEnum).\(connection.caseName)")
                        .font(.system(.callout, design: .monospaced))
                    Text("\(connection.filePath):\(connection.line)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("작성자 \(connection.author.displayName.isEmpty ? connection.author.email : connection.author.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.secondary)
                        Text(connection.lastCommitSHA.prefix(7))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("연결 안됨")
                    .foregroundStyle(.secondary)
                    .italic()
            }
            Spacer()
        }
    }
}
