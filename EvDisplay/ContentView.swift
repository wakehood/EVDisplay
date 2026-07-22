import SwiftUI

struct ContentView: View {
    var body: some View { ProportionalDashboardView() }
}

struct ProportionalDashboardView: View {
    // TOGGLE HERE: Set to true for UI development, false for live vehicle connections
    @State private var connectionManager = OBD2ConnectionManager(isPreviewMock: true)
    
    // Tracks the device's current width sizing category (compact = iPhone, regular = iPad)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 16
            let usableWidth = geometry.size.width - spacing
            
            // 1. DYNAMIC DISPATCH ENGINE: Check if device is compact (iPhone) or regular (iPad Landscape)
            if horizontalSizeClass == .compact {
                
                // --- iPHONE RESPONSIVE VERTICAL LAYOUT ---
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: spacing) {
                        
                        EVDashboardCard()
                            .frame(height: 320) // Enforce explicit structural frame tall heights on iPhone scrolling
                        
                        ChargingHealthDashboardCardView()
                            .frame(height: 180)
                        
                        CellsDashboardCardView()
                            .frame(height: 380) // Expanded slightly to provide space for your cell grids
                        
                    }
                    .padding(spacing)
                }
                .background(Color(.systemGroupedBackground))
                
            } else {
                
                // --- iPAD LANDSCAPE HORIZONTAL LAYOUT (Your original layout) ---
                HStack(spacing: spacing) {
                    EVDashboardCard()
                        .frame(width: usableWidth * 0.66)
                        .frame(maxHeight: .infinity)
                    
                    VStack(spacing: spacing) {
                        ChargingHealthDashboardCardView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        CellsDashboardCardView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: usableWidth * 0.34)
                    .frame(maxHeight: .infinity)
                }
                .padding(spacing)
                .background(Color(.systemGroupedBackground))
                
            }
        }
        .environment(connectionManager) // Direct type safety injection
    }
}


#Preview("iPad Pro Landscape Layout") {
    ProportionalDashboardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}

#Preview("iPhone Diagnostic Layout") {
    ProportionalDashboardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}


