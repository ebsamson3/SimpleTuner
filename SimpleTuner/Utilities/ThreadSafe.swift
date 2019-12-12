//
//  ThreadSafe.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation

class ThreadSafe<T> {
	
	private let queue = DispatchQueue(
		label: Bundle.main.bundleIdentifier! + "ThreadSafeVariable",
		attributes: .concurrent)
	
	private var _value: T
	
	init(value: T) {
		self._value = value
	}
	
	func getValue() -> T {
		return queue.sync { _value }
	}
	
	func setValue(to newValue: T) {
		queue.async(flags: .barrier) { self._value = newValue }
	}
}
