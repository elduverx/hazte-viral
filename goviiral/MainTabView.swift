//
//  MainTabView.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var scheme
    @State private var selectedTab: AppTab = .videoReactor
    
    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == .videoReactor ? "video.fill" : "video")
                        Text("Video Reactor")
                    }
                }
                .tag(AppTab.videoReactor)
            
            UGCScriptMakerView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == .scriptMaker ? "doc.text.fill" : "doc.text")
                        Text("Script Maker")
                    }
                }
                .tag(AppTab.scriptMaker)
        }
        .accentColor(Theme.accentStart)
    }
}

enum AppTab: String, CaseIterable {
    case videoReactor = "Video Reactor"
    case scriptMaker = "Script Maker"
    
    var icon: String {
        switch self {
        case .videoReactor: return "video"
        case .scriptMaker: return "doc.text"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .videoReactor: return "video.fill"
        case .scriptMaker: return "doc.text.fill"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SubscriptionManager.shared)
}