//
//  PitchRecognizer.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/10/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import Foundation
import TPCircularBuffer
import AVFoundation
import Accelerate

/// Protocol for recieving pitch recognizer results
protocol PitchRecognizerDelegate: class {
	func pitchRecognizer(didReturnNewResult result: Result<Double, Error>)
}

/// Errors thrown by pitch recognizer
enum PitchRecognizerError: LocalizedError {
	case couldNotDetectPitch
	case pitchBelowNyquist // Must sample at least 2 wavelength for a pitch to be detectable
}

/// Copies audio buffer data into a FIFO circular buffer and subsequently performs pitch recognition calculations
///
/// Algorithm taken from "A smarter way to find pitch":
/// https://www.researchgate.net/publication/230554927_A_smarter_way_to_find_pitch
class PitchRecognizer {
	typealias Maximum = (delay: Int, value: Float)
	
	// Buffer for storing audio input. Safe for 1 thread for read and 1 thread for writes.
	private var circularBuffer: TPCircularBuffer
	private let circularBufferSize: UInt32 
	private var availableBytes: UInt32 = 0
	
	private let minimumFrequency: Double
	private let sampleRate: Double
	
	// Calculate size required to detect minimum frequeuncy (> 2 wavelengths at said frequency)
	private var calculationInputSize: Int
	
	// Store caluclation status
	private var pendingCalculation: DispatchWorkItem?
	private var isCalculating = ThreadSafe<Bool>(value: false)
	
	weak var delegate: PitchRecognizerDelegate?
	
	init(minimumFrequency: Double = 25, sampleRate: Double = 44100) {
		
		self.minimumFrequency = minimumFrequency
		self.sampleRate = sampleRate
		
		let n = (1 / minimumFrequency) * 2 * sampleRate
		let	log2N = Int(ceil(log2(n)))
		let nPowerOfTwo = Int(1 << log2N)
		
		// Minimum power fo 2 sample size that contains 2 full wavelenths of minimum frequency
		calculationInputSize = nPowerOfTwo
		
		let bufferBytes = UInt32(calculationInputSize * 4 * MemoryLayout<Float>.size)
		
		circularBuffer = TPCircularBuffer()
		circularBufferSize = bufferBytes
		
		_TPCircularBufferInit(
			&circularBuffer,
			bufferBytes,
			MemoryLayout.size(ofValue: circularBuffer))
	}
	
	deinit {
		TPCircularBufferCleanup(&circularBuffer)
	}
	
	/// Add new audio input samples from a PCM buffer
	func append(buffer: AVAudioPCMBuffer) {
		
		guard let bufferPointer = buffer.floatChannelData?[0] else {
			return
		}
		
		let count = Int(buffer.frameLength)
		
		append(bufferPointer: bufferPointer, count: count)
	}
	
	/// Add new audio input samples from an unsafe array of floats
	func append(bufferPointer: UnsafeMutablePointer<Float>, count: Int) {
		
		// Writing to circular buffer is high priority and writes must be performed on a single thread
		DispatchQueue.main.async {
			
			let head = TPCircularBufferHead(
				&self.circularBuffer,
				&self.availableBytes)
			
			let bytesToWrite = count * MemoryLayout<Float>.size
			
			head?.copyMemory(
				from: bufferPointer,
				byteCount: min(Int(self.availableBytes), bytesToWrite))
			
			TPCircularBufferProduce(
				&self.circularBuffer,
				UInt32(bytesToWrite))
			
			if Int(self.circularBufferSize - self.availableBytes) + bytesToWrite >= self.calculationInputSize {
				self.queueNextCalculation()
			}
		}
	}
	
	/// Queues next pitch recognition attempt or runs it immediately if no current recoginition atempt is being made
	@objc private func queueNextCalculation() {
		let work = DispatchWorkItem(qos: .userInitiated) { [weak self] in
			self?.isCalculating.setValue(to: true)
			self?.recognizePitch()
			if let pendingCalculation = self?.pendingCalculation {
				pendingCalculation.perform()
			} else {
				self?.isCalculating.setValue(to: false)
			}
		}
		
		if self.isCalculating.getValue() == true {
			self.pendingCalculation = work
		} else {
			work.perform()
		}
	}
	
