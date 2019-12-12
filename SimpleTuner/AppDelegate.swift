//
//  AppDelegate.swift
//  SimpleTuner
//
//  Created by Edward Samson on 12/10/19.
//  Copyright © 2019 Edward Samson. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		window = UIWindow(frame: UIScreen.main.bounds)
		let viewModel = TunerViewModel(pitchRecognizer: PitchRecognizer())
		let viewController = TunerViewController(viewModel: viewModel)
		window?.rootViewController = viewController
		window?.makeKeyAndVisible()
		return true
	}
}

