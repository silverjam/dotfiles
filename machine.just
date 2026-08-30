# Machine setup: installing developer tooling, beyond the shell/dotfile
# personalization the top-level Justfile handles.
#
# Loaded as a module, so these are invoked with a `machine` prefix:
#
#     just machine                 # list them
#     just machine install-docker  # run one
#
# (`just --list machine` also works; `just machine --list` does not.)
#
# Originally the standalone silverjam/artos-machine-setup repo, vendored here
# at d1201d5 ("Add herdr install/verify/update recipes with SHA-256
# verification"). This copy is the source of truth now.
#
# House style: every tool gets an install / verify / update triple, releases
# are checksum- or signature-verified, and nothing is installed by piping a
# script into a shell.

# Keep this first and keep it harmless: without a default recipe, a bare
# `just machine` silently runs whichever recipe happens to be first in the file.

# List the machine setup recipes
default:
    @just --list machine

# ---------------------------------------------------------------------------
# Nix
#
# Note the chicken-and-egg: `just` itself comes from home.nix, so on a truly
# bare machine you cannot run this recipe — use ./scripts/bootstrap.sh, which
# calls the same script. This recipe is for repairing or re-running the nix
# setup on a machine that already has just.
# ---------------------------------------------------------------------------

# Install nix (multi-user) on an existing Linux system, plus the channels
install-nix:
    @{{justfile_directory() / "scripts/install-nix.sh"}}

# Verify the nix installation and channels are healthy
verify-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi

    command -v nix >/dev/null 2>&1 || { echo "nix: command not found on PATH"; exit 1; }
    nix --version
    echo "nix is installed: $(command -v nix)"

    systemctl is-active --quiet nix-daemon.service \
        || { echo "nix-daemon: not active (a multi-user install needs it)"; exit 1; }
    echo "nix-daemon: active"

    # NIX_PATH being empty is fine — nix has a compiled-in default nix-path.
    # What matters is that <nixpkgs> actually resolves, through root's channel.
    nix-instantiate --eval -E '<nixpkgs>' >/dev/null 2>&1 \
        || { echo "<nixpkgs>: does not resolve"; exit 1; }
    echo "<nixpkgs>: $(nix-instantiate --eval -E 'builtins.toString <nixpkgs>' | tr -d '\"')"

    sudo -n nix-channel --list 2>/dev/null | grep -q '^nixpkgs ' \
        && echo "root channel: nixpkgs present" \
        || echo "root channel: unverified (needs sudo)"
    nix-channel --list | grep -q '^home-manager ' \
        || { echo "user channel: home-manager missing"; exit 1; }
    echo "user channel: home-manager present"

# Update nix itself and the channels
update-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi

    # `nix upgrade-nix` is experimental and needs nix-command enabled, which
    # /etc/nix/nix.conf does not do here. This is the path the nix manual
    # documents for multi-user installs.
    sudo nix-channel --update
    sudo nix-env --install --attr nixpkgs.nix nixpkgs.cacert
    sudo systemctl daemon-reload
    sudo systemctl restart nix-daemon

    nix-channel --update
    echo "nix is now: $(nix --version)"

# Install openspec globally via npm
install-openspec:
    npm install -g @fission-ai/openspec

# Verify openspec was installed correctly
verify-openspec:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v openspec >/dev/null 2>&1 || { echo "openspec: command not found on PATH"; exit 1; }
    openspec --version
    echo "openspec is installed: $(command -v openspec)"

# Update openspec to the latest version
update-openspec: install-openspec verify-openspec

