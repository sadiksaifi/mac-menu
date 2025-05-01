# Contribution Guidlines

## Getting Started

To get started, please follow these steps:

1. Clone the repository to your local machine.
2. Create a new branch for your changes using the naming convention specified below.
3. Make your changes and commit them with a clear and descriptive message (see below for commit message guidelines).
4. Push your changes to your new branch.
5. Open a pull request with a clear description of your changes and add your respective reviewer(s) to the pull request.

## Branch Naming Convention

When creating a new branch, please use one of the following naming conventions:

- `feat/<branch-name>` for new feature development
- `bug/<branch-name>` for bug fixes
- `hotfix/<branch-name>` for critical bug fixes
- `refactor/<branch-name>` for code refactoring
- `docs/<branch-name>` for documentation updates

### Examples of Good Branch Names

```
feat/add-search-functionality
bug/fix-login-page
hotfix/resolve-data-not-saving
refactor/simplify-order-processing
docs/add-api-documentation
```

## Commit Message Guidelines

Please follow these guidelines when writing commit messages:

- Use imperative mood in the commit message (e.g. "Add feature" instead of "Added feature").
- Start the commit message with a verb in lowercase, such as "add", "fix", "update", "remove", "refactor", "docs", etc.
- Limit the first line to 72 characters or less.
- Add a brief summary of the changes in the blank line after the first line, if necessary.
- Be specific and descriptive about the changes made in the commit.
- Reference any issues that the commit fixes in the commit message using the syntax `fixes #<issue-number>`. For example, `fixes #42`.

### Examples of Good Commit Messages

```
feat: Implemented search functionality for products page
fix: Corrected spelling errors in login page
bug: Resolved issue with data not being saved to database
chore: Update dependencies to latest versions
docs: Add documentation for new API endpoint
refactor: Simplified logic for order processing
test: Add unit tests for user authentication
```

## FAQs

#### 1. How to close an issue using a commit?

- To close an issue using a commit message, use the syntax `fixes #<issue-number>` in the commit message. For example, `fixes #42`.

#### 2. How to close an issue using a pull request message?

- To close an issue using a pull request message, use the syntax `fixes #<issue-number>` in the pull request message. For example, `fixes #42`.

#### 3. How to link a pull request to an issue?

- To link a pull request to an issue, use the syntax `#<issue-number>` in the pull request message. For example, `#42`.

#### 4. How to link a pull request to multiple issues?

- To link a pull request to multiple issues, use the syntax `#<issue-number>` in the pull request message. For example, `#42, #43, #44`.

#### 5. How to link a pull request to an issue and close it?

- To link a pull request to an issue and close it, use the syntax `fixes #<issue-number>` in the pull request message. For example, `fixes #42`.

#### 6. How to link a pull request to multiple issues and close them?

- To link a pull request to multiple issues and close them, use the syntax `fixes #<issue-number>` in the pull request message. For example, `fixes #42, #43, #44`.

Thank you for your contributions!
