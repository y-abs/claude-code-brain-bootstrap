---
description: Create a structured plan for a task with checkable items
agent: "agent"
argument-hint: "[task description]"
---


Create a structured plan for the following task: {{input}}


## Instructions

1. Read `claude/tasks/lessons.md` for accumulated wisdom
2. Read `claude/architecture.md` for system context
3. Break the task into numbered, checkable steps
4. For each step, identify:
   - The exact files to modify
   - The change description
   - Dependencies on other steps
   - Risk areas and what to verify
5. Write the plan to `claude/tasks/todo.md` with checkable items
6. Identify which `claude/*.md` files are relevant and read them
7. Present the plan for approval before proceeding
