//
//  Palette.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-04.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa
import DynamicColor

/// The app's colours. Light mode is warm paper; dark mode is the same colours inverted.
enum Palette {
	private static let lightPaper = DynamicColor(hex: 0xfcedc7)

	/// The writing area.
	static var paper: NSColor { return color(light: lightPaper) }
	/// The documents sidebar, a shade darker than the paper.
	static var sidebar: NSColor { return color(light: lightPaper.shaded(amount: 0.06)) }
	/// The highlighted row in the sidebar.
	static var selection: NSColor { return color(light: lightPaper.mixed(withColor: DynamicColor(hex: 0xe8a33d), weight: 0.3)) }

	static func isDark(_ appearance: NSAppearance) -> Bool {
		if #available(OSX 10.14, *) {
			return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
		}
		return false
	}

	/// Follows light and dark mode as it changes on macOS 10.15 and later. On 10.14 the colour matches the mode
	/// at the moment it is asked for; older systems have no dark mode.
	private static func color(light: NSColor) -> NSColor {
		if #available(OSX 10.15, *) {
			return NSColor(name: nil) { appearance in
				return isDark(appearance) ? light.inverted() : light
			}
		}
		if #available(OSX 10.14, *), isDark(NSApp.effectiveAppearance) {
			return light.inverted()
		}
		return light
	}
}
