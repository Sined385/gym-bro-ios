//
//  DependencyContainer.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Swinject
import SwiftUI
import Supabase

/// Central dependency injection container using Swinject
final class DependencyContainer {

    // MARK: - Properties

    static let shared = DependencyContainer()
    private let container: Container

    // MARK: - Initialization

    private init() {
        container = Container()
        registerDependencies()
    }

    // MARK: - Registration

    private func registerDependencies() {
        registerServices()
        registerViewModels()
    }

    private func registerServices() {
        // Network Service
        container.register(NetworkServiceProtocol.self) { _ in
            NetworkService(tokenProvider: {
                try? await SupabaseConfig.client.auth.session.accessToken
            })
        }.inObjectScope(.container)

        // HealthKit Service
        container.register(HealthKitServiceProtocol.self) { _ in
            HealthKitService()
        }.inObjectScope(.container)

        // App Data State (singleton)
        container.register(AppDataState.self) { _ in
            AppDataState()
        }.inObjectScope(.container)

        // Active Session Manager (singleton)
        container.register(ActiveSessionManager.self) { resolver in
            ActiveSessionManager(
                appDataState: resolver.resolve(AppDataState.self)!
            )
        }.inObjectScope(.container)

        // Auth Service
        container.register(AuthServiceProtocol.self) { _ in
            SupabaseAuthService()
        }.inObjectScope(.container)

        // Analytics Tracking Service (singleton)
        container.register(AnalyticsTrackingServiceProtocol.self) { resolver in
            AnalyticsTrackingService(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        // Push Notification Service (singleton)
        container.register(PushNotificationService.self) { resolver in
            PushNotificationService(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }.inObjectScope(.container)
    }

    private func registerViewModels() {
        // ViewModels are registered in .transient scope to create new instances for each injection
        // This is the typical pattern for ViewModels which are usually @StateObject in views

        container.register(WorkoutViewModel.self) { resolver in
            WorkoutViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                healthKitService: resolver.resolve(HealthKitServiceProtocol.self)!
            )
        }

        container.register(AuthViewModel.self) { resolver in
            AuthViewModel(
                authService: resolver.resolve(AuthServiceProtocol.self)!,
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(OnboardingViewModel.self) { resolver in
            OnboardingViewModel(
                authService: resolver.resolve(AuthServiceProtocol.self)!,
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                healthKitService: resolver.resolve(HealthKitServiceProtocol.self)!
            )
        }

        container.register(HomeViewModel.self) { resolver in
            HomeViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                sessionManager: resolver.resolve(ActiveSessionManager.self)!,
                appDataState: resolver.resolve(AppDataState.self)!,
                healthKitService: resolver.resolve(HealthKitServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        container.register(SessionFlowViewModel.self) { (resolver, sessionId: String, sessionTitle: String) in
            SessionFlowViewModel(
                sessionId: sessionId,
                sessionTitle: sessionTitle,
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                sessionManager: resolver.resolve(ActiveSessionManager.self)!,
                healthKitService: resolver.resolve(HealthKitServiceProtocol.self)!
            )
        }

        container.register(CoachChatViewModel.self) { resolver in
            CoachChatViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                sessionManager: resolver.resolve(ActiveSessionManager.self)!,
                appDataState: resolver.resolve(AppDataState.self)!
            )
        }

        container.register(ExerciseLibraryViewModel.self) { resolver in
            ExerciseLibraryViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(TrainingPlanViewModel.self) { resolver in
            TrainingPlanViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                sessionManager: resolver.resolve(ActiveSessionManager.self)!,
                appDataState: resolver.resolve(AppDataState.self)!
            )
        }

        container.register(CommunityFeedViewModel.self) { resolver in
            CommunityFeedViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(NewPostViewModel.self) { resolver in
            NewPostViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(EditProfileViewModel.self) { resolver in
            EditProfileViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(MyProfileViewModel.self) { resolver in
            MyProfileViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                appDataState: resolver.resolve(AppDataState.self)!
            )
        }

        container.register(UserProfileViewModel.self) { (resolver, userId: String) in
            UserProfileViewModel(
                userId: userId,
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(SettingsViewModel.self) { resolver in
            SettingsViewModel(
                authService: resolver.resolve(AuthServiceProtocol.self)!,
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                pushService: resolver.resolve(PushNotificationService.self)!
            )
        }

        container.register(ExercisePreviewViewModel.self) { resolver in
            ExercisePreviewViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!
            )
        }

        container.register(NotificationsViewModel.self) { resolver in
            NotificationsViewModel(
                networkService: resolver.resolve(NetworkServiceProtocol.self)!,
                pushService: resolver.resolve(PushNotificationService.self)!
            )
        }

        // App Coordinator
        container.register(AppCoordinator.self) { resolver in
            AppCoordinator(
                authViewModel: resolver.resolve(AuthViewModel.self)!
            )
        }
    }

    // MARK: - Resolution

    func resolve<Service>(_ serviceType: Service.Type) -> Service {
        guard let service = container.resolve(serviceType) else {
            fatalError("Unable to resolve \(serviceType)")
        }
        return service
    }

    /// Resets the container - useful for testing
    func reset() {
        container.removeAll()
        registerDependencies()
    }
}

// MARK: - SwiftUI Environment Support

/// Environment key for dependency injection
struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension for Dependency Injection

extension View {
    /// Inject dependencies into the view hierarchy
    func inject(dependencies: DependencyContainer = .shared) -> some View {
        environment(\.dependencies, dependencies)
    }
}

// MARK: - Property Wrapper for Dependency Injection

@propertyWrapper
struct Injected<Service> {
    private let container: DependencyContainer

    var wrappedValue: Service {
        container.resolve(Service.self)
    }

    init(container: DependencyContainer = .shared) {
        self.container = container
    }
}
