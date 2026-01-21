//
//  goviiralApp.swift
//  goviiral
//
//  Created by duverney muriel on 8/12/25.
//

import SwiftUI

@main
struct goviiralApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(subscriptionManager)
        }
    }
}