# Install Docker Engine from Docker's official apt repository (Ubuntu/Debian)
install-docker:
    #!/usr/bin/env bash
    set -euo pipefail

    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y "$pkg" 2>/dev/null || true
    done

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    . /etc/os-release
    codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    arch="$(dpkg --print-architecture)"

    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<SOURCES
    Types: deb
    URIs: https://download.docker.com/linux/ubuntu
    Suites: ${codename}
    Components: stable
    Architectures: ${arch}
    Signed-By: /etc/apt/keyrings/docker.asc
    SOURCES

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if id -nG "$USER" | grep -qw docker; then
        echo "user '$USER' is already in the docker group"
    else
        sudo usermod -aG docker "$USER"
        echo "added user '$USER' to the docker group; log out and back in (or run 'newgrp docker') for it to take effect"
    fi

# Verify Docker Engine was installed correctly
verify-docker:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v docker >/dev/null 2>&1 || { echo "docker: command not found on PATH"; exit 1; }
    docker --version
    docker compose version
    sudo systemctl is-active --quiet docker && echo "docker daemon: active" || { echo "docker daemon: not active"; exit 1; }

    if id -nG "$USER" | grep -qw docker; then
        echo "user '$USER' is in the docker group"
    else
        echo "user '$USER' is NOT in the docker group (run 'just install-docker' or 'sudo usermod -aG docker $USER', then log out and back in)"
    fi

    sudo docker run --rm hello-world

# Install OpenAI's Codex CLI from the latest hash-verified GitHub release (no piped install script)
install-codex:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v jq >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y jq; }

    case "$(uname -m)" in
        x86_64) target="x86_64-unknown-linux-musl" ;;
        aarch64) target="aarch64-unknown-linux-musl" ;;
        *) echo "install-codex: unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    tag="$(curl -fsSL "https://api.github.com/repos/openai/codex/releases/latest" | jq -r '.tag_name')"
    [ -n "$tag" ] && [ "$tag" != "null" ] || { echo "install-codex: could not resolve latest release tag"; exit 1; }
    echo "install-codex: latest release is ${tag}"

    asset="codex-${target}.tar.gz"
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    expected_sha="$(curl -fsSL "https://api.github.com/repos/openai/codex/releases/tags/${tag}" \
        | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .digest' \
        | sed 's/^sha256://')"
    [ -n "$expected_sha" ] || { echo "install-codex: could not resolve expected digest for ${asset}"; exit 1; }

    curl -fsSL -o "$workdir/$asset" \
        "https://github.com/openai/codex/releases/download/${tag}/${asset}"

    actual_sha="$(sha256sum "$workdir/$asset" | awk '{print $1}')"
    if [ "$actual_sha" != "$expected_sha" ]; then
        echo "install-codex: checksum mismatch for ${asset}"
        echo "  expected: $expected_sha"
        echo "  actual:   $actual_sha"
        exit 1
    fi
    echo "install-codex: verified sha256 for ${asset}: $actual_sha"

    tar -xzf "$workdir/$asset" -C "$workdir"
    install -Dm755 "$workdir/codex-${target}" "$HOME/.local/bin/codex"
    echo "codex installed to $HOME/.local/bin/codex"

# Verify Codex CLI was installed correctly
verify-codex:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v codex >/dev/null 2>&1 || { echo "codex: command not found on PATH"; exit 1; }

    installed_version="$(codex --version | awk '{print $2}')"
    [ -n "$installed_version" ] || { echo "verify-codex: codex --version did not report a version"; exit 1; }

    echo "codex is installed: $(command -v codex) (version $installed_version)"

# Update Codex CLI to the latest version (re-runs the install recipe)
update-codex: install-codex verify-codex

# Install Visual Studio Code from Microsoft's official apt repository
install-vscode:
    #!/usr/bin/env bash
    set -euo pipefail

    sudo apt-get update
    sudo apt-get install -y wget gpg
    sudo install -m 0755 -d /etc/apt/keyrings
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null

    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<SOURCES
    Types: deb
    URIs: https://packages.microsoft.com/repos/code
    Suites: stable
    Components: main
    Architectures: amd64,arm64,armhf
    Signed-By: /etc/apt/keyrings/microsoft.gpg
    SOURCES

    sudo apt-get update
    sudo apt-get install -y code

