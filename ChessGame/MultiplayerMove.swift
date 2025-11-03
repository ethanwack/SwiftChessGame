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
    var createdAt: Date = Date()
}

class MultiplayerManager: ObservableObject {
    @Published var gameData: GameData?
    @Published var isInGame = false
    
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Create a new game (host)
    func createGame(timeControl: TimeInterval = 300) {
        guard let currentUser = Auth.auth().currentUser else {
            print("User not logged in")
            return
        }
        
        let newGame = GameData(
            boardPieces: ChessBoard().pieces,
            whitePlayerID: currentUser.uid,
            whiteTimeRemaining: timeControl,
            blackTimeRemaining: timeControl
        )
        
        do {
            let docRef = try db.collection("games").addDocument(from: newGame)
            listenToGame(id: docRef.documentID)
            isInGame = true
        } catch {
            print("Error creating game: \(error)")
        }
    }
    
    // MARK: - Join an existing game
    func joinGame(gameId: String) {
        guard let currentUser = Auth.auth().currentUser else {
            print("User not logged in")
            return
        }
        
        let gameRef = db.collection("games").document(gameId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let gameDoc: DocumentSnapshot
            do {
                try gameDoc = transaction.getDocument(gameRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var game = try? gameDoc.data(as: GameData.self),
                  game.gameStatus == "waiting",
                  game.blackPlayerID == nil else {
                return nil
            }
            
            game.blackPlayerID = currentUser.uid
            game.gameStatus = "active"
            
            do {
                try transaction.setData(from: game, forDocument: gameRef)
                return game
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] (_, error) in
            if let error = error {
                print("Error joining game: \(error)")
            } else {
                self?.listenToGame(id: gameId)
                self?.isInGame = true
            }
        }
    }
    
    // MARK: - Fetch available games
    func fetchAvailableGames(completion: @escaping ([GameData]) -> Void) {
        db.collection("games")
            .whereField("gameStatus", isEqualTo: "waiting")
            .whereField("whitePlayerID", isNotEqualTo: Auth.auth().currentUser?.uid ?? "")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching games: \(error)")
                    completion([])
                    return
                }
                
                let games = snapshot?.documents.compactMap { try? $0.data(as: GameData.self) } ?? []
                completion(games)
            }
    }
    
    // MARK: - Game state management
    private func listenToGame(id: String) {
        listener?.remove()
        
        listener = db.collection("games").document(id)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching game: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                do {
                    let game = try document.data(as: GameData.self)
                    DispatchQueue.main.async {
                        self?.gameData = game
                    }
                } catch {
                    print("Error decoding game data: \(error)")
                }
            }
    }
    
    func makeMove(from: Position, to: Position, piece: ChessPiece) {
        guard let gameId = gameData?.id,
              let currentUser = Auth.auth().currentUser else { return }
        
        let isWhite = gameData?.whitePlayerID == currentUser.uid
        let isBlack = gameData?.blackPlayerID == currentUser.uid
        
        guard (isWhite && gameData?.currentTurn == .white) ||
              (isBlack && gameData?.currentTurn == .black) else { return }
        
        let move = GameMove(from: from, to: to, pieceType: piece.type)
        
        let gameRef = db.collection("games").document(gameId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let gameDoc: DocumentSnapshot
            do {
                try gameDoc = transaction.getDocument(gameRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var game = try? gameDoc.data(as: GameData.self) else { return nil }
            
            // Update the game state
            if let pieceIndex = game.boardPieces.firstIndex(where: { $0.position == (from.row, from.col) }) {
                game.boardPieces[pieceIndex].position = (to.row, to.col)
                game.boardPieces[pieceIndex].hasMoved = true
                
                // Remove captured piece if any
                if let capturedIndex = game.boardPieces.firstIndex(where: { $0.position == (to.row, to.col) && $0.id != game.boardPieces[pieceIndex].id }) {
                    game.boardPieces.remove(at: capturedIndex)
                }
            }
            
            game.currentTurn = game.currentTurn == .white ? .black : .white
            game.lastMove = move
            
            do {
                try transaction.setData(from: game, forDocument: gameRef)
                return game
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { (_, error) in
            if let error = error {
                print("Error updating game: \(error)")
            }
        }
    }
    
    func endGame() {
        guard let gameId = gameData?.id else { return }
        
        let gameRef = db.collection("games").document(gameId)
        gameRef.updateData([
            "gameStatus": "ended"
        ]) { error in
            if let error = error {
                print("Error ending game: \(error)")
            }
        }
        
        listener?.remove()
        gameData = nil
        isInGame = false
    }
    
    deinit {
        listener?.remove()
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

