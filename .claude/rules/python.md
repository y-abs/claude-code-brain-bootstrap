---
paths:
  - "**/*.py"
---

# Python Conventions

> Path-scoped: auto-loaded when editing `.py` files.

- **Type hints on all function signatures** — including return types; no bare `def f(x):` in new code
- **Pydantic for data contracts** — validation and serialization at service boundaries
- **pytest** for testing — fixtures over `setUp/tearDown`, parameterize over copy-paste test blocks
- **ruff** for linting/formatting when available — falls back to flake8 + black
- **mypy** for type checking in CI — fix errors, don't `# type: ignore` by default
- **pathlib over os.path** — `Path(__file__).parent / "data"` not `os.path.join(os.path.dirname(...))`
- **Dataclasses or Pydantic models over plain dicts** — named fields, not `data["key"]` everywhere
- **`python3 -u`** in IDE terminals — unbuffered output; without `-u` output may be silently swallowed

