import SwiftUI

// MARK: - Platform-specific configuration
#if os(iOS) || os(iPadOS)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

// MARK: - Adaptive Layout
enum DeviceType {
    case phone, pad, mac
    
    static var current: DeviceType {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #elseif os(macOS)
        return .mac
        #else
        return .phone
        #endif
    }
}

// MARK: - Adaptive Chess Board
struct AdaptiveChessBoard: View {
    let boardSize: CGFloat
    let squareSize: CGFloat
    
    init() {
        switch DeviceType.current {
        case .phone:
            boardSize = min(UIScreen.main.bounds.width - 32, 400)
        case .pad:
            boardSize = min(UIScreen.main.bounds.width - 100, 600)
        case .mac:
            boardSize = 600
        }
        squareSize = boardSize / 8
    }
    
    var body: some View {
        // Your existing chess board view with adaptive sizing
        ChessBoardView(size: boardSize)
    }
}

// MARK: - Adaptive Game Lobby
struct AdaptiveGameLobby: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var multiplayerManager = MultiplayerManager()
    
    var body: some View {
        Group {
            switch DeviceType.current {
            case .phone:
                PhoneGameLobby(multiplayerManager: multiplayerManager)
            case .pad:
                PadGameLobby(multiplayerManager: multiplayerManager)
            case .mac:
                MacGameLobby(multiplayerManager: multiplayerManager)
            }
        }
        .environmentObject(authManager)
    }
}

// MARK: - Device-specific lobby layouts
private struct PhoneGameLobby: View {
    @ObservedObject var multiplayerManager: MultiplayerManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GameListView(multiplayerManager: multiplayerManager)
                .tabItem {
                    Label("Games", systemImage: "gamecontroller")
                }
                .tag(0)
            
            PlayerProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(1)
        }
    }
}

private struct PadGameLobby: View {
    @ObservedObject var multiplayerManager: MultiplayerManager
    
    var body: some View {
        NavigationView {
            GameListView(multiplayerManager: multiplayerManager)
            
            // Default detail view
            Text("Select a game to join")
                .font(.title)
        }
    }
}

private struct MacGameLobby: View {
    @ObservedObject var multiplayerManager: MultiplayerManager
    
    var body: some View {
        NavigationView {
            GameListView(multiplayerManager: multiplayerManager)
                .frame(minWidth: 250, maxWidth: 300)
            
            // Default detail view
            Text("Select a game to join")
                .font(.title)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { /* Add new game */ }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Shared Components
private struct GameListView: View {
    @ObservedObject var multiplayerManager: MultiplayerManager
    @State private var games: [GameData] = []
    
    var body: some View {
        List(games, id: \.id) { game in
            GameRowView(game: game) {
                multiplayerManager.joinGame(gameId: game.id)
            }
        }
        .onAppear {
            multiplayerManager.fetchAvailableGames { fetchedGames in
                games = fetchedGames
            }
        }
    }
}

private struct PlayerProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        List {
            if let user = authManager.user {
                Text("Email: \(user.email ?? "Guest")")
                Button("Sign Out") {
                    authManager.signOut()
                }
            }
        }
    }
}

// MARK: - Chess Board View
struct ChessBoardView: View {
    let size: CGFloat
    
    var body: some View {
        // Implement your chess board view here
        // This is just a placeholder
        VStack(spacing: 0) {
            ForEach(0..<8) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8) { col in
                        Rectangle()
                            .fill((row + col) % 2 == 0 ? Color.white : Color.black)
                            .frame(width: size/8, height: size/8)
                    }
                }
            }
        }
        .border(Color.black, width: 2)
    }
}