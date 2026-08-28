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

1. installs `curl`, `xz-utils` and `git` via apt if missing
2. installs upstream **nix in multi-user (daemon) mode** (needs sudo)
3. sources the nix profile so the rest of the script can see nix
4. adds the channels — `nixpkgs-unstable` for root, `home-manager` master for
   the user (master pairs with unstable nixpkgs; a release channel would skew)
5. links `nix/nixpkgs-config.nix` into place and checks it parses
6. links `home.nix`, installs home-manager, runs `home-manager switch -b bak`
7. hands off to `just install`

Note that `<nixpkgs>` resolves through **root's** channel, not the user's, so
step 4 has a sudo half. Flakes are deliberately not enabled; this setup is
channel-based throughout.


Day to day
----------

```sh
just              # list every recipe
just install      # the standard set
just doctor       # check what is installed, missing or drifted
just switch       # rebuild the home-manager generation
just machine      # developer tooling installers (docker, terraform, ...)
```

### The standard set — `just install`

| Recipe | What it does |
| --- | --- |
| `install-nix-config` | links `nix/nixpkgs-config.nix` → `~/.config/nixpkgs/config.nix` |
| `install-home-manager` | links `home.nix`, then `home-manager switch -b bak` |
| `install-git` | adds the `include.path` to `~/.gitconfig` (see below) |
| `install-nvim` | clones the LazyVim starter if absent, links the tracked files |
| `install-obsidian` | installs the launcher and icons |

### Optional extras — invoke individually

| Recipe | What it does |
| --- | --- |
| `install-zellij` | config, default layout and the zjstatus plugin |
| `install-tmux` | `~/.tmux.conf` |
| `install-fonts` | the bundled FiraCode Nerd Fonts, then `fc-cache` |
| `install-completions` | fish completions for `just` |

`just uninstall` removes every symlink these recipes created, and leaves
machine-local files (`~/.gitconfig`) and anything home-manager owns alone.


Machine setup — `just machine`
------------------------------

Installers for developer tooling, as opposed to the shell and dotfile
personalization above. These live in `machine-setup.just`, loaded as a module:

```sh
just machine                     # list them
just machine install-docker      # run one
just machine verify-docker
just machine update-docker
```

(`just --list machine` also works. `just machine --list` does not.)

Covered: codex, docker, fastmail, herdr, openspec, ssm, temporal, terraform,
terragrunt, tfenv, vscode. Every tool has an `install-` / `verify-` / `update-`
triple, releases are checksum- or signature-verified, and nothing is installed
by piping a script into a shell.

Deliberately no `install-all`: these touch apt repositories, add the user to
groups and need sudo throughout, so they stay individually invokable. They are
not part of `just install` and `just doctor` does not check them — use the
per-tool `verify-` recipes.

These were previously the standalone `silverjam/artos-machine-setup` repo,
vendored here at `d1201d5`. This copy is the source of truth now.


How things get installed
------------------------

Three mechanisms, each doing what it is actually good at:

**home-manager** (`home.nix`) owns packages and the config files it can link
declaratively. It uses `config.lib.file.mkOutOfStoreSymlink`, so the installed
files are symlinks back into this repo rather than copies in the nix store —
edits are live and `git status` sees them.

**The Justfile** owns everything home-manager can't or shouldn't: bootstrapping,
things needing a network clone (the LazyVim starter), files that must stay
mutable (`~/.gitconfig`), and system caches (fonts, desktop database).

**`scripts/bootstrap.sh`** owns the cold start, up to the point where the other
two can run.

### `~/.gitconfig` is deliberately not a symlink

It holds per-machine identity — work email on one box, personal on another — so
it stays a real file. `just install-git` only ensures it *includes* the shared
`dotfiles/gitconfig`:

```ini
[include]
	path = ~/dev/dotfiles/dotfiles/gitconfig
```

Identity is filled in only if unset. To set it non-interactively:

```sh
just install-git "Your Name" you@example.com
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
