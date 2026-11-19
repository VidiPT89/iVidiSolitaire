import CoreGraphics
import Foundation
import SwiftUI

/// What the Hint button is pointing at.
struct Hint: Equatable {
    var cardIDs: Set<UUID> = []
    var destination: PileKind?
    var stock = false
}

/// A comment shown above the toolbar: the coach's view of the last move, or why the hint points where it does.
struct CoachTip: Equatable, Identifiable {
    enum Kind: Equatable {
        case verdict(CoachVerdict)
        case hint(HintReason)
    }
    let id: Int
    let kind: Kind
}

/// How the player is doing on an Academy exercise.
enum PracticeFeedback: Equatable {
    case correct(LocalizedText)
    case wrong(LocalizedText)
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
        didSet { if exercise == nil { GameStateStore.saveState(state) } }
    }
    @Published var settings: GameSettings {
        didSet {
            if exercise == nil { GameStateStore.saveSettings(settings) }
            evaluate()
        }
    }
    @Published private(set) var coachTip: CoachTip?
    @Published private(set) var practiceFeedback: PracticeFeedback?
    @Published private(set) var practiceSolved = false
    @Published private(set) var hint: Hint?
    @Published private(set) var autoCompleteAvailable = false
    @Published private(set) var isAutoCompleting = false
    @Published private(set) var isStuck = false
    @Published private(set) var winResult: WinResult?
    @Published private(set) var flights: [UUID: CardFlight] = [:]
    /// Bumped per card when a tap can't go anywhere, so just that card shakes.
    @Published private(set) var shakeCounts: [UUID: Int] = [:]

    let clock = GameClock()
    /// Set when this model runs an Academy exercise: nothing is saved, timed or recorded.
    let exercise: Exercise?

    private var undoStack: [GameState] = []
    private var timer: Timer?
    private var isPaused = false
    private var winRecorded = false
    private var flightToken = 0
    private var hintTask: Task<Void, Never>?
    private var tipTask: Task<Void, Never>?
    private var tipCounter = 0
    private var practiceMistakes = 0
    private var practiceHintUsed = false
    private let statsStore = StatsStore()
    private let haptics = HapticsPlayer()
    private let sounds = SoundPlayer()

    init(settings: GameSettings? = nil, startFresh: Bool = false) {
        self.exercise = nil
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

    /// Starts an Academy exercise on its prepared position.
    init(exercise: Exercise) {
        self.exercise = exercise
        self.settings = GameSettings()
        self.state = exercise.makeState()
    }

    var canUndo: Bool { !undoStack.isEmpty && !isAutoCompleting }

    /// 3 stars without mistakes or help, 2 with one slip or the answer shown, 1 otherwise.
    var practiceStars: Int {
        if practiceMistakes == 0 && !practiceHintUsed { return 3 }
        return practiceMistakes <= 1 ? 2 : 1
    }

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
        guard exercise == nil, timer == nil, !isPaused, !state.isWon else { return }
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
        guard exercise == nil, !state.isWon else { return }
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
        guard canUndo, var previous = undoStack.popLast() else { return }
        winResult = nil
        previous.undosUsed = state.undosUsed + 1
        commit(previous, sound: { $0.cardPlace() })
        haptics.light()
    }

    // MARK: - Stock

    func drawFromStock() {
        guard !isAutoCompleting, !practiceSolved else { return }
        var next = state
        guard next.draw(settings) else {
            haptics.invalid()
            return
        }
        if let exercise, !exercise.answer.accepts(.draw) {
            practiceWrong(exercise.feedback(for: .draw))
            return
        }
        let before = state
        let recycled = state.stock.isEmpty
        commit(next, stagger: recycled ? 0 : 0.06, recordUndo: true, sound: { recycled ? $0.shuffle() : $0.cardFlip() })
        haptics.light()
        afterPlayerAction(.draw, on: before)
    }

    // MARK: - Moves

    func canMove(cardID: UUID, from source: PileKind, to destination: PileKind) -> Bool {
        state.canMove(cardID: cardID, from: source, to: destination)
    }

    /// Moves a card (or the run starting at it). `startRects` are where the dragged cards
    /// were released, so they fly from the finger to their slot instead of from their old pile.
    @discardableResult
    func tryMove(cardID: UUID, from source: PileKind, to destination: PileKind, startRects: [UUID: CGRect] = [:]) -> Bool {
        guard !isAutoCompleting, !practiceSolved else { return false }
        let move = Move(cardID: cardID, source: source, destination: destination)
        var next = state
        guard next.apply(move) else { return false }
        if let exercise, let attempt = exerciseAnswer(for: move), !exercise.answer.accepts(attempt) {
            practiceWrong(exercise.feedback(for: attempt))
            return false
        }
        let before = state
        commit(next, startRects: startRects, recordUndo: true, sound: { destination.isFoundation ? $0.foundation() : $0.cardPlace() })
        haptics.medium()
        afterPlayerAction(.move(move), on: before)
        return true
    }

    /// A single tap: send the card wherever it's most useful, or shake it if it can't go anywhere.
    func smartMove(cardID: UUID, from source: PileKind) {
        guard !isAutoCompleting, !practiceSolved else { return }
        if let destination = practiceDestination(for: cardID, from: source) ?? state.bestDestination(for: cardID, from: source),
           tryMove(cardID: cardID, from: source, to: destination) {
            return
        }
        rejectTap(on: cardID)
    }

    // MARK: - Coach & practice

    private func afterPlayerAction(_ action: PlayerAction, on before: GameState) {
        if let exercise {
            practiceSolved = true
            practiceFeedback = .correct(exercise.explanation)
            haptics.won()
            return
        }
        guard AppPreferences.coachEnabled, let verdict = before.coachVerdict(for: action) else { return }
        showTip(.verdict(verdict))
    }

    private func showTip(_ kind: CoachTip.Kind) {
        tipCounter += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { coachTip = CoachTip(id: tipCounter, kind: kind) }
        tipTask?.cancel()
        tipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.coachTip = nil }
        }
    }

    func dismissTip() {
        tipTask?.cancel()
        withAnimation { coachTip = nil }
    }

    private func practiceWrong(_ text: LocalizedText) {
        practiceMistakes += 1
        practiceFeedback = .wrong(text)
        haptics.invalid()
    }

    /// The exercise's view of a move: which card went where.
    private func exerciseAnswer(for move: Move) -> ExerciseAnswer? {
        guard let location = state.location(of: move.cardID) else { return nil }
        let code = state.pile(location.pile)[location.index].code
        switch move.destination {
        case .foundation: return .move(card: code, to: .foundation)
        case .tableau(let column): return .move(card: code, to: .column(column))
        case .stock, .waste: return nil
        }
    }

    /// In an exercise, a tap on the answer card sends it to the answer's pile.
    private func practiceDestination(for cardID: UUID, from source: PileKind) -> PileKind? {
        guard let exercise, case .move(let code, let target) = exercise.answer,
              let location = state.location(of: cardID) else { return nil }
        let card = state.pile(location.pile)[location.index]
        guard card.code == code else { return nil }
        switch target {
        case .foundation: return .foundation(card.suit)
        case .column(let column): return .tableau(column)
        case .anyColumn:
            return state.tableau.indices.map { PileKind.tableau($0) }.first { state.canMove(cardID: cardID, from: source, to: $0) }
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
        guard !isAutoCompleting, !practiceSolved else { return }
        if let exercise {
            practiceHintUsed = true
            showPracticeAnswer(exercise)
        } else if let move = state.usefulMoves().first, let location = state.location(of: move.cardID) {
            let ids = state.pile(location.pile)[location.index...].map(\.id)
            hint = Hint(cardIDs: Set(ids), destination: move.destination)
            showTip(.hint(state.hintReason(for: move)))
        } else if !state.stock.isEmpty || state.canRecycle(settings) {
            hint = Hint(stock: true)
            showTip(.hint(.drawStock))
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

    private func showPracticeAnswer(_ exercise: Exercise) {
        switch exercise.answer {
        case .draw:
            hint = Hint(stock: true)
        case .move(let code, _):
            guard let card = (state.tableau.flatMap { $0 } + state.waste).first(where: { $0.code == code }),
                  let location = state.location(of: card.id) else { return }
            let destination = practiceDestination(for: card.id, from: location.pile)
            let ids = state.pile(location.pile)[location.index...].map(\.id)
            hint = Hint(cardIDs: Set(ids), destination: destination)
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hint = nil
    }

    // MARK: - Auto-complete & stuck detection

    /// Only the banners animate when these flip; the rest of the board isn't caught in the animation.
    private func evaluate() {
        guard exercise == nil else { return }
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
        guard exercise == nil, state.isWon, !winRecorded else { return }
        winRecorded = true
        stopTimer()
        isAutoCompleting = false
        let records = statsStore.recordWin(time: clock.seconds, score: state.score, moves: state.moves)
        GameCenter.shared.reportWin(
            score: state.score,
            seconds: clock.seconds,
            drawThree: settings.drawMode == .drawThree,
            usedUndo: state.undosUsed > 0,
            stats: statsStore.load()
        )
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
