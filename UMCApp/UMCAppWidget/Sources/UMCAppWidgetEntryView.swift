import SwiftUI

struct UMCHomeWidgetEntryView: View {

    // MARK: - Property

    let entry: UMCHomeWidgetEntry

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("UMC")
                .font(.headline)
            Text("위젯 준비 중입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
