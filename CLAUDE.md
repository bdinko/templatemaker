# Fork notes (bdinko/templatemaker) - read before opening a PR upstream

This file exists only on the fork. Do not include it in a PR to
robertorenz/templatemaker.

## Start every upstream PR branch from `upstream/main`, never from this fork's `main`

This fork's `main` carries machine-specific commits that must never go upstream.
Commit `8c601aa` changes `agents/clarion-template-pro.md` and `skills/clarion-template/`
so they name this developer's Clarion installs and default to `clarion12`. Upstream
(Roberto Renz) has a different setup.

A branch cut from the fork's `main` carries those commits into the PR. That happened with
PR #42 (myCalendar 1.1, merged 2026-11). The maintainer had to strip the files himself and
asked for this:

> I left out the changes to agents/clarion-template-pro.md and skills/clarion-template/ that
> came in from your fork sync. They describe your own Clarion installs, which don't match the
> maintainer's setup. Next time, please keep those on a separate branch from template PRs.

### How to do it

```
git fetch upstream
git switch -c <topic> upstream/main
# ... make the change, commit ...
git push -u origin <topic>
gh pr create --repo robertorenz/templatemaker --base main --head bdinko:<topic>
```

Before opening the PR, check what it will send:

```
git diff --stat upstream/main...<topic>
```

The list must contain only the files the change is about. If `agents/` or `skills/` show up
and the PR is not about them, the branch came from the wrong base.

### Keep these apart

- **Template / designer / example work** goes in its own branch from `upstream/main`.
- **Skill and agent changes meant for upstream** go in a separate PR, also from
  `upstream/main`, written without any reference to this machine's installs.
- **Fork syncs** (`integration/sync-upstream-<date>`) merge `upstream/main` into the fork's
  `main` and go only to bdinko/templatemaker. They are never the base for an upstream PR.
