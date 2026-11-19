import Foundation

/// Text in both of the app's languages.
struct LocalizedText: Hashable {
    let pt: String
    let en: String

    func callAsFunction(_ language: AppLanguage) -> String {
        language == .portuguese ? pt : en
    }
}

enum ExerciseTarget: Hashable {
    case foundation
    case column(Int)
    /// Any tableau column the card can legally go to.
    case anyColumn
}

/// What the player did, or what an exercise expects: move a card (by its code, e.g. "8S") or draw.
enum ExerciseAnswer: Hashable {
    case move(card: String, to: ExerciseTarget)
    case draw

    func accepts(_ attempt: ExerciseAnswer) -> Bool {
        switch (self, attempt) {
        case (.draw, .draw):
            return true
        case let (.move(card, target), .move(attemptCard, attemptTarget)):
            guard card == attemptCard else { return false }
            if target == .anyColumn, case .column = attemptTarget { return true }
            return target == attemptTarget
        default:
            return false
        }
    }
}

/// A real Klondike position with one best move and an explanation for the tempting wrong ones.
struct Exercise: Identifiable {
    let id: String
    /// Seven columns, cards separated by spaces, "-" marks a face-down card ("-7C -QD AH").
    let tableau: [String]
    var waste = ""
    var stock = ""
    /// Highest card already on each foundation.
    var foundations: [Suit: Rank] = [:]
    let answer: ExerciseAnswer
    let prompt: LocalizedText
    let explanation: LocalizedText
    var mistakes: [ExerciseAnswer: LocalizedText] = [:]

    func makeState() -> GameState {
        var state = GameState()
        state.tableau = tableau.map { Self.parse($0) }
        state.waste = Self.parse(waste).map { var c = $0; c.isFaceUp = true; return c }
        state.stock = Self.parse(stock).map { var c = $0; c.isFaceUp = false; return c }
        for suit in Suit.allCases {
            let top = foundations[suit]?.rawValue ?? 0
            state.foundations[suit] = Rank.allCases.filter { $0.rawValue <= top }.map { Card(suit: suit, rank: $0, isFaceUp: true) }
        }
        return state
    }

    static func parse(_ text: String) -> [Card] {
        text.split(separator: " ").compactMap { token in
            let faceDown = token.hasPrefix("-")
            guard let card = Card(code: String(faceDown ? token.dropFirst() : token[...])) else { return nil }
            var result = card
            result.isFaceUp = !faceDown
            return result
        }
    }

    /// Feedback for a legal move that isn't the answer.
    func feedback(for attempt: ExerciseAnswer) -> LocalizedText {
        mistakes.first { $0.key.accepts(attempt) }?.value ?? LocalizedText(
            pt: "É uma jogada válida, mas há uma melhor. Pensa no que diz a lição.",
            en: "That's a legal move, but there's a better one. Think about what the lesson says."
        )
    }
}

struct Lesson: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedText
    let summary: LocalizedText
    let intro: LocalizedText
    let exercises: [Exercise]
}

extension Card {
    /// Two-character code: rank (A, 2–9, T, J, Q, K) then suit (S, H, D, C).
    init?(code: String) {
        guard code.count == 2, let rankChar = code.first, let suitChar = code.last else { return nil }
        let ranks: [Character: Rank] = ["A": .ace, "T": .ten, "J": .jack, "Q": .queen, "K": .king]
        let rank = ranks[rankChar] ?? rankChar.wholeNumberValue.flatMap(Rank.init(rawValue:))
        let suits: [Character: Suit] = ["S": .spades, "H": .hearts, "D": .diamonds, "C": .clubs]
        guard let rank, let suit = suits[suitChar] else { return nil }
        self.init(suit: suit, rank: rank)
    }

    var code: String {
        let rank = rank == .ten ? "T" : rank.label
        let suit: String = switch suit {
        case .spades: "S"
        case .hearts: "H"
        case .diamonds: "D"
        case .clubs: "C"
        }
        return rank + suit
    }

    /// Short name for tips, e.g. "8♠".
    var shortName: String {
        let symbol: String = switch suit {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
        return rank.label + symbol
    }
}

// MARK: - Lessons

enum Academy {
    static func lesson(id: String) -> Lesson? { lessons.first { $0.id == id } }

