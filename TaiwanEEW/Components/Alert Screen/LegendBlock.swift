//
//  Legend.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/8.
//

import SwiftUI

struct Legend: View {
    let maxIntensityValue: Int
    @Environment(\.colorScheme) private var colorScheme

    private var panelFill: Color {
        colorScheme == .light ? .white : Color("Pad")
    }

    private var displayedIntensities: [Int] {
        Array((1...min(max(maxIntensityValue, 1), 9)).reversed())
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            VStack(spacing: 2) {
                ForEach(displayedIntensities, id: \.self) { intensity in
                    LegendColorSwatch(intensity: intensity)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(displayedIntensities, id: \.self) { intensity in
                    LegendTickLabel(intensity: intensity)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(panelFill)
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.14), radius: 4, y: 1)
        )
    }
}

private struct LegendColorSwatch: View {
    let intensity: Int

    private var shindo: String {
        EEWService.intensityValueToString(int: intensity)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color(shindo))
            .frame(width: 8, height: 14)
    }
}

private struct LegendTickLabel: View {
    let intensity: Int

    private var label: String {
        EEWService.intensityValueToString(int: intensity)
            .replacingOccurrences(of: "-", with: "–")
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.primary)
            .frame(height: 14, alignment: .center)
    }
}

#Preview {
    Legend(maxIntensityValue: 9)
}
