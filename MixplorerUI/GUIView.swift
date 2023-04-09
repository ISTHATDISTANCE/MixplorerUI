//
//  GUIView.swift
//  Mixplorer
//
//  Created by 陆韬 on 3/8/23.
//

import SwiftUI

struct GUIView: View {
    var body: some View {
        List {
            ForEach(Placeholder.allCases) { i in
                NavigationLink(destination: PlaceholderDisplayView(display: i.rawValue, title: i.rawValue), label: {
                    Text(i.rawValue)
                })
            }
        }
        .navigationTitle("GUI")
    }
}