# Verify Visual Studio Code was installed correctly
verify-vscode:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v code >/dev/null 2>&1 || { echo "code: command not found on PATH"; exit 1; }
    code --version
    echo "vscode is installed: $(command -v code)"

# Update Visual Studio Code to the latest version
update-vscode:
    sudo apt-get update && sudo apt-get install -y code

# Install Fastmail's official desktop app via Flatpak/Flathub
install-fastmail:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v flatpak >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y flatpak; }
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.fastmail.Fastmail

# Verify the Fastmail desktop app was installed correctly
verify-fastmail:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v flatpak >/dev/null 2>&1 || { echo "flatpak: command not found on PATH"; exit 1; }
    flatpak info com.fastmail.Fastmail >/dev/null 2>&1 || { echo "com.fastmail.Fastmail: not installed"; exit 1; }
    version="$(flatpak info com.fastmail.Fastmail | awk -F': ' '/^ *Version/ {print $2}')"
    echo "fastmail is installed (version ${version:-unknown})"

# Update the Fastmail desktop app to the latest version
update-fastmail:
    sudo flatpak update -y com.fastmail.Fastmail

# Install Temporal's official CLI from the latest checksum-verified GitHub release (no piped install script)
install-temporal:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v jq >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y jq; }

    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) echo "install-temporal: unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    tag="$(curl -fsSL "https://api.github.com/repos/temporalio/cli/releases/latest" | jq -r '.tag_name')"
    [ -n "$tag" ] && [ "$tag" != "null" ] || { echo "install-temporal: could not resolve latest release tag"; exit 1; }
    version="${tag#v}"
    echo "install-temporal: latest release is ${tag}"

    asset="temporal_cli_${version}_linux_${arch}.tar.gz"
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    curl -fsSL -o "$workdir/checksums.txt" \
        "https://github.com/temporalio/cli/releases/download/${tag}/checksums.txt"
    curl -fsSL -o "$workdir/$asset" \
        "https://github.com/temporalio/cli/releases/download/${tag}/${asset}"

    (cd "$workdir" && grep " ${asset}\$" checksums.txt | sha256sum -c -)

    tar -xzf "$workdir/$asset" -C "$workdir"
    install -Dm755 "$workdir/temporal" "$HOME/.local/bin/temporal"
    echo "temporal installed to $HOME/.local/bin/temporal"

# Verify Temporal CLI was installed correctly
verify-temporal:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v temporal >/dev/null 2>&1 || { echo "temporal: command not found on PATH"; exit 1; }

    installed_version="$(temporal --version | awk '{print $3}')"
    [ -n "$installed_version" ] || { echo "verify-temporal: temporal --version did not report a version"; exit 1; }

    echo "temporal is installed: $(command -v temporal) (version $installed_version)"

# Update Temporal CLI to the latest version (re-runs the install recipe)
update-temporal: install-temporal verify-temporal

