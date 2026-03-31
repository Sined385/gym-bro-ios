# Claude Code - iOS Development Configuration

This directory contains custom slash commands and context for iOS native development with SwiftUI, MVVM architecture, and modern Swift features.

## Available Slash Commands

### 1. `/mvvm-review` - MVVM Architecture and Code Quality
Analyzes your codebase for MVVM architecture compliance and code quality:
- Verifies proper separation between View, ViewModel, and Model layers
- Identifies code smells and anti-patterns
- Reviews state management and Combine usage
- Checks Swift Concurrency implementation
- Provides actionable recommendations

**Usage**: `/mvvm-review`

### 2. `/implement` - Implementation and Building
Helps implement new features following iOS best practices:
- Implements features using MVVM architecture
- Follows SwiftUI best practices
- Uses Combine or async/await for async operations
- Ensures code compiles and builds successfully
- Optimizes for performance

**Usage**: `/implement`

### 3. `/test` - Unit Testing and Code Coverage
Creates comprehensive unit tests for your code:
- Writes tests for ViewModels and business logic
- Tests Combine publishers and async/await code
- Creates mocks and test fixtures
- Analyzes and improves code coverage
- Follows testing best practices

**Usage**: `/test`

### 4. `/review` - Code Review
Performs thorough code review focusing on:
- Functionality and correctness
- Architecture and design patterns
- Code quality and maintainability
- Swift and SwiftUI best practices
- Security and performance
- Accessibility compliance

**Usage**: `/review`

## Context File

The `context.md` file provides Claude with comprehensive knowledge about:
- Swift language features
- SwiftUI framework and patterns
- MVVM architecture principles
- Combine framework
- Swift Concurrency (async/await, actors)
- Unit testing with XCTest
- Code quality standards

This context is automatically loaded to ensure Claude has the necessary expertise for iOS development.

## How to Use

1. **Run a command**: Type `/` followed by the command name in Claude Code
   ```
   /mvvm-review
   /implement
   /test
   /review
   ```

2. **Combine with instructions**: You can provide additional context after the command
   ```
   /implement Add a new workout tracking feature
   /test for the WorkoutViewModel
   /review the authentication flow
   ```

3. **Sequential workflows**: Use commands in sequence for complete features
   ```
   1. /implement - Build the feature
   2. /test - Add unit tests
   3. /mvvm-review - Verify architecture
   4. /review - Final code review
   ```

## Skills Included

Claude now has expertise in:
- ✅ SwiftUI
- ✅ Swift (modern features)
- ✅ MVVM Architecture
- ✅ Combine Framework
- ✅ Swift Concurrency (async/await, actors)
- ✅ Unit Testing with XCTest
- ✅ iOS SDK and Frameworks
- ✅ Code Quality and Best Practices

## Customization

You can customize these commands by editing the markdown files in `.claude/commands/`:
- `mvvm-review.md` - Architecture and quality checks
- `implement.md` - Implementation guidelines
- `test.md` - Testing strategies
- `review.md` - Code review criteria

Update `context.md` to add project-specific context or modify the skill set.
