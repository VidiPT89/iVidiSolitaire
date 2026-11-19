import SwiftUI

enum L10nKey: String {
    case appName
    case newGame
    case continueGame
    case undo
    case hint
    case autoComplete
    case settings
    case stats
    case score
    case moves
    case time
    case drawMode
    case drawOne
    case drawThree
    case recycles
    case unlimited
    case limited
    case recycleLimit
    case appearance
    case systemMode
    case lightMode
    case darkMode
    case language
    case gamesPlayed
    case gamesWon
    case bestTime
    case averageTime
    case winStreak
    case bestStreak
    case bestScore
    case fewestMoves
    case youWon
    case playAgain
    case backToMenu
    case close
    case cancel
    case developedBy
    case website
    case github
    case winRate
    case autoCompleteSuggestion
    case noMovesMessage
    case faceDownCard
    case game
    case table
    case cardBack
    case controls
    case leftHanded
    case controlsFooter
    case soundEffects
    case haptics
    case about
    case resetStats
    case resetStatsConfirm
    case newGameConfirm
    case newGameConfirmMessage
    case newBestTime
    case newBestScore
    case themeEmber
    case themeFelt
    case themeOcean
    case themeWine
    case stock
    case academy
    case academySubtitle
    case lessonsDone
    case exerciseOf
    case start
    case practiceAgain
    case next
    case finish
    case showAnswer
    case lessonComplete
    case lessonCompleteMessage
    case keyIdea
    case coach
    case gameCenter
    case leaderboards
    case backToAcademy
    case tryAgainHint
    case yourTurn
    case privacyPolicy
}

