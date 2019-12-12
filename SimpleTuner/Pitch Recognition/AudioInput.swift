//
//  AudioInput.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation
import AVFoundation

/// Protocol for a tappable audio input
protocol AudioInput {
	
	var sampleRate: Double { get }
	
	func start() throws
	func stop()
	
	/// Installs a tap for audio buffer analysis/processing
	func installTap(
		withBufferSize bufferSize: AVAudioFrameCount,
		block: @escaping AVAudioNodeTapBlock)
	
}
