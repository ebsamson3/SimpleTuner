//
//  GaugeView.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import UIKit

/// Animatable gauge with a needle and dial. The dials values are denoted by a gradient
class GaugeView: UIView {

	//MARK: Properties
	
	// Dial start angle (radians)
	var startAngle: CGFloat = (-5/4) * .pi {
		didSet {
			updateDialLayerPath()
		}
	}
	
	// Dial end angle (radians)
	var endAngle: CGFloat = (1/4) * .pi {
		didSet {
			updateDialLayerPath()
		}
	}
	
	// Gradient stop color array
	var gradientColors = [
		UIColor.red.cgColor,
		UIColor.yellow.cgColor,
		UIColor.green.cgColor,
		UIColor.yellow.cgColor,
		UIColor.red.cgColor]
	{
		didSet {
			gradientLayer.colors = gradientColors
		}
	}
	
	// Locations of each gradient stop. 0 value is at 6 o'clock. Clockwise-increasing.
	var gradientLocations: [NSNumber] = [0.125,0.422,0.5, 0.575,0.875] {
		didSet {
			gradientLayer.locations = gradientLocations
		}
	}
	
	var needleColor = UIColor.lightGray {
		didSet {
			needleLayer.fillColor = needleColor.cgColor
		}
	}
	
	// Time it takes for the needle to traverse the entire dial
	var fullSweepDuration: Double = 1
	
	private (set) var value: Float = 0
	
	private var area: CGFloat {
		return bounds.width * bounds.height
	}
	
	//MARK: Sublayers
	let dialLayer = CAShapeLayer()
	let gradientLayer = CAGradientLayer()
	let needleLayer = CAShapeLayer()
	
	//MARK: View Lifecycle
	init() {
		super.init(frame: CGRect.zero)
		commonInit()
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		updateBounds(to: bounds)
	}
	
	private func commonInit() {
		
		layer.addSublayer(gradientLayer)
		layer.addSublayer(dialLayer)
		layer.addSublayer(needleLayer)
		
		updateBounds(to: bounds)
		
		dialLayer.fillColor = UIColor.clear.cgColor
		dialLayer.strokeColor = UIColor.red.cgColor
		dialLayer.lineCap = .round
		
		gradientLayer.colors = gradientColors
		gradientLayer.locations = gradientLocations
		gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
		gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
		gradientLayer.type = .conic
		
		needleLayer.fillColor = needleColor.cgColor
		setValue(value, animated: false)
	}
	
	/// Updates the sublayers in response to a change in the view's bounds
	private func updateBounds(to bounds: CGRect) {
		dialLayer.bounds = bounds
		gradientLayer.bounds = dialLayer.bounds
		needleLayer.bounds = dialLayer.bounds
		
		dialLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		gradientLayer.position = dialLayer.position
		needleLayer.position = dialLayer.position
		
		updateDialLayerPath()
		updateNeedleLayerPath()
		gradientLayer.mask = dialLayer
	}
	
	/// Draws the dial path
	private func updateDialLayerPath() {
		
		guard area > 0 else {
			dialLayer.path = nil
			return
		}
		
		let bounds = dialLayer.bounds
		let minSideLength = min(bounds.width, bounds.height)
		
		let lineWidth: CGFloat = minSideLength / 15
		let radius = (minSideLength - lineWidth) / 2
		
		let dialCenter = CGPoint(x: bounds.midX, y: bounds.midY)
		
		// Shorten the length of the dial to compensate for the dial path's rounded edges
		let capRadius = lineWidth / 2
		let circumfrence = 2 * .pi * radius
		let capRadians =  2 * .pi * (capRadius / circumfrence)
		let adjustedStartAngle = startAngle + capRadians
		let adjustedEndAngle = endAngle - capRadians
		
		let path = UIBezierPath(
			arcCenter: dialCenter,
			radius: radius,
			startAngle: adjustedStartAngle,
			endAngle: adjustedEndAngle,
			clockwise: true)
		
		dialLayer.lineWidth = lineWidth
		dialLayer.path = path.cgPath
	}
	
	/// Draws the needle path
	private func updateNeedleLayerPath() {
		
		guard area > 0 else {
			needleLayer.path = nil
			return
		}
		
		let bounds = needleLayer.bounds
		let minSideLength = min(bounds.width, bounds.height)
		
		let needleHeight = minSideLength / 3 // Height from tip to rotation point
		let needleRadius = needleHeight / 10 // Radius of needle base
		
		// Outer blade length of the needle
		let needleEdgeLength = sqrt(pow(needleHeight, 2) + pow(needleRadius, 2))
		
		// Angle at which the needle blade meets the rounded base
		let needleHalfAngle = asin(needleRadius / needleHeight)
		
		// Point at which right needle blade intersects the rounded base
		let rightIntersect = CGPoint(
			x: needleEdgeLength * sin(needleHalfAngle),
			y: -needleHeight + needleEdgeLength * cos(needleHalfAngle))
		
		// Start and end angle fo the rounded base
		let arcStart = -needleHalfAngle
		let arcEnd = .pi + needleHalfAngle
		
		let path = UIBezierPath()
		path.move(to: CGPoint(x: 0, y: -needleHeight)) // Move to needle tip
		path.addLine(to: rightIntersect) // Draw right edge
		
		// Draw rounded base
		path.addArc(
			withCenter: CGPoint.zero,
			radius: needleRadius,
			startAngle: arcStart,
			endAngle: arcEnd,
			clockwise: true)
		
		path.close() // Close path at needle tip
		
		// Translate path such that the rotation point it at the view's center
		path.apply(CGAffineTransform(translationX: bounds.midX, y: bounds.midY))
		
		needleLayer.path = path.cgPath
	}
	
	/// Updates the needle's rotation angle and animates the change if neccesary
	func setValue(_ newValue: Float, animated: Bool) {
		
		needleLayer.removeAllAnimations()
		
		let totalAngle = endAngle - startAngle // Find total dial angle
		
		let currentAngle: CGFloat
		
		// Get current rotation
		if let transform = needleLayer.presentation()?.transform {
			currentAngle = atan2(transform.m12, transform.m11)
		} else {
			currentAngle = startAngle + totalAngle * CGFloat(value)
		}
		
		// Constrain new values to between 0 and 1
		value = min(1, max(0, newValue))
		
		let newAngle = startAngle + (totalAngle * CGFloat(value)) + .pi / 2
		let rotation = abs(newAngle - currentAngle)
		
		// Adjust duration to facilitate constant needle velocity regardless of rotation distance
		let duration = Double(rotation / totalAngle) * fullSweepDuration
		
		if animated {
			needleLayer.transform = CATransform3DMakeRotation(newAngle, 0, 0, 1)
			let midAngleValue = (max(newAngle, currentAngle) - min(newAngle, currentAngle))
				/ 2 + min(newAngle, currentAngle)

			// Perform a key frame rotation that rotates through a desired midpoint. This controls rotation direction whereas the standard rotation animation uses the shortest path.
			CATransaction.begin()
			CATransaction.setDisableActions(true) // Remove default CALayer animations
			let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
			animation.values = [currentAngle, midAngleValue, newAngle]
			animation.duration = duration
			animation.keyTimes = [0.0, 0.5, 1.0]
			animation.timingFunctions = [
				CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear),
				CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
			]
			needleLayer.add(animation, forKey: "needleRotation")
			CATransaction.commit()
		} else {
			needleLayer.transform = CATransform3DMakeRotation(newAngle, 0, 0, 1)
		}
	}
}

