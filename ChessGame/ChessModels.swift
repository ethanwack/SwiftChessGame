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
    
    // Custom Codable implementation for tuple
    enum CodingKeys: String, CodingKey {
        case id, type, color, positionRow, positionCol, hasMoved
    }
    
    init(type: PieceType, color: PieceColor, position: (Int, Int)) {
        self.type = type
        self.color = color
        self.position = position
        self.hasMoved = false
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(PieceType.self, forKey: .type)
        color = try container.decode(PieceColor.self, forKey: .color)
        let row = try container.decode(Int.self, forKey: .positionRow)
        let col = try container.decode(Int.self, forKey: .positionCol)
        position = (row, col)
        hasMoved = try container.decode(Bool.self, forKey: .hasMoved)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(color, forKey: .color)
        try container.encode(position.0, forKey: .positionRow)
        try container.encode(position.1, forKey: .positionCol)
        try container.encode(hasMoved, forKey: .hasMoved)
    }

    func copy() -> ChessPiece {
        var new = ChessPiece(type: type, color: color, position: position)
        new.id = id
        new.hasMoved = hasMoved
        return new
    }
}

class ChessBoard: ObservableObject, Codable {
    @Published var pieces: [ChessPiece] = []
    
    enum CodingKeys: String, CodingKey {
        case pieces
    }

    init() {
        resetBoard()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pieces = try container.decode([ChessPiece].self, forKey: .pieces)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pieces, forKey: .pieces)
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
        if isInBounds(next) && board.piece(at: next) == nil {
            moves.append(next)
            if row == startRow && board.piece(at: (row + 2 * dir, col)) == nil {
                moves.append((row + 2 * dir, col))
            }
        }

        for dx in [-1, 1] {
            let diag = (row + dir, col + dx)
            if isInBounds(diag), let target = board.piece(at: diag), target.color != piece.color {
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

// MARK: - Game State Checking

func isKingInCheck(_ color: PieceColor, on board: ChessBoard) -> Bool {
    guard let king = board.pieces.first(where: { $0.color == color && $0.type == .king }) else {
        return false
    }
    
    for piece in board.pieces where piece.color != color {
        let moves = calculateValidMoves(for: piece, on: board)
        if moves.contains(where: { $0 == king.position }) {
            return true
        }
    }
    return false
}

func isKingInCheckmate(_ color: PieceColor, on board: ChessBoard) -> Bool {
    guard isKingInCheck(color, on: board) else { return false }
    
    for piece in board.pieces where piece.color == color {
        let moves = calculateValidMoves(for: piece, on: board)
        for move in moves {
            let testBoard = board.deepCopy()
            if let testPiece = testBoard.piece(at: piece.position) {
                testBoard.applyMove(piece: testPiece, to: move)
                if !isKingInCheck(color, on: testBoard) {
                    return false
                }
            }
        }
    }
    return true
}

func isStalemate(_ color: PieceColor, on board: ChessBoard) -> Bool {
    guard !isKingInCheck(color, on: board) else { return false }
    
    for piece in board.pieces where piece.color == color {
        let moves = calculateValidMoves(for: piece, on: board)
        for move in moves {
            let testBoard = board.deepCopy()
            if let testPiece = testBoard.piece(at: piece.position) {
                testBoard.applyMove(piece: testPiece, to: move)
                if !isKingInCheck(color, on: testBoard) {
                    return false
                }
            }
        }
    }
    return true
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

enum AIDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var id: String { rawValue }
    
    var depth: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

enum GameMode: String, CaseIterable {
    case vsPlayer = "Player vs Player"
    case vsAI = "Player vs AI"
}