enum L10n {
    private static let strings: [AppLanguage: [L10nKey: String]] = [
        .portuguese: [
            .appName: "iVidiSolitaire",
            .newGame: "Novo Jogo",
            .continueGame: "Continuar",
            .undo: "Anular",
            .hint: "Dica",
            .autoComplete: "Terminar",
            .settings: "Definições",
            .stats: "Estatísticas",
            .score: "Pontos",
            .moves: "Jogadas",
            .time: "Tempo",
            .drawMode: "Modo de Compra",
            .drawOne: "Virar 1 Carta",
            .drawThree: "Virar 3 Cartas",
            .recycles: "Voltas ao Baralho",
            .unlimited: "Ilimitadas",
            .limited: "Limitadas",
            .recycleLimit: "Máximo de voltas",
            .appearance: "Aparência",
            .systemMode: "Sistema",
            .lightMode: "Claro",
            .darkMode: "Escuro",
            .language: "Idioma",
            .gamesPlayed: "Jogos",
            .gamesWon: "Vitórias",
            .bestTime: "Melhor Tempo",
            .averageTime: "Tempo Médio",
            .winStreak: "Sequência Atual",
            .bestStreak: "Melhor Sequência",
            .bestScore: "Melhor Pontuação",
            .fewestMoves: "Menos Jogadas",
            .youWon: "Ganhaste!",
            .playAgain: "Jogar Novamente",
            .backToMenu: "Menu",
            .close: "Fechar",
            .cancel: "Cancelar",
            .developedBy: "Criado por David Arsénio Martins",
            .website: "ividi.dev",
            .github: "github.com/VidiPT89",
            .winRate: "Taxa de Vitórias",
            .autoCompleteSuggestion: "O jogo está resolvido!",
            .noMovesMessage: "Não há mais jogadas possíveis.",
            .faceDownCard: "Carta virada para baixo",
            .game: "Jogo",
            .table: "Mesa",
            .cardBack: "Verso das Cartas",
            .controls: "Controlos",
            .leftHanded: "Modo canhoto",
            .controlsFooter: "Toca numa carta para a jogar no melhor sítio, ou arrasta-a. O treinador comenta as tuas jogadas e explica as dicas. O modo canhoto troca o baralho e as fundações de lado.",
            .soundEffects: "Efeitos sonoros",
            .haptics: "Vibração",
            .about: "Sobre",
            .resetStats: "Repor Estatísticas",
            .resetStatsConfirm: "Apagar todas as estatísticas? Isto não pode ser anulado.",
            .newGameConfirm: "Começar um jogo novo?",
            .newGameConfirmMessage: "O jogo atual conta como desistência.",
            .newBestTime: "Novo recorde de tempo!",
            .newBestScore: "Novo recorde de pontos!",
            .themeEmber: "Brasa",
            .themeFelt: "Feltro",
            .themeOcean: "Oceano",
            .themeWine: "Vinho",
            .stock: "Baralho",
            .academy: "Academia",
            .academySubtitle: "Aprende a ganhar mais jogos",
            .lessonsDone: "%d de %d lições",
            .exerciseOf: "Exercício %d de %d",
            .start: "Começar",
            .practiceAgain: "Praticar outra vez",
            .next: "Seguinte",
            .finish: "Terminar",
            .showAnswer: "Mostrar",
            .lessonComplete: "Lição concluída!",
            .lessonCompleteMessage: "Agora experimenta numa partida a sério: o treinador avisa-te quando há uma jogada melhor.",
            .keyIdea: "A ideia",
            .coach: "Treinador na mesa",
            .gameCenter: "Game Center",
            .leaderboards: "Classificações do Game Center",
            .backToAcademy: "Academia",
            .tryAgainHint: "Tenta outra vez.",
            .yourTurn: "Faz a jogada no tabuleiro.",
            .privacyPolicy: "Política de privacidade",
        ],
        .english: [
            .appName: "iVidiSolitaire",
            .newGame: "New Game",
            .continueGame: "Continue",
            .undo: "Undo",
            .hint: "Hint",
            .autoComplete: "Finish",
            .settings: "Settings",
            .stats: "Statistics",
            .score: "Score",
            .moves: "Moves",
            .time: "Time",
            .drawMode: "Draw Mode",
            .drawOne: "Draw 1 Card",
            .drawThree: "Draw 3 Cards",
            .recycles: "Passes Through the Deck",
            .unlimited: "Unlimited",
            .limited: "Limited",
            .recycleLimit: "Maximum passes",
            .appearance: "Appearance",
            .systemMode: "System",
            .lightMode: "Light",
            .darkMode: "Dark",
            .language: "Language",
            .gamesPlayed: "Games",
            .gamesWon: "Wins",
            .bestTime: "Best Time",
            .averageTime: "Average Time",
            .winStreak: "Current Streak",
            .bestStreak: "Best Streak",
            .bestScore: "Best Score",
            .fewestMoves: "Fewest Moves",
            .youWon: "You Won!",
            .playAgain: "Play Again",
            .backToMenu: "Menu",
            .close: "Close",
            .cancel: "Cancel",
            .developedBy: "Developed by David Arsénio Martins",
            .website: "ividi.dev",
            .github: "github.com/VidiPT89",
            .winRate: "Win Rate",
            .autoCompleteSuggestion: "The game is solved!",
            .noMovesMessage: "There are no moves left.",
            .faceDownCard: "Face-down card",
            .game: "Game",
            .table: "Table",
            .cardBack: "Card Back",
            .controls: "Controls",
            .leftHanded: "Left-handed mode",
            .controlsFooter: "Tap a card to play it to the best spot, or drag it. The coach comments on your moves and explains hints. Left-handed mode swaps the stock and foundations.",
            .soundEffects: "Sound effects",
            .haptics: "Haptics",
            .about: "About",
            .resetStats: "Reset Statistics",
            .resetStatsConfirm: "Delete all statistics? This can't be undone.",
            .newGameConfirm: "Start a new game?",
            .newGameConfirmMessage: "The current game will count as a loss.",
            .newBestTime: "New best time!",
            .newBestScore: "New high score!",
            .themeEmber: "Ember",
            .themeFelt: "Felt",
            .themeOcean: "Ocean",
            .themeWine: "Wine",
            .stock: "Stock",
            .academy: "Academy",
            .academySubtitle: "Learn to win more games",
            .lessonsDone: "%d of %d lessons",
            .exerciseOf: "Exercise %d of %d",
            .start: "Start",
            .practiceAgain: "Practise Again",
            .next: "Next",
            .finish: "Finish",
            .showAnswer: "Show",
            .lessonComplete: "Lesson complete!",
            .lessonCompleteMessage: "Now try it in a real game: the coach tells you when there's a better move.",
            .keyIdea: "The idea",
            .coach: "Coach at the table",
            .gameCenter: "Game Center",
            .leaderboards: "Game Center Leaderboards",
            .backToAcademy: "Academy",
            .tryAgainHint: "Try again.",
            .yourTurn: "Make the move on the board.",
            .privacyPolicy: "Privacy policy",
        ],
    ]

