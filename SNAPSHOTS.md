# Snapshot, export, and backup discipline

ShadowStrike OS is disposable by design and recoverable by discipline.
The rule is simple: **snapshot before every provision change, snapshot again
after it, and never let the only copy of a good state live inside the thing
it protects.**

## Verification status of the commands

Commands are marked by how they were checked against the public OrbStack
documentation (docs.orbstack.dev, machines commands page, read 2026-10-28).

VERIFIED in the official command list: `orb list`, `orb info`, `orb create`,
`orb start`, `orb stop`, `orb restart`, `orb delete`, `orb rename`,
`orb default`, `orb push`, `orb pull`, `orb config`, `orb version`.

UNVERIFIED: `orb clone`, `orb export`, and `orb import` for Linux machines
do **not** appear in the official OrbStack command list for machines, and no
official machines export or import page was found. They are widely assumed
to exist and third party tooling wraps export and import functions, but
until they are confirmed on the operator's own install with `orb help` and
`orb export --help`, this document treats them as UNVERIFIED and never makes
them the only copy of anything. Check first:

```sh
orb help
orb clone --help
orb export --help
orb import --help
```

If a command answers with real help text on the installed version, it can be
promoted to verified in this file, with the OrbStack version noted next to
it (`orb version`).

## The discipline

1. **Before a provision change**
   - Stop the machine cleanly: `orb stop shadowstrike` (VERIFIED).
   - Confirm state: `orb list` and `orb info shadowstrike` (VERIFIED).
   - Take the snapshot by whichever route is verified on this install:
     - Preferred, if verified locally: clone or export the machine and name
       it with the date and the reason, for example
       `shadowstrike-20261028-pre-provision` (UNVERIFIED commands, confirm
       first as above).
     - Fallback, always available: pull the platform state out of the
       machine with `orb pull` (VERIFIED): the shadowstrike-os folder, the
       `~/shadowstrike` work root (notes, reports, engagement records), and
       the latest `sbom/` output. Files pulled to the host are a backup of
       the state that matters, even without a machine image.
   - Record the snapshot in the log table below (date, name or location,
     what is about to change).
2. **Make the change.** Run `provision.sh` (dry run first), install manual
   manifest rows, or change dotfiles.
3. **After the change**
   - Run `./sbom.sh` inside the machine and pull the new SBOM out.
   - Snapshot again, the same way, named for the finished state, for example
     `shadowstrike-20261028-provisioned-v1`.
   - Keep at least two known-good states: the last provisioned state and
     the one before it. Delete older snapshots deliberately, never by
     accident, and never delete the only pre-change state before the new
     state has booted and passed a login check.
4. **Weekly floor.** Even with no changes, pull the work root and SBOM out
   once a week. Engagement notes are the irreplaceable part; the machine
   itself is rebuildable from this folder in one provision run.

## Restore steps

From a machine image, if clone or export and import are verified locally:

1. Stop any running copy: `orb stop shadowstrike` (VERIFIED).
2. Import or clone back the chosen snapshot under a scratch name first
   (UNVERIFIED commands; use the exact forms confirmed in `orb help`).
3. Start it, log in, run the kernel parity audit and a tool spot check
   (`nmap --version`, `fastfetch`).
4. Only when the scratch copy passes: `orb rename` (VERIFIED) it into place
   or point `orb default` (VERIFIED) at it, and record the restore in the
   log.

From files only, which always works:

1. Create a fresh machine: `orb create kali shadowstrike` (VERIFIED).
2. Push this folder in with `orb push` (VERIFIED) and run the install order
   in the README: dry run, provision, manual rows, SBOM.
3. Restore the pulled `~/shadowstrike` work root over the fresh one.
4. Run the kernel parity audit. The parity table from the old machine is in
   its SBOM folder, so any difference is visible immediately.

## Snapshot log

| Date | State name or location | Reason | Verified route |
| --- | --- | --- | --- |
| (example) 2026-10-28 | shadowstrike-20261028-pre-provision | Before first provision | fallback file pull |
|  |  |  |  |
