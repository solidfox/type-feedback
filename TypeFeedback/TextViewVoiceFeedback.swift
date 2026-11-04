//
//  TextViewVoiceFeedback.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2017-03-10.
//  Copyright © 2017 Daniel Schlaug. All rights reserved.
//

import Foundation
import Cocoa

enum SpellingMode:Int {
	case sound
	case name
}

class TextViewVoiceFeedback: NSObject, NSTextViewDelegate {
	
	let speechSynthesizer = NSSpeechSynthesizer()
	let phonemPlayer = PhonemPlayer()
	var spellingMode: SpellingMode? = nil
	
	override init() {
		if let swedishVoice = TextViewVoiceFeedback.bestSwedishVoice() {
			speechSynthesizer.setVoice(swedishVoice)
		}
		
		super.init()
		
		loadDefaults()
		NotificationCenter.default.addObserver(self, selector: #selector(onSpellingModeUpdated(_:)), name: .spellingModeUpdated, object: nil)
	}
	
	/// The best installed Swedish voice: Sweden before other Swedish locales,
	/// then premium/enhanced (downloaded) voices before compact ones.
	/// Nil if no Swedish voice is installed; the default voice is used then.
	static func bestSwedishVoice() -> NSSpeechSynthesizer.VoiceName? {
		func locale(of voice: NSSpeechSynthesizer.VoiceName) -> String {
			let attributes = NSSpeechSynthesizer.attributes(forVoice: voice)
			let identifier = attributes[.localeIdentifier] as? String ?? ""
			return identifier.replacingOccurrences(of: "-", with: "_")
		}
		func rank(of voice: NSSpeechSynthesizer.VoiceName) -> Int {
			let id = voice.rawValue.lowercased()
			let country = locale(of: voice) == "sv_SE" ? 10 : 0
			if id.contains("premium") { return country + 3 }
			if id.contains("enhanced") { return country + 2 }
			if id.contains("compact") { return country }
			return country + 1
		}
		let swedish = NSSpeechSynthesizer.availableVoices.filter {
			let language = locale(of: $0)
			return language == "sv" || language.hasPrefix("sv_")
		}
		return swedish.max { rank(of: $0) < rank(of: $1) }
	}
	
	@objc func onSpellingModeUpdated(_ notification: Notification) {
		loadDefaults()
	}
	
	func loadDefaults() {
		let spellingModeRaw = NSUserDefaultsController.shared.defaults.integer(forKey: AppDefaults.keys.spellingMode.rawValue)
		spellingMode = SpellingMode(rawValue: spellingModeRaw)
	}
	
	func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
		
		if let newText = replacementString {
			if newText.count == 1 {
				let char = newText.first!
				switch char {
				case ".":
					let lastSentence = findLastSentenceIn(textView: textView, endingAtIndex: affectedCharRange.location)
					speechSynthesizer.startSpeaking(lastSentence)
				case " ":
					// Check that
					if affectedCharRange.location != 0 {
						let lastCharacter = textView.textStorage!.characters[affectedCharRange.location - 1].string
						if lastCharacter == "." {
							return true
						}
					}
					let lastWord = findLastWordIn(textView: textView, endingAtIndex: affectedCharRange.location)
					speechSynthesizer.startSpeaking(lastWord)
				default:
					if spellingMode == SpellingMode.name || !phonemPlayer.play(character: newText.lowercased().first!) {
						speechSynthesizer.startSpeaking(newText.lowercased())
					}
				}
			}
		}
		
		return true
	}
	
	func findLastWordIn(textView:NSTextView, endingAtIndex endIndex:Int) -> String {
		let string = textView.textStorage!.string
		let lowerBound = string.index(string.startIndex, offsetBy: textView.textStorage!.nextWord(from: endIndex, forward: false))
		let upperBound = string.index(string.startIndex, offsetBy: endIndex)
		
		return textView.textStorage!.string.substring(with: Range<String.Index>(uncheckedBounds: (lower: lowerBound, upper: upperBound)))
	}
	
	func findLastSentenceIn(textView:NSTextView, endingAtIndex endIndex:Int) -> String {
		let string = textView.textStorage!.string
		let upperBound = string.index(string.startIndex, offsetBy: endIndex)
		let truncatedString = textView.textStorage!.string[..<upperBound]
		
		let reversedString = String(truncatedString.reversed())
		
		let lowerBound = reversedString.range(of: ".")?.lowerBound ?? reversedString.endIndex
		
		let sentence = reversedString[..<lowerBound].reversed()
		
		return String(sentence)
	}
	
}
