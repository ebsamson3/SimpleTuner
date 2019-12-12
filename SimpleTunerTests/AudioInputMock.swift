//
//  AudioInputMock.swift
//  SimpleTunerTests
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation
import AVFoundation
@testable import SimpleTuner

enum AudioInputMockError: LocalizedError {
	case testError
}

class AudioInputMock: AudioInput {
	
	var errorToThrow: Error?
	var block: AVAudioNodeTapBlock?
	
	var sampleRate: Double = 44100
	
	func start() throws {
		if let errorToThrow = errorToThrow {
			throw errorToThrow
		}
	}
	
	func stop() {
	}
	
	func installTap(withBufferSize bufferSize: AVAudioFrameCount, block: @escaping AVAudioNodeTapBlock) {
		
//		guard let channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo) else {
//			return
//		}
//
//		let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channelLayout: channelLayout)
//
//		guard
//			let buffer = AVAudioPCMBuffer(
//				pcmFormat: audioFormat,
//				frameCapacity: bufferSize)
//		else {
//			return
//		}
//
//		memset(buffer.floatChannelData![0], <#T##__c: Int32##Int32#>, Int(bufferSize) * MemoryLayout<Float>.size)
//
//		self.block = block
	}
}
