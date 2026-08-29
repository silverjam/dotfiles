dotfiles
========

Config files, helper scripts and system customizations, plus the machinery to
install them on a new machine.

The repo is expected to live at `~/dev/dotfiles` — that path is baked into
`dotfiles/config.fish` and into `home.nix`.


Fresh machine
-------------

```sh
git clone <this repo> ~/dev/dotfiles
~/dev/dotfiles/scripts/bootstrap.sh
```

`scripts/bootstrap.sh` is plain POSIX sh with no dependencies, because it has to
run before nix, `just` and fish exist. It is idempotent — re-run it any time.
It:

1. installs `git` via apt if missing
2. runs `scripts/bootstrap-just.sh` — see below
3. runs `scripts/install-nix.sh` — see below
4. sources the nix profile so the rest of the script can see nix
5. links `nix/nixpkgs-config.nix` into place and checks it parses
6. links `home.nix`, installs home-manager, runs `home-manager switch -b bak`
7. hands off to `just install`

### Getting `just` before nix exists

`just` normally comes from `home.nix`, which is a problem when the thing you
want to run is `just machine install-nix`. `scripts/bootstrap-just.sh` breaks
that cycle by installing the standalone binary from GitHub into
`~/.local/bin`:

```sh
scripts/bootstrap-just.sh            # skips if just is already on PATH
scripts/bootstrap-just.sh --force    # install anyway
```

Linux x86_64 only, by design — it is a bootstrap shim, not a general
installer. It needs only `curl`, `tar` and `sha256sum` (no `jq`, which would
not be installed yet), resolves the latest release by following the
`/releases/latest` redirect, and verifies the tarball against the published
`SHA256SUMS` before unpacking.

It calls `scripts/bootstrap-path.sh` first, which puts `~/.local/bin` on PATH
for bash, zsh and fish. That script writes a marker-delimited block so re-runs
update in place, and leaves any shell alone that already handles `~/.local/bin`
— Ubuntu's stock `~/.profile` and `~/.bashrc` do. For fish it writes
`~/.config/fish/conf.d/00-local-bin.fish`, which is safe alongside
home-manager: home-manager only cleans up links it created itself.

Worth knowing which copy wins afterwards. `~/.local/bin` sits **ahead** of the
nix profile in PATH, so the bootstrap binary would keep shadowing the
nix-managed one and quietly go stale. `bootstrap.sh` therefore deletes
`~/.local/bin/just` once home-manager has provided its own. Running the script
by hand leaves the copy in place — remove it yourself, or re-run
`bootstrap.sh`, once nix is in charge.

### Installing nix by itself

`scripts/install-nix.sh` installs **upstream nix in multi-user (daemon) mode**
on top of an existing Linux system, then adds the channels: `nixpkgs-unstable`
for root and `home-manager` master for the user (master pairs with unstable
nixpkgs; a release channel would skew). It handles its own `curl`/`xz`
dependencies and is idempotent.

It is also exposed as a recipe, so it can be re-run or repaired without going
through the whole bootstrap:

```sh
just machine install-nix
just machine verify-nix
just machine update-nix
```

There is a chicken-and-egg to be aware of: `just` itself comes from `home.nix`,
so on a genuinely bare machine the recipe is not available yet — use
`scripts/bootstrap.sh`, which calls the same script. Both share one
implementation so they cannot drift.

Two things worth knowing about this setup. `<nixpkgs>` resolves through
**root's** channel, not the user's, so channel setup has a sudo half. And
flakes are deliberately not enabled; this is channel-based throughout, which is
also why `update-nix` uses the `nix-env` upgrade path the nix manual documents
for multi-user installs rather than the experimental `nix upgrade-nix`.


Day to day
----------

```sh
just              # list the top-level recipes
just install      # nix config, home-manager, then the config files
just doctor       # check what is installed, missing or drifted
just switch       # rebuild the home-manager generation
```

Two modules sit underneath. `just <module>` lists a module's recipes,
`just <module> <recipe>` runs one:

```sh
just dotfiles                    # link this repo's config files
just dotfiles install-nvim

just machine                     # install developer tooling
just machine install-docker
```

(`just --list dotfiles` also works. `just dotfiles --list` does not.)

### Top level — provisioning

| Recipe | What it does |
| --- | --- |
| `install` | `install-nix-config`, `install-home-manager`, then `just dotfiles install` |
| `install-nix-config` | links `nix/nixpkgs-config.nix` → `~/.config/nixpkgs/config.nix` |
| `install-home-manager` | links `home.nix`, then `switch` |
| `switch` | `home-manager switch -b bak`, sourcing the nix profile first |
| `doctor` | checks nix, channels, home-manager, git, and every managed link |
| `uninstall` | delegates to `just dotfiles uninstall` |

