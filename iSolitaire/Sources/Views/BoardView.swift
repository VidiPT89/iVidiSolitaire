import SwiftUI

struct BoardView: View {
    @StateObject private var game: GameModel
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showStats = false
    @State private var confirmNewGame = false
    @State private var pileFrames: [PileKind: CGRect] = [:]
    @State private var tableauHeight: CGFloat = 320
    @State private var dragPreview: DragPreview?
    @State private var dropTarget: PileKind?

    init(startFresh: Bool = false) {
        _game = StateObject(wrappedValue: GameModel(startFresh: startFresh))
    }

    private var lang: AppLanguage { appSettings.language }
    private var theme: TableTheme { appSettings.tableTheme }
    private var textColor: Color { theme.textColor(systemScheme) }
    private var boardScheme: ColorScheme { theme.isLight(systemScheme) ? .light : .dark }

    private let horizontalPadding: CGFloat = 8
    private let columnSpacing: CGFloat = 5
    private let tapMoveThreshold: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.2
            let metrics = cardMetrics(for: geo.size, landscape: landscape)
            let layout = BoardLayout(
                metrics: metrics,
                tableauHeight: tableauHeight,
                drawThree: game.settings.drawMode == .drawThree,
                leftHanded: appSettings.leftHanded
            )

            ZStack {
                TableBackground(theme: theme, scheme: systemScheme).equatable()

                if landscape {
                    VStack(spacing: 6) {
                        header
                        HStack(alignment: .top, spacing: 12) {
                            if appSettings.leftHanded { verticalToolbar }
                            board(layout: layout)
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .bottom) { banner.padding(.bottom, 8) }
                            if !appSettings.leftHanded { verticalToolbar }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.top, 4)
                } else {
                    VStack(spacing: 12) {
                        header
                        board(layout: layout)
                        banner
                        toolbar
                    }
                    .padding(.top, 8)
                }

                FlightLayer(flights: Array(game.flights.values), layout: layout, frames: pileFrames)

                if let dragPreview {
                    DragPreviewOverlay(preview: dragPreview)
                }
            }
            .coordinateSpace(name: "board")
            .onPreferenceChange(PileFramePreferenceKey.self) { pileFrames = $0 }
            .environment(\.colorScheme, boardScheme)
            .environment(\.cardBackStyle, appSettings.cardBack)
            .environment(\.appLanguage, lang)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resume() } else { game.pause() }
        }
        .onDisappear { game.pause() }
        .onAppear { game.resume() }
        .sheet(isPresented: $showSettings) {
            SettingsView(gameSettings: $game.settings).environmentObject(appSettings)
        }
        .sheet(isPresented: $showStats) {
            StatsView().environmentObject(appSettings)
        }
        .confirmationDialog(L10n.t(.newGameConfirm, lang), isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button(L10n.t(.newGame, lang), role: .destructive) { game.newGame() }
            Button(L10n.t(.cancel, lang), role: .cancel) {}
        } message: {
            Text(L10n.t(.newGameConfirmMessage, lang))
        }
        .overlay {
            if let result = game.winResult {
                WinOverlay(result: result, onPlayAgain: { game.newGame() }, onMenu: { dismiss() })
                    .environmentObject(appSettings)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Sizing

    private func cardMetrics(for size: CGSize, landscape: Bool) -> CardMetrics {
        let toolbarWidth: CGFloat = landscape ? 84 : 0
        let byWidth = (size.width - toolbarWidth - horizontalPadding * 2 - columnSpacing * 6) / 7
        // Leave room for the header/toolbar and roughly two and a half cards of tableau below the top row.
        let byHeight = landscape
            ? (size.height - 70) / (CardMetrics.aspect * 3.3)
            : (size.height - 190) / (CardMetrics.aspect * 3.0)
        return CardMetrics(width: max(32, min(byWidth, byHeight, 124)))
    }

    // MARK: - Board

    private func board(layout: BoardLayout) -> some View {
        let context = PileContext(
            layout: layout,
            draggedIDs: Set(dragPreview?.cards.map(\.id) ?? []),
            dropTarget: dropTarget,
            textColor: textColor,
            cardGesture: { card, source in cardGesture(card: card, source: source, layout: layout) }
        )
        let boardWidth = layout.metrics.width * 7 + columnSpacing * 6

        return VStack(spacing: layout.metrics.width * 0.28) {
            HStack(alignment: .top, spacing: columnSpacing) {
                if appSettings.leftHanded {
                    foundations(context)
                    Spacer(minLength: 0)
                    WasteView(game: game, context: context)
                    StockView(game: game, context: context)
                } else {
                    StockView(game: game, context: context)
                    WasteView(game: game, context: context)
                    Spacer(minLength: 0)
                    foundations(context)
                }
            }
            .zIndex(1)

            HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(0..<7, id: \.self) { column in
                    TableauColumnView(game: game, column: column, context: context)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { tableauHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, height in tableauHeight = height }
                }
            )
        }
        .frame(width: boardWidth)
        .padding(.horizontal, horizontalPadding)
    }

    private func foundations(_ context: PileContext) -> some View {
        ForEach(Suit.allCases, id: \.self) { suit in
            FoundationView(game: game, suit: suit, context: context)
        }
    }

    // MARK: - Drag & tap

    private func cardGesture(card: Card, source: PileKind, layout: BoardLayout) -> AnyGesture<DragGesture.Value> {
        AnyGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { value in
                guard card.isFaceUp, !game.isAutoCompleting else { return }
                guard dragPreview != nil || hypot(value.translation.width, value.translation.height) > tapMoveThreshold else { return }
                if dragPreview == nil {
                    guard let run = game.state.run(startingAt: card.id, in: source),
                          let location = game.state.location(of: card.id),
                          let rect = layout.rect(for: PileSlot(pile: location.pile, index: location.index, in: game.state), frames: pileFrames)
                    else { return }
                    dragPreview = DragPreview(
                        cards: run,
                        source: source,
                        grabOffset: CGSize(width: rect.minX - value.startLocation.x, height: rect.minY - value.startLocation.y),
                        location: value.location,
                        metrics: layout.metrics
                    )
                } else {
                    dragPreview?.location = value.location
                }
                if let dragPreview {
                    dropTarget = bestDropTarget(for: dragPreview)
                }
            }
            .onEnded { value in
                defer {
                    dragPreview = nil
                    dropTarget = nil
                }
                guard card.isFaceUp else { return }
                guard let preview = dragPreview else {
                    if hypot(value.translation.width, value.translation.height) <= tapMoveThreshold {
                        game.smartMove(cardID: card.id, from: source)
                    }
                    return
                }
                let rects = preview.cardRects
                if let target = bestDropTarget(for: preview),
                   game.tryMove(cardID: preview.cards[0].id, from: preview.source, to: target, startRects: rects) {
                    return
                }
                game.flyBack(startRects: rects)
            })
    }

    /// The legal pile the dragged card overlaps most.
    private func bestDropTarget(for preview: DragPreview) -> PileKind? {
        let cardRect = preview.topCardRect
        var best: (kind: PileKind, area: CGFloat)?
        for (kind, frame) in pileFrames {
            switch kind {
            case .foundation, .tableau: break
            case .stock, .waste: continue
            }
            guard kind != preview.source,
                  game.canMove(cardID: preview.cards[0].id, from: preview.source, to: kind) else { continue }
            let overlap = frame.intersection(cardRect)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > (best?.area ?? 0) { best = (kind, area) }
        }
        return best?.kind
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 10) {
            circleButton("chevron.left", label: L10n.t(.backToMenu, lang)) { dismiss() }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                HUDItem(icon: "star.fill", value: "\(game.state.score)", label: L10n.t(.score, lang))
                ClockHUDItem(clock: game.clock, label: L10n.t(.time, lang))
                HUDItem(icon: "hand.draw.fill", value: "\(game.state.moves)", label: L10n.t(.moves, lang))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .layoutPriority(1)
            Spacer(minLength: 0)
            circleButton("chart.bar.fill", label: L10n.t(.stats, lang)) { showStats = true }
            circleButton("gearshape.fill", label: L10n.t(.settings, lang)) { showSettings = true }
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 12)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var banner: some View {
        if game.autoCompleteAvailable {
            suggestionBanner(
                icon: "wand.and.stars",
                text: L10n.t(.autoCompleteSuggestion, lang),
                actionTitle: L10n.t(.autoComplete, lang),
                tint: AnyShapeStyle(Theme.accentGradient)
            ) { game.autoComplete() }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if game.isStuck {
            suggestionBanner(
                icon: "exclamationmark.triangle.fill",
                text: L10n.t(.noMovesMessage, lang),
                actionTitle: L10n.t(.newGame, lang),
                tint: AnyShapeStyle(Color(red: 0.75, green: 0.18, blue: 0.15))
            ) { game.newGame() }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var toolbarItems: [(icon: String, title: String, disabled: Bool, highlighted: Bool, action: () -> Void)] {
        [
            ("arrow.uturn.backward", L10n.t(.undo, lang), !game.canUndo, false, { game.undo() }),
            ("lightbulb.fill", L10n.t(.hint, lang), game.isAutoCompleting, false, { game.requestHint() }),
            ("wand.and.stars", L10n.t(.autoComplete, lang), !game.autoCompleteAvailable, game.autoCompleteAvailable, { game.autoComplete() }),
            ("plus.rectangle.on.rectangle", L10n.t(.newGame, lang), game.isAutoCompleting, false, { requestNewGame() }),
        ]
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(Array(toolbarItems.enumerated()), id: \.offset) { _, item in
                toolbarButton(item.icon, item.title, disabled: item.disabled, highlighted: item.highlighted, action: item.action)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var verticalToolbar: some View {
        VStack(spacing: 14) {
            ForEach(Array(toolbarItems.enumerated()), id: \.offset) { _, item in
                toolbarButton(item.icon, item.title, disabled: item.disabled, highlighted: item.highlighted, action: item.action)
            }
        }
        .frame(width: 76)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func toolbarButton(_ icon: String, _ title: String, disabled: Bool, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolEffect(.pulse, isActive: highlighted)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(highlighted ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(textColor.opacity(disabled ? 0.3 : 1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func suggestionBanner(icon: String, text: String, actionTitle: String, tint: AnyShapeStyle, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text).font(.footnote.weight(.semibold))
            Spacer(minLength: 4)
            Button(action: action) {
                Text(actionTitle)
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.22), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .frame(maxWidth: 520)
        .padding(.horizontal, 16)
    }

    private func requestNewGame() {
        if game.state.moves > 0 && !game.state.isWon {
            confirmNewGame = true
        } else {
            game.newGame()
        }
    }
}

private struct HUDItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Theme.accentGradient)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Observes only the clock, so the per-second tick redraws this label and nothing else.
private struct ClockHUDItem: View {
    @ObservedObject var clock: GameClock
    let label: String

    var body: some View {
        HUDItem(icon: "clock.fill", value: L10n.time(clock.seconds), label: label)
    }
}
