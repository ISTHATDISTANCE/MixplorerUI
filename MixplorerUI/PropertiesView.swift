//
//  PropertiesView.swift
//  Mixplorer
//
//  Created by 陆韬 on 3/8/23.
//

import SwiftUI
import HalfASheet

enum Property: String, CaseIterable, Identifiable {
    case clothes = "Clothes & Accessories"
    case electronics = "Electronic Products"
    case appearance = "Appearance"
    case food = "Food"
    case furniture = "Furniture"
    case industrial = "Industrial Products"
    case interior = "Interior"
    case tool = "Tool"
    case arm = "Arm"
    var id: Self {self}
}

struct PropertiesView: View {
    var body: some View {
        VStack {
            HStack {
                Text("Asset Store")
                    .font(.largeTitle)
                Spacer()
                Image(systemName: "bag.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .padding(12)
            }
            List {
                ForEach(Property.allCases) { i in
                    NavigationLink(destination: PropertiesDisplayView(item: i.rawValue), label: {
                        Text(i.rawValue)
                    })
                }
            }
        }.padding()
            .toolbar(.hidden)
    }
}

struct PropertiesDisplayView: View {
    let item: String
    @State private var isWatermelonShow = false
    @State private var isCoffeeShow = false
    @State private var isMilkShow = false
    @State private var isSandwichShow = false
    @State private var watermelonAmount = 0
    @State private var coffeeAmount = 0
    @State private var milkAmount = 0
    @State private var sandwichAmount = 0
    @State private var showBag = false
    
    var body: some View {
//        Text("You selected \(item)")
//            .navigationTitle(item)
        ZStack {
            VStack {
                
                HStack {
                    Text("Asset Store")
                        .font(.largeTitle)
                    Spacer()
                    Image(systemName: "bag")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(12)
                        .onTapGesture {
                            showBag.toggle()
                        }
                }
                HStack {
                    VStack {
                        Image("watermelon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(0.8)
                            .overlay(alignment: .topTrailing) {
                                if watermelonAmount > 0 {
                                    Text("\(watermelonAmount)")
                                        .bold(true)
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.white))
                                        .background(Circle().fill(.red).frame(width: 40, height: 40))
                                }
                            }
                        Text("Watermelon")
                    }.onTapGesture {
                        isWatermelonShow.toggle()
                    }
                    Spacer()
                    VStack {
                        Image("coffee")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(0.8)
                            .overlay(alignment: .topTrailing) {
                                if coffeeAmount > 0 {
                                    Text("\(coffeeAmount)")
                                        .bold(true)
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.white))
                                        .background(Circle().fill(.red).frame(width: 40, height: 40))
                                }
                            }
                        Text("Coffee")
                    }.onTapGesture {
                        isCoffeeShow.toggle()
                    }
                }
                HStack {
                    VStack {
                        Image("milk")
                            .resizable()
                            .aspectRatio(1.5, contentMode: .fit)
                            .scaleEffect(0.8)
                            .overlay(alignment: .topTrailing) {
                                if milkAmount > 0 {
                                    Text("\(milkAmount)")
                                        .bold(true)
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.white))
                                        .background(Circle().fill(.red).frame(width: 40, height: 40))
                                }
                            }
                        Text("Milk")
                    }.onTapGesture {
                        isMilkShow.toggle()
                    }
                    Spacer()
                    VStack {
                        Image("sandwich")
                            .resizable()
                            .aspectRatio(1.5, contentMode: .fit)
                            .scaleEffect(0.8)
                            .overlay(alignment: .topTrailing) {
                                if sandwichAmount > 0 {
                                    Text("\(sandwichAmount)")
                                        .bold(true)
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.white))
                                        .background(Circle().fill(.red).frame(width: 40, height: 40))
                                }
                            }
                        Text("Sandwich")
                    }.onTapGesture {
                        isSandwichShow.toggle()
                    }
                }
                Spacer()
            }.padding()
            
            HalfASheet(isPresented: $isWatermelonShow, title: "Add to Cart") {
                VStack {
                    Image("watermelon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(0.8)
                    HStack {
                        Image(systemName: "minus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                if (watermelonAmount > 0) {
                                    watermelonAmount -= 1
                                }
                            }
                        Text("\(watermelonAmount)")
                            .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        Image(systemName: "plus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                watermelonAmount += 1
                            }
                    }
                    Text("Watermelon")
                }
            }
            .height(.proportional(0.4))
            .contentInsets(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
            
            HalfASheet(isPresented: $isCoffeeShow) {
                VStack {
                    Image("coffee")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(0.8)
                    HStack {
                        Image(systemName: "minus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                if (coffeeAmount > 0) {
                                    coffeeAmount -= 1
                                }
                            }
                        Text("\(coffeeAmount)")
                            .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        Image(systemName: "plus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                coffeeAmount += 1
                            }
                    }
                    Text("Coffee")
                }
            }
            .height(.proportional(0.4))
            .contentInsets(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
            
            HalfASheet(isPresented: $isMilkShow, title: "Add to Cart") {
                VStack {
                    Image("milk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(0.8)
                    HStack {
                        Image(systemName: "minus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                if (milkAmount > 0) {
                                    milkAmount -= 1
                                }
                            }
                        Text("\(milkAmount)")
                            .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        Image(systemName: "plus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                milkAmount += 1
                            }
                    }
                    Text("Milk")
                }
            }
            .height(.proportional(0.4))
            .contentInsets(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
            
            HalfASheet(isPresented: $isSandwichShow, title: "Add to Cart") {
                VStack {
                    Image("sandwich")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(0.8)
                    HStack {
                        Image(systemName: "minus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                if (sandwichAmount > 0) {
                                    sandwichAmount -= 1
                                }
                            }
                        Text("\(sandwichAmount)")
                            .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        Image(systemName: "plus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .onTapGesture {
                                sandwichAmount += 1
                            }
                    }
                    Text("Sandwich")
                }
            }
            .height(.proportional(0.4))
            .contentInsets(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
            GeometryReader { _ in
                HStack {
                    Spacer()
                    SideMenuView(watermelonAmount: $watermelonAmount, coffeeAmount: $coffeeAmount, milkAmount: $milkAmount, sandwichAmount: $sandwichAmount, showBag: $showBag)
                        .offset(x: showBag ? 0 : UIScreen.main.bounds.width)
                        .animation (.interactiveSpring (response: 0.6, dampingFraction: 1.0, blendDuration: 0.8), value: showBag)
                }
            }
            .background(Color.black.opacity(showBag ? 0.5 : 0))
//            .onTapGesture {
//                showBag.toggle()
//            }
        }
        .toolbar(.hidden)
    }
}

struct PropertiesDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        PropertiesDisplayView(item: "preview")
    }
}
