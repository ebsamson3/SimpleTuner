//
//  Note.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

struct Note {
	
	private static let scaleDegreeToStringMap: [Int: String] = [
		0 : "C",
		1 : "C#",
		2 : "D",
		3 : "D#",
		4 : "E",
		5 : "F",
		6 : "F#",
		7 : "G",
		8 : "G#",
		9 : "A",
		10 : "A#",
		11 : "B",
		12 : "C"
	]
	
	let pitch: Double
	var midiValue: Double
	var scaleDegree: Double
	var stringValue: String
	
	init?(pitch: Double) {
		guard pitch > 0 else {
			return nil
		}
		
		self.pitch = pitch
		self.midiValue = 12 * log2(pitch / 440) + 69
		self.scaleDegree = midiValue.truncatingRemainder(dividingBy: 12)
		
		let roundedScaleDegree = Int(round(scaleDegree))
		
		guard let stringValue = Self.scaleDegreeToStringMap[roundedScaleDegree] else {
			return nil
		}
		
		self.stringValue = stringValue
	}
}
