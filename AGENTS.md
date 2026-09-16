# This is a fork

This repository mirrors `omacom/omarchy-iso` and carries the installer half of the Omarchy Fleet work. It is not a GitHub fork, so `upstream` has to be added by hand:

```bash
git remote add upstream https://github.com/omacom/omarchy-iso.git
```

Two branches matter and they have different rules.

- `quattro` is a pure mirror of upstream. **Never commit to it.** It is only ever fast-forwarded from `upstream/quattro`, which is what makes `git log quattro..fleet-main` the exact answer to what this fork has changed.
- `fleet-main` is the default branch and where every change lands. Branch from it, pull request into it.

```bash
git fetch upstream
git push origin upstream/quattro:quattro
```

Opening a pull request needs both ends named. `gh` takes a fork's parent as the default base, and this clone carries an `upstream` remote, so a bare `gh pr create` aims at `omacom/omarchy-iso` rather than at this fork. It has already done so once in the runtime repository and failed only because there were no commits between the two.

```bash
gh pr create --repo TechLuddite/omarchy-fleet-iso --base fleet-main --head <branch>
```

The runtime repository is the sibling checkout `../omarchy-fleet`, mirroring `omacom/omarchy`. Its `agents/skills/fleet.md` carries the fleet design and is worth reading before changing anything here.

## Signed commits

Sign every commit this fork adds to `fleet-main`. The signature has to verify on GitHub. What this fork produces is meant to run as root on machines that enrol, so who wrote a change must be checkable from the history alone.

Commit with signing as the maintainer's git configuration already sets it up. If a commit fails to sign, stop and report the error. Never work around it with `--no-gpg-sign`, `-c commit.gpgsign=false` or a change to git configuration.

Check before pushing. A signed commit shows a signature line and an unsigned one shows none:

```bash
git log --show-signature -1
```

Upstream's history is partly unsigned, which is expected. Fast-forwarding `quattro` creates no commits, so it needs no signature. Bringing new upstream commits into `fleet-main` is different. Once the branch requires signatures, GitHub blocks a pull request carrying unsigned commits whichever merge method is used, and only someone allowed to bypass the protection can merge it. That includes merging a clean branch cut from a newer `quattro` than `fleet-main` has already absorbed. That merge is the maintainer's call. Do not attempt it from a feature branch.

## What this fork has changed

One thing so far. `builder/build-iso.sh` used to name the three Omarchy packages separately in four places: the target list, the filter that withholds locally built packages from the online download, the keep-set that adds them back before pruning, and the expected-package count. Shipping a fourth package meant editing all four and keeping them in step, and missing the filter sends the new name to `pacman -Syw` against a mirror that does not carry it, which fails the build with a target-not-found error that does not explain itself.

They now live in one list in build order, published to `builder/build-omarchy-packages.sh` as `OMARCHY_PACKAGES`, with `OMARCHY_EXTRA_PACKAGES` appending to it. A build that ships another Omarchy package sets one environment variable. Default builds are unchanged, which `test/unit/offline-package-set-test.sh` asserts by evaluating the real blocks lifted out of the real files, since neither script can run outside the privileged build container.

## Branches that must stay clean

`fleet/generalise-local-packages` is cut from `quattro` and carries that change alone, so it can be offered to upstream unchanged. It fixes a real defect in their build and needs no fleet context to justify. Merging it into `fleet-main` is fine. Rebasing it onto `fleet-main` would ruin it.

## What is coming

The enrolment fields. The runtime side already reads `OMARCHY_FLEET_*` from the environment during system setup and writes a record, so the work here is a `fleet` object inside the existing `omarchy_install` block in `user_configuration.json` and the orchestrator passing it through. `omarchy-cidata-load` needs no change, because the fields live inside a file it already copies.

That work is worth more than it looks, because install-time enrolment is the only kind that survives a factory reset. `create_factory_snapshot` is the last phase of the install and the Omarchy configuration step runs well before it, so a record written from the environment during the install is inside the snapshot. A record written by hand afterwards is not, and a reset erases it. Verified on a booted machine on 2026-09-15.

