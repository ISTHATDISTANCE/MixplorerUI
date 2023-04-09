//
//  MainViewWrapper.swift
//  ARKitProject
//
//  Created by 陆韬 on 4/9/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, *)
struct MainViewWrapper: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
    
    typealias UIViewControllerType = UIViewController
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let storyboard = UIStoryboard(name: "Main", bundle: nil) // Replace "Main" with your storyboard name
        let viewController = storyboard.instantiateViewController(withIdentifier: "main") // Replace "UIKitViewController" with the identifier of your view controller in the storyboard
        return viewController
    }
}
