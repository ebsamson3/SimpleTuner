//
//  SimpleTunerTests.swift
//  SimpleTunerTests
//
//  Created by Edward Samson on 12/10/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import XCTest
@testable import SimpleTuner

class SimpleTunerTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
	
	func testPitchRecognition() {
		
		let testPitch: Double = 30
		let sampleRate: Double = 44100
		
		var sineWave = SineGenerator.generateSineWave(
			frequency: testPitch,
			sampleRate: sampleRate,
			duration: 0.25)
		
		let pitchRecognizer = PitchRecognizer(minimumFrequency: 25, sampleRate: sampleRate)
		let delegate = PitchRecognizerDelegateMock()
		pitchRecognizer.delegate = delegate
		
		let expectation = self.expectation(description: "Pitch Recognition Completed")
		
		delegate.didReturnResult = { result in
			switch result {
			case .success(let pitch):
				XCTAssertEqual(round(pitch), Float(testPitch))
			case .failure(let error):
				XCTFail("Pitch detection failed with error: \(error.localizedDescription)")
				break
			}
			expectation.fulfill()
		}
		
		//pitchRecognizer.start()
		pitchRecognizer.append(bufferPointer: &sineWave, count: sineWave.count)
		
		waitForExpectations(timeout: 5, handler: nil)
	}
	
	func testZeroSignalRecognition() {
		
		let sampleRate: Double = 44100
		
		var zeroSignal = [Float](repeating: 0, count: 4186)
		
		let pitchRecognizer = PitchRecognizer(minimumFrequency: 25, sampleRate: sampleRate)
		let delegate = PitchRecognizerDelegateMock()
		pitchRecognizer.delegate = delegate
		
		let expectation = self.expectation(description: "Pitch Recognition Completed")
		
		delegate.didReturnResult = { result in
			switch result {
			case .success(let pitch):
				XCTFail("Detected pitch: \(pitch) in zero signal")
			case .failure(_):
				XCTAssert(true)
				break
			}
			expectation.fulfill()
		}
		
		//pitchRecognizer.start()
		pitchRecognizer.append(bufferPointer: &zeroSignal, count: zeroSignal.count)
		
		waitForExpectations(timeout: 5, handler: nil)
	}
}
