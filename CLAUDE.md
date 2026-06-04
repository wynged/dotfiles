# dotfiles

Personal dotfiles repo. **Migrating WSL → native Ubuntu — see [MIGRATION.md](MIGRATION.md)**
for the full intent, what changed, and the verification checklist to run on the
new machine before trusting any of this.

<!-- ===== TEMPORARY: ONE-TIME CLAUDE MEMORY TRANSFER ===== -->
<!-- DELETE this entire section (and the tarball) once the transfer is complete. -->

## One-time Claude memory transfer

`claude-memory-transfer.tar.gz` (in this repo root) is a one-time bundle of Claude Code
memory from the source machine. It contains 223 memory `.md` files across all projects
plus the global `~/.claude/CLAUDE.md`, with the full `.claude/...` path structure preserved.

### Restore on the target machine

The tarball lives **only on the `transfer` branch** — it is deliberately kept off
`main` so `main`'s history never contains it. After cloning, grab it from there:

```bash
git clone https://github.com/wynged/dotfiles ~/source/dotfiles
cd ~/source/dotfiles
git checkout transfer     # brings claude-memory-transfer.tar.gz into the working tree
```

Then restore the memories **only** — always exclude `.claude/CLAUDE.md`, because the
global CLAUDE.md is managed by this repo's `claude` stow package (`stow` lays it
down as a symlink). Unpacking the tarball's copy would drop a real file where the
symlink belongs and make `stow claude` fail.

```bash
tar xzf claude-memory-transfer.tar.gz --exclude='.claude/CLAUDE.md' -C ~
git checkout main                       # leave the tarball behind on transfer
./install.sh                            # stow provides ~/.claude/CLAUDE.md + config
```

**Caveat:** the project folder names encode absolute paths (all
`-home-sirwassail-source-...`), so they assume the same username (`sirwassail`)
and the same `~/source/...` layout. If the username or paths differ on the target,
rename the folders to the new encoded paths or the memories won't attach to the
right project.

### Scrubbing the tarball from git after transfer

The tarball is committed **only on the `transfer` branch**, never on `main` — so
`main`'s history is permanently tarball-free, and "scrubbing" is just deleting the
throwaway branch. No history rewrite, no force-push:

```bash
git checkout main
git branch -D transfer                 # delete locally
git push origin --delete transfer      # delete on GitHub
```

The blob is then unreferenced and GitHub garbage-collects it. **Never merge
`transfer` into `main`.** `.gitignore` lists the tarball so it can't be added to
`main` by accident — the `transfer` branch deliberately bypasses that with
`git add -f`. If you regenerate the tarball, force-add it on `transfer` only.

### After the transfer is complete

When the new machine is set up and verified:

1. `rm ~/source/dotfiles/claude-memory-transfer.tar.gz`
2. Delete the `transfer` branch (see "Scrubbing" above).
3. On `main`, **delete this entire "One-time Claude memory transfer" section**
   (everything between the TEMPORARY comment markers) and commit.

<!-- ===== END TEMPORARY SECTION ===== -->
