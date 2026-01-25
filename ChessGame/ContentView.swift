import SwiftUI

// MARK: - Zobrist Hashing & Transposition Table
struct Zobrist {
    static let table = (0..<2).map { _ in
        (0..<6).map { _ in
            (0..<64).map { _ in UInt64.random(in: UInt64.min...UInt64.max) }
        }
    }
    static func hash(board: ChessBoard) -> UInt64 {
        var h: UInt64 = 0
        for piece in board.pieces {
            let c = piece.color == .white ? 0 : 1
            let t = ["king","queen","rook","bishop","knight","pawn"]
                .firstIndex(of: piece.type.rawValue)!
            let sq = piece.position.0 * 8 + piece.position.1
            h ^= table[c][t][sq]
        }
        return h
    }
}

class TranspositionTable {
    private var data = [UInt64: Int]()
    func get(_ h: UInt64) -> Int? { data[h] }
    func set(_ h: UInt64, _ score: Int) { data[h] = score }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var board = ChessBoard()
    
    @State private var selectedPiece: ChessPiece?
    @State private var validMoves = [(Int, Int)]()
    @State private var currentTurn: PieceColor = .white
    @State private var gameMode: GameMode = .vsAI
    @State private var difficulty: AIDifficulty = .medium
    @State private var aiPlaysAs: PieceColor = .black

    @State private var promotionTarget: ChessPiece?
    @State private var showPromotionPicker = false
    @State private var moveHistory = [ChessBoard]()

    @State private var whiteCaptures = [ChessPiece]()
    @State private var blackCaptures = [ChessPiece]()