# Install the AWS Session Manager plugin from the latest GPG-signature-verified release (no piped install script)
install-ssm:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v gpg >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y gnupg2; }

    case "$(uname -m)" in
        x86_64) arch="ubuntu_64bit" ;;
        aarch64) arch="ubuntu_arm64" ;;
        *) echo "install-ssm: unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    base_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${arch}"
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    curl -fsSL -o "$workdir/session-manager-plugin.deb" "${base_url}/session-manager-plugin.deb"
    curl -fsSL -o "$workdir/session-manager-plugin.deb.sig" "${base_url}/session-manager-plugin.deb.sig"

    expected_fingerprint="7959 6371 24CE 093A D501 D47A 2C4D 4AFF 6F67 57EE"
    # base64 of AWS's published ASCII-armored public key (heredocs don't survive just's
    # leading-whitespace recipe indentation, so the key is inlined as one line instead)
    pubkey_b64="LS0tLS1CRUdJTiBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tCgptRklFWjVFUlF4TUlLb1pJemowREFRY0NBd1FqdVp5K0lqRm9ZZzU3c0xUR2hGM2FaTEJhR3B6QitnWTZqN0l4ClA3TnFicFh5alZqOGErZHk3OWdTZDY0T0VhTXhVYjd2dy9qdWcrQ2ZSWHdWR1JNTnRJQkJWMU1nVTFOTklGTmwKYzNOcGIyNGdUV0Z1WVdkbGNpQThjMlZ6YzJsdmJpMXRZVzVoWjJWeUxYQnNkV2RwYmkxemFXZHVaWEpBWVcxaAplbTl1TG1OdmJUNGdLRUZYVXlCVGVYTjBaVzF6SUUxaGJtRm5aWElnVTJWemMybHZiaUJOWVc1aFoyVnlJRkJzCmRXZHBiaUJNYVc1MWVDQlRhV2R1WlhJZ1MyVjVLWWtCQUFRUUV3Z0FxQVVDWjVFUlE0RWNRVmRUSUZOVFRTQlQKWlhOemFXOXVJRTFoYm1GblpYSWdQSE5sYzNOcGIyNHRiV0Z1WVdkbGNpMXdiSFZuYVc0dGMybG5ibVZ5UUdGdApZWHB2Ymk1amIyMCtJQ2hCVjFNZ1UzbHpkR1Z0Y3lCTllXNWhaMlZ5SUZObGMzTnBiMjRnVFdGdVlXZGxjaUJRCmJIVm5hVzRnVEdsdWRYZ2dVMmxuYm1WeUlFdGxlU2tXSVFSNVdXTnhKTTRKT3RVQjFIb3NUVXIvYjJkWDdnSWUKQXdJYkF3SVZDQUFLQ1JBc1RVci9iMmRYN3JPMUFRQ2Exa2lnM2xRNzhXL1FIR1U3NnVIeDNYQXl2MHRmcEU5VQpvUUJDSXdGTFNnRUEzUERIdDNsWitzNm05SkxHSnN5K0NwNVpGenBpRjZSZ2x1Ui8yZ0E4NjFNPQo9MkRRbQotLS0tLUVORCBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tCg=="
    echo "$pubkey_b64" | base64 -d > "$workdir/session-manager-plugin.gpg"

    gnupghome="$workdir/gnupg"
    mkdir -m 700 "$gnupghome"
    gpg --homedir "$gnupghome" --import "$workdir/session-manager-plugin.gpg"

    actual_fingerprint="$(gpg --homedir "$gnupghome" --fingerprint --with-colons 2C4D4AFF6F6757EE \
        | awk -F: '/^fpr:/ { print $10; exit }' | sed -E 's/(.{4})/\1 /g; s/ $//')"
    if [ "$actual_fingerprint" != "$expected_fingerprint" ]; then
        echo "install-ssm: public key fingerprint mismatch"
        echo "  expected: $expected_fingerprint"
        echo "  actual:   $actual_fingerprint"
        exit 1
    fi

    gpg --homedir "$gnupghome" --verify "$workdir/session-manager-plugin.deb.sig" "$workdir/session-manager-plugin.deb"
    echo "install-ssm: verified GPG signature for session-manager-plugin.deb"

    sudo dpkg -i "$workdir/session-manager-plugin.deb"
    echo "session-manager-plugin installed: $(command -v session-manager-plugin)"

# Verify the AWS Session Manager plugin was installed correctly
verify-ssm:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v session-manager-plugin >/dev/null 2>&1 || { echo "session-manager-plugin: command not found on PATH"; exit 1; }
    session-manager-plugin
    echo "session-manager-plugin is installed: $(command -v session-manager-plugin)"

# Update the AWS Session Manager plugin to the latest version (re-runs the install recipe)
update-ssm: install-ssm verify-ssm

