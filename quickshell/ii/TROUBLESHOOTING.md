# Troubleshooting

## Shell not starting after `pacman -Syu` (Qt update)

### Symptom

After a system update, the ii shell does not come up (also not with `Ctrl+Super+R`).
Running it manually shows:

```
$ qs -c ii
qs: symbol lookup error: qs: undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6_PRIVATE_API
```

### Cause

`qt6-base` / `qt6-declarative` were upgraded (e.g. to 6.11.2), but quickshell
(`illogical-impulse-quickshell-git`) is still the binary built against the old Qt.
Quickshell links against Qt's **private API**, which is not ABI-stable between
Qt versions, so every Qt upgrade requires rebuilding quickshell.

The dotfiles and Hyprland config are fine; only the quickshell binary is stale.

### Fix

```sh
# build dependency (may be missing)
sudo pacman -S --needed cli11

# optional: get latest pinned quickshell commit
git -C ~/.cache/dots-hyprland pull

# rebuild + install
cd ~/.cache/dots-hyprland/sdata/dist-arch/illogical-impulse-quickshell-git
makepkg -fsi

# start shell
qs -c ii &
```

Then reload with `Ctrl+Super+R` or re-login.

### Verify

```sh
pacman -Qi illogical-impulse-quickshell-git | grep -iE 'build date|fecha de creación'
qs -c ii   # must not print the symbol lookup error
```

The build date must be newer than the Qt upgrade (`pacman -Qi qt6-base`).

### Prevention

Whenever `qt6-base` or `qt6-declarative` appears in a `pacman -Syu`, run
`makepkg -fsi` in the directory above right after the update.

If the build fails with compile errors, the pinned quickshell commit may be
incompatible with the new Qt: pull the latest dots-hyprland and rebuild, or
re-run `./setup install` from `~/.cache/dots-hyprland`.
