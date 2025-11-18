# 🐙 GitHub Integration Guide

> Comprehensive documentation for the Background AI Agent GitHub integration

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Setup](#setup)
- [Architecture](#architecture)
- [API Reference](#api-reference)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

---

## Overview

The Background AI Agent includes a powerful GitHub integration that automatically monitors your repositories, analyzes pull requests, detects issues, and provides AI-powered code reviews.

### Key Capabilities

- **Automatic PR Discovery**: Scans your repositories every 5 minutes for new pull requests
- **AI-Powered Code Review**: Uses Claude AI to analyze code changes and identify issues
- **Intelligent Caching**: Reduces API calls with smart caching strategies
- **Rate Limiting**: Respects GitHub API limits with built-in throttling
- **Queue Management**: Processes PRs efficiently with priority queuing
- **Auto-Commenting**: Posts detailed analysis comments on PRs with high-severity issues
- **Comprehensive Metrics**: Tracks analyzed PRs, issues found, and more

---

## Features

### 1. Real-Time PR Monitoring

The GitHub Monitor continuously scans your repositories for new pull requests and analyzes them automatically.

**What it does:**
- Fetches your top 10 most recently updated repositories
- Checks each repository for open pull requests
- Analyzes new PRs that haven't been checked yet
- Caches repository lists for 5 minutes to reduce API calls

### 2. AI-Powered Code Analysis

Each PR is analyzed using Claude AI to identify:

- **Bugs**: Potential runtime errors and logic issues
- **Security Vulnerabilities**: SQL injection, XSS, authentication issues
- **Performance Problems**: Memory leaks, inefficient algorithms, N+1 queries
- **Code Quality Issues**: Poor naming, duplication, complexity
- **Best Practice Violations**: Anti-patterns and style issues

### 3. Intelligent Filtering

Not all PRs are analyzed. The system intelligently filters based on:

- PR age (skips very old PRs)
- Already analyzed (tracks checked PRs)
- Queue capacity (max 20 PRs queued)
- Diff size (limits to first 500 lines for large PRs)

### 4. Auto-Commenting

When high-severity issues are found, the agent automatically posts a comment on the PR with:

- Detailed issue descriptions with file and line numbers
- Security concerns highlighted
- Performance notes
- Improvement suggestions
- Overall quality rating and recommendation

### 5. Rate Limiting & Retry Logic

Built-in safeguards to prevent API abuse:

- Minimum 2-second delay between API calls
- Automatic retry with exponential backoff (1s, 2s, 4s)
- Rate limit detection and handling
- Respects GitHub's X-RateLimit headers

---

## Setup

### Prerequisites

1. macOS 14.0 (Sonoma) or later
2. GitHub Personal Access Token with appropriate scopes
3. Claude API key (for AI analysis)

### Step 1: Generate GitHub Token

1. Go to [GitHub Settings > Developer Settings > Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "Background AI Agent"
4. Select the following scopes:
   - `repo` (Full control of private repositories)
   - `read:user` (Read user profile data)
   - `read:org` (Read org and team membership)
5. Click "Generate token"
6. **Save the token securely** - you won't be able to see it again!

### Step 2: Configure the Agent

**Option A: Environment Variables**

```bash
export GITHUB_TOKEN="ghp_your_token_here"
export CLAUDE_API_KEY="sk-ant-your_key_here"
```

**Option B: Settings Panel**

1. Launch the Background AI Agent
2. Click the menu bar icon
3. Open Settings
4. Enter your GitHub token and Claude API key
5. Tokens are stored securely in macOS Keychain

### Step 3: Enable GitHub Integration

In Settings, ensure "Enable GitHub Integration" is checked.

### Step 4: Verify Setup

Check the console output:

```
✅ GitHub monitor started - checking every 5 minutes
🔍 Checking GitHub for new PRs...
✅ Found 15 repositories
📋 Found 3 open PRs in my-awesome-repo
```

---

## Architecture

### Components

#### 1. **GitHubMonitor** (`GitHubMonitor.swift`)

The main orchestrator for GitHub monitoring.

**Responsibilities:**
- Manages monitoring lifecycle (start/stop)
- Schedules periodic PR checks
- Maintains PR queue and cache
- Tracks metrics and status

**Key Features:**
- Rate limiting with configurable delays
- Repository caching (5-minute expiry)
- PR queue management (max 20 items)
- Comprehensive error handling

#### 2. **GitHubService** (`GitHubService.swift`)

Low-level GitHub API client.

**Responsibilities:**
- Makes HTTP requests to GitHub API
- Handles authentication
- Parses API responses
- Implements retry logic

**API Methods:**
- `getRepositories()` - Fetch user repos
- `getPullRequests()` - Get PRs for a repo
- `getPullRequestDiff()` - Get PR diff
- `getPullRequestFiles()` - Get changed files
- `createIssueComment()` - Post comments
- `createReviewComment()` - Submit PR reviews
- `getRateLimit()` - Check API rate limits
- `getIssues()` - Fetch repository issues
- `createIssue()` - Create new issues
- `getRepositoryStats()` - Get repo statistics
- `getCommits()` - Fetch commit history
- `getBranches()` - List branches
- `getWorkflowRuns()` - Get CI/CD runs
- `approvePullRequest()` - Approve a PR

#### 3. **AIService** (`AIService.swift`)

Handles AI-powered code analysis.

**Responsibilities:**
- Integrates with Claude API
- Analyzes code for issues
- Generates fix suggestions
- Provides PR reviews

#### 4. **AgentEngine** (`AgentEngine.swift`)

Coordinates all monitoring systems.

**Responsibilities:**
- Starts/stops GitHub monitor
- Routes activities to UI
- Manages memory database

### Data Flow

```
┌─────────────────┐
│  GitHubMonitor  │ ──── Timer (5 min) ───> Check Repos
└────────┬────────┘
         │
         ├──> GitHubService.getRepositories()
         │
         ├──> For each repo:
         │    └──> GitHubService.getPullRequests()
         │
         ├──> For each PR:
         │    ├──> shouldAnalyzePR() (filtering)
         │    └──> addToQueue()
         │
         ├──> processQueue()
         │    └──> For each PR in queue:
         │         ├──> GitHubService.getPullRequestDiff()
         │         ├──> AIService.analyzePullRequest()
         │         └──> postAnalysisComment() (if high severity)
         │
         └──> Update metrics & notify user
```

---

## API Reference

### GitHubMonitor

#### `start(onActivity:)`

Starts the GitHub monitoring service.

```swift
let monitor = GitHubMonitor()
monitor.start { activity in
    print("Activity: \(activity.title)")
}
```

#### `stop()`

Stops the monitoring service and logs final metrics.

```swift
monitor.stop()
```

#### `scanPullRequest(url:)`

Manually scan a specific PR by URL.

```swift
await monitor.scanPullRequest(url: "https://github.com/owner/repo/pull/123")
```

#### `getMetrics()`

Get current monitoring statistics.

```swift
let metrics = monitor.getMetrics()
print("PRs Analyzed: \(metrics.totalPRsAnalyzed)")
print("Issues Found: \(metrics.totalIssuesFound)")
print("Queue Size: \(metrics.queueSize)")
print("Status: \(metrics.statusDescription)")
```

#### `clearCache()`

Clear the repository cache, forcing a fresh fetch on next check.

```swift
monitor.clearCache()
```

#### `resetMetrics()`

Reset all tracking metrics to zero.

```swift
monitor.resetMetrics()
```

### GitHubService

#### `getRepositories()`

Fetch all repositories for the authenticated user.

```swift
let repos = try await GitHubService.shared.getRepositories()
for repo in repos {
    print("Repo: \(repo.name)")
}
```

#### `getPullRequests(owner:repo:)`

Get open pull requests for a repository.

```swift
let prs = try await GitHubService.shared.getPullRequests(
    owner: "facebook",
    repo: "react"
)
```

#### `getPullRequestDiff(owner:repo:number:)`

Get the diff for a specific PR.

```swift
let diff = try await GitHubService.shared.getPullRequestDiff(
    owner: "owner",
    repo: "repo",
    number: 123
)
```

#### `createIssueComment(owner:repo:number:body:)`

Post a comment on a PR or issue.

```swift
try await GitHubService.shared.createIssueComment(
    owner: "owner",
    repo: "repo",
    number: 123,
    body: "Great work! LGTM 🎉"
)
```

#### `getRateLimit()`

Check current API rate limit status.

```swift
let rateLimit = try await GitHubService.shared.getRateLimit()
print("Remaining: \(rateLimit.remaining)/\(rateLimit.limit)")
print("Resets in: \(Int(rateLimit.timeUntilReset)) seconds")
print("Percent remaining: \(rateLimit.percentRemaining)%")
```

#### `getIssues(owner:repo:state:)`

Fetch issues for a repository.

```swift
let issues = try await GitHubService.shared.getIssues(
    owner: "owner",
    repo: "repo",
    state: "open"
)
```

#### `createIssue(owner:repo:title:body:labels:)`

Create a new issue.

```swift
let issue = try await GitHubService.shared.createIssue(
    owner: "owner",
    repo: "repo",
    title: "Bug: App crashes on launch",
    body: "Detailed description...",
    labels: ["bug", "priority-high"]
)
```

#### `getRepositoryStats(owner:repo:)`

Get repository statistics.

```swift
let stats = try await GitHubService.shared.getRepositoryStats(
    owner: "owner",
    repo: "repo"
)
print("⭐ Stars: \(stats.stars)")
print("🍴 Forks: \(stats.forks)")
print("🐛 Open Issues: \(stats.openIssues)")
```

#### `approvePullRequest(owner:repo:number:comment:)`

Approve a pull request.

```swift
try await GitHubService.shared.approvePullRequest(
    owner: "owner",
    repo: "repo",
    number: 123,
    comment: "Looks good to me!"
)
```

---

## Configuration

### AppConfig Settings

Located in `Config.swift`:

```swift
// GitHub API settings
static let githubToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
static let githubAPIURL = "https://api.github.com"
static let githubCheckInterval: TimeInterval = 300.0 // 5 minutes

// Feature flags
static var enableGitHubIntegration = true
```

### GitHubMonitor Settings

```swift
// Rate limiting
private let minAPICallInterval: TimeInterval = 2.0 // Min delay between calls

// Caching
private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

// Queue management
private let maxQueueSize = 20 // Maximum PRs in queue
```

### Customization

To change the monitoring interval:

```swift
// In AppConfig.swift
static let githubCheckInterval: TimeInterval = 600.0 // 10 minutes
```

To change the cache duration:

```swift
// In GitHubMonitor.swift
private let cacheValidityDuration: TimeInterval = 600 // 10 minutes
```

---

## Usage Examples

### Example 1: Basic Monitoring

```swift
// Start monitoring
let monitor = GitHubMonitor()
monitor.start { activity in
    print("📢 \(activity.title): \(activity.description)")
}

// Monitor will now check GitHub every 5 minutes
// and post activities when PRs are analyzed
```

### Example 2: Manual PR Scan

```swift
// Scan a specific PR
Task {
    await monitor.scanPullRequest(
        url: "https://github.com/myorg/myrepo/pull/456"
    )
}
```

### Example 3: Check Rate Limits

```swift
Task {
    do {
        let rateLimit = try await GitHubService.shared.getRateLimit()

        if rateLimit.isExceeded {
            print("⚠️ Rate limit exceeded!")
            print("Resets in \(Int(rateLimit.timeUntilReset)) seconds")
        } else {
            print("✅ \(rateLimit.remaining) requests remaining")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

### Example 4: Get Monitoring Metrics

```swift
let metrics = monitor.getMetrics()

print("=== GitHub Monitor Stats ===")
print("Total PRs Analyzed: \(metrics.totalPRsAnalyzed)")
print("Total Issues Found: \(metrics.totalIssuesFound)")
print("Queue Size: \(metrics.queueSize)")
print("Cached Repos: \(metrics.cachedRepoCount)")
print("Status: \(metrics.statusDescription)")
```

### Example 5: Fetch Repository Stats

```swift
Task {
    do {
        let stats = try await GitHubService.shared.getRepositoryStats(
            owner: "facebook",
            repo: "react"
        )

        print("📊 React Repository Stats:")
        print("  ⭐ Stars: \(stats.stars)")
        print("  🍴 Forks: \(stats.forks)")
        print("  🐛 Open Issues: \(stats.openIssues)")
        print("  👀 Watchers: \(stats.watchers)")
        print("  💾 Size: \(stats.size) KB")
        if let language = stats.language {
            print("  📝 Language: \(language)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

---

## Troubleshooting

### Issue: "GitHub token not configured"

**Solution:**
1. Verify your token is set: `echo $GITHUB_TOKEN`
2. Check Settings panel in the app
3. Ensure token has correct scopes (repo, read:user)

### Issue: "Rate limit exceeded"

**Solution:**
1. Check rate limit status: `GitHubService.shared.getRateLimit()`
2. Wait for rate limit reset (usually 1 hour)
3. Consider reducing check frequency in AppConfig
4. Use repository caching (already enabled)

### Issue: "No PRs being analyzed"

**Troubleshooting steps:**
1. Check if you have open PRs in your repositories
2. Verify GitHub integration is enabled in Settings
3. Check console for errors: `log stream --predicate 'process == "BackgroundAIAgent"'`
4. Clear cache: `monitor.clearCache()`

### Issue: "Network errors"

**Solution:**
- The system automatically retries with exponential backoff
- Check your internet connection
- Verify GitHub API is accessible: `curl https://api.github.com/zen`

### Issue: "AI analysis not working"

**Solution:**
1. Verify Claude API key is configured
2. Check Settings: `enableCodeAnalysis` is enabled
3. Check console for AI service errors

---

## Advanced Topics

### Custom PR Filtering

Modify `shouldAnalyzePR()` in `GitHubMonitor.swift`:

```swift
private func shouldAnalyzePR(_ pr: GitHubPR, in repo: GitHubRepo) -> Bool {
    let prId = "\(repo.name)#\(pr.number)"

    // Skip if already checked
    if checkedPRs.contains(prId) {
        return false
    }

    // Custom: Only analyze PRs from specific authors
    if pr.user.login != "specific-author" {
        return false
    }

    // Custom: Only analyze PRs with specific labels
    // (would need to fetch labels first)

    return true
}
```

### Webhook Integration

For real-time updates instead of polling, consider setting up a GitHub webhook:

1. Go to repo Settings > Webhooks
2. Add webhook URL pointing to your server
3. Select events: Pull requests, Issues, etc.
4. Implement webhook receiver in the app

### Extending API Methods

Add new methods to `GitHubService.swift`:

```swift
func getCollaborators(owner: String, repo: String) async throws -> [GitHubUser] {
    let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/collaborators")!
    let data = try await makeRequest(url: url)
    return try JSONDecoder().decode([GitHubUser].self, from: data)
}
```

### Performance Optimization

**Tips:**
1. Adjust `minAPICallInterval` based on your needs
2. Increase `cacheValidityDuration` for less frequent updates
3. Reduce `maxQueueSize` to process fewer PRs simultaneously
4. Limit repositories checked by filtering in `checkRealPRs()`

### Monitoring Multiple Organizations

```swift
// Extend GitHubService to fetch organization repos
func getOrganizationRepositories(org: String) async throws -> [GitHubRepo] {
    let url = URL(string: "\(AppConfig.githubAPIURL)/orgs/\(org)/repos?per_page=100")!
    let data = try await makeRequest(url: url)
    return try JSONDecoder().decode([GitHubRepo].self, from: data)
}

// Use in GitHubMonitor
let orgRepos = try await GitHubService.shared.getOrganizationRepositories(org: "myorg")
```

---

## Best Practices

### 1. **Rate Limit Management**

- Always check rate limits before intensive operations
- Cache aggressively to reduce API calls
- Use conditional requests with ETags when possible
- Respect the `Retry-After` header

### 2. **Error Handling**

- Catch specific errors: `GitHubError.rateLimitExceeded`, `GitHubError.networkError`
- Log errors with context for debugging
- Provide user-friendly error messages

### 3. **Security**

- Never commit API tokens to version control
- Store tokens in Keychain, not UserDefaults
- Use environment variables for development
- Limit token scopes to minimum required

### 4. **Performance**

- Process PRs asynchronously
- Use queue management to prevent overwhelming the system
- Limit diff size for AI analysis
- Cache frequently accessed data

### 5. **User Experience**

- Provide clear status updates
- Show progress for long operations
- Allow manual triggering of checks
- Display metrics and statistics

---

## API Rate Limits

GitHub API rate limits (with authentication):

- **REST API**: 5,000 requests per hour
- **Search API**: 30 requests per minute
- **GraphQL API**: 5,000 points per hour

**Current Usage:**
- Repository list: 1 request per 5 minutes (with caching)
- PR list per repo: 1 request per repo per 5 minutes
- PR diff: 1 request per PR analyzed
- Post comment: 1 request per comment

**Estimated Usage:**
- 10 repos × 12 checks/hour = 120 requests/hour
- 5 PRs analyzed/hour × 2 requests = 10 requests/hour
- **Total**: ~130 requests/hour (well within limits)

---

## Changelog

### Version 2.0 (Enhanced Edition)

**Added:**
- Real GitHub API integration (replaced simulation)
- Comprehensive error handling with retry logic
- Rate limit detection and handling
- Intelligent repository caching
- PR queue management system
- Additional API methods (issues, stats, commits, branches, workflows)
- Metrics tracking
- Manual PR scanning
- Auto-approval functionality

**Fixed:**
- Removed simulation code
- Fixed rate limiting issues
- Improved error messages

**Changed:**
- Check interval from 1 minute to 5 minutes
- Max diff size limited to 500 lines
- Queue size capped at 20 PRs

---

## Contributing

Contributions welcome! Areas for improvement:

- [ ] GraphQL API support
- [ ] Webhook integration
- [ ] Custom analysis rules
- [ ] PR template generation
- [ ] Multi-account support
- [ ] Analytics dashboard
- [ ] Export functionality

---

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review console logs: `log stream --predicate 'process == "BackgroundAIAgent"'`
3. Open an issue on GitHub with:
   - macOS version
   - App version
   - Console log output
   - Steps to reproduce

---

## License

MIT License - See LICENSE file for details

---

**Happy Coding! 🚀**

*Made with ❤️ and 🧠 by the Background AI Agent*