    @State private var whiteTimeRemaining: TimeInterval = 5 * 60
    @State private var blackTimeRemaining: TimeInterval = 5 * 60
    @State private var timer: Timer?
    @State private var activeTimerColor: PieceColor?

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 10) {
            Picker("Mode", selection: $gameMode) {
                Text("PvP").tag(GameMode.vsPlayer)
                Text("PvAI").tag(GameMode.vsAI)
            }.pickerStyle(SegmentedPickerStyle())

            if gameMode == .vsAI {
                Picker("AI Difficulty", selection: $difficulty) {
                    ForEach(AIDifficulty.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                Picker("AI Plays As", selection: $aiPlaysAs) {
                    Text("White").tag(PieceColor.white)
                    Text("Black").tag(PieceColor.black)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                clockView(color: .white, time: whiteTimeRemaining, isActive: currentTurn == .white)
                Spacer()
                clockView(color: .black, time: blackTimeRemaining, isActive: currentTurn == .black)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(whiteCaptures, id: \.id) { Text(pieceSymbol($0)) } }
            }
            .frame(height: 30)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 0) {
                ForEach(0..<8, id: \.self) { r in
                    ForEach(0..<8, id: \.self) { c in
                        squareView(row: r, col: c)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(blackCaptures, id: \.id) { Text(pieceSymbol($0)) } }
            }
            .frame(height: 30)

            if showPromotionPicker, let t = promotionTarget {
                promotionPicker(for: t)
            }

            HStack(spacing: 50) {
                Button("Undo") { undoLastMove() }
                    .disabled(moveHistory.isEmpty)
                Button("Reset") { resetGame() }
            }
        }
        .padding()
        .disabled(showPromotionPicker)
        .onAppear {
            startTimer(for: currentTurn)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertMessage))
        }
    }

    // MARK: - UI Components
    
    func clockView(color: PieceColor, time: TimeInterval, isActive: Bool) -> some View {
        VStack {
            Text(color == .white ? "White" : "Black")
                .font(.caption)
            Text(timeString(from: time))
                .font(.title2)
                .foregroundColor(isActive ? .green : .primary)
        }
    }

    func squareView(row: Int, col: Int) -> some View {
        let isLight = (row + col) % 2 == 0
        let piece = board.piece(at: (row, col))
        let isSelected = selectedPiece != nil && selectedPiece!.position == (row, col)
        let isValidMove = validMoves.contains(where: { $0 == (row, col) })
        
        return ZStack {
            // Chess board square background
            Rectangle()
                .fill(isLight ? Color(red: 0.9, green: 0.9, blue: 0.9) : Color(red: 0.3, green: 0.7, blue: 0.3))
                .border(isSelected ? Color.blue : Color.clear, width: 3)
            
            // Piece display
            if let p = piece {
                Text(pieceSymbol(p))
                    .font(.system(size: 35))
                    .fontWeight(.bold)
            }
            
            // Valid move indicator
            if isValidMove {
                Circle()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            handleTap(row: row, col: col)
        }
    }

    func promotionPicker(for piece: ChessPiece) -> some View {
        HStack(spacing: 20) {
            ForEach([PieceType.queen, .rook, .bishop, .knight], id: \.self) { type in
                Button(action: {
                    if let index = board.pieces.firstIndex(where: { $0.id == piece.id }) {
                        board.pieces[index].type = type
                    }
                    showPromotionPicker = false
                    promotionTarget = nil
                    endTurn()
                }) {
                    Text(pieceSymbol(ChessPiece(type: type, color: piece.color, position: (0,0))))
                        .font(.system(size: 50))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
    }

    func pieceSymbol(_ piece: ChessPiece) -> String {
        let symbols: [PieceColor: [PieceType: String]] = [
            .white: [.king: "♔", .queen: "♕", .rook: "♖", .bishop: "♗", .knight: "♘", .pawn: "♙"],
            .black: [.king: "♚", .queen: "♛", .rook: "♜", .bishop: "♝", .knight: "♞", .pawn: "♟"]
        ]
        return symbols[piece.color]?[piece.type] ?? ""
    }

    // MARK: - Game Logic

    func handleTap(row: Int, col: Int) {
        if let piece = selectedPiece {
            if validMoves.contains(where: { $0 == (row, col) }) {
                moveHistory.append(board.deepCopy())
                captureIfNeeded(at: (row, col))
                movePiece(piece, to: (row, col))
                
                if piece.type == .pawn && (row == 0 || row == 7) {
                    promotionTarget = board.piece(at: (row, col))
                    showPromotionPicker = true
                } else {
                    endTurn()
                }
            }
            selectedPiece = nil
            validMoves = []
        } else if let piece = board.piece(at: (row, col)), piece.color == currentTurn {
            selectedPiece = piece
            validMoves = calculateValidMoves(for: piece, on: board).filter { move in
                let testBoard = board.deepCopy()
                if let testPiece = testBoard.piece(at: piece.position) {
                    testBoard.applyMove(piece: testPiece, to: move)
                    return !isKingInCheck(currentTurn, on: testBoard)
                }
                return false
            }
        }
    }

    func captureIfNeeded(at pos: (Int, Int)) {
        if let captured = board.piece(at: pos), captured.color != currentTurn {
            if captured.color == .white {
                whiteCaptures.append(captured)
            } else {
                blackCaptures.append(captured)
            }
        }
    }

    func movePiece(_ piece: ChessPiece, to pos: (Int, Int)) {
        board.applyMove(piece: piece, to: pos)
    }

    func endTurn() {
        currentTurn = opposite(currentTurn)
        stopTimer()
        startTimer(for: currentTurn)

        let opponent = currentTurn

        if isKingInCheckmate(opponent, on: board) {
            alertMessage = "\(opponent == .white ? "White" : "Black") is checkmated! \(opposite(opponent) == .white ? "White" : "Black") wins!"
            showAlert = true
            stopTimer()
            return
        }
        if isStalemate(opponent, on: board) {
            alertMessage = "Stalemate! It's a draw!"
            showAlert = true
            stopTimer()
            return
        }
        if isKingInCheck(opponent, on: board) {
            alertMessage = "\(opponent == .white ? "White" : "Black") is in check!"
            showAlert = true
        }

        if gameMode == .vsAI && currentTurn == aiPlaysAs {
            DispatchQueue.global(qos: .userInitiated).async {
                makeAIMove()
                DispatchQueue.main.async {
                    endTurn()
                }
            }
        }
    }

    // MARK: - AI

    func makeAIMove() {
        let aiColor = aiPlaysAs
        let table = TranspositionTable()
        let allMoves = board.pieces.filter { $0.color == aiColor }
            .flatMap { p in calculateValidMoves(for: p, on: board).map { (p, $0) } }

        let ordered = allMoves.sorted {
            moveScore(piece: $0.0, target: $0.1) > moveScore(piece: $1.0, target: $1.1)
        }

        var bestScore = Int.min
        var alpha = Int.min
        var beta = Int.max
        var bestMove: (ChessPiece, (Int, Int))?

        for (piece, dest) in ordered {
            let test = board.deepCopy()
            if let tp = test.piece(at: piece.position) {
                test.applyMove(piece: tp, to: dest)
                if !isKingInCheck(aiColor, on: test) {
                    let score = minimax(board: test, depth: difficulty.depth, maximizing: false, color: aiColor, alpha: &alpha, beta: &beta, table: table)
                    if score > bestScore {
                        bestScore = score
                        bestMove = (piece, dest)
                        alpha = max(alpha, score)
                    }
                }
            }
        }

        if let (p, d) = bestMove {
            DispatchQueue.main.async {
                moveHistory.append(board.deepCopy())
                captureIfNeeded(at: d)
                movePiece(p, to: d)
            }
        }
    }

    func minimax(board: ChessBoard, depth: Int, maximizing: Bool,
                 color: PieceColor, alpha: inout Int, beta: inout Int, table: TranspositionTable
    ) -> Int {
        let h = Zobrist.hash(board: board)
        if let c = table.get(h) { return c }
        if depth == 0 {
            let eval = evaluate(board: board, for: color)
            table.set(h, eval)
            return eval
        }

        var best = maximizing ? Int.min : Int.max
        let moves = board.pieces
            .filter { $0.color == (maximizing ? color : opposite(color)) }
            .flatMap { p in calculateValidMoves(for: p, on: board).map { (p, $0) } }

        for (p, m) in moves {
            let copy = board.deepCopy()
            if let cp = copy.piece(at: p.position) {
                copy.applyMove(piece: cp, to: m)
                if !isKingInCheck(maximizing ? color : opposite(color), on: copy) {
                    let score = minimax(board: copy, depth: depth - 1, maximizing: !maximizing, color: color, alpha: &alpha, beta: &beta, table: table)
                    if maximizing {
                        best = max(best, score)
                        alpha = max(alpha, best)
                    } else {
                        best = min(best, score)
                        beta = min(beta, best)
                    }
                    if beta <= alpha { break }
                }
            }
        }

        table.set(h, best)
        return best
    }

    func moveScore(piece: ChessPiece, target: (Int, Int)) -> Int {
        if let cap = board.piece(at: target), cap.color != piece.color {
            return [.pawn: 100, .knight: 300, .bishop: 300, .rook: 500, .queen: 900][cap.type] ?? 0
        }
        return 0
    }

    func opposite(_ c: PieceColor) -> PieceColor { c == .white ? .black : .white }

    // MARK: - Timer Management
    
    func startTimer(for color: PieceColor) {
        stopTimer()
        activeTimerColor = color
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if color == .white {
                whiteTimeRemaining -= 1
                if whiteTimeRemaining <= 0 {
                    alertMessage = "White ran out of time! Black wins!"
                    showAlert = true
                    stopTimer()
                }
            } else {
                blackTimeRemaining -= 1
                if blackTimeRemaining <= 0 {
                    alertMessage = "Black ran out of time! White wins!"
                    showAlert = true
                    stopTimer()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        activeTimerColor = nil
    }

    func timeString(from seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func undoLastMove() {
        guard !moveHistory.isEmpty else { return }
        board.pieces = moveHistory.removeLast().pieces
        currentTurn = opposite(currentTurn)
        stopTimer()
        startTimer(for: currentTurn)
    }

    func resetGame() {
        board.resetBoard()
        currentTurn = .white
        moveHistory = []
        whiteCaptures = []
        blackCaptures = []
        whiteTimeRemaining = 5 * 60
        blackTimeRemaining = 5 * 60
        selectedPiece = nil
        validMoves = []
        stopTimer()
        startTimer(for: .white)
    }
}