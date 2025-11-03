//
//  ChessGameApp.swift
//  ChessGame
//
//  Created by Ethan Wacker on 6/21/25.
//

import SwiftUI
import FirebaseCore

@main
struct ChessGameApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var appSettings = AppSettings.shared
    
    init() {
        // Only initialize Firebase if online play is enabled
        if AppSettings.shared.isOnlineEnabled {
            do {
                try ConfigurationManager.shared.setupFirebase()
                
                #if os(macOS)
                ConfigurationManager.shared.configureForMacOS()
                #elseif os(iOS)
                ConfigurationManager.shared.configureForIOS()
                #endif
            } catch {
                print("Failed to configure Firebase: \(error)")
                // Disable online features if Firebase setup fails
                AppSettings.shared.isOnlineEnabled = false
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !appSettings.isOnlineEnabled || authManager.isAuthenticated {
                AdaptiveGameLobby()
                    .environmentObject(authManager)
                    .environmentObject(appSettings)
            } else {
                LoginView()
                    .environmentObject(authManager)
                    .environmentObject(appSettings)
            }
        }
    }
}
