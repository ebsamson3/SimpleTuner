//
//  TunerView.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import UIKit

/// A full screen tuner view with a gauge and note labels
class TunerView: UIView {
	
	//MARK: Properties
	var gaugeValue: Float {
		return gaugeView.value
	}
	
	var noteString: String? = "C" {
		didSet {
			noteLabel.text = noteString
		}
	}
	
	var accidentalString: String? = nil {
		didSet {
			accidentalLabel.text = accidentalString
		}
	}
	
	var isActive: Bool = false {
		didSet {
			noteLabel.textColor = isActive ? .white : .darkGray
			accidentalLabel.textColor = isActive ? .white : .darkGray
		}
	}
	
	//MARK: Subviews
	private var gaugeView = GaugeView()
	
	private lazy var noteLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.systemFont(ofSize: 100)
		label.text = noteString
		label.baselineAdjustment = .alignCenters
		label.textColor = isActive ? .white : .darkGray
		return label
	}()
	
	private lazy var accidentalLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.systemFont(ofSize: 33)
		label.text = accidentalString
		label.baselineAdjustment = .alignCenters
		label.textColor = isActive ? .white : .darkGray
		return label
	}()

	//MARK: View Lifecycle
	init() {
		super.init(frame: CGRect.zero)
		configure()
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		configure()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configure()
	}
	
	/// Sets the value of the tuner's gauge
	func setGaugeValue(_ value: Float, animated: Bool) {
		gaugeView.setValue(value, animated: animated)
	}
	
	/// Configure tuner layout
	private func configure() {
		backgroundColor = .black
		
		addSubview(noteLabel)
		addSubview(accidentalLabel)
		addSubview(gaugeView)
		
		noteLabel.translatesAutoresizingMaskIntoConstraints = false
		accidentalLabel.translatesAutoresizingMaskIntoConstraints = false
		gaugeView.translatesAutoresizingMaskIntoConstraints = false
		
		let screenBounds = UIScreen.main.bounds
		let minScreenDimension = min(screenBounds.width, screenBounds.height)
		let maxGaugeSize: CGFloat = 400
		let gaugeSize = min(minScreenDimension * 0.75, maxGaugeSize)
		
		NSLayoutConstraint.activate([
			gaugeView.centerXAnchor.constraint(equalTo: centerXAnchor),
			gaugeView.centerYAnchor.constraint(equalTo: centerYAnchor),
			gaugeView.widthAnchor.constraint(equalToConstant: gaugeSize),
			gaugeView.heightAnchor.constraint(equalToConstant: gaugeSize)
		])
		
		NSLayoutConstraint.activate([
			noteLabel.centerXAnchor.constraint(equalTo: gaugeView.centerXAnchor),
			noteLabel.centerYAnchor.constraint(equalTo: gaugeView.centerYAnchor, constant: gaugeSize / 3)
		])
		
		NSLayoutConstraint.activate([
			accidentalLabel.leadingAnchor.constraint(equalTo: noteLabel.trailingAnchor),
			accidentalLabel.centerYAnchor.constraint(equalTo: noteLabel.centerYAnchor,
												constant: -(noteLabel.font.pointSize - accidentalLabel.font.pointSize) / 2)
		])
	}
}


