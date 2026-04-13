---
mode: "agent"
description: "Generate comprehensive tests for the selected code following project conventions"
---
Generate comprehensive tests for the selected code following these conventions:

1. **Test runner**: Use {{TEST_FRAMEWORK}}
2. **Coverage**: Aim for every branch, every enum value, every guard condition
3. **Naming**: `describe('ModuleName')` → `it('should <behavior> when <condition>')`
4. **Fixtures**: Use in-memory mocks, not filesystem. Permanent fixtures in `test-fixtures/`, temp in temp dirs
5. **External dependencies**: Mock external services, database connections, and APIs. Never test with real infra
6. **Edge cases**: Include null/undefined, empty collections, boundary values, concurrent access

Output a complete test file ready to run.

