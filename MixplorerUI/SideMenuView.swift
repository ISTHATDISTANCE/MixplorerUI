//
//  SideMenuView.swift
//  Mixplorer
//
//  Created by 陆韬 on 3/18/23.
//

import SwiftUI

struct SideMenuView: View {
    @Binding var watermelonAmount: Int
    @Binding var coffeeAmount: Int
    @Binding var milkAmount: Int
    @Binding var sandwichAmount: Int
    @Binding var showBag: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Bag")
                        .font(.largeTitle)
                        .padding(EdgeInsets(top: 120, leading: 12, bottom: 12, trailing: 0))
                    Spacer()
                    Image(systemName: "multiply.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32)
                        .padding(EdgeInsets(top: 120, leading: 12, bottom: 12, trailing: 12))
                        .onTapGesture {
                            showBag.toggle()
                        }
                    
                }
                List {
                    
                    if watermelonAmount > 0 {
                        HStack {
                            Image("watermelon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                            Spacer()
                            HStack {
                                Text("Watermelon")
                                //                                .font(.system(size: 24))
                                Text("\(watermelonAmount)")
                                //                                .font(.system(size: 24))
                                    .bold(true)
                            }
                        }
                    }
                    if coffeeAmount > 0 {
                        HStack {
                            Image("coffee")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                            Spacer()
                            HStack {
                                Text("Coffee")
                                //                                .font(.system(size: 24))
                                Text("\(coffeeAmount)")
                                //                                .font(.system(size: 24))
                                    .bold(true)
                            }
                        }
                    }
                    if milkAmount > 0 {
                        HStack {
                            Image("milk")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                            Spacer()
                            HStack {
                                Text("Milk")
                                //                                .font(.system(size: 24))
                                Text("\(milkAmount)")
                                //                                .font(.system(size: 24))
                                    .bold(true)
                            }
                        }
                    }
                    if sandwichAmount > 0 {
                        HStack {
                            Image("sandwich")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                            Spacer()
                            HStack {
                                Text("Sandwich")
                                //                                .font(.system(size: 24))
                                Text("\(sandwichAmount)")
                                //                                .font(.system(size: 24))
                                    .bold(true)
                            }
                        }
                    }
                }
                Spacer()
                NavigationLink(destination: MainViewWrapper()) {
                    Text("I'm ready to go!")
                        .font(.system(size: 24))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 50, trailing: 0))
                }
            }
            .frame(width: 300)
            .background(.white)
            .padding()
                    .ignoresSafeArea()
//            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct SideMenuView_Container: View {
    @State private var watermelonAmount = 1
    @State private var coffeeAmount = 1
    @State private var milkAmount = 1
    @State private var sanwichAmount = 1
    @State private var showBag = true
    
    var body: some View {
        SideMenuView(watermelonAmount: $watermelonAmount, coffeeAmount: $coffeeAmount, milkAmount: $milkAmount, sandwichAmount: $sanwichAmount, showBag: $showBag)
    }
}

struct SideMenuView_Container_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuView_Container()
    }
}
