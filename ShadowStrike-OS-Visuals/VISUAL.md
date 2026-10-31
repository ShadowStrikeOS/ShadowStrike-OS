# ShadowStrike OS, drawn out

I made these five pictures because the README describes a platform
in three layers, and the honest state of it is easy to lose in that
description: what exists today is the design, the curated tool
manifest, the dotfiles, and the provisioning scaffold (v1) in this
repository. The full rig is not yet built, and this is not a
finished, downloadable distribution. The visuals say that where
they stand, not just here.

## The visuals

- [architecture.svg](architecture.svg): the platform as the README
  states it. Layer 0, the Apple Silicon Mac host. Layer 1, the
  OrbStack Kali daily driver. Layer 2, the native ARM64 Kali VM for
  kernel work. The cloud brain down the side, marked as a design
  that is not in this repo.
- [components.svg](components.svg): the files this repo actually
  holds, as job cards: provision.sh, tool-manifest.csv, sbom.sh,
  kernel-parity/, and the dotfiles and docs.
- [flowchart.svg](flowchart.svg): the build order from the README,
  as a staircase: snapshot, create the machine, copy the repo in,
  dry run, provision, manual rows, SBOM, snapshot again.
- [product-map.svg](product-map.svg): the product in one frame: who
  it serves, what goes in, what it gives back, and its boundaries.
- [statistics.svg](statistics.svg): the numbers from the table
  below, drawn as bars on paper.

Each sheet also ships as a PNG beside its SVG: the same drawing,
finished as a photograph of the paper page.

Every sheet here is drawn to look like what it is: a page sketched
by hand on paper, and each one is signed GK somewhere in the
drawing, never twice in the same place, because that is what I do
with a page I made.

## Written product map

What it is: a reproducible, customised Kali Linux platform for
authorised security work, built on an Apple Silicon Mac, designed
to be rebuilt from this repository. Today that means a scaffold:
provision.sh, the 56-tool manifest, the dotfiles, the kernel-parity
toolkit, the SBOM generator, and the snapshot discipline.

Who it serves: me, the operator (Epsilon0xCell), on systems,
networks, and accounts I own or am authorised in writing to test.
Scope is written down before an engagement starts.

Capabilities, grouped:

- Provisioning: provision.sh, idempotent, run inside a fresh
  OrbStack Kali machine. Directory layout, the apt rows of the
  manifest, dotfiles deployed with timestamped backups into
  ~/.shadowstrike-backups/, a wallpaper note, a weekly SBOM user
  timer, and the kernel-parity audit at the end. Its --dry-run
  prints every action, including every sudo call, and changes
  nothing.
- The loadout: tool-manifest.csv holds 56 tools across 9
  categories (web 10, terminal 9, recon 9, Active Directory 8,
  cloud 5, credentials 5, reporting 4, exploitation frameworks 3,
  post-exploitation 3), by source: 27 apt rows, 12 go, 9 pipx,
  7 manual, 1 github-release. Version pins are written only where
  verified; the rest are marked UNPINNED.
- Kernel parity: kernel-parity/audit.sh is a read-only audit of
  what the shared OrbStack kernel already has, and
  build-rtl88xxau.sh is the experimental, labelled route for the
  one out-of-tree wireless driver. PARITY.md explains the three
  routes honestly, including what is untested.
- Proof and recovery: sbom.sh writes a dated inventory under
  sbom/ (dpkg packages, pipx list, the manifest copy, a summary),
  and SNAPSHOTS.md sets the snapshot, export, and backup
  discipline, with OrbStack commands marked verified or
  unverified against the official documentation.

Inputs: this repository, an Apple Silicon Mac, OrbStack, a
Tailscale link from an iPhone, and, in the design, the cloud brain
services (Venice and the Agent Zero experience store). Outputs: a
provisioned OrbStack Kali machine when the build runs, dotfiles in
place, a dated SBOM, and snapshots to return to.

Boundaries, what it does NOT do: it is not a finished distribution
and there is nothing to download and boot. No kernel, installer
image, or built machine lives in this tree. The cloud brain is a
design, not code here. NightSalvo is named as the flagship
workload the platform exists to run; it is not shipped in this
repo. The Layer 2 VM exists as a plan and a scope, not as files.

## Statistics, with citations

Counted 2026-10-30, from the clone this folder ships in, at the
commit before this visuals commit (554f87b). Coverage note: I read
the README, SNAPSHOTS.md, provision.sh, sbom.sh, the kernel-parity
scripts and documents, the manifest, and the dotfiles in full.
That is every first-party text file in the tree; the only files
not read line by line are the LICENSE and the images.

| Number | Value | How it was counted, and from what |
|---|---|---|
| Files in the repo | 21 | git ls-files in the clone, counted 2026-10-30 |
| Shell lines (.sh) | 884 | Line count over the 4 tracked .sh files (provision.sh 221, sbom.sh 65, kernel-parity/audit.sh 347, kernel-parity/build-rtl88xxau.sh 251), by wc -l style counting over tracked files, binary and image files excluded, 2026-10-30 |
| Markdown lines | 474 | Line count over the 6 tracked .md files, same method, 2026-10-30 |
| No-extension lines | 107 | Line count over the 3 tracked files with no extension (LICENSE 21, dotfiles/.zshrc 85, sbom/.gitkeep 1), same method, 2026-10-30 |
| CSV lines | 57 | Line count over the 1 tracked .csv file (tool-manifest.csv: a header and 56 tool rows), same method, 2026-10-30 |
| tmux config lines | 56 | Line count over the 1 tracked .conf file (dotfiles/tmux.conf), same method, 2026-10-30 |
| JSONC lines | 54 | Line count over the 1 tracked .jsonc file (dotfiles/fastfetch/config.jsonc), same method, 2026-10-30 |
| Text lines | 16 | Line count over the 2 tracked .txt files (dotfiles/motd.txt and dotfiles/fastfetch/logo.txt), same method, 2026-10-30 |
| Commits | 5 | git log in the clone, counted 2026-10-30 |
| First commit | 2026-10-30 | git log, oldest entry, 2026-10-30 |
| Last commit before this one | 2026-10-30 | git log, newest entry, 2026-10-30 |
| Tests | No test suite exists, none run | No test files exist in git ls-files, checked 2026-10-30. I syntax-checked provision.sh and sbom.sh with bash -n (both parse), and ran provision.sh --dry-run with a throwaway HOME on 2026-10-30: it printed its directory, apt, and dotfile actions and changed nothing there. That is a scaffold check, not a test pass, and no pass is claimed. |
| Languages (API) | Shell 37,117 bytes | GitHub API, GET /repos/ShadowStrikeOS/ShadowStrike-OS/languages, read 2026-10-30 |
| Repo size (API) | 209 KB | GitHub API, GET /repos/ShadowStrikeOS/ShadowStrike-OS, size field, read 2026-10-30 |
| Stars / forks (API) | 1 / 0 | Same API response, read 2026-10-30 |

External statistics: none. No outside number says anything honest
about this repo, so the repo's own numbers are the whole table.

## Roadmap summary

Done: the design, the manifest, the dotfiles, and the provisioning
scaffold v1. Working now: the platform build itself is the open
work, in the README's own roadmap. Next: the first full provision
of the OrbStack daily driver, snapshotted. The full roadmap, with
the Later and Not planned sections, is in [ROADMAP.md](ROADMAP.md).
