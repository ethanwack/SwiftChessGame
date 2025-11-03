import Foundation
import FirebaseCore

enum ConfigurationError: Error {
    case missingPlist
    case invalidPlist
}

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private init() {}
    
    func setupFirebase() throws {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            throw ConfigurationError.missingPlist
        }
        
        guard let options = FirebaseOptions(contentsOfFile: path) else {
            throw ConfigurationError.invalidPlist
        }
        
        FirebaseApp.configure(options: options)
    }
    
    #if os(macOS)
    func configureForMacOS() {
        // macOS specific configuration
    }
    #endif
    
    #if os(iOS)
    func configureForIOS() {
        // iOS specific configuration
    }
    #endif
}