# iOS Development Context and Skills

## Project Type
This is an iOS native application built with SwiftUI and following MVVM architecture.

## Core Technologies and Skills

### Swift
- Modern Swift language features (5.9+)
- Value types and reference types
- Protocol-oriented programming
- Generics and type constraints
- Property wrappers
- Result builders
- Error handling patterns

### SwiftUI
- Declarative UI framework
- View composition and modifiers
- Property wrappers (@State, @Binding, @StateObject, @ObservedObject, @EnvironmentObject)
- Data flow and state management
- Navigation patterns (NavigationStack, NavigationPath)
- List and ScrollView optimization
- Custom view modifiers and styles
- Animations and transitions
- Layout containers (HStack, VStack, ZStack, Grid)

### MVVM Architecture
- **View**: SwiftUI views that only contain UI logic
- **ViewModel**: ObservableObject classes that handle business logic and expose @Published properties
- **Model**: Pure Swift data structures (structs/classes)
- Clear separation of concerns
- Unidirectional data flow
- Dependency injection for testability

### Combine Framework
- Publishers and Subscribers
- Operators (map, filter, flatMap, etc.)
- @Published property wrapper
- Handling asynchronous events
- Error handling in streams
- Cancellable subscriptions
- Combining multiple publishers

### Swift Concurrency
- async/await syntax
- Task and Task groups
- Actors for thread-safe state management
- MainActor for UI updates
- Structured concurrency
- AsyncSequence and AsyncStream
- Converting Combine to async/await

### Unit Testing
- XCTest framework
- Testing ViewModels in isolation
- Protocol-based mocking
- Testing async code with expectations
- Testing Combine publishers
- Testing Swift Concurrency code
- Code coverage metrics
- Test-driven development (TDD)

### Additional Skills
- URLSession for networking
- Codable for JSON serialization
- UserDefaults and Core Data for persistence
- iOS SDK frameworks
- Xcode and Interface Builder
- Git version control
- Swift Package Manager
- CocoaPods dependency management

## Architecture Principles

1. **Single Responsibility**: Each component has one clear purpose
2. **Dependency Injection**: Dependencies passed through initializers
3. **Protocol-Oriented**: Use protocols for abstraction and testability
4. **Immutability**: Prefer immutable data structures where possible
5. **Testability**: All business logic should be unit testable

## Code Quality Standards

- Follow Swift API Design Guidelines
- Use meaningful, descriptive names
- Keep functions small and focused
- Avoid force unwrapping (!)
- Use guard for early returns
- Handle all error cases
- Add documentation for public APIs
- Maintain high test coverage (80%+ for business logic)
