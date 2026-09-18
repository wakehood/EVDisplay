import SwiftUI
import OBD2Kit

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
                landscapeLayout(geometry: geometry)
            }
        }
        .environment(connectionManager)
    }

    // MARK: - iPhone Portrait
    private func iPhonePortraitLayout(geometry: GeometryProxy) -> some View {
        let sp: CGFloat = 16
        return ScrollView(.vertical, showsIndicators: false) {
            MCUDashboardCardView()
                .frame(height: 500)
                .padding([.horizontal, .top], sp)
            VCUDashboardCardView()
                .frame(height: 300)
                .padding(.horizontal, sp)
                .padding(.top, 8)
            if !connectionManager.isPreviewMock && connectionManager.isConnected {
                busLog
                    .padding(.horizontal, sp)
                    .padding(.top, 8)
            }
        }
        .background(Color("Shadow Background"))
    }

    // MARK: - iPad + iPhone Landscape
    //
    // MCU (60%) and VCU (40%) panels sit side by side.
    // On iPhone landscape the minimum card height kicks in and ScrollView allows scrolling.
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        let sp: CGFloat = 12
        let cardH = max(geometry.size.height - sp * 2, 280)
        let totalWidth = geometry.size.width - sp * 3   // left pad + gap + right pad
        let mcuWidth = totalWidth * 0.60
        let vcuWidth = totalWidth * 0.40

        return ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: sp) {
                MCUDashboardCardView()
                    .frame(width: mcuWidth, height: cardH)
                VCUDashboardCardView()
                    .frame(width: vcuWidth, height: cardH)
            }
            .padding(sp)

            if !connectionManager.isPreviewMock && connectionManager.isConnected {
                busLog
                    .padding(.horizontal, sp)
            }
        }
        .background(Color("Shadow Background"))
    }

    // MARK: - Bus console log
    private var busLog: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bus Active Line Traces")
                .font(.caption2)
                .foregroundColor(.secondary)
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
}

#Preview("iPad Landscape") {
    ProportionalDashboardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}

#Preview("iPhone Portrait") {
    ProportionalDashboardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}
