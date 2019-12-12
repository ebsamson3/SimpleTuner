//
//  MicrophoneInput.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/10/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

import Foundation

import Foundation
import AVFoundation

/// Simple API for managing a microphone audio collection
class MicrophoneInput: AudioInput {
	
	var sampleRate: Double {
		return audioEngine
			.inputNode
			.outputFormat(forBus: 0)
			.sampleRate
	}
	
	private let audioEngine = AVAudioEngine()
	
	// Since devices should only have 1 mic we make this class a singleton
	static let shared = MicrophoneInput()
	
	//TODO: Make this throw and handle errors w/ alert
	private init() {
		try! configure()
	}
	
	private func configure() throws {
		let audioSession = AVAudioSession.sharedInstance()
		try audioSession.setCategory(.record, mode: .measurement)
		try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
	}
	
	func start() throws {
		try audioEngine.start()
	}
	
	func stop() {
		audioEngine.stop()
	}
	
	/// Install tap for analyzing and processing microphone input audio
	func installTap(
		withBufferSize bufferSize: AVAudioFrameCount,
		block: @escaping AVAudioNodeTapBlock)
	{
		removeTap()
		let inputNode = audioEngine.inputNode
		let recordingFormat = inputNode.outputFormat(forBus: 0)
		
		inputNode.installTap(
			onBus: 0,
			bufferSize: bufferSize,
			format: recordingFormat, block: block)
	}
	
	/// Remove installed tap on microphone
	func removeTap() {
		let inputNode = audioEngine.inputNode
		inputNode.removeTap(onBus: 0)
	}
}

