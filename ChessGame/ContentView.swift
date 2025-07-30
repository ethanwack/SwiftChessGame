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
            .overlay(captureHighlights(), alignment: .center)

            if showPromotionPicker, let t = promotionTarget {
                promotionPicker(for: t)
            }

            if gameMode == .vsAI {
                HStack(spacing: 50) {
                    Button("Undo") { undoLastMove() }
                        .disabled(moveHistory.isEmpty)
                    Button("Reset") { resetGame() }
                }
            }
        }
        .padding()
        .disabled(showPromotionPicker)
        .onAppear {
            loadGame()
            startTimer(for: currentTurn)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertMessage))
        }
    }

    // … UI helpers (clockView, squareView, promotionPicker, pieceSymbol, etc.) …

    // MARK: - Game logic

    func handleTap(row: Int, col: Int) { /* unchanged logic */ }
    func captureIfNeeded(at pos: (Int, Int)) { /* unchanged logic */ }
    func movePiece(_ p: ChessPiece, to pos: (Int, Int)) { /* unchanged */ }

    func endTurn() {
        currentTurn = opposite(currentTurn)
        stopTimer(); startTimer(for: currentTurn)
        saveGame()

        let opponent = opposite(currentTurn)

        if isKingInCheckmate(opponent, on: board) {
            alertMessage = "\(opponent.capitalized) is checkmated!"
            showAlert = true
            stopTimer()
            return
        }
        if isStalemate(opponent, on: board) {
            alertMessage = "Stalemate!"
            showAlert = true
            stopTimer()
            return
        }
        if isKingInCheck(opponent, on: board) {
            alertMessage = "\(opponent.capitalized) is in check!"
            showAlert = true
        }

        if gameMode == .vsAI && currentTurn == aiPlaysAs {
            DispatchQueue.global(qos: .userInitiated).async {
                makeAIMove()
                DispatchQueue.main.async {
                    moveHistory.append(board.deepCopy())
                    currentTurn = opposite(aiPlaysAs)
                    stopTimer(); startTimer(for: currentTurn); saveGame()
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
                let score = minimap(board: test, depth: difficulty.depth, maximizing: false, color: aiColor, alpha: &alpha, beta: &beta, table: table)
                if score > bestScore {
                    bestScore = score
                    bestMove = (piece, dest)
                    alpha = max(alpha, score)
                }
            }
        }

        if let (p, d) = bestMove {
            DispatchQueue.main.async {
                captureIfNeeded(at: d)
                movePiece(p, to: d)
            }
        }
    }

    func minimap(board: ChessBoard, depth: Int, maximizing: Bool,
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
                let score = minimap(board: copy, depth: depth - 1, maximizing: !maximizing, color: color, alpha: &alpha, beta: &beta, table: table)
                if maximizing {
                    best = max(best, score); alpha = max(alpha, best)
                } else {
                    best = min(best, score); beta = min(beta, best)
                }
                if beta <= alpha { break }
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

    // MARK: - (Helper stubs implemented in ChessModels.swift)

    func calculateValidMoves(for piece: ChessPiece, on board: ChessBoard) -> [(Int, Int)] { /* ChessModels code */ }
    func evaluate(board: ChessBoard, for color: PieceColor) -> Int { /* ChessModels code */ }
    func isKingInCheck(_ c: PieceColor, on b: ChessBoard) -> Bool { /* ChessModels code */ }
    func isKingInCheckmate(_ c: PieceColor, on b: ChessBoard) -> Bool { /* ChessModels code */ }
    func isStalemate(_ c: PieceColor, on b: ChessBoard) -> Bool { /* ChessModels code */ }
    func opposite(_ c: PieceColor) -> PieceColor { c == .white ? .black : .white }

    // MARK: – Timer, Save/Load, Undo, Reset
    func startTimer(for color: PieceColor) { /* existing code */ }
    func stopTimer() { /* existing code */ }
    func timeString(from seconds: TimeInterval) -> String { /* existing code */ }
    func saveGame() { /* existing code */ }
    func loadGame() { /* existing code */ }
    func undoLastMove() { /* existing code */ }
    func resetGame() { /* existing code */ }
}
