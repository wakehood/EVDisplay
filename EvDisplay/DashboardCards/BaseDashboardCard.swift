//
//  BaseDashboardCard.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/20/26.
//

import SwiftUI

struct BaseDashboardCard<Content: View>: View {
    let title: String?
    let themeColor: Color
    let content: Content

    init(title: String? = nil, themeColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.themeColor = themeColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeColor.opacity(0.6), lineWidth: 1.5)
                )

            VStack(alignment: .leading) {
                if let title {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(themeColor)
                        .padding([.top, .leading])
                }

                Spacer(minLength: 0)

                // Injects the card's specific UI
                content
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
        }
        .clipped()
    }
}



