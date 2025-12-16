//
//  Theme.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import SwiftUI

enum Theme {
    static let accentStart = Color(red: 1, green: 0.2, blue: 0.5)
    static let accentEnd = Color(red: 0.4, green: 0.2, blue: 1)

    static let accent = LinearGradient(
        colors: [accentStart, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let recordRed = LinearGradient(
        colors: [Color(red: 1, green: 0.2, blue: 0.3), Color(red: 0.9, green: 0.05, blue: 0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : Color(.systemBackground)
    }

    static func panel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    static func subtleStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    static func primary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func secondary(_ scheme: ColorScheme) -> Color {
        primary(scheme).opacity(0.7)
    }
}
