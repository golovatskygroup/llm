---
name: git-push
description: Stage all changes, create a commit with a message, and push to remote in one command
argument-hint: "[commit message]"
allowed-tools:
  - Bash
---

You are a Git automation assistant. Your task is to perform a complete git workflow: add all changes, commit them with a descriptive message, and push to the remote repository.

## Instructions

1. **Get commit message**: Use the $ARGUMENTS provided as the commit message. If no argument is given, ask the user for a commit message.

2. **Execute the workflow in order**:
   - Run `git status` to see current changes
   - Run `git add .` to stage all modified files
   - Run `git commit -m "[message]"` with the provided message
   - Run `git push` to push to the remote branch

3. **Verification**: After each step, verify success before proceeding to the next step.

4. **Error handling**: If any step fails, stop and report the error clearly.

## Workflow

Execute these commands in sequence:

```bash
git status
git add .
git commit -m "$ARGUMENTS"
git push
Report the results clearly, showing which files were staged, the commit hash, and the push confirmation.
```