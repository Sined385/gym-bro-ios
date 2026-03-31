# GymBro - iOS MVVM Architecture Documentation

## Overview

GymBro is a fitness tracking iOS application built with SwiftUI following MVVM architecture with Swinject dependency injection, Alamofire for networking, and HealthKit integration.

## Architecture Principles

### MVVM (Model-View-ViewModel)

The app strictly follows MVVM pattern:

- **Models**: Pure Swift data structures representing domain entities (SwiftData models + API response models)
- **Views**: SwiftUI views containing only UI logic
- **ViewModels**: `ObservableObject` classes containing business logic, state management, and service coordination

### Dependency Injection

Using **Swinject** for dependency injection:
- Services registered in `DependencyContainer.swift`
- Protocol-based abstraction for testability
- `@Injected` property wrapper for convenient injection
- Environment-based injection for SwiftUI views

## Project Structure

```
GymBro/
├── App/
│   ├── GymBroApp.swift              # App entry point with SwiftData + DI setup
│   └── DependencyContainer.swift     # Swinject container configuration
├── Core/
│   ├── Extensions/                   # Swift extensions
│   └── Utilities/                    # Helper classes
├── Models/
│   ├── WorkoutSessionModel.swift     # SwiftData workout model
│   ├── ExerciseModel.swift          # SwiftData exercise model
│   ├── UserProfileModel.swift       # SwiftData user profile
│   ├── BodyMeasurementModel.swift   # SwiftData body measurements
│   └── ProgressGoalModel.swift      # SwiftData goals tracking
├── ViewModels/
│   └── WorkoutViewModel.swift        # Workout management ViewModel
├── Views/
│   └── ContentView.swift            # Main app view with ViewModel integration
├── Services/
│   ├── Networking/
│   │   ├── NetworkServiceProtocol.swift  # Protocol for testability
│   │   └── NetworkService.swift          # Alamofire implementation
│   └── HealthKit/
│       ├── HealthKitServiceProtocol.swift  # Protocol for testability
│       └── HealthKitService.swift          # HealthKit implementation
└── Resources/
    ├── Assets.xcassets/
    └── GymBro.entitlements         # HealthKit capabilities
```

## Core Components

### 1. Dependency Injection (Swinject)

**File**: `App/DependencyContainer.swift`

Features:
- Singleton container with `.shared` instance
- Service registration with lifecycle scopes
- Protocol-based service resolution
- SwiftUI environment integration
- `@Injected` property wrapper

Example usage:
```swift
// In ViewModel
init(networkService: NetworkServiceProtocol, healthKitService: HealthKitServiceProtocol) {
    self.networkService = networkService
    self.healthKitService = healthKitService
}

// In SwiftUI View
@Environment(\.dependencies) private var dependencies
@StateObject private var viewModel: WorkoutViewModel

init() {
    let container = DependencyContainer.shared
    _viewModel = StateObject(wrappedValue: container.resolve(WorkoutViewModel.self))
}
```

### 2. Networking Layer (Alamofire)

**Files**:
- `Services/Networking/NetworkServiceProtocol.swift`
- `Services/Networking/NetworkService.swift`

Features:
- Protocol-based abstraction (`NetworkServiceProtocol`)
- Generic request/response methods
- Async/await support
- JSON encoding/decoding with snake_case support
- Error handling with custom error types
- Multipart upload support
- Request/response interceptors ready

Example usage:
```swift
let endpoint = APIEndpoint(
    path: "/api/workouts",
    method: .post,
    parameters: ["name": "Morning Run"],
    encoding: .json
)

let response = try await networkService.request(endpoint, responseType: WorkoutResponse.self)
```

### 3. HealthKit Service

**Files**:
- `Services/HealthKit/HealthKitServiceProtocol.swift`
- `Services/HealthKit/HealthKitService.swift`

Features:
- Full HealthKit integration
- **Workouts**: Save, fetch, delete workout sessions
- **Heart Rate**: Track and query heart rate data
- **Active Energy**: Monitor calories burned
- **Body Measurements**: Weight, body fat %, lean body mass
- Async/await API
- Protocol-based for testability

Example usage:
```swift
// Request authorization
try await healthKitService.requestAuthorization()

// Save workout
let workout = WorkoutData(
    activityType: .running,
    startDate: startDate,
    endDate: endDate,
    totalEnergyBurned: 300
)
try await healthKitService.saveWorkout(workout)

// Fetch workouts
let workouts = try await healthKitService.fetchWorkouts(from: startDate, to: endDate)
```

