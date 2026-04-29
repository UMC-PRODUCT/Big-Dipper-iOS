import APICoverageCore
import Foundation

enum HTMLReportFormatter {
    static func render(_ snapshot: CoverageSnapshot) -> String {
        let timestamp = ISO8601DateFormatter().string(from: snapshot.generatedAt)
        let body = [
            renderHeader(snapshot, timestamp: timestamp),
            renderProjectSummary(snapshot),
            renderOwnerRollup(snapshot),
            renderEndpointTable(snapshot),
            renderUnmatched(snapshot),
        ].joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Stella — API Coverage</title>
        <style>\(stylesheet)</style>
        </head>
        <body>
        <main>
        \(body)
        </main>
        <script>\(filterScript)</script>
        </body>
        </html>
        """
    }

    private static func renderHeader(_ snapshot: CoverageSnapshot, timestamp: String) -> String {
        """
        <header>
          <h1>Stella</h1>
          <p class="subtitle">
            \(escape(snapshot.openAPI.title)) ·
            v\(escape(snapshot.openAPI.version)) ·
            오퍼레이션 \(snapshot.openAPI.totalPaths)개 ·
            생성 <time>\(timestamp)</time>
          </p>
        </header>
        """
    }

    private static func renderProjectSummary(_ snapshot: CoverageSnapshot) -> String {
        let cards = snapshot.projects.map { project -> String in
            let stats = snapshot.summary[project.key]
            let matched = stats?.matched ?? 0
            let total = snapshot.openAPI.totalPaths
            let unmatched = stats?.unmatched ?? 0
            let percent = total > 0 ? Int((Double(matched) / Double(total) * 100).rounded()) : 0
            let level = percent >= 85 ? "good" : (percent >= 60 ? "warn" : "bad")
            return """
            <article class="card">
              <h3>\(escape(project.displayName))</h3>
              <p class="path">\(escape(project.rootPath))</p>
              <div class="coverage \(level)">
                <span class="percent">\(percent)%</span>
                <span class="muted">커버리지</span>
              </div>
              <div class="bar"><div class="fill \(level)" style="width:\(percent)%"></div></div>
              <ul class="metrics">
                <li>매치 <strong>\(matched)</strong></li>
                <li>누락 <strong>\(total - matched)</strong></li>
                <li>매치 안됨 <strong>\(unmatched)</strong></li>
              </ul>
            </article>
            """
        }.joined(separator: "\n")

        return """
        <section>
          <h2>프로젝트별 커버리지</h2>
          <div class="cards">\(cards)</div>
        </section>
        """
    }

    private static func renderOwnerRollup(_ snapshot: CoverageSnapshot) -> String {
        var totals: [String: (owned: Int, matched: Int, github: String?)] = [:]
        for endpoint in snapshot.endpoints {
            guard let owner = endpoint.owner else { continue }
            let isMatched = endpoint.connections.values.contains { $0 != nil }
            var entry = totals[owner.displayName] ?? (0, 0, owner.githubUsername)
            entry.owned += 1
            if isMatched { entry.matched += 1 }
            totals[owner.displayName] = entry
        }

        if totals.isEmpty {
            return """
            <section>
              <h2>담당자</h2>
              <p class="muted">owners.yml에 담당자가 지정되지 않았습니다.</p>
            </section>
            """
        }

        let rows = totals
            .sorted { $0.key < $1.key }
            .map { name, data -> String in
                let percent = data.owned > 0
                    ? Int((Double(data.matched) / Double(data.owned) * 100).rounded())
                    : 0
                let github = data.github.map { "<span class=\"muted\">@\(escape($0))</span>" } ?? ""
                return """
                <tr>
                  <td>\(escape(name)) \(github)</td>
                  <td class="num">\(data.owned)</td>
                  <td class="num">\(data.matched)</td>
                  <td class="num">\(percent)%</td>
                </tr>
                """
            }
            .joined(separator: "\n")

        return """
        <section>
          <h2>담당자별 엔드포인트</h2>
          <table class="rollup">
            <thead><tr><th>담당자</th><th class="num">담당 수</th><th class="num">매치</th><th class="num">매치율</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>
        </section>
        """
    }

    private static func renderEndpointTable(_ snapshot: CoverageSnapshot) -> String {
        let projectKeys = snapshot.projects.map(\.key)
        let projectHeaders = snapshot.projects
            .map { "<th>\(escape($0.displayName))</th>" }
            .joined()

        let rows = snapshot.endpoints.map { endpoint -> String in
            let connectionCells = projectKeys.map { key -> String in
                let connection = endpoint.connections[key] ?? nil
                if let connection {
                    let blame = connection.author.displayName.isEmpty
                        ? connection.author.email
                        : connection.author.displayName
                    return """
                    <td class="conn matched">
                      <span class="dot good">●</span>
                      <code>\(escape(connection.routerEnum)).\(escape(connection.caseName))</code>
                      <span class="muted">by \(escape(blame))</span>
                    </td>
                    """
                } else {
                    return "<td class=\"conn missing\"><span class=\"dot bad\">○</span> <span class=\"muted\">—</span></td>"
                }
            }.joined()

            let ownerCell = endpoint.owner.map {
                "<span class=\"owner\">\(escape($0.displayName))</span>"
            } ?? "<span class=\"muted\">—</span>"

            return """
            <tr data-owner="\(escape(endpoint.owner?.displayName ?? ""))" data-tag="\(escape(endpoint.tag ?? ""))">
              <td><span class="method m-\(endpoint.key.method.rawValue.lowercased())">\(endpoint.key.method.rawValue)</span></td>
              <td><code>\(escape(endpoint.key.path))</code></td>
              <td>\(escape(endpoint.summary ?? endpoint.operationId ?? "—"))</td>
              <td>\(escape(endpoint.tag ?? "—"))</td>
              <td>\(ownerCell)</td>
              \(connectionCells)
            </tr>
            """
        }.joined(separator: "\n")

        let owners = snapshot.endpoints.compactMap { $0.owner?.displayName }
        let uniqueOwners = Array(Set(owners)).sorted()
        let ownerOptions = (["<option value=\"\">모든 담당자</option>"] + uniqueOwners.map {
            "<option value=\"\(escape($0))\">\(escape($0))</option>"
        }).joined()

        return """
        <section>
          <h2>엔드포인트</h2>
          <div class="filters">
            <input id="search" placeholder="경로 / 요약 / operationId 검색" oninput="apicovFilter()">
            <select id="ownerFilter" onchange="apicovFilter()">\(ownerOptions)</select>
          </div>
          <table id="endpoints">
            <thead><tr><th>메서드</th><th>경로</th><th>요약</th><th>태그</th><th>담당자</th>\(projectHeaders)</tr></thead>
            <tbody>\(rows)</tbody>
          </table>
        </section>
        """
    }

    private static func renderUnmatched(_ snapshot: CoverageSnapshot) -> String {
        guard !snapshot.unmatchedRouterCases.isEmpty else { return "" }

        let rows = snapshot.unmatchedRouterCases.map { entry -> String in
            """
            <tr>
              <td>\(escape(entry.project))</td>
              <td><code>\(escape(entry.routerEnum)).\(escape(entry.caseName))</code></td>
              <td class="reason">\(escape(entry.reason))</td>
              <td><code class="muted">\(escape(entry.filePath)):\(entry.line)</code></td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <section>
          <h2>매치 안됨 (\(snapshot.unmatchedRouterCases.count)개)</h2>
          <table>
            <thead><tr><th>프로젝트</th><th>라우터 케이스</th><th>사유</th><th>위치</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>
        </section>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let stylesheet = """
    :root {
      color-scheme: light dark;
      --bg: #fff; --fg: #1a1a1a; --muted: #6b7280;
      --line: #e5e7eb; --card: #f9fafb; --good: #16a34a;
      --warn: #d97706; --bad: #dc2626; --accent: #2563eb;
    }
    @media (prefers-color-scheme: dark) {
      :root { --bg: #0b0c0f; --fg: #e5e7eb; --muted: #9ca3af;
              --line: #1f2937; --card: #111827; }
    }
    body { font-family: -apple-system, system-ui, sans-serif; background: var(--bg);
           color: var(--fg); margin: 0; padding: 0; }
    main { max-width: 1400px; margin: 0 auto; padding: 32px 24px; }
    header h1 { margin: 0 0 4px; font-size: 32px; }
    .subtitle { margin: 0; color: var(--muted); font-size: 14px; }
    section { margin-top: 32px; }
    section h2 { font-size: 18px; margin: 0 0 12px; }
    .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
    .card { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 16px; }
    .card h3 { margin: 0 0 4px; font-size: 16px; }
    .path { font-size: 12px; color: var(--muted); margin: 0 0 12px;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .coverage { display: flex; align-items: baseline; gap: 8px; }
    .coverage .percent { font-size: 32px; font-weight: 700; }
    .coverage.good .percent { color: var(--good); }
    .coverage.warn .percent { color: var(--warn); }
    .coverage.bad .percent { color: var(--bad); }
    .bar { height: 6px; background: var(--line); border-radius: 3px; margin: 8px 0;
           overflow: hidden; }
    .fill { height: 100%; }
    .fill.good { background: var(--good); }
    .fill.warn { background: var(--warn); }
    .fill.bad { background: var(--bad); }
    .metrics { list-style: none; padding: 0; margin: 8px 0 0;
               display: flex; gap: 16px; font-size: 13px; color: var(--muted); }
    .metrics strong { color: var(--fg); }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 8px 10px; text-align: left; border-bottom: 1px solid var(--line);
             vertical-align: top; }
    th { font-weight: 600; color: var(--muted); position: sticky; top: 0; background: var(--bg); }
    .num { text-align: right; font-variant-numeric: tabular-nums; }
    code { font-family: ui-monospace, SF Mono, monospace; font-size: 12px; }
    .muted { color: var(--muted); }
    .method { display: inline-block; padding: 2px 6px; border-radius: 4px;
              font-size: 11px; font-weight: 700; color: #fff; }
    .m-get { background: #2563eb; }
    .m-post { background: #16a34a; }
    .m-put { background: #d97706; }
    .m-patch { background: #9333ea; }
    .m-delete { background: #dc2626; }
    .conn .dot { font-size: 14px; vertical-align: middle; }
    .dot.good { color: var(--good); }
    .dot.bad { color: var(--muted); }
    .filters { display: flex; gap: 8px; margin-bottom: 8px; }
    .filters input, .filters select {
      padding: 6px 10px; border: 1px solid var(--line); border-radius: 6px;
      background: var(--bg); color: var(--fg); font-size: 13px;
    }
    .filters input { flex: 1; max-width: 360px; }
    .owner { display: inline-block; padding: 2px 6px; border-radius: 4px;
             background: var(--accent); color: #fff; font-size: 12px; }
    .reason { color: var(--warn); }
    .rollup td:first-child { font-weight: 500; }
    """

    private static let filterScript = """
    function apicovFilter() {
      const q = document.getElementById('search').value.toLowerCase();
      const owner = document.getElementById('ownerFilter').value;
      const rows = document.querySelectorAll('#endpoints tbody tr');
      rows.forEach(function (row) {
        const text = row.textContent.toLowerCase();
        const matchText = q === '' || text.includes(q);
        const matchOwner = owner === '' || row.dataset.owner === owner;
        row.style.display = (matchText && matchOwner) ? '' : 'none';
      });
    }
    """
}
