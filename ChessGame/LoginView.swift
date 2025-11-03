import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chess.queen.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.primary)
                
                Text("Chess Game")
                    .font(.largeTitle)
                    .bold()
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                    if isSignUp {
                        authManager.signUp(email: email, password: password)
                    } else {
                        authManager.signIn(email: email, password: password)
                    }
                }) {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
                
                Button(action: { authManager.signInAnonymously() }) {
                    Text("Play as Guest")
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }
}