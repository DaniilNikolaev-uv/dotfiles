#!/usr/bin/env bash
# Нужен python3 или файл с эмодзи, например от rofimoji

EMOJI_DB="/usr/share/rofimoji/data/emojis_all.csv"  # или свой файл

if [ -f "$EMOJI_DB" ]; then
    SELECTED=$(cat "$EMOJI_DB" | walker --dmenu -p "🔍 Emoji" | cut -f1)
else
    # Fallback — генерируем через python
    SELECTED=$(python3 -c "
import unicodedata
for cp in range(0x1F300, 0x1FAFF):
    try:
        c = chr(cp)
        name = unicodedata.name(c, '')
        if name:
            print(f'{c} {name.lower()}')
    except: pass
" | walker --dmenu -p "🔍 Emoji" | awk '{print $1}')
fi

[ -n "$SELECTED" ] && echo -n "$SELECTED" | wl-copy