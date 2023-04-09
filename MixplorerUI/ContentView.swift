//
//  ContentView.swift
//  MixplorerUI
//
//  Created by 陆韬 on 4/9/23.
//

import SwiftUI
import HalfASheet


enum Placeholder: String, CaseIterable, Identifiable {
    var id: Self {self}
    
    case item1 = "item 1"
    case item2 = "item 2"
    case item3 = "item 3"
}

struct ContentView: View {
    @State private var GUISelection = "Red"
    @State private var propertySelection: Property = .clothes
    @State private var plantSelection = "Green"
    @State private var transportationSelection = "Black"
    @State private var isWelcomeShow = true
    let colors = ["Red", "Green", "Blue", "Black", "Tartan"]
    
    var body: some View {
        NavigationView(content: {
            ZStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Asset Store")
                            .font(.largeTitle)
                        Spacer()
                        Image(systemName: "bag")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .padding(12)
                    }
                    Spacer()
                    Text("Select virtual objects you would like to bring to Mix Reality environment, and add them to your bag.")
                    List {
                        NavigationLink(destination: GUIView(), label: {
                            Text("GUIs")
                        })
                        NavigationLink(destination: PropertiesView(), label: {
                            Text("Properties")
                        })
                        NavigationLink(destination: PlantsView(), label: {
                            Text("Plants")
                        })
                        NavigationLink(destination: TTView(), label: {
                            Text("Transportation Tools")
                        })
                        NavigationLink(destination: MainViewWrapper(), label: {
                            Text("Cam")
                        })
                    }
                    .toolbar(.hidden)
                }
                .padding()
                HalfASheet(isPresented: $isWelcomeShow, title: "Welcome to Mixplorer") {
                    VStack {
                        Text("Mixplorer is a AR data collection app that enables AI-assisted object placement in the AR environment.")
                    }.padding()
                }
                .height(.proportional(0.4))
                .contentInsets(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
            }
        })
    }
}


struct PlaceholderDisplayView: View {
    let display: String
    let title: String
    var body: some View {
        Text("You selected \(display)")
            .navigationTitle(title)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

