import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) var dismiss

    let workout: Workout

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0C).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Summary card
                        summaryCard

                        // Exercises (if any)
                        if let exercises = workout.exercises, !exercises.isEmpty {
                            exercisesCard(exercises)
                        }

                        // Notes
                        if let notes = workout.notes, !notes.isEmpty {
                            notesCard(notes)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(workout.name ?? workout.type.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: 0x00B4D8))
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            // Type + date header
            HStack {
                Text(workout.type.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0x8B5CF6).opacity(0.15))
                    .foregroundColor(Color(hex: 0x8B5CF6))
                    .cornerRadius(6)

                Spacer()

                Text(formatDate(workout.date))
                    .font(.caption)
                    .foregroundColor(Color(hex: 0x606070))
            }

            // Stats row
            HStack(spacing: 0) {
                if let duration = workout.duration {
                    statItem(value: "\(duration)", unit: "min", icon: "clock")
                    Spacer()
                }
                if let cals = workout.calories {
                    statItem(value: "\(cals)", unit: "kcal", icon: "flame.fill")
                    Spacer()
                }
                if let exercises = workout.exercises {
                    statItem(value: "\(exercises.count)", unit: "exercises", icon: "list.bullet")
                    Spacer()
                }
                if let exercises = workout.exercises {
                    let totalSets = exercises.reduce(0) { $0 + ($1.sets?.count ?? 0) }
                    if totalSets > 0 {
                        statItem(value: "\(totalSets)", unit: "sets", icon: "repeat")
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: 0x141418))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func statItem(value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: 0x00B4D8))

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundColor(.white)

            Text(unit)
                .font(.caption2)
                .foregroundColor(Color(hex: 0x606070))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercises Card

    private func exercisesCard(_ exercises: [WorkoutExercise]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(hex: 0xA0A0B0))

            ForEach(exercises) { exercise in
                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)

                    if let sets = exercise.sets, !sets.isEmpty {
                        ForEach(sets) { set in
                            HStack {
                                Text("Set \(set.setNumber)")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: 0x606070))
                                    .frame(width: 44, alignment: .leading)

                                if let weight = set.weight {
                                    Text("\(Int(weight)) lbs")
                                        .font(.caption.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundColor(.white)
                                }

                                if let reps = set.reps {
                                    Text("× \(reps)")
                                        .font(.caption.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundColor(Color(hex: 0xA0A0B0))
                                }

                                Spacer()

                                if set.completed == true {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: 0x00D68F))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(12)
                .background(Color(hex: 0x1C1C22))
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color(hex: 0x141418))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Notes Card

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(hex: 0xA0A0B0))

            Text(notes)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(hex: 0x141418))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func formatDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let date = df.date(from: String(dateStr.prefix(10))) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "EEEE, MMM d"
        return out.string(from: date)
    }
}
