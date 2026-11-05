//
//  Defaults.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2020-01-17.
//  Copyright © 2020 Daniel Schlaug. All rights reserved.
//

import Foundation

class AppDefaults {
	enum keys:String {
		case textViewContents = "TextViewContents"
		case legacyTextMigrated = "LegacyTextMigrated"
		case spellingMode = "SpellingMode"
		case sidebarHidden = "SidebarHidden"
	}
}
