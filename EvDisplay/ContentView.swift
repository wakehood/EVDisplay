import SwiftUI

struct ContentView: View {
    var body: some View { ProportionalDashboardView() }
}

struct ProportionalDashboardView: View {
    @State private var connectionManager = OBD2ConnectionManager(isPreviewMock: false)

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { geometry in
            if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                iPhonePortraitLayout(geometry: geometry)
            } else {
                gridLayout(geometry: geometry)
            }
        }
        .environment(connectionManager)
    }

    // MARK: - iPhone Portrait: single-column vertical scroll
    private func iPhonePortraitLayout(geometry: GeometryProxy) -> some View {
        let sp: CGFloat = 16
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: sp) {
                GeneralDashboardCardView()
                    .frame(height: 150)
                EVDashboardCard()
                    .frame(height: 320)
                ChargingDashboardCardView()
                    .frame(height: 180)
                HealthDashboardCardView()
                    .frame(height: 230)
                CellsDashboardCardView()
                    .frame(height: 550)
            }
            .padding(sp)

            // Bus console log
            VStack(alignment: .leading, spacing: 4) {
                Text("Bus Active Line Traces").font(.caption2).foregroundColor(.secondary)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(0..<connectionManager.receivedLogs.count, id: \.self) { index in
                                Text(connectionManager.receivedLogs[index])
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 80)
                    .background(Color.black)
                    .cornerRadius(6)
                    .onChange(of: connectionManager.receivedLogs.count) { _, newValue in
                        if newValue > 0 { withAnimation { proxy.scrollTo(newValue - 1) } }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - iPad + iPhone Landscape: 3-row 2-column grid
    //
    // Row 1: EV (58%) | General (42%)
    // Row 2: Charging (50%) | Health (50%)
    // Row 3: Cells (full width)
    //
    // Heights are proportional to screen height on iPad (fills screen without scrolling).
    // On iPhone landscape the proportional heights are shorter than the minimums, so the
    // ScrollView kicks in to let the user scroll through all panels.
    private func gridLayout(geometry: GeometryProxy) -> some View {
        let sp: CGFloat = 12
        // Usable height after top/bottom padding (sp each) + 2 inter-row gaps (sp each)
        let totalH = geometry.size.height - sp * 4
        // Proportions fill iPad screens exactly; minimums ensure content fits on iPhone landscape.
        // Row 1 min 260: EVDashboardCard gauge is 160pt + ~40pt title = needs ~200pt, 60pt breathing room.
        // Row 2 min 220: HealthDashboardCardView 7-item grid needs ~204pt minimum.
        // Row 3 min 360: 9-col iPad grid is ~272pt, 6-col iPhone landscape grid is ~348pt.
        let row1H = max(totalH * 0.35, 260)
        let row2H = max(totalH * 0.28, 220)
        let row3H = max(totalH * 0.37, 360)
        // Usable width after left/right padding (sp each) + 1 inter-column gap (sp)
        let evColW = (geometry.size.width - sp * 3) * 0.58

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: sp) {
                HStack(spacing: sp) {
                    EVDashboardCard()
                        .frame(width: evColW, height: row1H, alignment: .top)
                        .clipped()
                    GeneralDashboardCardView()
                        .frame(maxWidth: .infinity)
                        .frame(height: row1H, alignment: .top)
                        .clipped()
                }
                HStack(spacing: sp) {
                    ChargingDashboardCardView()
                        .frame(maxWidth: .infinity)
                        .frame(height: row2H, alignment: .top)
                        .clipped()
                    HealthDashboardCardView()
                        .frame(maxWidth: .infinity)
                        .frame(height: row2H, alignment: .top)
                        .clipped()
                }
                CellsDashboardCardView()
                    .frame(maxWidth: .infinity)
                    .frame(height: row3H, alignment: .top)
                    .clipped()
            }
            .padding(sp)
        }
        .background(Color(.systemGroupedBackground))
    }
}


#Preview("iPad Grid Layout") {
    ProportionalDashboardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}

#Preview("iPhone Portrait Layout") {
    ProportionalDashboardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}
