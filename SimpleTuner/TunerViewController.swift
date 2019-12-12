//
//  TunerViewController.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/11/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import UIKit

class TunerViewController: UIViewController {
	
	let viewModel: TunerViewModel
	
	var tunerView: TunerView {
		return view as! TunerView
	}
	
	init(viewModel: TunerViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
		
		viewModel.didSetGaugeValue = { [weak self] gaugeValue in
			self?.tunerView.setGaugeValue(gaugeValue, animated: true)
		}
		
		viewModel.didSetNoteString = { [weak self] noteString in
			self?.tunerView.noteString = noteString
		}

		viewModel.didStAccidentalString = { [weak self] accidentalString in
			self?.tunerView.accidentalString = accidentalString
		}
		
		viewModel.didSetIsActive = { [weak self] isActive in
			self?.tunerView.isActive = isActive
		}
		
		tunerView.setGaugeValue(viewModel.gaugeValue, animated: false)
		tunerView.noteString = viewModel.noteString
		tunerView.accidentalString = viewModel.accidentalString
		tunerView.isActive = viewModel.isActive
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func loadView() {
		view = TunerView()
	}
}
