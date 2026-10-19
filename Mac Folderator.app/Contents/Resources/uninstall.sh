#!/bin/bash
# =============================================================================
#  Mac Folderator — scripts/uninstall.sh
#  Removes Mac Folderator completely: processes, Quick Action, app, settings and mounted
#  disk images, and (by default) restores the original icon of every folder it colored.
#  It does NOT touch your wallpaper, theme, Dock or any other app.
#
#  This is also the script the app runs (in Terminal) when you choose "Uninstall…".
#
#  Usage:   bash scripts/uninstall.sh
#           bash scripts/uninstall.sh --keep-colors      (leave the folders colored)
#
#  Rimuove Mac Folderator del tutto (app, azione rapida, impostazioni, dischi montati) e,
#  di default, riporta all'icona originale le cartelle colorate.
#  Uso:  bash scripts/uninstall.sh   |   --keep-colors per lasciare le cartelle colorate
# =============================================================================
KEEP_COLORS=0
case "${1:-}" in --keep-colors|--tieni-colori) KEEP_COLORS=1 ;; esac

IT=0; case "${LANG:-}" in it*) IT=1 ;; esac
m()    { if [ "$IT" -eq 1 ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }
say()  { printf '\033[38;5;149m▸\033[0m %s\n' "$(m "$1" "$2")"; }
warn() { printf '\033[38;5;215m!\033[0m %s\n' "$(m "$1" "$2")"; }

[ "$(uname)" = "Darwin" ] || { echo "$(m 'Funziona solo su macOS.' 'This only works on macOS.')"; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "$(m "Non usare sudo: te lo chiederà solo se serve." "Do not run this with sudo: it asks for it only if needed.")"; exit 1; }

# ---------------------------------------------------------------- 1. stop everything
say "Fermo l'app e gli eventuali servizi in background…" "Stopping the app and any background service…"
for label in it.macfolderator.watch it.macfolderator.folderwatch it.macneon.folderwatch; do
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
  launchctl remove "$label" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/$label.plist"
done
pkill -x MacFolderator 2>/dev/null
pkill -f "\.macfolderator/bin|\.macneon/bin" 2>/dev/null
pkill -x fswatch 2>/dev/null
sleep 1

# ---------------------------------------------------------------- 2. folder icons
reset_folder() {
  local p="$1"
  [ -d "$p" ] || return 0
  rm -f "$p/Icon"$'\r' 2>/dev/null
  xattr -d com.apple.FinderInfo "$p" 2>/dev/null
  touch "$p" 2>/dev/null
}
if [ "$KEEP_COLORS" -eq 0 ]; then
  say "Riporto le cartelle all'icona originale…" "Restoring the original folder icons…"
  n=0
  for M in "$HOME/.macfolderator/manifest.tsv" "$HOME/.macneon/manifest.tsv"; do
    [ -f "$M" ] || continue
    while IFS=$'\t' read -r kind path; do
      case "$kind" in FOLDER|AUTO|ICON) reset_folder "$path"; n=$((n+1)) ;; esac
    done < "$M"
  done
  echo "   $(m 'cartelle ripristinate' 'folders restored'): $n"
fi

# ---------------------------------------------------------------- 3. mounted disk images
say "Espello i dischi di installazione…" "Ejecting installer disk images…"
for v in /Volumes/Mac\ Folderator*; do
  [ -d "$v" ] || continue
  hdiutil detach "$v" >/dev/null 2>&1 || hdiutil detach "$v" -force >/dev/null 2>&1 || warn "Non riesco a espellere $v" "Could not eject $v"
done

# ---------------------------------------------------------------- 4. the app
remove_path() {
  local t="$1"
  [ -e "$t" ] || return 0
  rm -rf "$t" 2>/dev/null
  [ -e "$t" ] || { echo "   $(m 'rimosso' 'removed'): $t"; return 0; }
  chflags -R nouchg,noschg "$t" 2>/dev/null
  xattr -cr "$t" 2>/dev/null
  rm -rf "$t" 2>/dev/null
  [ -e "$t" ] || { echo "   $(m 'rimosso' 'removed'): $t"; return 0; }
  warn "Serve la password per rimuovere: $t" "Your password is needed to remove: $t"
  sudo rm -rf "$t"
  [ -e "$t" ] && warn "Ancora presente: $t (abilita il Terminale in Impostazioni di Sistema → Privacy e sicurezza → Gestione app e riprova)" \
                      "Still there: $t (enable Terminal in System Settings → Privacy & Security → App Management, then retry)"
}
say "Rimuovo l'app…" "Removing the app…"
for t in \
  "/Applications/Mac Folderator.app" \
  "$HOME/Applications/Mac Folderator.app" \
  "$HOME/Applications/MacNeon" \
  "$HOME/.Trash/Mac Folderator.app" \
  "$HOME/.Trash/Mac Folderator"* ; do
  remove_path "$t"
done
# copies that were downloaded or dragged around (only the app, never the sources)
for t in "$HOME/Downloads/Mac Folderator.app" "$HOME/Desktop/Mac Folderator.app"; do remove_path "$t"; done

# ---------------------------------------------------------------- 5. Quick Action and settings
say "Rimuovo azione rapida e impostazioni…" "Removing the Quick Action and settings…"
rm -rf "$HOME/Library/Services/Colora cartella.workflow" "$HOME/Library/Services/Color Folder.workflow"
rm -rf "$HOME/.macfolderator" "$HOME/.macneon"
rm -f "$HOME/Library/Preferences/it.macfolderator.app.plist"
/System/Library/CoreServices/pbs -update 2>/dev/null

# ---------------------------------------------------------------- 6. final check
killall Finder 2>/dev/null
echo
left=0
for t in "/Applications/Mac Folderator.app" "$HOME/Applications/Mac Folderator.app" "$HOME/.macfolderator" "$HOME/.macneon"; do
  [ -e "$t" ] && { warn "Rimasto: $t" "Left over: $t"; left=1; }
done
pgrep -x MacFolderator >/dev/null && { warn "MacFolderator è ancora in esecuzione" "MacFolderator is still running"; left=1; }
if [ "$left" -eq 0 ]; then
  printf '\033[38;5;149m%s\033[0m\n' "$(m 'Fatto. Mac Folderator è stato rimosso del tutto.' 'Done. Mac Folderator has been completely removed.')"
else
  echo "$(m "Qualcosa è rimasto: guarda le righe con '!' qui sopra." "Something is left over: see the lines marked '!' above.")"
fi
