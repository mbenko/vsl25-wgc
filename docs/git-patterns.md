# Git 

For this repo we will use Git as our version control system.

## Branching Strategy

Protected main branch, require pull request for changes.

Release branches with code per environment. Require pull request that runs CI on create, and runs CD on merge.

Feature branches for new features with name `feature/feature-name`.

