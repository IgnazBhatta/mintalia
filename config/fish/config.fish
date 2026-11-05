# mintalia — fish configuration
#
# CachyOS ships a nice fish prompt; source it when present so this config also
# works on plain Arch.
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Reprint the Noctalia-themed welcome screen without opening a new terminal.
function greet --description 'Show the fastfetch welcome screen'
    fastfetch
end

# Tools the mintalia installer may have added.
for dir in $HOME/.local/bin $HOME/.opencode/bin $HOME/.spicetify
    if test -d $dir
        fish_add_path -m $dir
    end
end
