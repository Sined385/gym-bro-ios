//
//  ContentView.swift
//  GymBro
//
//  Created by Denys Yefremov on 12.03.2026.
//

import SwiftUI
import HealthKit

struct ContentView: View {

    // MARK: - Environment

    @Environment(\.dependencies) private var dependencies

    // MARK: - ViewModel

    @StateObject private var viewModel: WorkoutViewModel

    // MARK: - Initialization

    init() {
        // Initialize with injected dependencies
        let container = DependencyContainer.shared
        _viewModel = StateObject(wrappedValue: container.resolve(WorkoutViewModel.self))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else {
                    contentView
                }
            }
            .navigationTitle("GymJam")
            .task {
                // Request HealthKit authorization on appear
                await viewModel.requestHealthKitAuthorization()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Welcome Header
                headerView

                // Statistics Cards
                statisticsView

                // Workout List
                workoutsListView

                Spacer()
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to GymJam!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your personal fitness companion")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !viewModel.isHealthKitAuthorized {
                Button {
                    Task {
                        await viewModel.requestHealthKitAuthorization()
                    }
                } label: {
                    Label("Authorize HealthKit", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        VStack(spacing: 12) {
            Text("This Week")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(
                    title: "Workouts",
                    value: "\(viewModel.totalWorkoutsThisWeek)",
                    icon: "figure.run",
                    color: .blue
                )

                StatCard(
                    title: "Calories",
                    value: String(format: "%.0f", viewModel.totalCaloriesBurnedThisWeek),
                    icon: "flame.fill",
                    color: .orange
                )

                if let avgHeartRate = viewModel.averageHeartRate {
                    StatCard(
                        title: "Avg HR",
                        value: String(format: "%.0f", avgHeartRate),
                        icon: "heart.fill",
                        color: .red
                    )
                }
            }
        }
    }

    // MARK: - Workouts List View

    private var workoutsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        viewModel.startWorkout(type: .traditionalStrengthTraining)
                    }
                } label: {
                    Label("Start", systemImage: "plus.circle.fill")
                }
            }

            if viewModel.workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "figure.run.circle",
                    description: Text("Start your first workout to see it here")
                )
                .frame(height: 200)
            } else {
                ForEach(viewModel.workouts.prefix(5), id: \.id) { workout in
                    WorkoutRow(workout: workout, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Workout Row Component

struct WorkoutRow: View {
    let workout: WorkoutData
    let viewModel: WorkoutViewModel

    var body: some View {
        HStack {
            Image(systemName: workoutIcon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(workoutTypeName)
                    .font(.headline)

                Text(workout.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.formattedDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let calories = workout.totalEnergyBurned {
                    Text("\(Int(calories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var workoutIcon: String {
        switch workout.activityType {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .traditionalStrengthTraining: return "dumbbell.fill"
        case .yoga: return "figure.yoga"
        default: return "figure.mixed.cardio"
        }
    }

    private var workoutTypeName: String {
        switch workout.activityType {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        default: return "Workout"
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .inject(dependencies: .shared)
}
