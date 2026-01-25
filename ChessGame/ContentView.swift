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
    @State private var gameMode: GameMode = .vsPlayer
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
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 8) {
                // Minimal top controls
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("White")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatTime(whiteTimeRemaining))
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(currentTurn == .white ? .white : .gray)
                    }
                    .padding(6)
                    .background(currentTurn == .white ? Color.black : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(6)
                    
                    Spacer()
                    
                    Text(currentTurn == .white ? "⚪" : "⚫")
                        .font(.title)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Black")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatTime(blackTimeRemaining))
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(currentTurn == .black ? .white : .gray)
                    }
                    .padding(6)
                    .background(currentTurn == .black ? Color.black : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
                // Game mode selector - compact
                HStack(spacing: 8) {
                    Picker("", selection: $gameMode) {
                        Text("PvP").tag(GameMode.vsPlayer)
                        Text("AI").tag(GameMode.vsAI)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 100)
                    
                    if gameMode == .vsAI {
                        Picker("", selection: $difficulty) {
                            Text("Easy").tag(AIDifficulty.easy)
                            Text("Med").tag(AIDifficulty.medium)
                            Text("Hard").tag(AIDifficulty.hard)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 120)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .font(.caption)
                
                // LARGE Chess board - responsive
                VStack(spacing: 0) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 8), spacing: 0) {
                        ForEach(0..<64, id: \.self) { idx in
                            let row = idx / 8
                            let col = idx % 8
                            squareView(row: row, col: col)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .border(Color.black, width: 3)
                }
                .padding(4)
                
                // Minimal captured pieces
                VStack(spacing: 4) {
                    if !whiteCaptures.isEmpty {
                        HStack(spacing: 2) {
                            Text("W:")
                                .font(.caption2)
                                .fontWeight(.bold)
                            ForEach(whiteCaptures, id: \.id) {
                                Text(pieceSymbol($0))
                                    .font(.system(size: 14))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                    }
                    
                    if !blackCaptures.isEmpty {
                        HStack(spacing: 2) {
                            Text("B:")
                                .font(.caption2)
                                .fontWeight(.bold)
                            ForEach(blackCaptures, id: \.id) {
                                Text(pieceSymbol($0))
                                    .font(.system(size: 14))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                    }
                }
                
                // Bottom controls - compact
                HStack(spacing: 8) {
                    Button(action: { undoLastMove() }) {
                        Text("Undo")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(moveHistory.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .disabled(moveHistory.isEmpty)
                    
                    Button(action: { resetGame() }) {
                        Text("Reset")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .padding(.vertical, 4)
            
            // Promotion picker overlay
            if showPromotionPicker, let t = promotionTarget {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Promote Pawn to:")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            ForEach([PieceType.queen, .rook, .bishop, .knight], id: \.self) { type in
                                Button(action: {
                                    if let index = board.pieces.firstIndex(where: { $0.id == t.id }) {
                                        board.pieces[index].type = type
                                    }
                                    showPromotionPicker = false
                                    promotionTarget = nil
                                    endTurn()
                                }) {
                                    VStack(spacing: 4) {
                                        Text(pieceSymbol(ChessPiece(type: type, color: t.color, position: (0,0))))
                                            .font(.system(size: 36))
                                        Text(type.rawValue.uppercased())
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .padding()
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.4))
                .ignoresSafeArea()
            }
        }
        .onAppear {
            startTimer(for: currentTurn)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Game Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
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
        
        // Traditional chess colors
        let lightColor = Color(red: 0.96, green: 0.94, blue: 0.87) // Beige
        let darkColor = Color(red: 0.54, green: 0.42, blue: 0.32)  // Brown
        
        return ZStack(alignment: .center) {
            // Square background
            Rectangle()
                .fill(isLight ? lightColor : darkColor)
            
            // Selection highlight
            if isSelected {
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
            }
            
            // Valid move indicator
            if isValidMove {
                Circle()
                    .fill(Color(red: 1, green: 0.84, blue: 0))  // Gold
                    .opacity(0.7)
                    .frame(width: 12, height: 12)
            }
            
            // Piece display
            if let p = piece {
                Text(pieceSymbol(p))
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
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