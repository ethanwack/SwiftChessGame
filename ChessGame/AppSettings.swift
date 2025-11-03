import SwiftUI

class AppSettings: ObservableObject {
    @Published var isOnlineEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isOnlineEnabled, forKey: "isOnlineEnabled")
        }
    }
    
    init() {
        self.isOnlineEnabled = UserDefaults.standard.bool(forKey: "isOnlineEnabled")
    }
    
    static let shared = AppSettings()
}

enum GameMode: String, CaseIterable {
    case vsAI = "Play vs Computer"
    case localMultiplayer = "Local 2-Player"
    case onlineMultiplayer = "Online Multiplayer"
    
    var requiresOnline: Bool {
        self == .onlineMultiplayer
    }
}