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

Restore the memories **only** — always exclude `.claude/CLAUDE.md`, because the
global CLAUDE.md is managed by this repo's `claude` stow package (`stow` lays it
down as a symlink). Unpacking the tarball's copy would drop a real file where the
symlink belongs and make `stow claude` fail.

```bash
tar xzf claude-memory-transfer.tar.gz --exclude='.claude/CLAUDE.md' -C ~
cd ~/source/dotfiles && ./install.sh    # stow provides ~/.claude/CLAUDE.md + config
```

**Caveat:** the project folder names encode absolute paths (all
`-home-sirwassail-source-...`), so they assume the same username (`sirwassail`)
and the same `~/source/...` layout. If the username or paths differ on the target,
rename the folders to the new encoded paths or the memories won't attach to the
right project.

### Scrubbing the tarball from git after transfer

**Goal: leave no trace of the tarball in git history.** This is already handled by
design — `claude-memory-transfer.tar.gz` is listed in `.gitignore`, so it is **never
tracked or committed**. There is nothing to scrub from history; "scrubbing" is just
deleting the file.

Because it's never in a commit, the tarball does **not** travel via `git push` /
`git clone`. Move it to the new machine **out of band** — a direct file copy, `rsync`,
or USB — exactly so it stays out of history. Do **not** `git add -f` it: force-adding
puts the blob in a commit, and removing it afterward means rewriting history
(`git filter-repo` / BFG) and force-pushing — the opposite of easy.

### After the transfer is complete

This was a deliberate one-time move. When done, on the new machine:

```bash
rm ~/source/dotfiles/claude-memory-transfer.tar.gz   # nothing in git to clean up
```

Then **delete this entire "One-time Claude memory transfer" section from this CLAUDE.md**
(everything between the TEMPORARY comment markers) and commit.

<!-- ===== END TEMPORARY SECTION ===== -->
