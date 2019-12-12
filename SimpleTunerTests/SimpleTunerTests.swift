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
		
		// Given a 30 Hz Sine Wave
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
				// The detected pitch to be equal to 30
				XCTAssertEqual(round(pitch), testPitch)
			case .failure(let error):
				XCTFail("Pitch detection failed with error: \(error.localizedDescription)")
				break
			}
			expectation.fulfill()
		}
		
		// When the sine wave audio is appended to the pitch recognizer
		pitchRecognizer.append(bufferPointer: &sineWave, count: sineWave.count)
		
		waitForExpectations(timeout: 5, handler: nil)
	}
	
	func testEmptySignalRecognition() {
		
		let sampleRate: Double = 44100
		
		// Given an empty audio signal
		var emptySignal = [Float](repeating: 0, count: 4186)
		
		let pitchRecognizer = PitchRecognizer(minimumFrequency: 25, sampleRate: sampleRate)
		let delegate = PitchRecognizerDelegateMock()
		pitchRecognizer.delegate = delegate
		
		let expectation = self.expectation(description: "Pitch Recognition Completed")
		
		delegate.didReturnResult = { result in
			switch result {
			case .success(let pitch):
				XCTFail("Detected pitch: \(pitch) in zero signal")
			case .failure(_):
				// The detected pitch detection should fail
				XCTAssert(true)
				break
			}
			expectation.fulfill()
		}
		
		// When the empty audio is appended to the pitch recognizer
		pitchRecognizer.append(bufferPointer: &emptySignal, count: emptySignal.count)
		
		waitForExpectations(timeout: 5, handler: nil)
	}
	
	func testAudioInputAlert() {
		
		// Given a audio input that cannot be started
		let audioInput = AudioInputMock()
		audioInput.errorToThrow = AudioInputMockError.testError
		
		// When a tuner view model is initialized with the faulty audio input
		let viewModel = TunerViewModel(
			pitchRecognizer: PitchRecognizer(),
			audioInput: audioInput)
		
		// The view model is expected to display an alert
		XCTAssertNotNil(viewModel.alertMessage)
	}
	
	func testTunerViewModelValidPitch() {
		
		// Given a tuner view model
		let viewModel = TunerViewModel(
			pitchRecognizer: PitchRecognizer(),
			audioInput: AudioInputMock())
		
		// When a 440 Hz pitch detection even occurs
		viewModel.pitchRecognizer(didReturnNewResult: .success(440))
		
		// IThe view model is expected to tell the tuner UI to display an A
		XCTAssertEqual(viewModel.gaugeValue, 0.5)
		XCTAssertEqual(viewModel.noteString, "A")
		XCTAssertEqual(viewModel.accidentalString, nil)
		XCTAssertEqual(viewModel.isActive, true)
	}
	
	func testTunerViewModelNegativePitch() {
		
		// Given a tuner view model
		let viewModel = TunerViewModel(
			pitchRecognizer: PitchRecognizer(),
			audioInput: AudioInputMock())
		
		// When a physically impossible detection event occurs
		viewModel.pitchRecognizer(didReturnNewResult: .success(-1))
		
		// The view model is expected to update tell the tuner to move the inactive state
		XCTAssertEqual(viewModel.isActive, false)
	}
}
