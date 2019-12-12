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

protocol PitchRecognizerDelegate: class {
	func pitchRecognizer(didReturnNewResult result: Result<Double, Error>)
}

enum PitchRecognizerError: LocalizedError {
	case couldNotDetectPitch
	case pitchBelowNyquist
}

class PitchRecognizer {
	typealias Maximum = (delay: Int, value: Float)
	
	private var circularBuffer: TPCircularBuffer
	private let totalBufferSize: UInt32
	private var availableBytes: UInt32 = 0
	
	private let minimumFrequency: Double
	private let sampleRate: Double
	private var calculationInputSize: Int
	
	private var calculationTimer: Timer?
	private var pendingCalculation: DispatchWorkItem?
	private var isCalculating = ThreadSafe<Bool>(value: false)
	
	weak var delegate: PitchRecognizerDelegate?
	
	init(minimumFrequency: Double = 25, sampleRate: Double = 44100) {
		
		self.minimumFrequency = minimumFrequency
		self.sampleRate = sampleRate
		
		let n = (1 / minimumFrequency) * 2 * sampleRate
		let	log2N = Int(ceil(log2(n)))
		let nPowerOfTwo = Int(1 << log2N)
		calculationInputSize = nPowerOfTwo
		
		let bufferBytes = UInt32(calculationInputSize * 4 * MemoryLayout<Float>.size)
		
		circularBuffer = TPCircularBuffer()
		totalBufferSize = bufferBytes
		
		_TPCircularBufferInit(
			&circularBuffer,
			bufferBytes,
			MemoryLayout.size(ofValue: circularBuffer))
	}
	
	deinit {
		TPCircularBufferCleanup(&circularBuffer)
	}
	
	func append(buffer: AVAudioPCMBuffer) {
		
		guard let bufferPointer = buffer.floatChannelData?[0] else {
			return
		}
		
		let count = Int(buffer.frameLength)
		
		append(bufferPointer: bufferPointer, count: count)
	}
	