    static let lessons: [Lesson] = [
        Lesson(
            id: "aces",
            icon: "arrow.up.circle.fill",
            title: LocalizedText(pt: "Ases e Dois primeiro", en: "Aces and Twos First"),
            summary: LocalizedText(pt: "Nunca bloqueiam nada: sobem logo.", en: "They never block anything: send them up."),
            intro: LocalizedText(
                pt: "Um Ás ou um Dois não serve de apoio a nenhuma carta no tabuleiro, por isso não há razão para os guardar. Manda-os para a fundação assim que aparecem: libertam espaço e muitas vezes destapam uma carta escondida.",
                en: "An Ace or a Two can't hold any other card on the tableau, so there's no reason to keep them there. Send them to the foundation as soon as they show up: they free space and often uncover a hidden card."
            ),
            exercises: [
                Exercise(
                    id: "aces.1",
                    tableau: ["-7C -QD AH", "-4S 6D 5S", "-9C JS", "-2D 6H", "-KC -3H 9S", "-8S TS", "-5D -JC 4C"],
                    answer: .move(card: "AH", to: .foundation),
                    prompt: LocalizedText(pt: "Qual é a melhor jogada?", en: "What's the best move?"),
                    explanation: LocalizedText(
                        pt: "O Ás vai para a fundação e vira a carta que estava por baixo. Nunca te arrependes de subir um Ás.",
                        en: "The Ace goes to the foundation and turns over the card beneath it. You never regret playing an Ace."
                    ),
                    mistakes: [
                        .move(card: "5S", to: .anyColumn): LocalizedText(
                            pt: "Mudar o 5♠ de coluna não revela nada. O Ás, pelo contrário, sobe e vira uma carta.",
                            en: "Moving the 5♠ across reveals nothing. The Ace, on the other hand, goes up and turns a card."
                        ),
                    ]
                ),
                Exercise(
                    id: "aces.2",
                    tableau: ["-6C 3D", "-9H QS", "-4H -8C TC", "-JD 7S", "KC", "-5S -2C 9C", "-TH -6S 8S"],
                    waste: "4D 2S",
                    foundations: [.spades: .ace],
                    answer: .move(card: "2S", to: .foundation),
                    prompt: LocalizedText(pt: "O 2♠ do monte: para onde?", en: "The 2♠ from the waste: where to?"),
                    explanation: LocalizedText(
                        pt: "Na fundação o 2♠ nunca atrapalha, e o 4♦ por baixo fica disponível.",
                        en: "On the foundation the 2♠ never gets in the way, and the 4♦ beneath becomes available."
                    ),
                    mistakes: [
                        .move(card: "2S", to: .anyColumn): LocalizedText(
                            pt: "Em cima do 3♦ o 2♠ só ia tapar uma carta. Na fundação não bloqueia nada.",
                            en: "On the 3♦ the 2♠ would only cover a card. On the foundation it blocks nothing."
                        ),
                    ]
                ),
            ]
        ),
        Lesson(
            id: "reveal",
            icon: "eye.fill",
            title: LocalizedText(pt: "Revelar cartas escondidas", en: "Reveal Hidden Cards"),
            summary: LocalizedText(pt: "As cartas viradas para baixo são o inimigo.", en: "Face-down cards are the enemy."),
            intro: LocalizedText(
                pt: "O que te impede de ganhar são as cartas viradas para baixo. Quando tens várias jogadas, prefere a que vira uma carta escondida. As cartas do monte continuam lá: podem esperar.",
                en: "What stops you from winning are the face-down cards. When you have several moves, prefer the one that turns a hidden card. The waste cards will still be there: they can wait."
            ),
            exercises: [
                Exercise(
                    id: "reveal.1",
                    tableau: ["-3C TS", "-QH 5C", "-6D -KH 9H", "-2S JC", "-7H 4S", "TC", "-8D -AS -5H QC"],
                    waste: "9D",
                    answer: .move(card: "9H", to: .anyColumn),
                    prompt: LocalizedText(pt: "Há dois noves vermelhos. Qual deves jogar?", en: "There are two red nines. Which one should you play?"),
                    explanation: LocalizedText(
                        pt: "O 9♥ estava em cima de duas cartas escondidas: ao movê-lo, viras uma delas. O 9♦ do monte pode esperar.",
                        en: "The 9♥ was sitting on two hidden cards: moving it turns one of them. The 9♦ in the waste can wait."
                    ),
                    mistakes: [
                        .move(card: "9D", to: .anyColumn): LocalizedText(
                            pt: "É válida, mas não revela nada. Joga primeiro o 9♥, que vira uma carta escondida.",
                            en: "It's legal, but it reveals nothing. Play the 9♥ first: it turns a hidden card."
                        ),
                    ]
                ),
                Exercise(
                    id: "reveal.2",
                    tableau: ["-2D QD", "9H", "-5C TD", "-4D -JS 8C 7H", "-3H KH", "-9S 4C", "-AC -KS JD"],
                    waste: "6S",
                    answer: .move(card: "8C", to: .column(1)),
                    prompt: LocalizedText(pt: "Podes mover uma sequência inteira. Encontra a jogada que revela uma carta.", en: "You can move a whole run. Find the move that reveals a card."),
                    explanation: LocalizedText(
                        pt: "O 8♣ leva o 7♥ com ele para cima do 9♥, e a carta escondida por baixo fica à vista.",
                        en: "The 8♣ takes the 7♥ with it onto the 9♥, and the hidden card underneath comes into view."
                    ),
                    mistakes: [
                        .move(card: "6S", to: .anyColumn): LocalizedText(
                            pt: "O 6♠ ficava em cima do 7♥: a sequência cresce, mas nenhuma carta é revelada.",
                            en: "The 6♠ would sit on the 7♥: the run grows, but no card is revealed."
                        ),
                    ]
                ),
            ]
        ),
        Lesson(
            id: "tallest",
            icon: "chart.bar.fill",
            title: LocalizedText(pt: "A coluna mais alta primeiro", en: "Tallest Column First"),
            summary: LocalizedText(pt: "Abre onde há mais cartas escondidas.", en: "Open where most cards are hidden."),
            intro: LocalizedText(
                pt: "Quando duas jogadas revelam uma carta, escolhe a da coluna com mais cartas viradas para baixo. É lá que estão mais cartas presas, e cada uma que viras dá-te mais opções.",
                en: "When two moves both reveal a card, pick the one from the column with the most face-down cards. That's where most cards are trapped, and each one you turn gives you more options."
            ),
            exercises: [
                Exercise(
                    id: "tallest.1",
                    tableau: ["8C", "-AD -9S 7D", "-3C QC", "-6H JS", "-KD 4H", "-2H -QS -5C -TD -4S 7H", "-8D 3H"],
                    answer: .move(card: "7H", to: .column(0)),
                    prompt: LocalizedText(pt: "Os dois setes vermelhos cabem no 8♣. Qual escolhes?", en: "Both red sevens fit on the 8♣. Which do you choose?"),
                    explanation: LocalizedText(
                        pt: "O 7♥ estava em cima de cinco cartas escondidas. Abrir essa coluna liberta muito mais do que a outra.",
                        en: "The 7♥ was sitting on five hidden cards. Opening that column frees far more than the other one."
                    ),
                    mistakes: [
                        .move(card: "7D", to: .anyColumn): LocalizedText(
                            pt: "Revelavas uma carta, mas a coluna do 7♥ tem cinco escondidas: é essa que mais precisa de ser aberta.",
                            en: "You'd reveal a card, but the 7♥ column has five hidden cards: that's the one that most needs opening."
                        ),
                    ]
                ),
                Exercise(
                    id: "tallest.2",
                    tableau: ["-AH QC", "-5D 9S", "-3S 6C", "-TC 2D", "7D", "-4H -JD -KS -8C -9H 6S", "-QD 5C"],
                    answer: .move(card: "6S", to: .column(4)),
                    prompt: LocalizedText(pt: "Dois seis pretos, um só 7♦.", en: "Two black sixes, only one 7♦."),
                    explanation: LocalizedText(
                        pt: "O 6♠ destapa a coluna com cinco cartas escondidas. O 6♣ só tinha uma por baixo.",
                        en: "The 6♠ opens the column with five hidden cards. The 6♣ only had one beneath it."
                    ),
                    mistakes: [
                        .move(card: "6C", to: .anyColumn): LocalizedText(
                            pt: "O 6♣ só tem uma carta escondida por baixo. O 6♠ tem cinco: joga esse.",
                            en: "The 6♣ only has one hidden card beneath it. The 6♠ has five: play that one."
                        ),
                    ]
                ),
            ]
        ),
        Lesson(
            id: "kings",
            icon: "crown.fill",
            title: LocalizedText(pt: "Colunas vazias e Reis", en: "Empty Columns and Kings"),
            summary: LocalizedText(pt: "Só um Rei ocupa um espaço vazio.", en: "Only a King can fill an empty space."),
            intro: LocalizedText(
                pt: "Uma coluna vazia só aceita um Rei. Esvaziá-la sem um Rei à vista não ajuda. Quando tens um espaço vazio, escolhe o Rei que revela uma carta, ou aquele em que a próxima carta pode encaixar.",
                en: "An empty column only takes a King. Emptying one with no King in sight doesn't help. When you have an empty space, choose the King that reveals a card, or the one the next card can fit on."
            ),
            exercises: [
                Exercise(
                    id: "kings.1",
                    tableau: ["-3S 9D", "5H", "-QC JH", "-7D 6S", "-4H -AC 8C", "-2S TD", "-JS -6D 4D"],
                    answer: .move(card: "8C", to: .column(0)),
                    prompt: LocalizedText(pt: "Podias esvaziar uma coluna. Vale a pena?", en: "You could empty a column. Is it worth it?"),
                    explanation: LocalizedText(
                        pt: "Não há nenhum Rei à vista, por isso uma coluna vazia não servia para nada. O 8♣ revela uma carta.",
                        en: "There's no King in sight, so an empty column would be useless. The 8♣ reveals a card."
                    ),
                    mistakes: [
                        .move(card: "5H", to: .anyColumn): LocalizedText(
                            pt: "Esvaziavas uma coluna, mas não há nenhum Rei à vista para a ocupar.",
                            en: "You'd empty a column, but there's no King in sight to fill it."
                        ),
                    ]
                ),
                Exercise(
                    id: "kings.2",
                    tableau: ["-3D 7C", "-9S 2H", "", "-5D TH", "-8C 6C", "-4C -JD KH", "-AS QH"],
                    waste: "KS",
                    answer: .move(card: "KH", to: .column(2)),
                    prompt: LocalizedText(pt: "Tens uma coluna vazia e dois Reis. Qual vai para lá?", en: "You have an empty column and two Kings. Which one goes there?"),
                    explanation: LocalizedText(
                        pt: "O K♥ estava em cima de duas cartas escondidas: ao movê-lo, viras uma. O K♠ do monte não destapava nada.",
                        en: "The K♥ was on top of two hidden cards: moving it turns one over. The K♠ from the waste uncovered nothing."
                    ),
                    mistakes: [
                        .move(card: "KS", to: .anyColumn): LocalizedText(
                            pt: "O Rei do monte pode esperar: o K♥ revela uma carta escondida.",
                            en: "The waste King can wait: the K♥ reveals a hidden card."
                        ),
                    ]
                ),
                Exercise(
                    id: "kings.3",
                    tableau: ["-5H 9C", "-7S KD", "-2C JS", "", "-8H 4S", "-TD 6H", "-3D KC"],
                    waste: "QH",
                    answer: .move(card: "KC", to: .column(3)),
                    prompt: LocalizedText(pt: "Os dois Reis revelam uma carta. Olha para o monte.", en: "Both Kings reveal a card. Look at the waste."),
                    explanation: LocalizedText(
                        pt: "A Q♥ do monte só cabe num Rei preto. Com o K♣ na coluna vazia, ela pode ir a seguir.",
                        en: "The Q♥ in the waste only fits on a black King. With the K♣ in the empty column, it can follow."
                    ),
                    mistakes: [
                        .move(card: "KD", to: .anyColumn): LocalizedText(
                            pt: "Também revela uma carta, mas a Q♥ do monte não cabe num Rei vermelho.",
                            en: "It reveals a card too, but the Q♥ in the waste can't go on a red King."
                        ),
                        .move(card: "QH", to: .anyColumn): LocalizedText(
                            pt: "Primeiro o Rei: move o K♣ para a coluna vazia e revela uma carta. A Q♥ vai a seguir.",
                            en: "King first: move the K♣ to the empty column and reveal a card. The Q♥ follows."
                        ),
                    ]
                ),
            ]
        ),
        Lesson(
            id: "foundations",
            icon: "hourglass",
            title: LocalizedText(pt: "Fundações sem pressa", en: "No Rush to the Foundations"),
            summary: LocalizedText(pt: "Uma carta média ainda pode fazer falta.", en: "A middle card may still be needed."),
            intro: LocalizedText(
                pt: "Subir um 4 ou um 5 cedo demais pode deixar outra carta sem sítio. Antes de mandar uma carta para a fundação, vê se ainda serve de apoio a uma carta de cor oposta que está a tapar cartas escondidas.",
                en: "Sending a 4 or a 5 up too early can leave another card with nowhere to go. Before playing a card to the foundation, check whether it's still the only landing spot for an opposite-colour card covering hidden cards."
            ),
            exercises: [
                Exercise(
                    id: "foundations.1",
                    tableau: ["-JS 3C", "-TC 8D", "-9C 6S 5H", "-7D KS", "-QD -8H 4C", "-2S JC", "-KD 9H"],
                    foundations: [.hearts: .four],
                    answer: .move(card: "4C", to: .column(2)),
                    prompt: LocalizedText(pt: "O 5♥ podia subir. Mas devia?", en: "The 5♥ could go up. But should it?"),
                    explanation: LocalizedText(
                        pt: "O 4♣ só cabe no 5♥. Primeiro usa-o para revelar a carta escondida; o 5♥ sobe mais tarde.",
                        en: "The 4♣ only fits on the 5♥. Use it first to reveal the hidden card; the 5♥ can go up later."
                    ),
                    mistakes: [
                        .move(card: "5H", to: .foundation): LocalizedText(
                            pt: "Na fundação, o 5♥ deixava o 4♣ sem sítio. Usa-o primeiro para revelar a carta escondida.",
                            en: "On the foundation, the 5♥ would leave the 4♣ stranded. Use it first to reveal the hidden card."
                        ),
                    ]
                ),
                Exercise(
                    id: "foundations.2",
                    tableau: ["8H 7C", "-JD 9D", "-QH 3D", "-8S KH", "-AD 4H", "-KD 6D", "-5H JC"],
                    foundations: [.clubs: .six],
                    answer: .move(card: "6D", to: .column(0)),
                    prompt: LocalizedText(pt: "O 7♣ está pronto para subir. Pensa no 6♦.", en: "The 7♣ is ready to go up. Think about the 6♦."),
                    explanation: LocalizedText(
                        pt: "O 6♦ precisa de um 7 preto e o 7♣ é o único à vista. Em cima dele, o 6♦ revela uma carta.",
                        en: "The 6♦ needs a black 7 and the 7♣ is the only one in sight. On it, the 6♦ reveals a card."
                    ),
                    mistakes: [
                        .move(card: "7C", to: .foundation): LocalizedText(
                            pt: "Com o 7♣ na fundação, o 6♦ ficava sem sítio e a carta por baixo dele continuava escondida.",
                            en: "With the 7♣ on the foundation, the 6♦ would have nowhere to go and the card under it would stay hidden."
                        ),
                    ]
                ),
            ]
        ),
        Lesson(
            id: "split",
            icon: "scissors",
            title: LocalizedText(pt: "Partir uma sequência", en: "Splitting a Run"),
            summary: LocalizedText(pt: "Pega só no fim para destapar uma carta.", en: "Take just the end to uncover a card."),
            intro: LocalizedText(
                pt: "Não precisas de mover uma sequência inteira. Podes pegar só nas últimas cartas. É útil quando a carta do meio pode ir para a fundação.",
                en: "You don't have to move a whole run. You can pick up just the last cards. It's useful when the card in the middle can go to the foundation."
            ),
            exercises: [
                Exercise(
                    id: "split.1",
                    tableau: ["-4D JS", "-KS 5C", "-TD 2S", "-QC 9S 8H 7C", "-3S KD", "-6C TC", "-JC 8D"],
                    foundations: [.hearts: .seven],
                    answer: .move(card: "7C", to: .column(6)),
                    prompt: LocalizedText(pt: "O 8♥ podia subir, mas está tapado.", en: "The 8♥ could go up, but it's covered."),
                    explanation: LocalizedText(
                        pt: "Pegas só no 7♣ e pões no 8♦. O 8♥ fica livre para subir para a fundação.",
                        en: "Take just the 7♣ and put it on the 8♦. The 8♥ is free to go up to the foundation."
                    )
                ),
                Exercise(
                    id: "split.2",
                    tableau: ["-8S QS", "-2C -JS 6C 5D 4S", "-9D KC", "-TH 7S", "-3C 9C", "5H", "-QD 8C"],
                    foundations: [.diamonds: .four],
                    answer: .move(card: "4S", to: .column(5)),
                    prompt: LocalizedText(pt: "Encontra a carta que podia ir para a fundação.", en: "Find the card that could go to the foundation."),
                    explanation: LocalizedText(
                        pt: "O 4♠ vai para o 5♥ e o 5♦ fica pronto para a fundação.",
                        en: "The 4♠ goes onto the 5♥ and the 5♦ is ready for the foundation."
                    )
                ),
            ]
        ),
        Lesson(
            id: "stock",
            icon: "rectangle.stack.fill",
            title: LocalizedText(pt: "Usar o monte", en: "Using the Stock"),
            summary: LocalizedText(pt: "Sem jogadas úteis, vira o monte.", en: "No useful moves? Turn the stock."),
            intro: LocalizedText(
                pt: "Mover cartas de lado não revela nada. Quando o tabuleiro não tem jogadas úteis, vira o monte. E quando a carta do monte encaixa, vê se ela abre caminho a outra.",
                en: "Moving cards sideways reveals nothing. When the tableau has no useful moves, turn the stock. And when a waste card fits, check whether it opens the way for another."
            ),
            exercises: [
                Exercise(
                    id: "stock.1",
                    tableau: ["-9D QS", "-4C JC", "-KH 7S 6H", "-2D 9S", "-TS 7C", "-5S KS", "-8H 3S"],
                    stock: "AD 3H TC",
                    answer: .draw,
                    prompt: LocalizedText(pt: "Não há nada a revelar. O que fazes?", en: "There's nothing to reveal. What do you do?"),
                    explanation: LocalizedText(
                        pt: "Sem jogadas úteis no tabuleiro, virar o monte é a jogada certa.",
                        en: "With no useful moves on the tableau, turning the stock is the right move."
                    ),
                    mistakes: [
                        .move(card: "6H", to: .anyColumn): LocalizedText(
                            pt: "Mudar o 6♥ de coluna não revela nada. Sem jogadas úteis, vira o monte.",
                            en: "Moving the 6♥ to another column reveals nothing. With no useful moves, turn the stock."
                        ),
                    ]
                ),
                Exercise(
                    id: "stock.2",
                    tableau: ["QD", "-6S 4C", "-9C 2H", "-3D 8S", "-7H KH", "-AS TH", "-5C 6D"],
                    waste: "JC",
                    stock: "4S QH",
                    answer: .move(card: "JC", to: .column(0)),
                    prompt: LocalizedText(pt: "Antes de virar mais cartas…", en: "Before turning more cards…"),
                    explanation: LocalizedText(
                        pt: "O J♣ vai para a Q♦, e em cima dele cabe o 10♥, que revela uma carta.",
                        en: "The J♣ goes onto the Q♦, and the 10♥ fits on it next, revealing a card."
                    ),
                    mistakes: [
                        .draw: LocalizedText(
                            pt: "Antes de virar mais cartas, aproveita o J♣: em cima dele cabe o 10♥, que revela uma carta.",
                            en: "Before turning more cards, use the J♣: the 10♥ fits on it and reveals a card."
                        ),
                    ]
                ),
            ]
        ),
    ]
}

/// Best stars per exercise, saved on the device.
enum AcademyProgress {
    private static let key = "iVidiSolitaire.academyStars"

    static func stars() -> [String: Int] {
        GameStateStore.defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    static func record(_ earned: Int, for exerciseID: String) {
        var all = stars()
        all[exerciseID] = max(all[exerciseID] ?? 0, earned)
        GameStateStore.defaults.set(all, forKey: key)
    }

    /// Stars for a lesson: the weakest exercise, or 0 until every exercise is done.
    static func stars(for lesson: Lesson, in all: [String: Int] = stars()) -> Int {
        lesson.exercises.map { all[$0.id] ?? 0 }.min() ?? 0
    }

    static func completedLessons(in all: [String: Int] = stars()) -> Int {
        Academy.lessons.filter { stars(for: $0, in: all) > 0 }.count
    }

    static func reset() {
        GameStateStore.defaults.removeObject(forKey: key)
    }
}
