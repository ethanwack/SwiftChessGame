//
//  MultiplayerMove.swift
//  ChessGame
//
//  Created by Ethan Wacker on 6/23/25.
//
import Foundation
// import FirebaseFirestore
// import FirebaseAuth
import Combine

// MARK: - Firebase Stubs for local testing

// MARK: - Data Models for Firestore

struct GameMove: Codable {
    let from: Position
    let to: Position
    let pieceType: PieceType
}

struct Position: Codable, Equatable {
    let row: Int
    let col: Int
}

struct GameData: Codable {
    var id: String = ""
    var boardPieces: [ChessPiece] = []
    var currentTurn: PieceColor = .white
    var whitePlayerID: String
    var blackPlayerID: String?
    var whiteTimeRemaining: TimeInterval = 300
    var blackTimeRemaining: TimeInterval = 300
    var gameStatus: String = "waiting"
    var lastMove: GameMove?
    var createdAt: Date = Date()
}

class MultiplayerManager: ObservableObject {
    @Published var gameData: GameData?
    @Published var isInGame = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func createGame(timeControl: TimeInterval = 300) {
        guard let currentUser = AuthenticationManager().user else {
            print("User not logged in")
            return
        }
        
        let initialBoard = ChessBoard().pieces
        let newGame = GameData(
            boardPieces: initialBoard,
            currentTurn: .white,
            whitePlayerID: currentUser.uid,
            blackPlayerID: nil,
            whiteTimeRemaining: timeControl,
            blackTimeRemaining: timeControl,
            gameStatus: "waiting"
        )
        
        isInGame = true
        print("Game created")
    }
    
    func joinGame(gameId: String) {
        guard let currentUser = AuthenticationManager().user else {
            print("User not logged in")
            return
        }
        
        isInGame = true
        print("Joined game: \(gameId)")
    }
    
    func fetchAvailableGames(completion: @escaping ([GameData]) -> Void) {
        guard let currentUserId = AuthenticationManager().user?.uid else {
            completion([])
            return
        }
        
        completion([])
    }
    
    func makeMove(from: Position, to: Position, piece: ChessPiece) {
        // Stub implementation
    }
    
    func endGame() {
        gameData = nil
        isInGame = false
    }
}
