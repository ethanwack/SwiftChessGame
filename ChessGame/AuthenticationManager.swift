import SwiftUI
// import FirebaseAuth
// import FirebaseFirestore

// MARK: - Firebase Stubs for local testing
class AuthenticationManager: ObservableObject {
    struct LocalUser {
        let uid: String
        let email: String?
    }
    
    struct LocalAuth {
        static let auth = LocalAuth()
        var currentUser: LocalUser? = nil
        
        func signIn(withEmail email: String, password: String, completion: @escaping (AuthResult?, Error?) -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let user = LocalUser(uid: UUID().uuidString, email: email)
                completion(AuthResult(user: user), nil)
            }
        }
        
        func createUser(withEmail email: String, password: String, completion: @escaping (AuthResult?, Error?) -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let user = LocalUser(uid: UUID().uuidString, email: email)
                completion(AuthResult(user: user), nil)
            }
        }
        
        func signOut() throws {
            currentUser = nil
        }
    }
    
    struct AuthResult {
        let user: LocalUser
    }
    
    @Published var user: LocalUser?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    init() {
        user = LocalAuth.auth.currentUser
        isAuthenticated = user != nil
    }
    
    func signIn(email: String, password: String) {
        LocalAuth.auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                self?.user = result?.user
                self?.isAuthenticated = true
            }
        }
    }
    
    func signUp(email: String, password: String) {
        LocalAuth.auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                self?.user = result?.user
                self?.isAuthenticated = true
            }
        }
    }
    
    func signOut() {
        do {
            try LocalAuth.auth.signOut()
            user = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                self?.user = result?.user
                self?.isAuthenticated = true
            }
        }
    }
}