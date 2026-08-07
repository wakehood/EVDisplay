//
//  GaugeMetrics.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/6/26.
//

import CoreGraphics

/// Single source of truth for all dashboard gauge frame dimensions.
/// Change values here to resize consistently across the whole UI.
enum GaugeMetrics {

    // MARK: - Stroke / bar thickness shared by all gauges
    /// Change this one value to scale arc width on SOC/motor gauges and bar height on the cell voltage gauge.
    static let gaugeStrokeWidth: CGFloat = 16
    /// Exact height needed for CellVoltageRangeGaugeView (label 12 + gap 4 + bar + gap 4 + cutoff 11).
    static let cellGaugeHeight: CGFloat = 12 + 4 + gaugeStrokeWidth + 4 + 11

    // MARK: - Accent / side gauges (thermometer, cell voltage bar)
    static let thermometerWidth:      CGFloat = 52
    static let thermometerHeight:     CGFloat = 72
    static let thermometerWidthIPad:  CGFloat = 72
    static let thermometerHeightIPad: CGFloat = 100

    // MARK: - SOC semicircle gauge (MCU card)
    static let socGaugeMaxPhone:    CGFloat = 180
    static let socGaugeMaxIPad:     CGFloat = 300
    static let socGaugeMaxPortrait: CGFloat = 150   // tighter height in portrait

    // MARK: - Motor speed semicircle gauge (VCU card)
    static let motorGaugeMaxPhone: CGFloat = 220
    static let motorGaugeMaxIPad:  CGFloat = 360
}