	/// Reads audio data from the circular buffer and peforms a square difference pitch recoginition algorithm on it
	private func recognizePitch() {
		
		var readableBytes: UInt32 = 0
		
		guard
			let tail = TPCircularBufferTail(&circularBuffer, &readableBytes)
			else {
				return
		}
		
		let tailFloatPointer = tail.assumingMemoryBound(to: Float.self)
		
		let tailBufferPointer = UnsafeBufferPointer(
			start: tailFloatPointer,
			count: calculationInputSize)
		
		// Create calculation input data array from circular buffer
		var inputArray = Array(tailBufferPointer)
		
		// Clear circular buffer to open up space for future audio buffer writes
		TPCircularBufferConsume(
			&circularBuffer,
			readableBytes)
		
		// Double input array length with padded zeros
		inputArray.append(contentsOf: Array(repeating: 0, count: calculationInputSize))
		
		// Calculate linear autocorrelation
		let linearAC = calculateLinearAutocorrelation(
			ofInput: &inputArray,
			count: inputArray.count)
		
		// Find the square difference to remove linear autocorrelation tapering due to signal dropoff
		let squareDifference = calculatSquareDifference(
			fromLinearAC: linearAC,
			originalSignal: inputArray)
		
		// Calculate the pitch from the square difference peaks
		let newPitch = calculatePitch(
			fromSquareDifference: squareDifference,
			sampleRate: sampleRate)
		
		guard let pitch = newPitch else {
			DispatchQueue.main.async { [weak self] in
				self?.delegate?.pitchRecognizer(
					didReturnNewResult: .failure(PitchRecognizerError.couldNotDetectPitch))
			}
			return
		}
		
		guard pitch >= minimumFrequency else {
			DispatchQueue.main.async { [weak self] in
				self?.delegate?.pitchRecognizer(
					didReturnNewResult: .failure(PitchRecognizerError.pitchBelowNyquist))
			}
			return
		}
		
		DispatchQueue.main.async { [weak self] in
			self?.delegate?.pitchRecognizer(didReturnNewResult: .success(pitch))
		}
	}
	
	/// Calculates the linear autocorrepation of an input signal
	func calculateLinearAutocorrelation(
		ofInput input: UnsafeMutablePointer<Float>,
		count: Int) -> [Float]
	{
		let log2n = UInt(floor(log2(Double(count))))
		let nPowerOfTwo = Int(1 << log2n) // Real buffer length (must be power of 2)
		let nOver2 = nPowerOfTwo / 2 // Complex buffer length
		
		// Real and imaginary components of split complex buffer
		var real = [Float](repeating: 0, count: nOver2)
		var imag = [Float](repeating: 0, count: nOver2)
		
		var tempSplitComplex = DSPSplitComplex(
			realp: &real,
			imagp: &imag)
		
		// Precalculated data from FFT. Could store for increased performance.
		guard
			let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
		else {
			return []
		}
		
		// Pack data into a split complex buffer prior to FFT. For more information on packing and unpacking data for FFT and IFFT operations see:
		// https://developer.apple.com/library/archive/documentation/Performance/Conceptual/vDSP_Programming_Guide/UsingFourierTransforms/UsingFourierTransforms.html

		input.withMemoryRebound(to: DSPComplex.self, capacity: nOver2) {
			vDSP_ctoz(
				$0, 2,
				&tempSplitComplex, 1,
				vDSP_Length(nOver2))
		}
		
		// Forward FFT
		vDSP_fft_zrip(
			fftSetup,
			&tempSplitComplex, 1,
			log2n,
			FFTDirection(FFT_FORWARD))
		
		// Multiply the transformed data by its complex conjugation
		vDSP_zvcmul(
			&tempSplitComplex, 1, // Normal input
			&tempSplitComplex, 1, // Complex conjugate input
			&tempSplitComplex, 1, // Output = dot product of the two inputs
			vDSP_Length(nOver2))
		
		// Performing the IFFT.
		vDSP_fft_zrip(
			fftSetup,
			&tempSplitComplex, 1,
			log2n,
			FFTDirection(FFT_INVERSE))
		
		vDSP_destroy_fftsetup(fftSetup)
		
		// Combining the scaling for the FFT and IFFT
		// - FFT Requires scaling by 1 / 2 ( Done twice to account for complex conjugate scaling)
		// - IFFT Requires scaling by 1 / n
		var scale: Float = 1 / Float(nPowerOfTwo * 4)
		vDSP_vsmul(tempSplitComplex.realp, 1, &scale, tempSplitComplex.realp, 1, vDSP_Length(nOver2))
		vDSP_vsmul(tempSplitComplex.imagp, 1, &scale, tempSplitComplex.imagp, 1, vDSP_Length(nOver2))
		
		// Creating output array
		var output = [Float](repeating: 0, count: nOver2)
		let outputPointer = UnsafeMutablePointer(mutating: &output)
		
		// Unpacking data from split complex from into output array
		outputPointer.withMemoryRebound(to: DSPComplex.self, capacity: nOver2 / 2) {
			vDSP_ztoc(&tempSplitComplex, 1, $0, 2, vDSP_Length(nOver2 / 2))
		}
		
		return output
	}

