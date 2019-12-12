//
//  PitchRecognizorDelegateMock.swift
//  SimpleTunerTests
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation
@testable import SimpleTuner

class PitchRecognizerDelegateMock: PitchRecognizerDelegate {
	var didReturnResult: ((Result<Double, Error>) -> Void)?
	
	func pitchRecognizer(didReturnNewResult result: Result<Double, Error>) {
		didReturnResult?(result)
	}
}
