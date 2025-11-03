import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GameLobbyView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var multiplayerManager = MultiplayerManager()
    @State private var showingCreateGame = false
    @State private var availableGames: [GameData] = []
    @State private var selectedGameMode: GameMode = .vsAI
    
    var body: some View {
        NavigationView {
            VStack {
                // Game Mode Picker
                Picker("Game Mode", selection: $selectedGameMode) {
                    Text("vs Computer").tag(GameMode.vsAI)
                    Text("Local 2-Player").tag(GameMode.localMultiplayer)
                    Text("Online Multiplayer").tag(GameMode.onlineMultiplayer)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedGameMode == .onlineMultiplayer {
                    // Online Multiplayer View
                    VStack {
                        Button(action: { showingCreateGame = true }) {
                            Text("Create New Game")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        Text("Available Games")
                            .font(.headline)
                            .padding(.top)
                        
                        List(availableGames, id: \.id) { game in
                            GameRowView(game: game) {
                                multiplayerManager.joinGame(gameId: game.id)
                            }
                        }
                    }
                }
                
                NavigationLink(
                    destination: ContentView()
                        .environmentObject(multiplayerManager)
                        .environmentObject(authManager),
                    isActive: $multiplayerManager.isInGame
                ) {
                    EmptyView()
                }
            }
            .navigationTitle("Chess Game")
            .navigationBarItems(trailing: Button("Sign Out") {
                authManager.signOut()
            })
            .sheet(isPresented: $showingCreateGame) {
                CreateGameView(multiplayerManager: multiplayerManager)
            }
            .onAppear {
                if selectedGameMode == .onlineMultiplayer {
                    multiplayerManager.fetchAvailableGames { games in
                        availableGames = games
                    }
                }
            }
        }
    }
}

struct GameRowView: View {
    let game: GameData
    let joinAction: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Host: \(game.whitePlayerID)")
                    .font(.subheadline)
                Text("Status: \(game.gameStatus)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Join", action: joinAction)
                .disabled(game.gameStatus != "waiting")
        }
        .padding(.vertical, 8)
    }
}

struct CreateGameView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var multiplayerManager: MultiplayerManager
    @State private var timeControl: Int = 5 // minutes
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Game Settings")) {
                    Stepper("Time: \(timeControl) minutes", value: $timeControl, in: 1...60)
                }
                
                Button("Create Game") {
                    multiplayerManager.createGame(timeControl: Double(timeControl) * 60)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Create New Game")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}