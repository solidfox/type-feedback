//
//  PhonemPlayer.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2020-01-17.
//  Copyright © 2020 Daniel Schlaug. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

@objc class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		player.prepareToPlay()
	}
}

class PhonemPlayer {
	
	let phonems: Dictionary<Character, AVAudioPlayer>
	
	init() {
		let fileManager = FileManager.default
		let phonemsFolder = Bundle.main.resourcePath! + "/Phonems/sv_SE"
		let phonemPaths = try! fileManager.contentsOfDirectory(atPath: phonemsFolder)
		
		var mutablePhonemsDictionary = Dictionary<Character, AVAudioPlayer>()
		
		print(phonemPaths)
		
		phonemPaths.forEach { (phonemAudioFilePath) in
			if phonemAudioFilePath.contains(".m4a") {
				let phonemUrl = URL.init(fileURLWithPath: phonemsFolder + "/" + phonemAudioFilePath)
				let phonemAudioPlayer = try! AVAudioPlayer(contentsOf: phonemUrl)
				phonemAudioPlayer.prepareToPlay()
				mutablePhonemsDictionary[phonemAudioFilePath.lowercased().first!] = phonemAudioPlayer
			}
		}
		
		phonems = mutablePhonemsDictionary
	}
	
	func play(character: Character) -> Bool {
		if let audioPlayer = phonems[character] {
			audioPlayer.play()
			return true
		} else {
			return false
		}
	}
}
