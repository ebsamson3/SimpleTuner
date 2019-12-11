//
//  SineGenerator.swift
//  SimpleTunerTests
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

struct SineGenerator {
	static func generateSineWave(
		frequency: Double,
		sampleRate: Double,
		duration: Double) -> [Float]
	{
		// Total number of samples
		let numberOfSamples = Int(duration * sampleRate)
		
		// Angle change per sample
		let angleDelta = Float((frequency / sampleRate) * 2 * Double.pi)
		
		let sineWave: [Float] = (0..<numberOfSamples).map { index in
			let value: Float = sin(angleDelta * Float(index))
			return value
		}
		return sineWave
	}
}

