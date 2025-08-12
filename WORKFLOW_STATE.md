# Workflow State Documentation

## ⚠️ CRITICAL: AI Assistant Warning

**DO NOT "FIX" THE SEED WORKSPACE DURING REFACTORING WORKFLOWS!**

This document exists because AI assistants consistently try to "fix" workspace/seed/ during configuration refactoring, which is **incorrect** and **breaks the workflow**.

## Current Workflow State: REFACTORING IN PROGRESS

**Active Workflow**: Nginx Configuration Update (Workflow #1 from PIPELINE_FLOWS.md)  
**Phase**: Monolithic → Modular Configuration Refactoring  
**Status**: In Progress

### What Each Workspace Represents RIGHT NOW:

```
workspace/seed/     ← OLD production state (monolithic nginx.conf)
    └── nginx.conf  ← Single monolithic config file
    └── NO conf.d/  ← This is CORRECT - old architecture

workspace/wip/      ← NEW refactored state (modular architecture)
    └── nginx.conf  ← Main config including conf.d/
    └── conf.d/     ← Modular site configurations

workspace/prep/     ← Built from NEW state (clean runtime)
    └── conf.d/     ← Present - built from wip

workspace/ship/     ← Built from NEW state (deployment package)
    └── conf.d/     ← Present - built from prep
```

## WHY seed SHOULD NOT HAVE conf.d/

- `seed` represents **production snapshot BEFORE refactoring**
- Adding conf.d/ to seed would **destroy the workflow integrity**
- Tests that expect conf.d/ in seed are **testing the wrong architecture**
- Seed must remain **unchanged** until refactoring is complete and deployed

## Integration Test Status

The following tests are **EXPECTED TO FAIL** during refactoring:

```bash
# FAILING - This is CORRECT behavior during refactoring
tests/integration/pipeline_flow.bats:
  - "seed workspace has valid structure" 
    └── Expects conf.d/ in seed (old architecture assumption)
  
  - "init-wip creates proper WIP workspace from seed"
    └── Expects old→old copy, but we're doing old→new refactoring
```

## Correct Actions for AI Assistants

### ✅ DO:
- Update test expectations to handle refactoring workflow
- Work with wip/, prep/, ship/ workspaces  
- Document the refactoring progress
- Fix issues in the NEW architecture (wip/conf.d/)

### ❌ DO NOT:
- Add conf.d/ directory to seed/
- "Fix" seed to match wip architecture
- Modify seed/nginx.conf to include conf.d/
- Assume seed is "broken" because it lacks conf.d/

## How to Handle Test Failures

When integration tests fail during refactoring:

1. **Identify if failure is refactoring-related**
   - Does it expect old architecture in seed?
   - Does it assume seed→wip is old→old copy?

2. **Update test expectations**
   - Skip tests that don't apply during refactoring
   - Add refactoring-aware test conditions
   - Test the actual workflow: old→new transformation

3. **Document test status**
   - Mark which tests are expected to fail
   - Explain why failure is correct

## Workflow Completion Criteria

Refactoring will be complete when:

1. ✅ New architecture works in wip/prep/ship
2. ✅ All sites functional with modular configs
3. ⏳ New architecture deployed to production
4. ⏳ seed updated with NEW production state
5. ⏳ Integration tests updated for new architecture

## Emergency Override

If you absolutely must modify seed during refactoring:

1. **Document the reason** in git commit
2. **Update this file** to reflect the change
3. **Notify the team** about workflow state change

## References

- `PIPELINE_FLOWS.md` - Workflow #1: Nginx Configuration Update
- `HANDOVER.md` - Session history and refactoring progress
- `docs/BACKEND_SERVICES_ARCHITECTURE.md` - Future architecture plans

---
**Created**: 2025-08-12  
**Purpose**: Prevent AI assistants from breaking refactoring workflows  
**Status**: Refactoring in progress - seed intentionally represents old state