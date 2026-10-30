# SHADOWSTRIKE OS

A reproducible, customised Kali Linux platform for authorised security work,
built to be rebuilt: one provisioning script, one curated tool manifest, one
set of dotfiles, one snapshot discipline. If the machine dies, the platform
does not. It is rebuilt from this folder.

Operator: Epsilon0xCell
Mark: the globe-head operator (see `assets/`). Silver is the mark, green is
the signal. Static use of the logo is never recoloured, never stretched, and
never placed on a light background.

## Safety and authorisation

ShadowStrike OS is only ever used against networks, systems, and accounts the
operator owns or is authorised in writing to test. No exceptions, no grey
areas. Scope is written down before an engagement starts, and the tooling is
only pointed inside that scope. If authorisation is unclear, the work does
not start.

## Platform shape

Two layers, one platform, on a Mac with Apple Silicon:

1. **OrbStack Kali machine (the daily driver).** A Kali Linux machine running
   in OrbStack on ARM64. It carries the terminal workflow, the tool manifest,
   the agent system that runs on top of it, and day to day engagement work.
   OrbStack runs one shared kernel of its own for every machine, so this
   layer gets its Kali kernel features by parity, not by replacement: see
   `kernel-parity/` for the audit that measures which features the shared
   kernel already has and the experimental module route for the rest.
2. **A real ARM64 Kali VM (the kernel layer).** A full virtual machine from
   the official Kali ARM64 installer, reserved for kernel-level work and for
   the three things parity cannot deliver inside OrbStack:
   - fragmentation patching (kernel-level packet fragmentation work),
   - nested KVM (virtualisation inside the guest),
   - USB gadget functions (the guest acting as a USB device).
   This VM also owns any USB wireless adapter whose driver must be built
   against a genuine Kali kernel.

The split is deliberate. The daily driver stays light, fast, and disposable.
The kernel layer exists for the small set of jobs that truly need a kernel,
instead of forcing the whole platform to live in a heavy VM for their sake.

## What is in this folder

| Path | Purpose |
| --- | --- |
| `provision.sh` | Idempotent provisioning, run inside a fresh OrbStack Kali machine. Supports `--dry-run`. |
| `tool-manifest.csv` | The curated tool set. Roughly 56 tools, on purpose. |
| `dotfiles/` | zsh, tmux, fastfetch, MOTD, prompt fallback note. |
| `assets/` | The organisation logo, wallpaper and lock screen source. |
| `sbom.sh` | Generates a dated software inventory under `sbom/`. |
| `SNAPSHOTS.md` | Snapshot, export, and backup discipline. Read it before the first provision. |
| `kernel-parity/` | The kernel parity audit and the experimental driver build. |

## The manifest philosophy

Kali's full install is a warehouse. A flagship platform is a loadout.
`tool-manifest.csv` holds roughly 45 to 60 tools chosen because each one is
the current best answer for its job: the ProjectDiscovery suite for recon and
scanning, NetExec and Certipy for Active Directory, Caido as the intercepting
proxy, Prowler for cloud, Sliver as the manual C2 install, and a tight set of
terminal staples. Everything else is installed per engagement, recorded in
the manifest first, and removed when the engagement closes. Quality over
volume is the rule, and the SBOM proves what is actually installed.

Version pins: a pin is only written in the manifest where it was verified
against the tool's public release page. Everything else is marked UNPINNED,
which means the provision installs the current release and `sbom.sh` records
the exact version that landed. An honest UNPINNED beats an invented pin.

## Install order

Run these in order. Steps 1 to 3 happen on the host, step 4 onward inside
the machine.

1. **Snapshot the starting point.** Follow `SNAPSHOTS.md`: confirm the
   machine is listed and healthy before changing anything.
2. **Create the machine** (host): `orb create kali shadowstrike` creates a
   Kali machine named shadowstrike. Open a shell with `orb -m shadowstrike`.
3. **Copy this folder into the machine** (host): `orb push` this folder to
   the operator home inside the machine, or clone it there.
4. **Dry run first** (inside the machine): `./provision.sh --dry-run` prints
   every action, including every sudo call, and changes nothing. Read it.
5. **Provision** (inside the machine): `./provision.sh` installs the apt rows
   of the manifest, deploys the dotfiles (anything replaced is backed up into
   a timestamped folder under `~/.shadowstrike-backups/`), installs the MOTD
   and fastfetch configuration, writes the wallpaper note, and finishes by
   running the kernel-parity audit when it is present alongside.
6. **Install the manual rows.** BloodHound CE, Caido, Sliver, and the other
   rows marked manual in the manifest are installed by hand, following each
   project's own documentation, then recorded by the next SBOM run.
7. **Generate the SBOM**: `./sbom.sh` writes the dated inventory. Commit the
   manifest and the SBOM summary with the provision change.
8. **Snapshot again.** A provisioned, inventoried machine is the restore
   point. See `SNAPSHOTS.md`.

## Rebuilds and updates

`provision.sh` is idempotent: running it again converges the machine to the
manifest instead of stacking changes. Before any provision change, snapshot.
After any provision change, run `sbom.sh` and snapshot again. The kernel
parity audit is re-run after every OrbStack update, because a shared-kernel
update can change the parity table overnight.
