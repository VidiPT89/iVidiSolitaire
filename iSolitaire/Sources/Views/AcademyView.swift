import SwiftUI

/// The Academy: short strategy lessons, each followed by exercises on real positions.
struct AcademyView: View {
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var stars = AcademyProgress.stars()
    @State private var openLesson: Lesson?

    private var lang: AppLanguage { appSettings.language }
    private var theme: TableTheme { appSettings.tableTheme }
    private var textColor: Color { theme.textColor(colorScheme) }

    var body: some View {
        ZStack {
            TableBackground(theme: theme, scheme: colorScheme).equatable()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    progressCard
                    ForEach(Array(Academy.lessons.enumerated()), id: \.element.id) { index, lesson in
                        Button { openLesson = lesson } label: { lessonRow(lesson, number: index + 1) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.t(.academy, lang))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $openLesson, onDismiss: { stars = AcademyProgress.stars() }) { lesson in
            LessonView(lesson: lesson).environmentObject(appSettings)
        }
        .onAppear { stars = AcademyProgress.stars() }
    }

    private var progressCard: some View {
        let done = AcademyProgress.completedLessons(in: stars)
        let total = Academy.lessons.count
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t(.academySubtitle, lang))
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(done), total: Double(total))
                .tint(Theme.ember)
            Text(L10n.format(.lessonsDone, lang, done, total))
                .font(.caption)
                .opacity(0.75)
        }
        .foregroundStyle(textColor)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func lessonRow(_ lesson: Lesson, number: Int) -> some View {
        let earned = AcademyProgress.stars(for: lesson, in: stars)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accentGradient)
                Image(systemName: lesson.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(number). \(lesson.title(lang))")
                    .font(.headline)
                Text(lesson.summary(lang))
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(2)
                StarRow(stars: earned, size: 11)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .opacity(0.5)
        }
        .foregroundStyle(textColor)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct StarRow: View {
    let stars: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index < stars ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Color.secondary.opacity(0.6)))
            }
        }
        .accessibilityLabel("\(stars)/3")
    }
}

/// A lesson's explanation, with a button into its exercises.
struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var practising = false
    @State private var completedStars: Int?

    private var lang: AppLanguage { appSettings.language }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.accentGradient)
                            Image(systemName: lesson.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 60, height: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title(lang)).font(.title2.weight(.bold))
                            StarRow(stars: AcademyProgress.stars(for: lesson))
                        }
                    }

                    if let completedStars {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(L10n.t(.lessonComplete, lang), systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                            StarRow(stars: completedStars, size: 20)
                            Text(L10n.t(.lessonCompleteMessage, lang))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t(.keyIdea, lang).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.ember)
                        Text(lesson.intro(lang))
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button { practising = true } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(L10n.t(completedStars == nil && AcademyProgress.stars(for: lesson) == 0 ? .start : .practiceAgain, lang))
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.close, lang)) { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $practising) {
                ExerciseFlowView(lesson: lesson) { stars in
                    practising = false
                    if let stars { completedStars = stars }
                }
                .environmentObject(appSettings)
            }
        }
        .tint(Theme.ember)
    }
}

/// Plays a lesson's exercises one after the other.
struct ExerciseFlowView: View {
    let lesson: Lesson
    /// Called with the lesson's stars when every exercise is done, or nil when closed early.
    let onFinish: (Int?) -> Void
    @State private var index = 0
    @State private var earned: [Int] = []

    var body: some View {
        let exercise = lesson.exercises[index]
        BoardView(practice: PracticeConfig(
            exercise: exercise,
            lessonTitle: lesson.title,
            step: index + 1,
            total: lesson.exercises.count,
            onNext: { stars in
                AcademyProgress.record(stars, for: exercise.id)
                earned.append(stars)
                if index + 1 < lesson.exercises.count {
                    index += 1
                } else {
                    GameCenter.shared.reportAcademy(
                        completedLessons: AcademyProgress.completedLessons(),
                        totalLessons: Academy.lessons.count
                    )
                    onFinish(earned.min() ?? 1)
                }
            },
            onClose: { onFinish(nil) }
        ))
        .id(exercise.id)
    }
}
