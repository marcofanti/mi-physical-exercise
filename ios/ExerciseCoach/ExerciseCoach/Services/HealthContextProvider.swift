import Foundation
import HealthKit
import Observation

/// Read-only HealthKit grounding: summarizes the last 7 days of steps and
/// workouts into a single prompt line, e.g.
/// `Client activity this week: avg 4,200 steps/day; 2 workouts (Walking 25 min, Running 30 min).`
///
/// If authorization is denied or data is unavailable, `summaryLine` stays nil
/// and the turn prompt reverts to the exact Python form.
@MainActor
@Observable
final class HealthContextProvider {
    private(set) var summaryLine: String?
    private(set) var isAuthorized = false

    @ObservationIgnored private let store = HKHealthStore()

    private static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKObjectType.workoutType(),
    ]

    /// Requests read access (no-op if already determined) and refreshes the
    /// summary. Safe to call at every session start.
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            isAuthorized = true
        } catch {
            summaryLine = nil
            return
        }

        async let steps = averageDailySteps()
        async let workouts = recentWorkouts()
        summaryLine = Self.buildSummary(
            averageSteps: await steps,
            workouts: await workouts
        )
    }

    // MARK: - Queries

    /// Average daily steps over the last 7 full days.
    private func averageDailySteps() async -> Int? {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -7, to: end) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let stepsType = HKQuantityType(.stepCount)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let total = sum.doubleValue(for: .count())
                continuation.resume(returning: Int(total / 7))
            }
            store.execute(query)
        }
    }

    /// Up to 10 workouts from the last 7 days, most recent first.
    private func recentWorkouts() async -> [HKWorkout] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -7, to: .now) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Formatting

    static func buildSummary(averageSteps: Int?, workouts: [HKWorkout]) -> String? {
        var parts: [String] = []

        if let averageSteps, averageSteps > 0 {
            let formatted = averageSteps.formatted(.number.grouping(.automatic))
            parts.append("avg \(formatted) steps/day")
        }

        if !workouts.isEmpty {
            let details = workouts.prefix(3)
                .map { workout in
                    let minutes = Int(workout.duration / 60)
                    return "\(workout.workoutActivityType.displayName) \(minutes) min"
                }
                .joined(separator: ", ")
            let label = workouts.count == 1 ? "workout" : "workouts"
            parts.append("\(workouts.count) \(label) (\(details))")
        }

        guard !parts.isEmpty else { return nil }
        return "Client activity this week: \(parts.joined(separator: "; "))."
    }
}

extension HKWorkoutActivityType {
    /// Human-readable names for the workout types most likely in student data;
    /// everything else falls back to "Workout".
    var displayName: String {
        switch self {
        case .walking: "Walking"
        case .running: "Running"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .yoga: "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "Strength Training"
        case .hiking: "Hiking"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .highIntensityIntervalTraining: "HIIT"
        case .dance, .socialDance: "Dance"
        case .basketball: "Basketball"
        case .soccer: "Soccer"
        case .tennis: "Tennis"
        default: "Workout"
        }
    }
}