# Install Terraform from HashiCorp's official apt repository (Ubuntu/Debian)
install-terraform:
    #!/usr/bin/env bash
    set -euo pipefail

    sudo apt-get update
    sudo apt-get install -y wget gpg
    sudo install -m 0755 -d /etc/apt/keyrings
    wget -qO- https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor | sudo tee /etc/apt/keyrings/hashicorp.gpg >/dev/null

    . /etc/os-release
    codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"

    sudo tee /etc/apt/sources.list.d/hashicorp.sources >/dev/null <<SOURCES
    Types: deb
    URIs: https://apt.releases.hashicorp.com
    Suites: ${codename}
    Components: main
    Architectures: amd64,arm64
    Signed-By: /etc/apt/keyrings/hashicorp.gpg
    SOURCES

    sudo apt-get update
    sudo apt-get install -y terraform

# Verify Terraform was installed correctly
verify-terraform:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v terraform >/dev/null 2>&1 || { echo "terraform: command not found on PATH"; exit 1; }
    terraform -version
    echo "terraform is installed: $(command -v terraform)"

# Update Terraform to the latest version
update-terraform:
    sudo apt-get update && sudo apt-get install -y terraform

# Install Terragrunt from the latest checksum-verified GitHub release (no piped install script)
install-terragrunt:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v jq >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y jq; }

    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) echo "install-terragrunt: unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    tag="$(curl -fsSL "https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest" | jq -r '.tag_name')"
    [ -n "$tag" ] && [ "$tag" != "null" ] || { echo "install-terragrunt: could not resolve latest release tag"; exit 1; }
    echo "install-terragrunt: latest release is ${tag}"

    asset="terragrunt_linux_${arch}"
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    curl -fsSL -o "$workdir/SHA256SUMS" \
        "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/SHA256SUMS"
    curl -fsSL -o "$workdir/$asset" \
        "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/${asset}"

    (cd "$workdir" && grep " ${asset}\$" SHA256SUMS | sha256sum -c -)

    install -Dm755 "$workdir/$asset" "$HOME/.local/bin/terragrunt"
    echo "terragrunt installed to $HOME/.local/bin/terragrunt"

# Verify Terragrunt was installed correctly
verify-terragrunt:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v terragrunt >/dev/null 2>&1 || { echo "terragrunt: command not found on PATH"; exit 1; }

    installed_version="$(terragrunt --version | awk '{print $3}')"
    [ -n "$installed_version" ] || { echo "verify-terragrunt: terragrunt --version did not report a version"; exit 1; }

    echo "terragrunt is installed: $(command -v terragrunt) (version $installed_version)"

# Update Terragrunt to the latest version (re-runs the install recipe)
update-terragrunt: install-terragrunt verify-terragrunt

# Install herdr, the coding-agent runtime, from the latest hash-verified GitHub release (no piped install script)
install-herdr:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v jq >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y jq; }

    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) echo "install-herdr: unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    tag="$(curl -fsSL "https://api.github.com/repos/herdrdev/herdr/releases/latest" | jq -r '.tag_name')"
    [ -n "$tag" ] && [ "$tag" != "null" ] || { echo "install-herdr: could not resolve latest release tag"; exit 1; }
    echo "install-herdr: latest release is ${tag}"

    asset="herdr-linux-${arch}"
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    expected_sha="$(curl -fsSL "https://api.github.com/repos/herdrdev/herdr/releases/tags/${tag}" \
        | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .digest' \
        | sed 's/^sha256://')"
    [ -n "$expected_sha" ] || { echo "install-herdr: could not resolve expected digest for ${asset}"; exit 1; }

    curl -fsSL -o "$workdir/$asset" \
        "https://github.com/herdrdev/herdr/releases/download/${tag}/${asset}"

    actual_sha="$(sha256sum "$workdir/$asset" | awk '{print $1}')"
    if [ "$actual_sha" != "$expected_sha" ]; then
        echo "install-herdr: checksum mismatch for ${asset}"
        echo "  expected: $expected_sha"
        echo "  actual:   $actual_sha"
        exit 1
    fi
    echo "install-herdr: verified sha256 for ${asset}: $actual_sha"

    install -Dm755 "$workdir/$asset" "$HOME/.local/bin/herdr"
    echo "herdr installed to $HOME/.local/bin/herdr"

