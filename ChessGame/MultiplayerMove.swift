//
//  MultiplayerMove.swift
//  ChessGame
//
//  Created by Ethan Wacker on 6/23/25.
//
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Data Models for Firestore

struct GameMove: Codable {
    let from: Position
    let to: Position
    let pieceType: PieceType
}

struct Position: Codable {
    let row: Int
    let col: Int
}

struct GameData: Codable {
    var id: String = "" // Firestore document ID
    var boardPieces: [ChessPiece] = []
    var currentTurn: PieceColor = .white
    var whitePlayerID: String
    var blackPlayerID: String?
    var whiteTimeRemaining: TimeInterval = 300
    var blackTimeRemaining: TimeInterval = 300
    var gameStatus: String = "waiting" // "waiting", "active", "ended"
    var lastMove: GameMove?
}

class MultiplayerManager: ObservableObject {
    @Published var gameData: GameData?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Create a new game (host)
    func createGame() {
        guard let currentUser = Auth.auth().currentUser else {
            print("User not logged in")
            return
        }

        let initialBoard = ChessBoard().pieces // Make sure your ChessBoard model's pieces are Codable
        let newGame = GameData(
            boardPieces: initialBoard,
            currentTurn: .white,
            whitePlayerID: currentUser.uid,
            blackPlayerID: nil,
            whiteTimeRemaining: 300,
            blackTimeRemaining: 300,
            gameStatus: "waiting"
        )

        do {
            let docRef = try db.collection("games").addDocument(from: newGame)
            self.listenToGame(gameID: docRef.documentID)
            print("Game created with ID: \(docRef.documentID)")
        } catch {
            print("Failed to create game: \(error)")
        }
    }

    // MARK: - Join existing game as black player
    func joinGame(gameID: String) {
        guard let currentUser = Auth.auth().currentUser else {
            print("User not logged in")
            return
        }

        let gameRef = db.collection("games").document(gameID)

        gameRef.getDocument { snapshot, error in
            guard let snapshot = snapshot, snapshot.exists else {
                print("Game does not exist")
                return
            }
            do {
                var game = try snapshot.data(as: GameData.self)
                if game.blackPlayerID == nil {
                    game.blackPlayerID = currentUser.uid
                    game.gameStatus = "active"
                    try gameRef.setData(from: game)
                    self.listenToGame(gameID: gameID)
                } else {
                    print("Game already has two players")
                }
            } catch {
                print("Error joining game: \(error)")
            }
        }
    }

    // MARK: - Listen for updates to game document
    func listenToGame(gameID: String) {
        listener?.remove()

        listener = db.collection("games").document(gameID).addSnapshotListener { [weak self] snapshot, error in
            guard let data = snapshot?.data() else { return }
            do {
                let game = try snapshot?.data(as: GameData.self)
                DispatchQueue.main.async {
                    self?.gameData = game
                }
            } catch {
                print("Error decoding game data: \(error)")
            }
        }
    }

    // MARK: - Send move to Firestore
    func makeMove(newBoardPieces: [ChessPiece], currentTurn: PieceColor, whiteTime: TimeInterval, blackTime: TimeInterval, lastMove: GameMove?) {
        guard let gameID = gameData?.id else { return }
        let gameRef = db.collection("games").document(gameID)

        // Update Firestore with new state
        gameRef.updateData([
            "boardPieces": try! Firestore.Encoder().encode(newBoardPieces),
            "currentTurn": currentTurn.rawValue,
            "whiteTimeRemaining": whiteTime,
            "blackTimeRemaining": blackTime,
            "lastMove": lastMove != nil ? try! Firestore.Encoder().encode(lastMove) : NSNull()
        ]) { error in
            if let error = error {
                print("Error updating move: \(error)")
            }
        }
    }

    // MARK: - Cleanup
    func stopListening() {
        listener?.remove()
    }
}

