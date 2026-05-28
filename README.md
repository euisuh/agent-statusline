# Claude Statusline Backup

Backup of the fancy Unicode Claude Code statusline that was active before
switching to a fixed-width ASCII statusline.

## Files

- `statusline.fancy-unicode.sh` - original `~/.claude/statusline.sh`
- `statusline.ascii-current.sh` - fixed-width ASCII statusline currently in use
- `settings.snapshot.json` - Claude settings snapshot showing the statusline command

## Restore Fancy Unicode

```sh
cp statusline.fancy-unicode.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

## Restore ASCII

```sh
cp statusline.ascii-current.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Claude settings should contain:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```
