---
name: typescript-developer
description: Implement and review TypeScript/JavaScript code. Covers strict typing discipline, async patterns, testing conventions (Jest/Vitest), and common pitfalls. Invoke before implementing or reviewing TypeScript or JavaScript files.
metadata:
  model: inherit
---

## Use this skill when

- Implementing or reviewing TypeScript or JavaScript code
- Writing or reviewing tests in a TypeScript/JavaScript project
- Making decisions about typing, async patterns, or module structure

## Do not use this skill when

- The task contains no TypeScript or JavaScript files
- You are working in a different language entirely

## TypeScript Discipline

### Typing
- Enable `strict: true` in tsconfig. Never weaken it.
- Avoid `any` — use `unknown` when the type is genuinely unknown, then narrow with `typeof` or `instanceof`.
- Avoid type assertions (`as Foo`) except at system boundaries (API responses, JSON parsing). Asserting inside business logic hides a type error.
- Avoid non-null assertions (`!`) — handle the null case explicitly.
- Prefer `interface` for object shapes, `type` for unions and aliases.
- Use discriminated unions instead of optional fields that only make sense together.

### Async Patterns
- Always `await` or chain `.catch()` on Promises — floating Promises are silent failures.
- Don't mix `async/await` and `.then()/.catch()` in the same function.
- In async event handlers, wrap the body in try/catch — unhandled async errors don't bubble to the caller.
- Prefer `Promise.all()` for independent parallel operations over sequential awaits.
- An `async` function that never `await`s is a code smell — check if it needs to be async.

### Error Handling
- Don't swallow errors with empty catch blocks.
- Use `catch (e: unknown)` and narrow with `instanceof` — not `catch (e: any)`.
- Typed error classes beat raw strings for recoverable, domain-specific errors.

### Modules
- Prefer named exports over default exports — easier to refactor and grep.
- Avoid circular imports — they cause subtle initialization bugs.
- Use tsconfig path aliases over deep relative imports (`../../../`).

## Testing Conventions

### Framework detection
- Check `package.json` devDependencies: `jest` → Jest, `vitest` → Vitest.
- Vitest is ESM-native and faster; Jest requires `--experimental-vm-modules` for ESM projects.
- Check `jest.config.*` or `vitest.config.*` for custom test root or file patterns.

### File placement
- **Colocated** (most common): `foo.ts` → `foo.test.ts` in the same directory.
- **Separate**: `src/foo.ts` → `tests/foo.test.ts` mirroring the source tree.
- Grep for existing test files to determine which convention the project uses before creating new ones.

### Writing tests
- Test behavior, not implementation. Inputs → outputs. Don't assert on private methods or internal state.
- Use `describe` blocks to group related scenarios; use `it` or `test` for individual cases.
- Test error paths explicitly — don't only test the happy path.
- For async tests, always `await` the assertion or return the Promise — an unawaited async test always passes.

### Mocking
- Mock at the module boundary (external deps, I/O), not internal helpers.
- Use `jest.spyOn` / `vi.spyOn` to assert side effects occurred without replacing the full module.
- Reset mocks between tests with `beforeEach(() => jest.resetAllMocks())` — shared mock state causes flaky tests.
- Excessive mocking often signals the code under test has too many dependencies.

## Common Review Catches
- Floating Promises (no `await`, no `.catch()`)
- `any` types introduced silently in new code
- Type assertions (`as`) inside business logic instead of at system boundaries
- `console.log` left in production code paths
- Missing `await` on async setup/teardown in tests (`beforeEach`, `afterEach`)
- `JSON.parse()` without try/catch at I/O boundaries
- `useEffect` with a stale or missing dependency array (React)
- Empty catch blocks or catch blocks that only log and re-throw the wrong type
