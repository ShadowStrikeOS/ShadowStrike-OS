# ShadowStrike OS: Kernel Parity Toolkit

Getting the benefits of the Kali kernel inside an OrbStack Kali machine,
on a kernel OrbStack owns and will not replace.

OrbStack runs one shared kernel for all of its Linux machines, with no
option to boot Kali's kernel instead. This toolkit stops arguing with
that fact and measures our way around it: audit what the running kernel
already has, try building the one out-of-tree driver we actually miss
against the headers OrbStack ships, and route whatever is left to the
real Kali VM that is part of the same ShadowStrike platform.

## The two commands

Run both from inside the OrbStack Kali machine.

```sh
./audit.sh
```

Read-only kernel audit. Loads nothing, installs nothing, writes only to
a temporary directory. Checks wireless, networking, TUN, WireGuard,
Bluetooth, USB gadget, packet sockets, BPF, namespaces, KVM, and header
support against the running kernel's own configuration, then reports
module loading capability without loading anything.

```sh
./build-rtl88xxau.sh --i-understand-this-is-experimental
```

Experimental, and labelled that way everywhere. Attempts to build the
out-of-tree RTL8812AU driver against OrbStack's shipped kernel headers.
Refuses to run without the acknowledgement flag, installs nothing unless
`--install-deps` is also given, logs everything, and never loads the
module it builds. It prints the manual load and verify commands instead.

## The verdict it produces

One summary line from the audit:

```text
SUMMARY: present X of Y checked features
```

Plus, per feature, PRESENT, MISSING, or UNKNOWN with the exact CONFIG
symbol behind it, and from the builder either SUCCESS with a module path
or FAILED-AT with the step that failed. Those outputs decide what lives
in OrbStack, what needs a built module, and what belongs to the side VM.

Full reasoning, risks, and the honest unknowns list: see
[PARITY.md](PARITY.md).
