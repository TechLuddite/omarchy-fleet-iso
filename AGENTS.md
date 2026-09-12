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

The runtime repository is the sibling checkout `../omarchy-fleet`, mirroring `omacom/omarchy`. Its `agents/skills/fleet.md` carries the fleet design and is worth reading before changing anything here.

## What this fork has changed

One thing so far. `builder/build-iso.sh` used to name the three Omarchy packages separately in four places: the target list, the filter that withholds locally built packages from the online download, the keep-set that adds them back before pruning, and the expected-package count. Shipping a fourth package meant editing all four and keeping them in step, and missing the filter sends the new name to `pacman -Syw` against a mirror that does not carry it, which fails the build with a target-not-found error that does not explain itself.

They now live in one list in build order, published to `builder/build-omarchy-packages.sh` as `OMARCHY_PACKAGES`, with `OMARCHY_EXTRA_PACKAGES` appending to it. A build that ships another Omarchy package sets one environment variable. Default builds are unchanged, which `test/unit/offline-package-set-test.sh` asserts by evaluating the real blocks lifted out of the real files, since neither script can run outside the privileged build container.

## Branches that must stay clean

`fleet/generalise-local-packages` is cut from `quattro` and carries that change alone, so it can be offered to upstream unchanged. It fixes a real defect in their build and needs no fleet context to justify. Merging it into `fleet-main` is fine. Rebasing it onto `fleet-main` would ruin it.

## What is coming

The enrolment fields. The runtime side already reads `OMARCHY_FLEET_*` from the environment during system setup and writes a record, so the work here is a `fleet` object inside the existing `omarchy_install` block in `user_configuration.json` and the orchestrator passing it through. `omarchy-cidata-load` needs no change, because the fields live inside a file it already copies.

Two precedents in this repository make that straightforward. The kids mode branch adds `omarchy_install.profile` to the same block. And `tailscale_authkey` shows how a secret file on the autoinstall drive reaches a phase: the loader copies it, its path arrives in the orchestrator's environment, and the phase reads it. A deploy key for cloning a private configuration repository follows that path. The drive is readable by whoever holds it, so such a key must be per host, revocable, and scoped to one repository.

## Testing

```bash
./test/all
```

Fast, VM-free and session-free here: shell suites under `test/unit/` plus a Python suite. This is unlike the runtime repository, where the full suite drives whatever Wayland session is reachable. The QEMU scenarios live behind `./test/integration` and need a machine you are not using.

Building an ISO needs Docker, produces roughly six gigabytes, and takes a long time:

```bash
./bin/omarchy-iso-make --no-boot-offer --local-source ../omarchy-fleet ../omarchy-fleet-pkgs
```

## Repository settings that are deliberate

Upstream's nightly ISO build workflow is disabled here. It would otherwise build a full ISO unattended every night in a repository nobody is watching. Re-enable it only if someone is going to read the results.

Anything committed here has to stand on its own for a reader who has never seen this project's internal notes. No shorthand reference codes, no internal host names, no pointers to private records.
