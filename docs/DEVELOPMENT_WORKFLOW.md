# Development Workflow

## Default Git Flow

Always use feature branches and PR workflow for better readability and review process.

### 1. Create Feature Branch
```bash
git checkout -b feature/descriptive-feature-name
```

### 2. Make Changes and Commit
```bash
# Stage your changes
git add [files]

# Commit with descriptive message
git commit -m "$(cat <<'EOF'
feat: brief description of feature

## Summary
- Key changes made
- Important improvements
- Architecture decisions

## Implementation Details
- Technical details
- New commands/features
- Breaking changes (if any)

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 3. Push Feature Branch
```bash
git push origin feature/descriptive-feature-name
```

### 4. Create Pull Request
- GitHub will show the PR creation link in the push output
- Or go to: `https://github.com/llm-case-studies/Nginx_RP_Pipeline/pull/new/feature/your-branch-name`
- Add detailed description of changes
- Request review if needed

### 5. After PR Approval
- Merge via GitHub interface
- Delete feature branch: `git branch -d feature/descriptive-feature-name`
- Pull latest main: `git checkout main && git pull origin main`

## Branch Naming Conventions

- **Features**: `feature/add-new-pipeline-stage`
- **Bug fixes**: `fix/resolve-container-networking`  
- **Docs**: `docs/update-deployment-guide`
- **Refactoring**: `refactor/cleanup-port-handling`

## Commit Message Format

Use conventional commits format:
- `feat:` for new features
- `fix:` for bug fixes  
- `docs:` for documentation
- `refactor:` for refactoring
- `test:` for tests
- `chore:` for maintenance

Always include Claude Code attribution and co-authorship.

## Example Workflow

```bash
# Start new feature
git checkout main
git pull origin main
git checkout -b feature/add-monitoring

# Make changes, test locally
./scripts/safe-rp-ctl start-ship  # verify works

# Commit and push
git add .
git commit -m "feat: add container monitoring dashboard"
git push origin feature/add-monitoring

# Create PR via GitHub link in output
# Merge after review
# Clean up
git checkout main
git pull origin main
git branch -d feature/add-monitoring
```

## Benefits

✅ **Better code review** - Changes are isolated and reviewable
✅ **Cleaner git history** - Main branch stays stable  
✅ **Easier rollback** - Can revert entire features cleanly
✅ **Team collaboration** - Multiple people can work on separate features
✅ **CI/CD integration** - Automated testing on PR branches