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

class MicrophoneInput: AudioInput {
	
	var sampleRate: Double {
		return audioEngine
			.inputNode
			.outputFormat(forBus: 0)
			.sampleRate
	}
	
	private let audioEngine = AVAudioEngine()
	static let shared = MicrophoneInput()
	
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
	
	func removeTap() {
		let inputNode = audioEngine.inputNode
		inputNode.removeTap(onBus: 0)
	}
}

