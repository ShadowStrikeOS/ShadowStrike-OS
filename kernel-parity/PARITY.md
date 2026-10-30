# Kernel Parity on OrbStack: How ShadowStrike OS Gets Kali Kernel Benefits Without a Kali Kernel

This document is part of the ShadowStrike OS Kernel Parity Toolkit. It
explains, honestly and in order, what kernel we are actually running inside
an OrbStack Linux machine on a Mac with Apple Silicon, what that kernel
already gives us, what we can add to it, and what still belongs in a real
virtual machine that is part of the same platform.

No em dashes are used in this document, on purpose. Neither are any claims
we have not earned yet. Where something is untested, it says untested.

## Why OrbStack cannot take the Kali kernel

OrbStack does not boot a kernel per machine. Every container and every
Linux machine it runs shares one kernel, built and shipped by OrbStack,
chosen by OrbStack, and replaced when OrbStack updates. There is no
configuration option, command line flag, or machine setting that hands
boot to a distribution kernel instead. Custom distribution images, if and
when they arrive, change the userland. They do not change this.

Kali ships its own kernel (a different version, with its own patch set).
Putting that kernel inside an OrbStack machine is therefore not a hard
problem we have failed to solve. It is a door that does not exist in the
building. Anyone claiming to have done it should be asked for a screen
recording, not a screenshot.

So the flagship question is not "how do we replace the kernel". It is:
"how much of what the Kali kernel would have given us can we get on the
kernel OrbStack actually runs". That is what parity means here.

## The three parity routes

### Route 1: Features the OrbStack kernel already has

OrbStack kernels are modern mainline-style kernels, and a surprising share
of Kali-relevant capability is not a Kali patch at all. It is ordinary
kernel configuration: the cfg80211 and mac80211 wireless stack, in-tree
MediaTek mt76 drivers including MT7921U USB Wi-Fi, nftables and legacy
iptables, TUN devices, WireGuard, Bluetooth with USB HCI, USB gadget
support, packet sockets, BPF, user and network namespaces, and more.

If the running kernel already has a feature compiled in or as a module,
parity for that feature is already achieved. No build, no risk, nothing
to maintain. We just have to check, instead of assuming either way.

That checking is Route 1's whole job, and it is what `audit.sh` does.

### Route 2: Modules built against the headers OrbStack ships

OrbStack machines ship the headers for their own running kernel at
`/sys/kernel/kheaders.tar.xz`. Headers are the contract a kernel offers
to out-of-tree modules. A module built against the correct headers, for
the correct kernel release, can in principle be loaded into that kernel
even though the distribution never packaged it.

This is the route for hardware whose driver lives out of tree. Our test
case is the Realtek RTL8812AU chipset (used by a common class of USB
Wi-Fi adapters), whose driver is maintained out of tree by the
aircrack-ng project. The in-tree MediaTek adapters need none of this.
The out-of-tree Realtek driver is exactly the kind of thing a Kali kernel
user would take for granted, and exactly the thing OrbStack users are
told to give up on. Nobody, at the time of writing, has published whether
it works. `build-rtl88xxau.sh` is our instrument for finding out, built
to be safe to run and explicit about failure.

Route 2 has real costs, stated plainly:

- The module must be rebuilt after OrbStack updates, because the kernel
  and its headers change under it.
- The kernel may refuse an unsigned module. If it does, that refusal is
  a finding, not a script bug.
- A header tarball is not always a fully prepared build tree. The build
  may fail on missing generated files, and that failure decides whether
  this route is viable at all.

### Route 3: The side virtual machine, as part of the same platform

Anything the audit proves missing, and the module route cannot supply,
belongs in a real ARM64 virtual machine running the genuine Kali kernel,
sitting beside OrbStack on the same host. That machine owns the jobs
that truly need a distribution kernel: adapter drivers that will not
build any other way, kernel level work, anything needing custom kernel
configuration.

We frame this as part of ShadowStrike OS, not as a defeat for it. The
platform was always two layers: OrbStack as the fast daily driver, and
one real VM for kernel work. Parity work shrinks what the VM is needed
for. It was never going to delete it, and this document does not pretend
otherwise.

## Running the audit

From inside the OrbStack Kali machine:

```sh
chmod +x audit.sh
./audit.sh
```

The audit is read-only. It loads nothing, installs nothing, and writes
only to a temporary directory that it removes on exit. It reports:

- The running kernel release, architecture, and any OrbStack markers it
  can find in the command line or early boot log.
- The first kernel configuration it can read, in this order:
  `/proc/config.gz`, then `/boot/config-*`, then the configuration
  carried inside the shipped headers tarball.
- Each checked feature as PRESENT, MISSING, or UNKNOWN, with the exact
  CONFIG symbol behind the verdict. UNKNOWN is an honest answer: it
  means the symbol was not found either way in a readable config, or no
  config was readable at all.
- Module loading capability, tested without loading anything: whether
  `/sys/module` exists, whether modprobe and insmod are present, whether
  the `modules_disabled` sysctl is set, and whether the shipped headers
  exist for building against.
- A summary line: present X of Y checked features.

Reading the output is simple. PRESENT rows are parity already won.
MISSING rows go to Route 2 if a module can supply them, and to Route 3
if they cannot. UNKNOWN rows mean we need a better config source before
arguing about them, starting with the headers tarball the audit already
tries last.

## Running the experimental driver build

From inside the OrbStack Kali machine, with eyes open:

```sh
chmod +x build-rtl88xxau.sh
./build-rtl88xxau.sh --i-understand-this-is-experimental
```

Add `--install-deps` only if you want it to install build dependencies
with apt. Without that flag it installs nothing. Add `--local-src DIR`
to build an existing checkout of the driver instead of cloning it.

The script refuses to run without the acknowledgement flag. It verifies
the shipped headers exist, extracts them, fetches the driver from its
upstream project at runtime (the driver is not vendored into this
package and stays under its own licence), and attempts the build against
those headers. It logs everything, and ends with either SUCCESS and the
path to the built module, or FAILED-AT with the step that failed.

It never loads the module. If a module is built, the script prints the
exact `insmod` command and the `dmesg`, `lsmod`, `ip link`, and `iw dev`
checks to run by hand, plus the `rmmod` command that undoes it. Loading
a kernel module is a human decision, on a machine a human is watching.

## What we do not know until the audit runs on a real machine

This toolkit was written and syntax-checked off-device, and the audit
was test-run on an ordinary Linux machine to prove it degrades
gracefully. The following are open until someone runs it inside a real
OrbStack Kali machine:

- The exact feature table of the current OrbStack kernel. Versions move,
  and any table we printed here from memory would be a claim, not a
  measurement. The audit exists precisely so the platform ships
  measurements instead.
- Whether the headers tarball in current OrbStack builds carries a
  complete enough tree for out-of-tree builds, including generated files
  such as autoconf.h in a usable place.
- Whether module loading is permitted at all in an OrbStack machine, or
  locked down by sysctl, capabilities, or signing policy.
- Whether the RTL8812AU build, if it compiles, produces a module whose
  vermagic matches the running kernel, and whether a passed-through USB
  adapter then appears as a working wireless interface with monitor mode.
- How much of the Kali kernel benefit list survives contact with all of
  the above. Our expectation, labelled as expectation and not fact, is
  that Route 1 covers most of daily work, Route 2 is a genuine coin toss
  worth publishing either way, and Route 3 remains the honest home for
  the rest.

When the first real audit output exists, it belongs in this repository
next to this document, dated, with the OrbStack and Kali versions named.
That output, not this prose, is the flagship evidence.
