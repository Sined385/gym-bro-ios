//
//  GymBroApp.swift
//  GymBro
//
//  Created by Denys Yefremov on 12.03.2026.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct GymBroApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - SwiftData Container

    let modelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSessionModel.self,
            ExerciseModel.self,
            UserProfileModel.self,
            BodyMeasurementModel.self,
            ProgressGoalModel.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let foo = Array<Int>()
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Dependency Injection

    let dependencies = DependencyContainer.shared

    // MARK: - Coordinator

    @StateObject private var coordinator: AppCoordinator = {
        DependencyContainer.shared.resolve(AppCoordinator.self)
    }()

    @StateObject private var authViewModel: AuthViewModel = {
        DependencyContainer.shared.resolve(AuthViewModel.self)
    }()

    @StateObject private var sessionManager: ActiveSessionManager = {
        DependencyContainer.shared.resolve(ActiveSessionManager.self)
    }()

    @StateObject private var deepLinkRouter: DeepLinkRouter = {
        DependencyContainer.shared.resolve(DeepLinkRouter.self)
    }()

    @Environment(\.scenePhase) private var scenePhase

    private let analyticsService: AnalyticsTrackingServiceProtocol = {
        DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
    }()

    // MARK: - App Body

    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.currentRoute {
                case .loading:
                    LoadingView()

                case .authentication:
                    AuthenticationView(authViewModel: authViewModel, isStandalone: true)
                        .environmentObject(coordinator)

                case .onboarding:
                    OnboardingContainerView(
                        viewModel: DependencyContainer.shared.resolve(OnboardingViewModel.self)
                    )
                    .environmentObject(authViewModel)
                    .environmentObject(coordinator)

                case .buildingPlan:
                    BuildingPlanView()
                        .environmentObject(coordinator)

                case .home:
                    MainTabView()
                        .environmentObject(sessionManager)
                        .environmentObject(coordinator)
                        .environmentObject(deepLinkRouter)
                }
            }
            .inject(dependencies: dependencies)
            .modelContainer(modelContainer)
            .onOpenURL { url in
                if !deepLinkRouter.handle(url: url) {
                    GIDSignIn.sharedInstance.handle(url)
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                _ = deepLinkRouter.handle(url: url)
            }
            .task {
                await coordinator.determineInitialRoute()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    analyticsService.trackAppOpened()
                case .background:
                    analyticsService.trackAppBackgrounded()
                    analyticsService.flush()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.gymBroBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // App icon or logo
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.gymBroPrimaryGradient)

                ProgressView()
                    .tint(.gymBroPrimary)

                Text("GymJam")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.gymBroTextPrimary)
            }
        }
    }
}
