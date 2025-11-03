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
    @State private var showError = false
    @State private var errorMessage = ""
    
    init() {
        do {
            try ConfigurationManager.shared.setupFirebase()
            
            #if os(macOS)
            ConfigurationManager.shared.configureForMacOS()
            #elseif os(iOS)
            ConfigurationManager.shared.configureForIOS()
            #endif
        } catch {
            print("Failed to configure Firebase: \(error)")
            // We'll show this in the UI via showError
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                AdaptiveGameLobby()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .alert("Configuration Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}