### 4. SwiftData Models

**Files**:
- `Models/WorkoutSessionModel.swift`
- `Models/ExerciseModel.swift`
- `Models/UserProfileModel.swift`
- `Models/BodyMeasurementModel.swift`
- `Models/ProgressGoalModel.swift`

Features:
- Modern SwiftData persistence
- Relationships (Workout ↔ Exercises)
- HealthKit sync tracking
- Progress goal calculations

### 5. ViewModel (MVVM)

**File**: `ViewModels/WorkoutViewModel.swift`

Features:
- `@MainActor` for UI safety
- Dependency injection via initializer
- `@Published` properties for SwiftUI binding
- Business logic separation
- Service coordination (HealthKit + Network)
- Loading states and error handling

Example usage:
```swift
@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var workouts: [WorkoutData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let networkService: NetworkServiceProtocol
    private let healthKitService: HealthKitServiceProtocol

    init(networkService: NetworkServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.networkService = networkService
        self.healthKitService = healthKitService
    }

    func loadWorkouts() async {
        // Business logic here
    }
}
```

## Testing

### Mock Services

**Files**:
- `GymBroTests/Mocks/MockNetworkService.swift`
- `GymBroTests/Mocks/MockHealthKitService.swift`

Features:
- Full protocol conformance
- Call tracking (call counts, parameters)
- Configurable responses and errors
- Reset functionality for test isolation

### Unit Tests

**Files**:
- `GymBroTests/Services/NetworkServiceTests.swift` (13 tests)
- `GymBroTests/Services/HealthKitServiceTests.swift` (18 tests)
- `GymBroTests/ViewModels/WorkoutViewModelTests.swift` (15 tests)

Coverage:
- **46 total unit tests**
- Service layer fully tested
- ViewModel business logic tested
- Error handling tested
- Async operations tested

Example test:
```swift
@Test("Should save workout successfully")
func testSaveWorkout() async throws {
    let mockService = MockHealthKitService()

    let workout = WorkoutData(
        activityType: .running,
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        totalEnergyBurned: 300
    )

    try await mockService.saveWorkout(workout)

    #expect(mockService.saveWorkoutCallCount == 1)
}
```

## Dependencies

### Swift Package Manager

- **Alamofire** (5.11.1): Networking
- **Swinject** (2.10.0): Dependency Injection

### Apple Frameworks

- **SwiftUI**: UI framework
- **SwiftData**: Persistence (iOS 18+)
- **HealthKit**: Health data integration
- **Combine**: Reactive programming

## Configuration

### Build Settings

- **iOS Deployment Target**: 18.0
- **Swift Version**: 5.0
- **Architecture**: arm64 (Apple Silicon)

### Capabilities

- HealthKit enabled
- Health Records access

### Info.plist Keys

- `NSHealthShareUsageDescription`: HealthKit read permission
- `NSHealthUpdateUsageDescription`: HealthKit write permission

## Best Practices Implemented

1. **Separation of Concerns**: Clear separation between UI, business logic, and data layers
2. **Protocol-Oriented Programming**: All services have protocols for abstraction
3. **Dependency Injection**: Swinject for loose coupling and testability
4. **Async/Await**: Modern Swift concurrency throughout
5. **Error Handling**: Comprehensive error types and handling
6. **Unit Testing**: High test coverage with mocks
7. **SwiftUI Best Practices**: Proper state management with @StateObject, @Published
8. **Type Safety**: Strongly typed throughout, minimal optionals

## Next Steps

1. Implement remaining ViewModels (Profile, Goals, Progress)
2. Add more Views for complete UI
3. Implement backend API endpoints
4. Add authentication flow
5. Enhance error handling with user-friendly messages
6. Add offline support with sync
7. Implement data caching strategies
8. Add analytics and logging

## Build Status

✅ **BUILD SUCCEEDED** (as of 2026-03-12)

Minor warnings (non-blocking):
- HKWorkout API deprecation (iOS 17+) - consider migrating to HKWorkoutBuilder
- Swift 6 sendability warnings - can be addressed in future updates

## Test Execution

Run tests using:
```bash
xcodebuild test -scheme GymBro -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Current test suite: **46 tests** covering services and ViewModels
