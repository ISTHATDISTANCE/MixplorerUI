//
//  ContentView.swift
//  ARKitProject
//
//  Created by Henry Wu on 4/9/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import SwiftUI
import UIKit

struct ContentView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ViewController

    func makeUIViewController(context: Context) -> ViewController {
        
        // Load Main.storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Instantiate ViewController
        guard let viewController = storyboard.instantiateInitialViewController() as? ViewController else {
            fatalError("Couldn't instanciate a ViewController class.")
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