# Verify herdr was installed correctly
verify-herdr:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v herdr >/dev/null 2>&1 || { echo "herdr: command not found on PATH"; exit 1; }

    installed_version="$(herdr --version | awk '{print $2}')"
    [ -n "$installed_version" ] || { echo "verify-herdr: herdr --version did not report a version"; exit 1; }

    echo "herdr is installed: $(command -v herdr) (version $installed_version)"

# Update herdr to the latest version (re-runs the install recipe)
update-herdr: install-herdr verify-herdr

# Install tfenv, a Terraform version manager, via git clone (official install method)
install-tfenv:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -d "$HOME/.tfenv" ]; then
        echo "install-tfenv: $HOME/.tfenv already exists, pulling latest instead"
        git -C "$HOME/.tfenv" pull --ff-only
    else
        git clone --depth=1 https://github.com/tfutils/tfenv.git "$HOME/.tfenv"
    fi

    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.tfenv/bin/"* "$HOME/.local/bin/"
    echo "tfenv installed to $HOME/.tfenv (symlinked into $HOME/.local/bin)"

# Verify tfenv was installed correctly
verify-tfenv:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v tfenv >/dev/null 2>&1 || { echo "tfenv: command not found on PATH"; exit 1; }
    tfenv --version
    echo "tfenv is installed: $(command -v tfenv)"

# Update tfenv to the latest version (re-runs the install recipe)
update-tfenv: install-tfenv verify-tfenv

# ---------------------------------------------------------------------------
# apt package bundles
#
# From the "Machine Setup" notes in silverjam/yurts-notes.md. Packages that
# home.nix already provides are deliberately left out, so the nix-managed copy
# stays the one on PATH: watchman and htop were dropped from these lists.
# ---------------------------------------------------------------------------

# Toolchain and headers for compiling from source. pyenv needs these to build
# Pythons; without them the builds fail late with missing-header errors.
build_tools := "autoconf automake build-essential cmake gdb pkg-config authbind " + \
               "libbz2-dev libedit-dev liblzma-dev libncurses-dev libpq-dev " + \
               "libreadline-dev libssl-dev libz-dev python3-dev tk-dev"

dev_tools := "pass zsh"

sys_tools := "wavemon iw kazam xclip inkscape"

# Install the build toolchain and headers needed to compile from source
install-build-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo apt-get update
    sudo apt-get install -y {{build_tools}}

# Verify the build toolchain is installed
verify-build-tools: (_verify_apt "build-tools" build_tools)

# Update the build toolchain to the latest packaged versions
update-build-tools:
    sudo apt-get update && sudo apt-get install -y {{build_tools}}

# Install assorted development tools
install-dev-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo apt-get update
    sudo apt-get install -y {{dev_tools}}

# Verify the development tools are installed
verify-dev-tools: (_verify_apt "dev-tools" dev_tools)

# Update the development tools to the latest packaged versions
update-dev-tools:
    sudo apt-get update && sudo apt-get install -y {{dev_tools}}

# Install assorted system and desktop utilities
install-sys-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo apt-get update
    sudo apt-get install -y {{sys_tools}}

# Verify the system utilities are installed
verify-sys-tools: (_verify_apt "sys-tools" sys_tools)

# Update the system utilities to the latest packaged versions
update-sys-tools:
    sudo apt-get update && sudo apt-get install -y {{sys_tools}}

# Report which packages in a bundle are installed, listing any that are missing
[private]
_verify_apt group packages:
    #!/usr/bin/env bash
    set -euo pipefail
    missing=()
    total=0
    for pkg in {{packages}}; do
        total=$((total + 1))
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "{{group}}: all $total packages installed"
    else
        echo "{{group}}: $((total - ${#missing[@]}))/$total installed, missing: ${missing[*]}"
        exit 1
    fi
