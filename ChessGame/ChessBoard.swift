//
//  ChessBoard.swift
//  ChessGame
//
//  Created by Ethan Wacker on 6/23/25.
//
import Foundation

class ChessBoard: ObservableObject {
    @Published var pieces: [ChessPiece] = []

    init() {
        resetBoard()
    }

    func resetBoard() {
        pieces = []

        for col in 0..<8 {
            pieces.append(ChessPiece(type: .pawn, color: .white, position: (6, col)))
            pieces.append(ChessPiece(type: .pawn, color: .black, position: (1, col)))
        }

        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for col in 0..<8 {
            pieces.append(ChessPiece(type: backRank[col], color: .white, position: (7, col)))
            pieces.append(ChessPiece(type: backRank[col], color: .black, position: (0, col)))
        }
    }

    func piece(at position: (Int, Int)) -> ChessPiece? {
        pieces.first(where: { $0.position == position })
    }

    func move(piece: ChessPiece, to destination: (Int, Int)) {
        // Castling logic
        if piece.type == .king, abs(destination.1 - piece.position.1) == 2 {
            let row = piece.position.0
            if destination.1 > piece.position.1 {
                if let rook = piece(at: (row, 7)) {
                    rook.position = (row, 5)
                    rook.hasMoved = true
                }
            } else {
                if let rook = piece(at: (row, 0)) {
                    rook.position = (row, 3)
                    rook.hasMoved = true
                }
            }
        }

        // Capture
        pieces.removeAll { $0.position == destination && $0.color != piece.color }

        piece.position = destination
        piece.hasMoved = true
    }

    func slidingMoves(from position: (Int, Int), directions: [(Int, Int)], for piece: ChessPiece) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []

        for dir in directions {
            var step = 1
            while true {
                let newPos = (position.0 + dir.0 * step, position.1 + dir.1 * step)
                if !isOnBoard(newPos) { break }

                if let blocking = piece(at: newPos) {
                    if blocking.color != piece.color {
                        moves.append(newPos)
                    }
                    break
                } else {
                    moves.append(newPos)
                }

                step += 1
            }
        }

        return moves
    }

    func isOnBoard(_ pos: (Int, Int)) -> Bool {
        return (0..<8).contains(pos.0) && (0..<8).contains(pos.1)
    }

    func isKingInCheck(color: PieceColor) -> Bool {
        guard let king = pieces.first(where: { $0.color == color && $0.type == .king }) else { return false }
        return isSquareAttacked(king.position, by: opposite(color))
    }

    func isSquareAttacked(_ pos: (Int, Int), by attackerColor: PieceColor) -> Bool {
        for attacker in pieces where attacker.color == attackerColor {
            let moves = pseudoLegalMoves(for: attacker)
            if moves.contains(pos) {
                return true
            }
        }
        return false
    }

    func moveLeavesKingInCheck(piece: ChessPiece, to destination: (Int, Int)) -> Bool {
        let testBoard = self.copy()
        guard let testPiece = testBoard.piece(at: piece.position) else { return true }
        testBoard.move(piece: testPiece, to: destination)
        return testBoard.isKingInCheck(color: piece.color)
    }

    func canCastleKingside(color: PieceColor) -> Bool {
        let row = color == .white ? 7 : 0
        guard let king = piece(at: (row, 4)), !king.hasMoved else { return false }
        guard let rook = piece(at: (row, 7)), rook.type == .rook, !rook.hasMoved else { return false }

        for col in 5...6 {
            if piece(at: (row, col)) != nil || isSquareAttacked((row, col), by: opposite(color)) {
                return false
            }
        }

        return true
    }

    func canCastleQueenside(color: PieceColor) -> Bool {
        let row = color == .white ? 7 : 0
        guard let king = piece(at: (row, 4)), !king.hasMoved else { return false }
        guard let rook = piece(at: (row, 0)), rook.type == .rook, !rook.hasMoved else { return false }

        for col in 1...3 {
            if piece(at: (row, col)) != nil { return false }
        }

        for col in 2...4 {
            if isSquareAttacked((row, col), by: opposite(color)) {
                return false
            }
        }

        return true
    }

    func pseudoLegalMoves(for piece: ChessPiece) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []
        let pos = piece.position
        let dir = piece.color == .white ? -1 : 1

        func add(_ r: Int, _ c: Int) {
            if isOnBoard((r, c)) {
                if let target = piece(at: (r, c)) {
                    if target.color != piece.color {
                        moves.append((r, c))
                    }
                } else {
                    moves.append((r, c))
                }
            }
        }

        switch piece.type {
        case .pawn:
            let one = (pos.0 + dir, pos.1)
            if piece(at: one) == nil { moves.append(one) }

            let two = (pos.0 + 2*dir, pos.1)
            if pos.0 == (piece.color == .white ? 6 : 1), piece(at: one) == nil, piece(at: two) == nil {
                moves.append(two)
            }

            for dc in [-1, 1] {
                let cap = (pos.0 + dir, pos.1 + dc)
                if let enemy = piece(at: cap), enemy.color != piece.color {
                    moves.append(cap)
                }
            }

        case .knight:
            let offsets = [(-2,-1), (-2,1), (-1,-2), (-1,2), (1,-2), (1,2), (2,-1), (2,1)]
            for o in offsets { add(pos.0 + o.0, pos.1 + o.1) }

        case .bishop:
            moves += slidingMoves(from: pos, directions: [(-1,-1), (-1,1), (1,-1), (1,1)], for: piece)

        case .rook:
            moves += slidingMoves(from: pos, directions: [(-1,0), (1,0), (0,-1), (0,1)], for: piece)

        case .queen:
            moves += slidingMoves(from: pos, directions: [(-1,-1), (-1,1), (1,-1), (1,1), (-1,0), (1,0), (0,-1), (0,1)], for: piece)

        case .king:
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr != 0 || dc != 0 {
                        add(pos.0 + dr, pos.1 + dc)
                    }
                }
            }
        }

        return moves
    }

    func copy() -> ChessBoard {
        let newBoard = ChessBoard()
        newBoard.pieces = self.pieces.map { $0.copy() }
        return newBoard
    }
}

