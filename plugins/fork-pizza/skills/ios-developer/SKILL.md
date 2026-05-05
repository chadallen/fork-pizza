---
name: ios-developer
description: Implement and review Swift/SwiftUI code. Covers Swift 6 concurrency, SwiftUI patterns, testing with XCTest, and common pitfalls. Invoke before implementing or reviewing Swift or iOS files.
metadata:
  model: inherit
---

## Use this skill when

- Implementing or reviewing Swift/SwiftUI code
- Working on iOS views, navigation, data persistence, or networking
- Making architecture decisions for native iOS features

## Do not use this skill when

- The task involves only web frontend (React, HTML/CSS) or backend code
- The code is cross-platform (Flutter, React Native) without native Swift components

## Swift Discipline

### Concurrency (Swift 6+)
- Use `async/await` over completion handlers for new code.
- Annotate UI-bound types with `@MainActor`. Don't scatter `@MainActor` on individual methods when the whole type is UI-bound.
- Use `actor` for shared mutable state — not locks or dispatch queues.
- Don't call synchronous blocking I/O inside `async` functions — offload with `Task.detached` or a background actor.
- Use `TaskGroup` for structured concurrent work over raw `Task` spawning.
- Mark protocol conformances as `@MainActor` when they access main-actor state: `extension Foo: @MainActor SomeProtocol`.

### SwiftUI
- Prefer `@State` + `@Observable` (iOS 17+) over `@StateObject` + `ObservableObject` for new code.
- Use `foregroundStyle()` not `foregroundColor()`. Use `containerBackground()` not `background()` for widgets.
- Break views into small, focused structs — one per file when non-trivial.
- Use `NavigationStack` with `navigationDestination(for:)` — not `NavigationView` or `NavigationLink(destination:)`.
- Don't put heavy computation in view `body` — use `.task {}` for async work.

### Error Handling
- Use typed throws (`throws(SomeError)` in Swift 6) where the error type is known.
- Don't use `try!` or `try?` silently — handle errors explicitly.
- Custom error types should conform to `LocalizedError` for user-facing messages.

### Data & Persistence
- Prefer SwiftData (iOS 17+) over Core Data for new projects.
- Use Keychain for credentials — never UserDefaults.
- Codable for API responses — avoid manual JSON parsing.

## Testing Conventions

### Framework detection
- Default: XCTest. Check for a `*Tests` target in the Xcode project or Package.swift.
- Check for Swift Testing (`import Testing`, `@Test` macro) — preferred for new test targets in Swift 6.

### File placement
- Mirror the source tree: `Sources/Auth/LoginService.swift` → `Tests/AuthTests/LoginServiceTests.swift`.
- Name test files `*Tests.swift` to match the target discovery convention.

### Writing tests
- Test behavior, not implementation. Call public API, assert observable outcomes.
- Use `XCTAssertEqual` over `XCTAssertTrue` for better failure messages.
- For async tests, use `async throws` test methods — don't spin run loops.
- Test error paths: verify that invalid input throws the expected error.

### Mocking
- Use protocols at boundaries (network, persistence). Inject mock conformances in tests.
- Don't mock Foundation types or SwiftUI views.
- For network tests, prefer URLProtocol-based stubs over mocking URLSession directly.

## Common Review Catches
- Force unwraps (`!`) outside of tests or `fatalError`-guarded preconditions
- `@MainActor` missing on types that update UI state
- `NavigationView` instead of `NavigationStack` (deprecated iOS 16)
- `foregroundColor()` instead of `foregroundStyle()`
- `ObservableObject` + `@Published` when `@Observable` macro is available (iOS 17+)
- Missing `Sendable` conformance on types passed across actor boundaries
- `print()` in production code — use `os.Logger`
- Heavy work in view `body` instead of `.task {}`
