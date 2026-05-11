# Architecture & Implementation Decisions

## org-gcal: Passphrase-free GPG token decryption

**Date:** 2026-02-25
**Status:** Implemented

### Problem
org-gcal stores OAuth tokens in a `plstore` file encrypted with a GPG key. Every time Emacs loads or refreshes the token, GPG prompts for the key's passphrase — even with `epg-pinentry-mode 'loopback` (which routes the prompt through the Emacs minibuffer).

### Decision
Use **gpg-agent TTL caching** with `pinentry-gnome3` to eliminate repeated passphrase prompts.

### Implementation
1. Created `~/.gnupg/gpg-agent.conf` with:
   - `default-cache-ttl 604800` (1 week)
   - `max-cache-ttl 604800` (1 week)
   - `pinentry-program /usr/bin/pinentry-gnome3`
2. Changed `epg-pinentry-mode` from `'loopback` to `'default` in `spacemacs.org` and `user-config.el`

### Alternatives Considered
- **`pam-gnupg`**: Auto-unlocks GPG key at login by matching the GPG passphrase to the Linux login password. Rejected because the org-gcal GPG key passphrase does not match the login password, and changing it would add complexity.
- **`epg-pinentry-mode 'loopback` (previous)**: Routes pinentry through Emacs minibuffer. Works but prompts every time gpg-agent cache expires (default: 10 minutes).

### Effect
After entering the passphrase once via a GUI dialog (pinentry-gnome3), gpg-agent caches it for 1 week. No further prompts during normal use.

### Security Note
The GPG key and plstore-encrypted tokens remain secure at rest. The only change is extending the in-memory cache window from 10 minutes to 1 week.

### Update (2026-05-11): keep `'loopback`, prime the agent at startup
The org-gcal idle timer can fire at moments when no minibuffer is available; if the gpg-agent passphrase cache has expired by then, loopback pinentry can't prompt and gpg returns the misleading `epg-error "Decryption failed" "No secret key: <subkey>"` (it really means "No PINentry"). Other PCs use `'loopback` and we want config parity, so we keep `'loopback` and instead prime the gpg-agent cache once at Emacs startup via `my/org-gcal--prime-gpg-cache` (hooked into `emacs-startup-hook` with a 2-second idle deferral). The minibuffer is reachable at that point, so the user types the passphrase once; the agent's 1-week TTL then covers every subsequent timer-driven decrypt.
