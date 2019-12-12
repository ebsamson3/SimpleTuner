//
//  Note.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

/// A structure that stores the midi note information of a particular pitch
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
	var midiValue: Double // Midi note number
	var scaleDegree: Double // Note # in octave starting and ending with C
	var stringValue: String // String representation of the note
	
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
