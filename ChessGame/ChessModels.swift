import Foundation

enum PieceType: String, Codable {
    case king, queen, rook, bishop, knight, pawn
}

enum PieceColor: String, Codable {
    case white, black
}

struct ChessPiece: Identifiable, Codable {
    var id = UUID()
    var type: PieceType
    var color: PieceColor
    var position: (Int, Int)
    var hasMoved = false

    func copy() -> ChessPiece {
        var new = ChessPiece(type: type, color: color, position: position)
        new.id = id
        new.hasMoved = hasMoved
        return new
    }
}

class ChessBoard: ObservableObject, Codable {
    @Published var pieces: [ChessPiece] = []

    init() {
        resetBoard()
    }

    func resetBoard() {
        pieces = []
        let backRow: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for i in 0..<8 {
            pieces.append(ChessPiece(type: .pawn, color: .white, position: (6, i)))
            pieces.append(ChessPiece(type: .pawn, color: .black, position: (1, i)))
            pieces.append(ChessPiece(type: backRow[i], color: .white, position: (7, i)))
            pieces.append(ChessPiece(type: backRow[i], color: .black, position: (0, i)))
        }
    }

    func deepCopy() -> ChessBoard {
        let copy = ChessBoard()
        copy.pieces = pieces.map { $0.copy() }
        return copy
    }

    func piece(at pos: (Int, Int)) -> ChessPiece? {
        pieces.first(where: { $0.position == pos })
    }

    func applyMove(piece: ChessPiece, to dest: (Int, Int)) {
        pieces.removeAll { $0.position == dest && $0.color != piece.color }
        if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
            pieces[index].position = dest
            pieces[index].hasMoved = true
        }
    }
}

// MARK: - Move Logic

func isInBounds(_ pos: (Int, Int)) -> Bool {
    (0..<8).contains(pos.0) && (0..<8).contains(pos.1)
}

func slideMoves(from pos: (Int, Int), directions: [(Int, Int)], board: ChessBoard, color: PieceColor) -> [(Int, Int)] {
    var result = [(Int, Int)]()
    for dir in directions {
        var (r, c) = pos
        while true {
            r += dir.0
            c += dir.1
            let next = (r, c)
            guard isInBounds(next) else { break }
            if let other = board.piece(at: next) {
                if other.color != color {
                    result.append(next)
                }
                break
            } else {
                result.append(next)
            }
        }
    }
    return result
}

func calculateValidMoves(for piece: ChessPiece, on board: ChessBoard) -> [(Int, Int)] {
    var moves = [(Int, Int)]()
    let (row, col) = piece.position
    let directions: [(Int, Int)]

    switch piece.type {
    case .pawn:
        let dir = piece.color == .white ? -1 : 1
        let startRow = piece.color == .white ? 6 : 1
        let next = (row + dir, col)
        if board.piece(at: next) == nil {
            moves.append(next)
            if row == startRow && board.piece(at: (row + 2 * dir, col)) == nil {
                moves.append((row + 2 * dir, col))
            }
        }

        for dx in [-1, 1] {
            let diag = (row + dir, col + dx)
            if let target = board.piece(at: diag), target.color != piece.color {
                moves.append(diag)
            }
        }

    case .rook:
        directions = [(1,0),(-1,0),(0,1),(0,-1)]
        moves.append(contentsOf: slideMoves(from: piece.position, directions: directions, board: board, color: piece.color))

    case .bishop:
        directions = [(1,1),(-1,-1),(1,-1),(-1,1)]
        moves.append(contentsOf: slideMoves(from: piece.position, directions: directions, board: board, color: piece.color))

    case .queen:
        directions = [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)]
        moves.append(contentsOf: slideMoves(from: piece.position, directions: directions, board: board, color: piece.color))

    case .knight:
        let offsets = [(2,1),(1,2),(-1,2),(-2,1),(-2,-1),(-1,-2),(1,-2),(2,-1)]
        for offset in offsets {
            let dest = (row + offset.0, col + offset.1)
            if isInBounds(dest), board.piece(at: dest)?.color != piece.color {
                moves.append(dest)
            }
        }

    case .king:
        let offsets = [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)]
        for offset in offsets {
            let dest = (row + offset.0, col + offset.1)
            if isInBounds(dest), board.piece(at: dest)?.color != piece.color {
                moves.append(dest)
            }
        }
    }

    return moves
}

// MARK: - Evaluation

func evaluate(board: ChessBoard, for color: PieceColor) -> Int {
    let weights: [PieceType: Int] = [
        .pawn: 100, .knight: 300, .bishop: 300,
        .rook: 500, .queen: 900, .king: 10000
    ]
    var score = 0
    for piece in board.pieces {
        let value = weights[piece.type, default: 0]
        score += (piece.color == color ? value : -value)
    }
    return score
}