Two precedents in this repository make that straightforward. The kids mode branch adds `omarchy_install.profile` to the same block. And `tailscale_authkey` shows how a secret file on the autoinstall drive reaches a phase: the loader copies it, its path arrives in the orchestrator's environment, and the phase reads it. A deploy key for cloning a private configuration repository follows that path. The drive is readable by whoever holds it, so such a key must be per host, revocable, and scoped to one repository.

## Testing

```bash
./test/all
```

Fast, VM-free and session-free here: shell suites under `test/unit/` plus a Python suite. This is unlike the runtime repository, where the full suite drives whatever Wayland session is reachable. The QEMU scenarios live behind `./test/integration` and need a machine you are not using.

Building an ISO needs Docker, produces roughly six gigabytes, and takes a long time:

```bash
./bin/omarchy-iso-make --no-boot-offer --keep-pkg-cache --local-source ../omarchy-fleet ../omarchy-fleet-pkgs
```

This has been run once, on 2026-09-15, and it works. Three things learned doing it.

**`--keep-pkg-cache` is not optional on a machine you use.** Without it `bin/omarchy-iso-make` runs `sudo rm -rf /var/cache/pacman/pkg/*` against the build host before it starts, which is the host's own downgrade and rollback cache. The flag exists so unattended builds need no interactive sudo, and skipping the purge costs the build nothing.

**An autoinstall drive has to name the development packages.** `builder/build-iso.sh` maps the `edge`, `dev` and `local` refs to `omarchy-dev` and `omarchy-settings-dev`, and `--local-source` sets the ref to `local`. The ISO exports those names into the configurator's environment, so an interactive install gets them right. A cidata drive skips the configurator and carries its own package list in `user_configuration.json`, so it has to agree by hand. A drive that asks for `omarchy` fails late, inside archinstall, with a target-not-found against an offline mirror that has no package by that name.

**A machine installed from one of these ISOs is only valid until it updates.** The fleet code ships inside `omarchy-dev`, which is the name upstream publishes on its edge channel, and the installed system points there. The package version is a commit count, so this build loses to upstream's whenever upstream's development branch is ahead of the branch point. Two machines were updated on 2026-09-15 and one `pacman -Syu` replaced the runtime package and removed every fleet command, the menu entry and the install leaf with no warning. Check `pacman -Q omarchy-dev` on a test machine before trusting a result from it.

## Bench machines

`bin/omarchy-fleet-vm-make` builds a persistent libvirt machine, installed unattended from a locally built ISO, and `bin/omarchy-fleet-vm-view` opens a viewer for each on a chosen Hyprland output.

They exist because none of the three routes already here leaves a machine behind. `bin/omarchy-iso-boot` boots an ISO in a throwaway QEMU process, `bin/omarchy-iso-test` drives the interactive install through OCR and keystrokes, and `test/integration` installs once and boots throwaway overlays of that base image. Checking that a menu entry appears only on an enrolled machine, or that a factory reset does what it claims, needs machines that survive a reboot and can be compared side by side.

```bash
bin/omarchy-fleet-vm-make 1
bin/omarchy-fleet-vm-make 2
OMARCHY_FLEET_VM_OUTPUT=<output> bin/omarchy-fleet-vm-view
```

The guest user and password match `GUEST_USER` and `GUEST_PASSWORD` in the integration harness, so a machine from either route is reached the same way.

**One duplication is deliberate and has to be kept in step.** `build_cidata` in `test/integration.d/base-test.sh` writes the same autoinstall drive and is the copy to follow. That function is welded to the harness it lives in and cannot be sourced from outside it, so the partition arithmetic exists twice. If one changes, change the other.

Each script carries what it cost to learn in its own header, including why the teardown does not use `undefine --remove-all-storage`, why a viewer is placed by focusing an output rather than moving a window, and why a window on the wrong output shows a remote watcher nothing. Read the header before changing either one.

## Repository settings that are deliberate

Upstream's nightly ISO build workflow is disabled here. It would otherwise build a full ISO unattended every night in a repository nobody is watching. Re-enable it only if someone is going to read the results.

Anything committed here has to stand on its own for a reader who has never seen this project's internal notes. No shorthand reference codes, no internal host names, no pointers to private records.
