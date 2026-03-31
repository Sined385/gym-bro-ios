# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -scheme GymBro -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build

# Clean build
xcodebuild -scheme GymBro -sdk iphonesimulator clean build

# Run all unit tests
xcodebuild test -scheme GymBro -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'

# Run specific test target / class / method
xcodebuild test -scheme GymBro -sdk iphonesimulator -only-testing:GymBroTests
xcodebuild test -scheme GymBro -sdk iphonesimulator -only-testing:GymBroTests/AuthViewModelTests
xcodebuild test -scheme GymBro -sdk iphonesimulator -only-testing:GymBroTests/AuthViewModelTests/testSignInWithApple

# Resolve Swift packages
xcodebuild -resolvePackageDependencies
```

## Architecture

### MVVM + Swinject Dependency Injection

Views → ViewModels → Services. All services are protocol-based.

**DependencyContainer** (`App/DependencyContainer.swift`) registers everything:
- Services in `.container` scope (singletons): `NetworkServiceProtocol`, `AuthServiceProtocol`, `HealthKitServiceProtocol`, `ActiveSessionManager`, `AppDataState`, `PushNotificationService`
- ViewModels in `.transient` scope (new per injection), except `HomeViewModel` which is `.container`
- `SessionFlowViewModel` and `UserProfileViewModel` take runtime parameters via Swinject's `(resolver, param)` pattern

**Resolution:** `DependencyContainer.shared.resolve(Type.self)` or `@Injected` property wrapper.

### Navigation Flow

**AppCoordinator** (`App/AppCoordinator.swift`) manages root routing:
```
.loading → determineInitialRoute()
  ├─ No auth → .authentication
  ├─ Auth + no onboarding → .onboarding
  ├─ Auth + onboarding → .buildingPlan (plan generation) → .home
```

**MainTabView** — 5 tabs: Home, Plan, Coach (center action), Community, Profile.

### Networking Layer

`Services/Networking/NetworkService.swift` — Alamofire wrapper with auto-injected Supabase JWT.

`Services/Networking/APIRouter.swift` — Type-safe route enums for every API module:
- `HomeRouter` — dashboard, sessions, history
- `SessionRouter` — exercises, sets, supersets, completion with feedback
- `CoachRouter` — SSE chat, conversations, message actions
- `PlanRouter` — active plan, generate, start plan session
- `ExerciseRouter` — library CRUD, previous sets
- `CommunityRouter` — feed, posts, likes, comments, follows, profiles
- `NotificationRouter` — device tokens, list, read/unread
- `OnboardingRouter` — submit, fetch, update rest time

All routes target the NestJS backend at `/api/v1/...`.

### Key Singletons

- **ActiveSessionManager** — tracks the currently active workout session across the app. Views check `sessionManager.activeSession` to show mini-player bar, prevent starting duplicate sessions, etc.
- **AppDataState** — shared state for cross-cutting data (e.g., plan needs refresh, home needs reload after session completes).

### Session Flow

The workout session lifecycle spans multiple screens:
1. `HomeView` or `TrainingPlanView` → starts session via API → creates `SessionFlowViewModel`
2. `SessionFlowContainer` → `SessionStartedView` → `ExerciseLoggingView` (log sets) → `WorkoutFeedbackView`
3. On completion: `ActiveSessionManager` clears active session, `AppDataState` signals refresh

### Coach Chat

`CoachChatViewModel` uses SSE streaming (`text/event-stream`) to receive AI responses. Events: `text_delta`, `session_created`, `done`, `error`. The AI can create workout sessions via tool calls, rendered as `CoachWorkoutCard`.

### Onboarding

10-step flow managed by `OnboardingViewModel`:
1. Authentication (Apple/Google)
2. Primary Goal
3. Primary Sport
4. Experience Level
5. Training Frequency
6. Workout Duration
7. Rest Time
8. Equipment
9. Injuries
10. Body Metrics

Data persisted to backend via `PUT /api/v1/onboarding`.

## Key Technologies

- **iOS 18.0+**, Xcode 16.0+, Swift 6
- **Supabase SDK 2.41.1** — auth + session management
- **Swinject 2.10** — DI container
- **Alamofire 5.11** — HTTP client
- **Firebase** — Analytics, push notifications
- **HealthKit** — workout data sync

### Supabase Patterns

```swift
// Session access (throws, not optional)
let session = try await SupabaseConfig.client.auth.session

// Token injection — NetworkService gets token via closure:
NetworkService(tokenProvider: { try? await SupabaseConfig.client.auth.session.accessToken })
```

Credentials in `Services/Auth/SupabaseConfig.swift`. Mock auth available in DEBUG builds via `AuthViewModel.mockSignIn()`.

### Design System

`Core/DesignSystem/` — Colors (`#E86A75` primary, `#F8F9FA` bg, `#2D3240` dark), Typography (`.gymBroHeaderLarge/Medium/Small`, `.gymBroBody`, `.gymBroButton`), Shadows. All views should use these tokens.

## Important Patterns

- All ViewModels: `@MainActor final class` conforming to `ObservableObject`, must `import Combine` for `@Published`
- Onboarding step views must NOT include their own `ScrollView` — `OnboardingContainerView` provides it
- `AuthenticationView` has dual mode: `isStandalone: true` (full screen) vs `false` (embedded in onboarding)
- `StepHeader` uses horizontal layout: gradient icon + title side by side
- `SelectionCard` supports optional `showCheckmark` for multi-select

## API Documentation

- `.claude/HOME_SCREEN_API.md` — Home screen backend API spec
- `.claude/SUPABASE_SETUP.md` — Supabase project setup
- `.claude/ONBOARDING_API_SPEC.md` — Onboarding data API spec