    static func t(_ key: L10nKey, _ language: AppLanguage) -> String {
        strings[language]?[key] ?? strings[.english]?[key] ?? key.rawValue
    }

    static func cardName(_ card: Card, _ language: AppLanguage) -> String {
        switch language {
        case .portuguese:
            let ranks = ["Ás", "Dois", "Três", "Quatro", "Cinco", "Seis", "Sete", "Oito", "Nove", "Dez", "Valete", "Dama", "Rei"]
            let suits: [Suit: String] = [.hearts: "Copas", .diamonds: "Ouros", .clubs: "Paus", .spades: "Espadas"]
            return "\(ranks[card.rank.rawValue - 1]) de \(suits[card.suit]!)"
        case .english:
            let ranks = ["Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King"]
            let suits: [Suit: String] = [.hearts: "Hearts", .diamonds: "Diamonds", .clubs: "Clubs", .spades: "Spades"]
            return "\(ranks[card.rank.rawValue - 1]) of \(suits[card.suit]!)"
        }
    }

    static func themeName(_ theme: TableTheme, _ language: AppLanguage) -> String {
        switch theme {
        case .ember: return t(.themeEmber, language)
        case .felt: return t(.themeFelt, language)
        case .ocean: return t(.themeOcean, language)
        case .wine: return t(.themeWine, language)
        }
    }

    static func format(_ key: L10nKey, _ language: AppLanguage, _ args: CVarArg...) -> String {
        String(format: t(key, language), arguments: args)
    }

    static func coachText(_ kind: CoachTip.Kind, _ language: AppLanguage) -> String {
        let pt = language == .portuguese
        switch kind {
        case .verdict(let verdict):
            switch verdict {
            case .foundationTooSoon(let waiting):
                return pt ? "Cuidado: o \(waiting.shortName) só cabia nessa carta. Agora ficou sem sítio."
                          : "Careful: the \(waiting.shortName) could only go on that card. Now it has nowhere to go."
            case .emptiedWithoutKing:
                return pt ? "Esvaziaste uma coluna sem nenhum Rei à vista para a ocupar."
                          : "You emptied a column with no King in sight to fill it."
            case .missedTallerColumn(let card):
                return pt ? "Havia uma coluna com mais cartas escondidas: o \(card.shortName) abria essa."
                          : "Another column had more hidden cards: the \(card.shortName) would have opened it."
            case .missedReveal(let card):
                return pt ? "Havia uma jogada melhor: o \(card.shortName) revelava uma carta escondida."
                          : "There was a better move: the \(card.shortName) would have revealed a hidden card."
            case .drewWithMoves(let card):
                return pt ? "Antes de virar o monte, vê o tabuleiro: o \(card.shortName) tinha jogada."
                          : "Before turning the stock, check the board: the \(card.shortName) had a move."
            case .uncoveredFoundationCard:
                return pt ? "Bem visto! Destapaste uma carta para a fundação." : "Well spotted! You uncovered a card for the foundation."
            case .choseTallestColumn:
                return pt ? "Boa escolha: abriste a coluna com mais cartas escondidas." : "Good choice: you opened the column with the most hidden cards."
            }
        case .hint(let reason):
            switch reason {
            case .toFoundation(let card):
                return pt ? "Manda o \(card.shortName) para a fundação." : "Send the \(card.shortName) to the foundation."
            case .reveal(let card):
                return pt ? "Move o \(card.shortName) para revelar uma carta escondida." : "Move the \(card.shortName) to reveal a hidden card."
            case .fromWaste(let card):
                return pt ? "Usa o \(card.shortName) do monte." : "Use the \(card.shortName) from the waste."
            case .uncover(let card):
                return pt ? "Move o \(card.shortName) para destapar uma carta para a fundação." : "Move the \(card.shortName) to uncover a card for the foundation."
            case .freeColumn(let card):
                return pt ? "Move o \(card.shortName) para libertar uma coluna para um Rei." : "Move the \(card.shortName) to free a column for a King."
            case .drawStock:
                return pt ? "Não há jogadas no tabuleiro: vira o monte." : "No moves on the board: turn the stock."
            }
        }
    }

    static func time(_ seconds: Int) -> String {
        seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
