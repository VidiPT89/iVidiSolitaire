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
}

enum L10n {
    private static let strings: [AppLanguage: [L10nKey: String]] = [
        .portuguese: [
            .appName: "iSolitaire",
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
            .controlsFooter: "Toca numa carta para a jogar no melhor sítio, ou arrasta-a. O modo canhoto troca o baralho e as fundações de lado.",
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
        ],
        .english: [
            .appName: "iSolitaire",
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
            .controlsFooter: "Tap a card to play it to the best spot, or drag it. Left-handed mode swaps the stock and foundations.",
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
