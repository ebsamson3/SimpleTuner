//
//  GaugeView.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import UIKit

class GaugeView: UIView {

	var startAngle: CGFloat = (-5/4) * .pi {
		didSet {
			updateArcLayerPath()
		}
	}
	
	var endAngle: CGFloat = (1/4) * .pi {
		didSet {
			updateArcLayerPath()
		}
	}
	
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
	
	var fullSweepDuration: Double = 2
	
	private (set) var value: Float = 0
	
	private var area: CGFloat {
		return bounds.width * bounds.height
	}
	
	let arcLayer = CAShapeLayer()
	let gradientLayer = CAGradientLayer()
	let needleLayer = CAShapeLayer()
	
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
		layer.addSublayer(arcLayer)
		layer.addSublayer(needleLayer)
		
		updateBounds(to: bounds)
		
		arcLayer.fillColor = UIColor.clear.cgColor
		arcLayer.strokeColor = UIColor.red.cgColor
		arcLayer.lineCap = .round
		
		gradientLayer.colors = gradientColors
		gradientLayer.locations = gradientLocations
		gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
		gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
		gradientLayer.type = .conic
		
		needleLayer.fillColor = needleColor.cgColor
		setValue(value, animated: false)
	}
	
	private func updateBounds(to bounds: CGRect) {
		arcLayer.bounds = bounds
		gradientLayer.bounds = arcLayer.bounds
		needleLayer.bounds = arcLayer.bounds
		
		arcLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		gradientLayer.position = arcLayer.position
		needleLayer.position = arcLayer.position
		
		updateArcLayerPath()
		updateNeedleLayerPath()
		gradientLayer.mask = arcLayer
	}
	
	private func updateArcLayerPath() {
		
		guard area > 0 else {
			arcLayer.path = nil
			return
		}
		
		let bounds = arcLayer.bounds
		let minSideLength = min(bounds.width, bounds.height)
		
		let lineWidth: CGFloat = minSideLength / 15
		let radius = (minSideLength - lineWidth) / 2
		
		let arcCenter = CGPoint(x: bounds.midX, y: bounds.midY)
		
		let capRadius = lineWidth / 2
		let circumfrence = 2 * .pi * radius
		let capRadians =  2 * .pi * (capRadius / circumfrence)
		let adjustedStartAngle = startAngle + capRadians
		let adjustedEndAngle = endAngle - capRadians
		
		let path = UIBezierPath(
			arcCenter: arcCenter,
			radius: radius,
			startAngle: adjustedStartAngle,
			endAngle: adjustedEndAngle,
			clockwise: true)
		
		arcLayer.lineWidth = lineWidth
		arcLayer.path = path.cgPath
	}
	
	private func updateNeedleLayerPath() {
		
		guard area > 0 else {
			needleLayer.path = nil
			return
		}
		
		let bounds = needleLayer.bounds
		let minSideLength = min(bounds.width, bounds.height)
		
		let needleHeight = minSideLength / 3
		let needleRadius = needleHeight / 10
		
		let path = UIBezierPath()
		
		let dialEdgeLength = sqrt(pow(needleHeight, 2) + pow(needleRadius, 2))
		let dialHalfAngle = asin(needleRadius / needleHeight)
		
		let rightIntersect = CGPoint(
			x: dialEdgeLength * sin(dialHalfAngle),
			y: -needleHeight + dialEdgeLength * cos(dialHalfAngle))
		
		let arcStart = -dialHalfAngle
		let arcEnd = .pi + dialHalfAngle
		
		path.move(to: CGPoint(x: 0, y: -needleHeight))
		path.addLine(to: rightIntersect)
		path.addArc(
			withCenter: CGPoint.zero,
			radius: needleRadius,
			startAngle: arcStart,
			endAngle: arcEnd,
			clockwise: true)
		path.close()
		path.apply(CGAffineTransform(translationX: bounds.midX, y: bounds.midY))
		
		needleLayer.path = path.cgPath
	}
	
	func setValue(_ newValue: Float, animated: Bool) {
		
		needleLayer.removeAllAnimations()
		
		let totalAngle = endAngle - startAngle
		
		let currentAngle: CGFloat
		
		if let transform = needleLayer.presentation()?.transform {
			currentAngle = atan2(transform.m12, transform.m11)
		} else {
			currentAngle = startAngle + totalAngle * CGFloat(value)
		}
		
		value = min(1, max(0, newValue))
		let newAngle = startAngle + (totalAngle * CGFloat(value)) + .pi / 2
		let rotationAngle = abs(newAngle - currentAngle)
		let duration = Double(rotationAngle / totalAngle) * fullSweepDuration
		
		if animated {
			needleLayer.transform = CATransform3DMakeRotation(newAngle, 0, 0, 1)
			let midAngleValue = (max(newAngle, currentAngle) - min(newAngle, currentAngle))
				/ 2 + min(newAngle, currentAngle)

			CATransaction.begin()
			CATransaction.setDisableActions(true)
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

