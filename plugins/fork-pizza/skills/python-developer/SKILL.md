---
name: python-developer
description: Implement and review Python code. Covers type hints, pytest conventions, async patterns, and common pitfalls to catch in review. Invoke before implementing or reviewing Python files.
metadata:
  model: inherit
---

## Use this skill when

- Implementing or reviewing Python code
- Writing or reviewing pytest tests
- Making decisions about async patterns, typing, or project structure in Python

## Do not use this skill when

- The task contains no Python files
- You are working in a different language entirely

## Python Discipline

### Type Hints
- Annotate all function signatures (parameters and return type). Unannotated public functions are a review flag.
- Use modern union syntax: `str | None` (Python 3.10+), not `Optional[str]` from `typing`.
- Use `TypeAlias` for complex reused types — don't repeat long type expressions.
- `Any` in annotations is a last resort, the same as `any` in TypeScript.
- If mypy or pyright is configured in the project, run it — type hints without a checker are decorative.

### Common Pitfalls
- **Mutable default arguments**: `def foo(items=[])` — the list is shared across all calls. Use `None` and initialize inside the function body.
- **Late binding closures**: variables in closures capture the variable, not its value at definition time. Use `lambda x=x: x` to capture the current value.
- **Import side effects**: modules that produce side effects on import cause subtle ordering bugs. Keep imports pure.
- **Catching broad exceptions**: `except Exception` hides bugs. Catch the specific exception type you expect.
- **Silencing exceptions**: `except: pass` is almost always wrong.

### Async Patterns (asyncio)
- Don't call synchronous blocking I/O inside `async def` — use `asyncio.to_thread()` to wrap blocking calls.
- Use `asyncio.gather()` for independent coroutines; prefer `asyncio.TaskGroup` (3.11+) for structured concurrency with proper cancellation.
- Avoid `asyncio.get_event_loop()` in application code — use `asyncio.run()` at the entry point.
- Async generators require `async for`, not `for`.

### Error Handling
- Catch specific exception types, not bare `except` or `except Exception`.
- Use `contextlib.suppress(SomeError)` when you genuinely and intentionally want to ignore a specific exception.
- Custom exception classes should inherit from a project-level base exception so callers can catch broadly when needed.

## Testing with pytest

### File placement
- Default pytest convention: `tests/` directory at project root.
- File naming: `test_*.py` (preferred) or `*_test.py` — pytest discovers both.
- Mirror the source tree: `src/auth/login.py` → `tests/auth/test_login.py`.
- Shared fixtures and plugins belong in `conftest.py` at the appropriate directory level.

### Fixtures
- Use fixtures for setup/teardown — not `setUp`/`tearDown` (that's unittest style).
- Scope fixtures to the narrowest appropriate level: `function` (default) > `module` > `session`. Over-scoping causes state leakage between tests.
- Fixtures that need cleanup use `yield` — code after `yield` is the teardown phase.

### Writing tests
- Use `pytest.mark.parametrize` for multiple input/output cases — don't repeat test bodies.
- Test the public interface, not internal implementation details.
- For async code, use `pytest-asyncio` and mark with `@pytest.mark.asyncio`.
- Use `pytest.raises(SomeError)` to assert exceptions — not try/except blocks in tests.

### Mocking
- Use `unittest.mock.patch` or `pytest-mock`'s `mocker` fixture.
- **Patch at the point of use, not the point of definition**: if `mymodule.py` does `import os`, patch `mymodule.os`, not `os`.
- `MagicMock` for objects; `patch` for module-level names and functions.
- Reset or scope mocks properly — shared mock state between tests causes order-dependent failures.

## Common Review Catches
- Mutable default arguments (`def foo(items=[])`)
- Missing type annotations on public functions
- `except Exception` or bare `except:` that swallows real errors
- Synchronous blocking I/O calls inside `async def`
- Missing `conftest.py` when multiple test files repeat the same fixture
- f-strings in logging calls: `logging.info(f"value: {x}")` — use `logging.info("value: %s", x)` for deferred formatting
- `print()` left in (use `logging`)
- Mutable class-level attributes shared across instances
