import SwiftUI
import Charts

struct HistoryChartView: View {
    let snapshots: [Snapshot]

    var body: some View {
        Chart {
            ForEach(snapshots) { snap in
                LineMark(
                    x: .value("Date", snap.timestamp),
                    y: .value("Value", snap.value)
                )
            }
        }
        .padding()
        .navigationTitle(NSLocalizedString("HistoryTitle", comment: ""))
    }
}
