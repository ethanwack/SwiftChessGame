import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var isOnlineEnabled = false
    
    private init() {}
}