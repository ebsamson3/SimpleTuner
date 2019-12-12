//
//  TunerViewModel.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

/// Starts pitch detection and converts detected values into UI updates
class TunerViewModel {
	
	//MARK: Properties
	
	// Binding functions for UI updates
	var didSetGaugeValue: ((Float) -> ())?
	var didSetNoteString: ((String?) -> ())?
	var didStAccidentalString: ((String?) -> ())?
	var didSetIsActive: ((Bool) -> Void)?
	
	//MARK: UI state variables
	
	var gaugeValue: Float = 0 {
		didSet {
			didSetGaugeValue?(gaugeValue)
		}
	}
	
	var noteString: String? = "C" {
		didSet {
			didSetNoteString?(noteString)
		}
	}
	
	var accidentalString: String? = nil {
		didSet {
			didStAccidentalString?(accidentalString)
		}
	}
	
	var isActive: Bool = false {
		didSet {
			didSetIsActive?(isActive)
		}
	}
	
	//MARK: Pitch detection components
	private let pitchRecognizer: PitchRecognizer
	private let audioInput: AudioInput
	
	//TODO: Add alert controller for displaying alert messages
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
	
	/// Start reading audio from input
	func startAudioInput() {
		do {
			try audioInput.start()
		} catch {
			alertMessage = "Unable to access audio input"
		}
	}
	
}

extension TunerViewModel: PitchRecognizerDelegate {
	/// Convert detected pitch into UI updates
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
