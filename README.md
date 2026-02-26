# AwesomeWM Requirements
- **wezterm** (terminal)
- **rofi** (application launcher)
- **flameshot** (screenshots)
- **satty** (screenshots - Area Capture annotation)
- **oxipng** (screenshots - PNG optimization after capture)
- **picom** (compositor)
- **mpd** + **mpc** (music player)
- **wireplumber** (audio control - `wpctl`)
- **greenclip** (clipboard manager)
- **micro** (text editor)
- For screenshot.sh you need to add it to your path variable (~/.config/awesome/screenshot.sh)
  - For some reason it won't launch with $HOME or ~ in awesomewm and I can't be bothered to find out why right now

## System Utilities
- **numlockx** (numlock control)
- **jq** (JSON parsing)
- **curl** (HTTP requests for uploads)

## Optional Components
- **easyeffects** (audio effects)
- **xhidecursor** (cursor hider)

---

# FastFetch Requirements

## Script Dependencies
- **jq** (JSON parsing for `lines.json`)

## Logo Assets
- PNG image files in `~/.config/fastfetch/logos/`, shown is decided by `/etc/os-release` so name your images to your distro, or part of it
- Distro PNGs included are: Arch, CachyOS for now
- Fallback `default.png`
