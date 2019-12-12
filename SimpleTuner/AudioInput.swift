//
//  AudioInput.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioInput {
	
	var sampleRate: Double { get }
	
	func start() throws
	func stop()
	
	func installTap(
		withBufferSize bufferSize: AVAudioFrameCount,
		block: @escaping AVAudioNodeTapBlock)
	
}
