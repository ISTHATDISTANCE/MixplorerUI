//
//  StartViewWrapper.swift
//  ARKitProject
//
//  Created by 陆韬 on 4/9/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

@available(iOS 16.0, *)
class StartViewWrapper: UIHostingController<StartView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: StartView())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
