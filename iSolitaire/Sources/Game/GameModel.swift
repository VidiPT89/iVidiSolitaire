import CoreGraphics
import Foundation
import SwiftUI

/// What the Hint button is pointing at.
struct Hint: Equatable {
    var cardIDs: Set<UUID> = []
    var destination: PileKind?
    var stock = false
}

struct WinResult: Equatable {
    let score: Int
    let seconds: Int
    let moves: Int
    let isBestTime: Bool
    let isBestScore: Bool
}

/// The game clock lives apart from `state`, so its once-a-second tick only redraws the time
/// label (not all 52 cards), and undoing a move never winds the clock back.
@MainActor
final class GameClock: ObservableObject {
    @Published var seconds = 0
}

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var state: GameState {
        didSet { GameStateStore.saveState(state) }
    }
    @Published var settings: GameSettings {
        didSet {
            GameStateStore.saveSettings(settings)
            evaluate()
        }
    }
    @Published private(set) var hint: Hint?
    @Published private(set) var autoCompleteAvailable = false
    @Published private(set) var isAutoCompleting = false
    @Published private(set) var isStuck = false
    @Published private(set) var winResult: WinResult?
    @Published private(set) var flights: [UUID: CardFlight] = [:]
    /// Bumped per card when a tap can't go anywhere, so just that card shakes.
    @Published private(set) var shakeCounts: [UUID: Int] = [:]

    let clock = GameClock()

    private var undoStack: [GameState] = []
    private var timer: Timer?
    private var isPaused = false
    private var winRecorded = false
    private var flightToken = 0
    private var hintTask: Task<Void, Never>?
    private let statsStore = StatsStore()
    private let haptics = HapticsPlayer()
    private let sounds = SoundPlayer()

    init(settings: GameSettings? = nil, startFresh: Bool = false) {
        self.settings = settings ?? GameStateStore.loadSettings() ?? GameSettings()
        let saved = GameStateStore.loadState().flatMap { $0.isWon ? nil : $0 }
        if !startFresh, let saved {
            self.state = saved
            undoStack = GameStateStore.loadHistory(for: saved)
            clock.seconds = saved.elapsedSeconds
            evaluate()
            if saved.moves > 0 { startTimer() }
        } else {
            self.state = saved ?? GameState()
            newGame()
        }
    }

    var canUndo: Bool { !undoStack.isEmpty && !isAutoCompleting }

    func isFlying(_ cardID: UUID) -> Bool { flights[cardID] != nil }

    // MARK: - Setup

    func newGame() {
        recordAbandonIfInProgress()
        stopTimer()
        undoStack.removeAll()
        winResult = nil
        winRecorded = false
        isAutoCompleting = false
        shakeCounts.removeAll()
        clock.seconds = 0
        commit(.newDeal(), sound: { $0.deal() })
    }

    // MARK: - Timer

    /// The clock starts with the first move, not the deal, so looking at a fresh board is free.
    private func startTimer() {
        guard timer == nil, !isPaused, !state.isWon else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clock.seconds += 1 }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Stops the clock and saves the time played, e.g. when the app goes to the background.
    func pause() {
        isPaused = true
        stopTimer()
        guard !state.isWon else { return }
        if state.elapsedSeconds != clock.seconds {
            state.elapsedSeconds = clock.seconds
        }
        GameStateStore.saveHistory(undoStack, for: state)
    }

    func resume() {
        isPaused = false
        if state.moves > 0 { startTimer() }
    }

    // MARK: - Applying changes

    /// Replaces the state in one go, so the card flights and the new board land in the same frame.
    private func commit(
        _ committed: GameState,
        startRects: [UUID: CGRect] = [:],
        stagger: Double = 0,
        recordUndo: Bool = false,
        sound: ((SoundPlayer) -> Void)? = nil
    ) {
        var newState = committed
        newState.elapsedSeconds = clock.seconds
        if recordUndo {
            undoStack.append(state)
            if undoStack.count > 300 { undoStack.removeFirst() }
        }
        let newFlights = CardFlight.diff(from: state, to: newState, startRects: startRects, stagger: stagger) {
            flightToken += 1
            return flightToken
        }
        state = newState
        launch(newFlights)
        sound?(sounds)
        clearHint()
        evaluate()
        if state.moves > 0 { startTimer() }
        checkWin()
    }

    private func launch(_ newFlights: [CardFlight]) {
        guard !newFlights.isEmpty else { return }
        for flight in newFlights { flights[flight.cardID] = flight }
        let longest = newFlights.map(\.delay).max() ?? 0
        let tokens = Set(newFlights.map(\.token))
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((longest + CardFlight.duration + 0.04) * 1_000_000_000))
            guard let self else { return }
            self.flights = self.flights.filter { !tokens.contains($0.value.token) }
        }
    }

    // MARK: - Undo

    func undo() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        winResult = nil
        commit(previous, sound: { $0.cardPlace() })
        haptics.light()
    }

    // MARK: - Stock

    func drawFromStock() {
        guard !isAutoCompleting else { return }
        var next = state
        guard next.draw(settings) else {
            haptics.invalid()
            return
        }
        let recycled = state.stock.isEmpty
        commit(next, stagger: recycled ? 0 : 0.06, recordUndo: true, sound: { recycled ? $0.shuffle() : $0.cardFlip() })
        haptics.light()
    }

    // MARK: - Moves

    func canMove(cardID: UUID, from source: PileKind, to destination: PileKind) -> Bool {
        state.canMove(cardID: cardID, from: source, to: destination)
    }

    /// Moves a card (or the run starting at it). `startRects` are where the dragged cards
    /// were released, so they fly from the finger to their slot instead of from their old pile.
    @discardableResult
    func tryMove(cardID: UUID, from source: PileKind, to destination: PileKind, startRects: [UUID: CGRect] = [:]) -> Bool {
        guard !isAutoCompleting else { return false }
        var next = state
        guard next.apply(Move(cardID: cardID, source: source, destination: destination)) else { return false }
        let toFoundation: Bool = { if case .foundation = destination { return true } else { return false } }()
        commit(next, startRects: startRects, recordUndo: true, sound: { toFoundation ? $0.foundation() : $0.cardPlace() })
        haptics.medium()
        return true
    }

    /// A single tap: send the card wherever it's most useful, or shake it if it can't go anywhere.
    func smartMove(cardID: UUID, from source: PileKind) {
        guard !isAutoCompleting else { return }
        if let destination = state.bestDestination(for: cardID, from: source) {
            tryMove(cardID: cardID, from: source, to: destination)
        } else {
            rejectTap(on: cardID)
        }
    }

    /// Sends cards that were dropped in an invalid spot back to their pile from the drop point.
    func flyBack(startRects: [UUID: CGRect]) {
        let backFlights: [CardFlight] = startRects.compactMap { cardID, rect in
            guard let location = state.location(of: cardID) else { return nil }
            let card = state.pile(location.pile)[location.index]
            let slot = PileSlot(pile: location.pile, index: location.index, in: state)
            flightToken += 1
            return CardFlight(token: flightToken, fromCard: card, toCard: card, from: slot, to: slot, fromRect: rect, delay: 0)
        }
        launch(backFlights)
        haptics.invalid()
    }

    private func rejectTap(on cardID: UUID) {
        shakeCounts[cardID, default: 0] += 1
        haptics.invalid()
    }

    // MARK: - Hint

    func requestHint() {
        guard !isAutoCompleting else { return }
        if let move = state.usefulMoves().first, let location = state.location(of: move.cardID) {
            let ids = state.pile(location.pile)[location.index...].map(\.id)
            hint = Hint(cardIDs: Set(ids), destination: move.destination)
        } else if !state.stock.isEmpty || state.canRecycle(settings) {
            hint = Hint(stock: true)
        } else {
            hint = nil
            haptics.invalid()
            return
        }
        haptics.light()
        hintTask?.cancel()
        hintTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.hint = nil }
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hint = nil
    }

    // MARK: - Auto-complete & stuck detection

    /// Only the banners animate when these flip; the rest of the board isn't caught in the animation.
    private func evaluate() {
        let available = !isAutoCompleting && state.autoCompletePlan(settings) != nil
        let stuck = !isAutoCompleting && state.isStuck(settings)
        guard available != autoCompleteAvailable || stuck != isStuck else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            autoCompleteAvailable = available
            isStuck = stuck
        }
    }

    func autoComplete() {
        guard !isAutoCompleting, let plan = state.autoCompletePlan(settings) else { return }
        undoStack.append(state)
        isAutoCompleting = true
        autoCompleteAvailable = false
        Task { @MainActor [weak self] in
            await self?.run(plan)
        }
    }

    /// Plays the finishing moves one at a time so the end reads as a cascade.
    private func run(_ plan: [AutoCompleteStep]) async {
        for step in plan {
            // Leaving the board or backgrounding the app stops the cascade; Finish stays available.
            guard isAutoCompleting, !isPaused else { break }
            var next = state
            switch step {
            case .move(let move):
                guard next.apply(move) else { break }
                commit(next, sound: { $0.foundation() })
                haptics.light()
                try? await Task.sleep(nanoseconds: 95_000_000)
            case .draw:
                guard next.draw(settings) else { break }
                commit(next, sound: { $0.cardFlip() })
                try? await Task.sleep(nanoseconds: 140_000_000)
            }
        }
        isAutoCompleting = false
        evaluate()
    }

    // MARK: - Win

    private func checkWin() {
        guard state.isWon, !winRecorded else { return }
        winRecorded = true
        stopTimer()
        isAutoCompleting = false
        let records = statsStore.recordWin(time: clock.seconds, score: state.score, moves: state.moves)
        haptics.won()
        sounds.win()
        GameStateStore.clearState()
        let result = WinResult(
            score: state.score,
            seconds: clock.seconds,
            moves: state.moves,
            isBestTime: records.isBestTime,
            isBestScore: records.isBestScore
        )
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { self?.winResult = result }
        }
    }

    private func recordAbandonIfInProgress() {
        guard state.moves > 0, !state.isWon else { return }
        statsStore.recordAbandon()
    }
}
