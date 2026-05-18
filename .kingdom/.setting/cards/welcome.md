# welcome

**Fires when:** `/kingdom:day` kickoff, first card printed.
**Used by:** [`commands/day.md`](../../../commands/day.md) Step 3.

## Template

The card has 4 time-of-day variants. Pick the variant based on the local hour, wrap in `[!TIP]` alert.

### Morning (05:00-11:59)

```markdown
> [!TIP]
> ```
> ╭─ 👑 Good morning${USER_NAME:+, }${USER_NAME} ─────────────────────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │  ${WX_LINE}                                             │
> ╰────────────────────────────────────────────────────────╯
> ```
```

### Afternoon (12:00-17:59)

```markdown
> [!TIP]
> ```
> ╭─ 👑 Good afternoon${USER_NAME:+, }${USER_NAME} ───────────────────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │  ${WX_LINE}                                             │
> ╰────────────────────────────────────────────────────────╯
> ```
```

### Evening (18:00-21:59)

```markdown
> [!TIP]
> ```
> ╭─ 👑 Good evening${USER_NAME:+, }${USER_NAME} ─────────────────────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │  ${WX_LINE}                                             │
> ╰────────────────────────────────────────────────────────╯
> ```
```

### Late (22:00-04:59)

```markdown
> [!TIP]
> ```
> ╭─ 👑 Working late${USER_NAME:+, }${USER_NAME}? ────────────────────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │  ${WX_LINE} · coffee? ☕                                │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${USER_NAME}` | `kingdom.json.welcome.userName`, defaults to empty | `Alice` (with comma prefix) or empty (no comma) |
| `${LOCAL_DATETIME}` | `date '+%A, %B %-d, %Y · %H:%M %Z'` | `Monday, May 18, 2026 · 18:35 +07` |
| `${WX_LINE}` | `fetch_weather_line` helper (3s timeout; silent on failure) | `☀️  Bangkok · 32°C · clear · feels like 35°C` |

## Variant selection

```bash
HOUR=$(date '+%-H')
if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 12 ]; then
  CARD_VARIANT=morning
elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then
  CARD_VARIANT=afternoon
elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 22 ]; then
  CARD_VARIANT=evening
else
  CARD_VARIANT=late
fi
```

## Notes

- The weather line is **optional**. If `kingdom.json.welcome.weather = false`, the helper returns an empty string and `render_card` drops the line. If the API call times out or fails, same behaviour (silent skip).
- Weather emoji selection from WMO codes is in `fetch_weather_line` helper. Common mappings: `0` ☀️ · `1-3` 🌤️/⛅/☁️ · `45-48` 🌫️ · `51-67` 🌧️ · `71-77` ❄️ · `80-82` 🌦️ · `95-99` ⛈️.
