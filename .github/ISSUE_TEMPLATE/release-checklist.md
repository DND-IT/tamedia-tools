---
name: Release Checklist
about: Checklist for creating a new release
title: 'Release v[VERSION]'
labels: release
assignees: ''
---

## Pre-release Checklist

- [ ] All tests passing on main branch
- [ ] Version bumped in `scripts/common.sh`
- [ ] Version bumped in all Formula files
- [ ] CHANGELOG updated (if applicable)
- [ ] Documentation updated
- [ ] No hardcoded secrets or sensitive data

## Release Process

- [ ] Create and push version tag: `git tag v[VERSION] && git push origin v[VERSION]`
- [ ] Wait for GitHub Actions to create release
- [ ] Verify release artifacts uploaded correctly
- [ ] Test installation methods:
  - [ ] Direct installation: `curl -sSL .../install.sh | bash`
  - [ ] Homebrew installation (after tap update)

## Post-release

- [ ] Verify Homebrew tap PR created
- [ ] Merge Homebrew tap PR
- [ ] Test Homebrew installation: `brew tap dnd-it/tamedia-tools && brew install tamedia-tools`
- [ ] Update internal documentation
- [ ] Announce release in team channels

## Rollback Plan

If issues are found:
1. Delete the release in GitHub
2. Delete the tag: `git push --delete origin v[VERSION]`
3. Fix issues
4. Start release process again

---
Replace `[VERSION]` with the actual version number throughout this checklist.