//
//  TunerViewModel.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

class TunerViewModel {
	
	var didSetGaugeValue: ((Float) -> ())?
	var didSetNoteStringValue: ((String?) -> ())?
	var didStAccidentalStringValue: ((String?) -> ())?
	var didSetIsActiveValue: ((Bool) -> Void)?
	
	var gaugeValue: Float = 0 {
		didSet {
			didSetGaugeValue?(gaugeValue)
		}
	}
	
	var noteString: String? = "C" {
		didSet {
			didSetNoteStringValue?(noteString)
		}
	}
	
	var accidentalString: String? = nil {
		didSet {
			didStAccidentalStringValue?(accidentalString)
		}
	}
	
	var isActive: Bool = false {
		didSet {
			didSetIsActiveValue?(isActive)
		}
	}
	
	private let pitchRecognizer: PitchRecognizer
	private let audioInput: AudioInput
	
	var alertMessage: String?
	
	init(pitchRecognizer: PitchRecognizer, audioInput: AudioInput = MicrophoneInput.shared) {
		self.audioInput = audioInput
		self.pitchRecognizer = pitchRecognizer
		
		pitchRecognizer.delegate = self
		
		audioInput.installTap(withBufferSize: 4096) { (buffer, when) in
			pitchRecognizer.append(buffer: buffer)
		}
		
		startAudioInput()
	}
	
	func startAudioInput() {
		do {
			try audioInput.start()
		} catch {
			alertMessage = "Unable to access audio input"
		}
	}
	
}

extension TunerViewModel: PitchRecognizerDelegate {
	func pitchRecognizer(didReturnNewResult result: Result<Double, Error>) {
		switch result {
		case .failure:
			isActive = false
		case .success(let pitch):
			guard let note = Note(pitch: pitch) else {
				isActive = false
				return
			}
			
			isActive = true
			
			let scaleDegree = note.scaleDegree
			gaugeValue = Float(scaleDegree - round(scaleDegree) + 0.5)
			
			let characters = Array(note.stringValue).map {
				String($0)
			}
			
			noteString = characters.first
			accidentalString = characters.count > 1 ? characters[1] : nil
		}
	}
}