	func append(bufferPointer: UnsafeMutablePointer<Float>, count: Int) {
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
			
			if Int(self.totalBufferSize - self.availableBytes) + bytesToWrite >= self.calculationInputSize {
				self.fireTimer()
			}
		}
//		let head = TPCircularBufferHead(
//			&circularBuffer,
//			&availableBytes)
//
//		print(availableBytes)
//
//		let bytesToWrite = count * MemoryLayout<Float>.size
//
//		print(head ?? "no head found")
//
//		head?.copyMemory(
//			from: bufferPointer,
//			byteCount: min(Int(availableBytes), bytesToWrite))
//
//		TPCircularBufferProduce(
//					&circularBuffer,
//					UInt32(bytesToWrite))
	}
	
	func start() {
//		calculationTimer?.invalidate()
//
//		let timer = Timer(
//			timeInterval: 0.1,
//			target: self,
//			selector: #selector(fireTimer),
//			userInfo: [:],
//			repeats: true)
//
//		self.calculationTimer = timer
//
//		RunLoop.current.add(timer, forMode: .common)
		
	}
	
	func stop() {
//		calculationTimer?.invalidate()
	}
	
	@objc private func fireTimer() {
		let work = DispatchWorkItem(qos: .userInitiated) { [weak self] in
			self?.isCalculating.setValue(to: true)
			self?.recognizePitch()
			self?.isCalculating.setValue(to: false)
		}
		
		if self.isCalculating.getValue() == true {
			self.pendingCalculation = work
		} else {
			work.perform()
		}
	}
	
	private func recognizePitch() {
		
		var readableBytes: UInt32 = 0
		
		guard
			let tail = TPCircularBufferTail(&circularBuffer, &readableBytes)
		else {
			return
		}
		
		if
			readableBytes >= calculationInputSize * MemoryLayout<Float>.size
		{
			let tailFloatPointer = tail.assumingMemoryBound(to: Float.self)
			
			let tailBufferPointer = UnsafeBufferPointer(
				start: tailFloatPointer,
				count: calculationInputSize)
			
			var inputArray = Array(tailBufferPointer)
			
			TPCircularBufferConsume(
				&circularBuffer,
				readableBytes)
			
			inputArray.append(contentsOf: Array(repeating: 0, count: calculationInputSize))
			
			let linearAC = calculateLinearAutocorrelation(
				ofInput: &inputArray,
				count: inputArray.count)

			let squareDifference = calculatSquareDifference(
				fromLinearAC: linearAC,
				originalSignal: inputArray)

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
	}
	
	func calculateLinearAutocorrelation(
		ofInput input: UnsafeMutablePointer<Float>,
		count: Int) -> [Float]
	{
		// log2(W), where W is the number of samples in the calculation window
		let log2n = UInt(floor(log2(Double(count))))
		
		// Largest power of 2 that is less than W. The FFT is more performant when applied to windows with lengths equal to powers of 2.
		let nPowerOfTwo = Int(1 << log2n)
		
		// Dividing the largest power of 2 by 2. Once we get into computations on complex buffers it will make sense why this value is important.
		let nOver2 = nPowerOfTwo / 2
		
		// The Fast Fourier Transform results in complex values, z = x + iy, where z is a complex number, x and y are the real it’s real and imaginary components respectively, and i = sqrt(-1). For this implementation, we must create separate buffers for the real x and imaginary y components.
		var real = [Float](repeating: 0, count: nOver2)
		var imag = [Float](repeating: 0, count: nOver2)
		
//		// Since accelerates digital signal processing method to scale a signal is not in place, we must create output buffers for the result of a scaling operation that we will perform
//		var scaledReal = [Float](repeating: 0, count: nOver2)
//		var scaledImag = [Float](repeating: 0, count: nOver2)
		
		// A split complex buffer for storing real and imaginary components of complex numbers in the separate buffers defined above
		var tempSplitComplex = DSPSplitComplex(
			realp: &real,
			imagp: &imag)
		
		//Here we define fftSetup, or precalculated data that is used by Accelerate to perform Fast Fourier Transforms. The parameters are the log of the max input size the setup can handle and the types of sizes the setup is compatible with respectively. In this case kFFTRadix2 denotes that our input’s size will be a power of 2.
		guard
			let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
		else {
			return []
		}
		
		//In order to put our input data into a split complex buffer, we must first rebound the memory such that we can temporarily treat it as if it were of type [DSPComplex] instead of type [Float], where a DSPComplex is 2 adjacent floating point values that make up a single complex number, with the first value being the real component and the second value being the imaginary component. Since this structure deals with pairs of floating values, we must stride through it by 2. A confusing point for me was why are we switching to a data structure that puts every other element of our entirely real signal into the imagery component of a DSPComplex. Essentially, Accelerate favors packing data in such a way that speeds up the FFT and preserves buffer size even if it doesn't make physical sense.
		input.withMemoryRebound(to: DSPComplex.self, capacity: nOver2) {
			//Once our data is cast as an array of DSPComplex, we use the Accelerate function vDSP_ctoz() to convert our data from the interleaved complex form to the split complex form, DSPSplitComplex, that the FFT function expects as an input. In the DSPSplitComplex form imaginary and real components of complex numbers are stored in separate buffers.
			vDSP_ctoz(
				$0, 2, // Input DSPComplex buffer
				&tempSplitComplex, 1, // Output DSPSplitComplex buffer
				vDSP_Length(nOver2)) // Number of "complex values" in our buffers
		}
		
		// We will use the in place variation of Accelerate's FFT. The transform is packed, meaning that all FFT results after the frequency W/2 are discarded and the real component of the DSPSplitComplex at the would be index (W/2) + 1 is stored in the imaginary component of the DSPSplitComplex at index 0. This enables the input and output buffers to be the same size, W/2, and due to the mirrored nature of FFT results, no non-recoverable data is lost. Note that Accelerate's IFFT is implemented in such a way that it unpacks the signal in addition to transforming it back to the time domain. For more information you can check out the Packing For One Dimensional Arrays section in Apple's Using Fourier Transforms documentation: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/vDSP_Programming_Guide/UsingFourierTransforms/UsingFourierTransforms.html
		vDSP_fft_zrip(
			fftSetup, // Precalculated data
			&tempSplitComplex, 1, // Output/input buffer and stride
			log2n, // Log 2 of the input signal count
			FFTDirection(FFT_FORWARD)) // FFT direction
		
	//	//A thing to watch out for is that Accelerate's FFT functions do not perform any scaling automatically. The forward FFT requires us to scale the result by 1/2
	//	var scale: Float = 2
	//
	//	//Here we use the vDSP_vsdiv() function, which divides a vector by a scaler, to scale our FFT result. Since it is not an in place function, we will utilize the scaled result buffers we created as part of step 1.
	//	vDSP_vsdiv(
	//		&real, 1, &scale, // Unscaled real component input buffer
	//		&scaledReal, 1, // Scaled real component output buffer
	//		vDSP_Length(nOver2))
	//
	//	vDSP_vsdiv(
	//		&imag, 1, &scale, // Unscaled imaginary component input buffer
	//		&scaledImag, 1, // Scaled imaginary component output buffer
	//		vDSP_Length(nOver2))
	//
	//	//Setting the split complex buffer to the new scaled values
	//	tempSplitComplex = DSPSplitComplex(
	//		realp: &scaledReal,
	//		imagp: &scaledImag)
	//
	//	//This may look a little strange since we use the same argument three times in a row, so I'll break down what is happening. The first argument pair is the scaled FFT result from our last step and its stride. The first argument pair is multiplied by complex conjugate of the second argument pair. Since we want to multiply our signal by its own complex conjugate, the second argument pair is the same as the first. Lastly, we want to perform an in place operation, so the third argument pair, the output buffer, is yet again the same as the first and second.
		vDSP_zvcmul(
			&tempSplitComplex, 1, // Normal input
			&tempSplitComplex, 1, // Complex conjugate input
			&tempSplitComplex, 1, // Output = dot product of the two inputs
			vDSP_Length(nOver2))
		
		// Performing the IFFT. An important thing to note is that this signal reverses the packing process of the Accelerate's FFT. So no further unpacking action is required of us.
		vDSP_fft_zrip(
			fftSetup, // Precalculated data
			&tempSplitComplex, 1,  // Output/input buffer and stride
			log2n, // Log 2 of the input signal count
			FFTDirection(FFT_INVERSE)) // FFT direction
		
		// Before returning from the function, we destroy our precalculated data. If this is an operation you plan on performing many times, it may be better to store the precalculated data for future use.
		vDSP_destroy_fftsetup(fftSetup)
		
		//A convenient initializer for creating an array from a [DSPSplitComplex]. It even handles scaling. In this case we will scale by 1/W since that is the scaling that needs to be after the IFFT.
		
		var inverseScale: Float = 1 / Float(nPowerOfTwo * 4)
		
		vDSP_vsmul(tempSplitComplex.realp, 1, &inverseScale, tempSplitComplex.realp, 1, vDSP_Length(nOver2))
		vDSP_vsmul(tempSplitComplex.imagp, 1, &inverseScale, tempSplitComplex.imagp, 1, vDSP_Length(nOver2))
		
		var output = [Float](repeating: 0, count: nOver2)
		let outputPointer = UnsafeMutablePointer(mutating: &output)
		
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
		
		// Squaring our original siganl
		let count = originalSignal.count
		var originalSignalSquared: [Float] = Array(
			repeating: 0,
			count: count)
		
		vDSP_vsq(
			originalSignal, 1, // Original signal input
			&originalSignalSquared, 1, // Output for squared signal
			vDSP_Length(count))
		
		
		// Buffer for our result
		var squareDifference: [Float] = Array(
			repeating: 0,
			count: linearAC.count)

		// 2 * the autocorrelation value at delay time 0, which is equal to the sum of the square of the original value
		var m: Float = 2 * linearAC[0]
		
		let lastDelay = squareDifference.count - 1
		
		// To get the Square Difference Function value at a specific delay, we take the corresponding linear autocorrelation value and divide it by the greatest possible autocorrelation magnitude at that delay. We start at delay 0, where the greatest magnitude is the total sum of our squared signal and gradually decrease the greatest possible magnitude as the delay increases to account for less and less signal being used in the autocorrelation function.
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
