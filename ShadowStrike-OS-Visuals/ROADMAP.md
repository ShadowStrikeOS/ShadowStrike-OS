# ShadowStrike OS roadmap

Written 2026-10-30 from the repo as it stands, including the
roadmap section the README already carries. No dates on the
future items. This repo is a scaffold, and this roadmap says so
in every section it applies to.

## Done

- The platform design, written in the README: the Apple Silicon
  Mac host, the OrbStack Kali daily driver, the native ARM64 Kali
  VM for kernel work, and the cloud brain.
- The curated tool manifest: 56 tools in tool-manifest.csv across
  9 categories, with honest UNPINNED marks where no version was
  verified.
- The dotfiles: zsh, tmux, fastfetch, MOTD, and the prompt
  fallback note.
- The provisioning scaffold v1: provision.sh (idempotent, with a
  --dry-run that prints every action and every sudo call),
  sbom.sh, and the kernel-parity toolkit (a read-only audit and
  the experimental RTL88xxAU driver build), plus SNAPSHOTS.md.

## Working now

- Nothing in flight inside this repo. The repo landed in one day,
  2026-10-30, and the work it points at, building the rig, happens
  on the machine, not in this tree. No TODO or FIXME notes exist
  anywhere in the repo, checked 2026-10-30.

## Next

These are the README's own roadmap items, in its order:

- Complete the first full provision of the OrbStack daily driver
  from the v1 scaffold and snapshot it.
- Close out the kernel-parity table; keep the ARM64 VM scoped to
  kernel, USB, and nested-virtualisation work only.
- Exercise the full remote loop, iPhone over Tailscale into
  Ghostty on the host, into the daily driver, as the standard way
  of working.

## Later

- Wire the cloud brain and the Agent Zero experience store into
  the daily workflow, so engagement lessons persist by default.
- Keep the manifest curated: tools enter by decision and leave at
  engagement close; the SBOM stays the proof.

## Not planned

- Shipping this as a downloadable distribution. The README is
  plain that the point is the opposite: if the machine dies, the
  platform is rebuilt from this repository.
- An internet-exposed SSH path into the host. Remote access is
  Tailscale only, by design.
- Forcing Kali kernel features into the OrbStack daily driver.
  Whatever parity cannot deliver is routed to Layer 2.