These stay at the top level rather than moving into a module because `install`
depends on them, and just cannot express dependencies across modules.

### `just dotfiles` — this repo's config files

| Recipe | What it does |
| --- | --- |
| `install` | `install-git`, `install-nvim`, `install-obsidian` |
| `install-git` | adds the `include.path` to `~/.gitconfig` (see below) |
| `install-nvim` | clones the LazyVim starter if absent, links the tracked files |
| `install-obsidian` | installs the launcher and icons |
| `install-zellij` | config, default layout and the zjstatus plugin |
| `install-tmux` | `~/.tmux.conf` |
| `install-fonts` | the bundled FiraCode Nerd Fonts, then `fc-cache` |
| `install-completions` | fish completions for `just` |
| `uninstall` | removes every symlink the module created |

The last four are not part of `just dotfiles install` — invoke them
individually.

### `just machine` — developer tooling

Installers for third-party tooling, as opposed to the personalization above.

| Group | Recipes |
| --- | --- |
| nix | `install-nix` (also used by the bootstrap) |
| apt bundles | `install-build-tools`, `install-dev-tools`, `install-sys-tools` |
| tools | codex, docker, fastmail, herdr, openspec, ssm, temporal, terraform, terragrunt, tfenv, vscode |

Everything has an `install-` / `verify-` / `update-` triple. Releases are
checksum- or signature-verified, and nothing is installed by piping a script
into a shell.

`build-tools` is the toolchain and headers `pyenv` needs to build Pythons.
Packages `home.nix` already provides are left out of these bundles, so the
nix-managed copy stays the one on PATH — `watchman` and `htop` are omitted for
that reason.

Deliberately no `install-all`, and `just doctor` does not check them: these
touch apt repositories, add the user to groups and need sudo throughout, so
they stay individually invokable. Use the per-tool `verify-` recipes.

These were previously the standalone `silverjam/artos-machine-setup` repo,
vendored at `d1201d5`; the apt bundles came from the "Machine Setup" notes in
`silverjam/yurts-notes.md`. This copy is the source of truth now.


How things get installed
------------------------

Three mechanisms, each doing what it is actually good at:

**home-manager** (`home.nix`) owns packages and the config files it can link
declaratively. It uses `config.lib.file.mkOutOfStoreSymlink`, so the installed
files are symlinks back into this repo rather than copies in the nix store —
edits are live and `git status` sees them.

**The Justfile and its modules** own everything home-manager can't or shouldn't:
bootstrapping, things needing a network clone (the LazyVim starter), files that
must stay mutable (`~/.gitconfig`), system caches (fonts, desktop database) and
third-party tool installers.

`scripts/link.sh` does the actual symlinking for every recipe that makes a link.
It is a script rather than a just recipe because just modules cannot call each
other's private recipes — a nested `just _link` from inside a module resolves
against the top-level Justfile instead.

**`scripts/bootstrap.sh`** owns the cold start, up to the point where the other
two can run.

### `~/.gitconfig` is deliberately not a symlink

It holds per-machine identity — work email on one box, personal on another — so
it stays a real file. `just dotfiles install-git` only ensures it *includes* the shared
`dotfiles/gitconfig`:

```ini
[include]
	path = ~/dev/dotfiles/dotfiles/gitconfig
```

Identity is filled in only if unset. To set it non-interactively:

```sh
just dotfiles install-git "Your Name" you@example.com
```

### `nix/nixpkgs-config.nix` must always parse

nixpkgs reads it on *every* evaluation. A file that is entirely commented out
parses as empty and breaks `home-manager switch` with `syntax error, unexpected
end of file`. `just doctor` checks this explicitly.


Notes
-----

- **zellij rewrites its own config.** `~/.config/zellij/config.kdl` is a symlink
  into this repo, so if zellij regenerates it the change lands in `git status`.
  Review before committing.
- **`lazy-lock.json` is not tracked.** `~/.config/nvim` is a starter clone, so a
  fresh machine resolves plugin versions afresh rather than reproducing an
  existing machine's.
- **Per-host config** is handled inside the files themselves —
  `lazyvim/lua/plugins/lazyvim.lua` picks a colorscheme from the hostname, and
  `dotfiles/alacritty.ganymede.toml` is a host variant.
- **terraform and terragrunt** are commented out in `home.nix` because they are
  non-free; `just machine install-terraform` / `install-terragrunt` handle them
  instead.
- **Not wired up:** `dotfiles/alacritty.toml`, `wezterm.lua`, `vimrc*`,
  `spacemacs`, `bash_aliases`, `vscode-keybindings.json`, and the WezTerm /
  Alacritty / Cursor `.desktop` files. The last three contain absolute
  `/home/jmob/...` paths; rewrite those to `@DOTFILES@` and
  `_install-desktop` will template them at install time.