	/// Calculates the Square Difference Function, which is essentially a linear autocorrelation that compensates for the gradual loss of amplitude as delay increases. Effectively flattening out the linear autocorrelation.
	private func calculatSquareDifference(
		fromLinearAC linearAC: [Float],
		originalSignal: [Float]) -> [Float]
	{
		
		let count = originalSignal.count
		var originalSignalSquared: [Float] = Array(
			repeating: 0,
			count: count)
		
		// Squaring the original siganl
		vDSP_vsq(
			originalSignal, 1,
			&originalSignalSquared, 1,
			vDSP_Length(count))
		
		
		// Buffer for our result
		var squareDifference: [Float] = Array(
			repeating: 0,
			count: linearAC.count)

		// 2 * the autocorrelation value at delay time 0, which is equal to the sum of the square of the original signal
		var m: Float = 2 * linearAC[0]
		
		let lastDelay = squareDifference.count - 1
		
		// To get the Square Difference Function value at a specific delay, we take the corresponding linear autocorrelation value and normalize it by the greatest possible autocorrelation magnitude at that delay. We start at delay 0, where the greatest magnitude is the total sum of our squared signal and gradually decrease the greatest possible magnitude as the delay increases to account for less and less signal being used in the autocorrelation function.
		for delay in 0...lastDelay {
			squareDifference[delay] = 2 * linearAC[delay] / m
			m -= originalSignalSquared[delay]
			m -= originalSignalSquared[lastDelay - delay]
		}
		return squareDifference
	}

	/// Finds the square difference function peak where the delay == fundamental frequency of the signal
	private func calculatePitch(
		fromSquareDifference squareDifference: [Float],
		sampleRate: Double) -> Double?
	{
		
		guard squareDifference.count > 2 else {
			return nil
		}
		
		// Array for storing every found peak
		var maxima = [Maximum]()
		
		// Greatest value for current positive region of signal
		var currentMaximum: Maximum?
		
		// Do not attempt to collect maxima if the signal is negative
		var shouldCollectMaximum = false
		
		for delay in 1..<squareDifference.count - 1 {
			
			if
				squareDifference[delay - 1] <= 0 &&
				squareDifference[delay] > 0
			{
				// If there was a positively sloped zero crossing, start collecting maxima
				shouldCollectMaximum = true
				currentMaximum = nil
			}
			else if
				// If there was a negatively sloped zero crossing, stop collecting maxima and store the greatest maxima recorded in the previous positive signal region
				squareDifference[delay - 1] > 0 &&
				squareDifference[delay] <= 0
			{
				shouldCollectMaximum = false
				if let newMaximum = currentMaximum {
					maxima.append(newMaximum)
				}
			}
			
			// If we are currently collecting maxima and the signal is a local maximum, store it if its value is greater that the previous greatest maxima for the current positive signal region
			if
				shouldCollectMaximum &&
				squareDifference[delay] > squareDifference[delay - 1] &&
				squareDifference[delay] > squareDifference[delay + 1]
			{
				if let previousMaximum = currentMaximum {
					if squareDifference[delay] > previousMaximum.value {
						currentMaximum = (delay: delay, value: squareDifference[delay])
					}
				} else {
					currentMaximum = (delay: delay, value: squareDifference[delay])
				}
			}
		}
		
		// Only consider maxima whose peaks are within a certain threshold of the peak square difference function value
		let k: Float = 0.9
		let threshold = squareDifference[0] * k
		
		// Finding the maximum that corresponds to the fundamental frequency
		guard let fundamentalMaximum = maxima.lazy.filter({ $0.value > threshold}).first else {
			return nil
		}
		
		// Convert the delay in terms of samples to the delay in terms of seconds. This is equal to the fundamental frequency.
		let pitch = sampleRate / Double(fundamentalMaximum.delay)
		
		return pitch
	}
}
