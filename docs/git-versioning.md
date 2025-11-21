# Versioning and Changelog Process

This project uses GitVersion and git-chglog to manage versioning and changelog generation. The process is automated using a GitHub Actions workflow.

## Versioning

### Tool: GitVersion
GitVersion is used to determine the version number based on the Git history and branching strategy.

### Workflow
1. **Trigger**: The workflow is triggered on pushes to the `main` and `feature/GitVersion` branches, as well as manually via `workflow_dispatch`.
2. **Checkout Code**: The code is checked out with full history.
3. **Install GitVersion**: GitVersion is downloaded and installed as a standalone binary.
4. **Run GitVersion**: GitVersion is executed to compute the version number, which is then stored in the workflow output.

## Changelog

### Tool: git-chglog
git-chglog is used to generate or update the `CHANGELOG.md` file based on the Git history.

### Workflow
1. **Install git-chglog**: The git-chglog binary is downloaded and installed.
2. **Generate/Update Changelog**: git-chglog is run to generate or update the `CHANGELOG.md` file. If the configuration file `.chglog/config.yml` is not found, a default one is generated.

## Commit and Tag

### Workflow
1. **Commit Changes**: If there are changes to the `CHANGELOG.md`, they are committed with a message indicating the version update.
2. **Tag Release**: A Git tag is created with the computed version number and pushed to the repository.

## GitHub Release

### Workflow
1. **Create Release**: The workflow uses the `softprops/action-gh-release` action to create a GitHub release with the generated changelog as the release body.

## Summary of Workflow Steps
1. **Checkout Code**: Fetch the full history of the repository.
2. **Install GitVersion**: Download and install GitVersion.
3. **Run GitVersion**: Compute the version number using GitVersion.
4. **Install git-chglog**: Download and install git-chglog.
5. **Generate/Update Changelog**: Generate or update the `CHANGELOG.md` file using git-chglog.
6. **Commit Changes**: Commit the changes to `CHANGELOG.md` if any.
7. **Tag Release**: Create and push a Git tag with the computed version number.
8. **Create GitHub Release**: Create a GitHub release with the changelog as the release body.

This automated process ensures that versioning and changelog updates are consistent and based on the project's Git history and branching strategy.