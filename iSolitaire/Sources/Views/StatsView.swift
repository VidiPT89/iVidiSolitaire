import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var stats = StatsStore().load()
    @State private var confirmReset = false
    @ObservedObject private var gameCenter = GameCenter.shared

    private var lang: AppLanguage { appSettings.language }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    winRateCard

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        tile("flame.fill", L10n.t(.winStreak, lang), "\(stats.currentWinStreak)")
                        tile("trophy.fill", L10n.t(.bestStreak, lang), "\(stats.bestWinStreak)")
                        tile("stopwatch.fill", L10n.t(.bestTime, lang), stats.bestTimeSeconds.map(L10n.time) ?? "—")
                        tile("clock.fill", L10n.t(.averageTime, lang), stats.averageWinSeconds.map(L10n.time) ?? "—")
                        tile("star.fill", L10n.t(.bestScore, lang), stats.gamesWon > 0 ? "\(stats.bestScore)" : "—")
                        tile("hand.draw.fill", L10n.t(.fewestMoves, lang), stats.fewestMoves.map { "\($0)" } ?? "—")
                    }

                    if gameCenter.isAuthenticated {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { GameCenter.shared.showLeaderboards() }
                        } label: {
                            Label(L10n.t(.leaderboards, lang), systemImage: "trophy.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .tint(Theme.ember)
                    }

                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label(L10n.t(.resetStats, lang), systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(stats.gamesPlayed == 0)
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.t(.stats, lang))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.close, lang)) { dismiss() }
                }
            }
            .confirmationDialog(L10n.t(.resetStatsConfirm, lang), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L10n.t(.resetStats, lang), role: .destructive) {
                    StatsStore().reset()
                    withAnimation { stats = GameStats() }
                }
                Button(L10n.t(.cancel, lang), role: .cancel) {}
            }
        }
    }

    private var winRateCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(stats.winRate) / 100)
                    .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(stats.winRate)%").font(.title2.weight(.heavy)).monospacedDigit()
                    Text(L10n.t(.winRate, lang)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 14) {
                bigNumber(L10n.t(.gamesPlayed, lang), stats.gamesPlayed)
                bigNumber(L10n.t(.gamesWon, lang), stats.gamesWon)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func bigNumber(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)").font(.title.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func tile(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.accentGradient)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
