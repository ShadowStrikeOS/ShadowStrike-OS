# Prompt and summary fallbacks

The login experience is layered so it never breaks on a minimal machine.

1. **MOTD always prints.** `.zshrc` prints `~/shadowstrike/motd.txt` on
   interactive shells. It needs nothing but cat.
2. **fastfetch when present.** After the MOTD, `.zshrc` runs fastfetch with
   the config in `fastfetch/` (globe logo block, operator line, OS, kernel,
   shell, terminal, uptime). When fastfetch is absent, that step is skipped
   silently and the MOTD still stands. To check by hand: `command -v
   fastfetch`.
3. **Starship when present.** The zsh prompt uses starship if the binary
   exists. Starship is a github-release row in the manifest, not an apt
   dependency, so its absence is a normal state.
4. **Built in prompt otherwise.** With neither starship nor fastfetch, the
   fallback in `.zshrc` is a two line prompt in the theme greens: user and
   host, working directory, git branch when inside a repository, and the
   time on the right. No plugin is required for it to work.

Rule: polish is optional, the prompt is not. A bare machine still identifies
itself, shows the operator line in the MOTD, and gives a working prompt.
