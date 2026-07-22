import SwiftUI

struct ContentView: View {
    var body: some View { ProportionalDashboardView() }
}

struct ProportionalDashboardView: View {
    // TOGGLE HERE: Set to true for UI development, false for live vehicle connections
    @State private var connectionManager = OBD2ConnectionManager(isPreviewMock: true)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                EVDashboardCardView()
                    .frame(width: (geometry.size.width - 16) * 0.66)
                    .frame(maxHeight: .infinity)
                
                VStack(spacing: 16) {
                    ChargingHealthDashboardCardView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    CellsDashboardCardView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: (geometry.size.width - 16) * 0.34)
                .frame(maxHeight: .infinity)
            }
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
        .environment(connectionManager) // Direct type safety injection
    }
}

#Preview {
    ProportionalDashboardView()
    // Prevents child elements from crashing on layout resolution loops
    .environment(OBD2ConnectionManager(isPreviewMock: true)) 
}



