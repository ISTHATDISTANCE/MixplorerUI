//
//  StartView.swift
//  ARKitProject
//
//  Created by 陆韬 on 4/9/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import SwiftUI

@available(iOS 16.0, *)
struct StartView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        NavigationStack {
            NavigationLink("lalal", destination: MainViewWrapper())
        }
    }
}

@available(iOS 16.0, *)
struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
    }
}
