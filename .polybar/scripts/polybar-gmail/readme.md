# Polybar Gmail

Modified Readme.md for this configuration. credit/rights goes to it's Developer.

A [Polybar](https://github.com/jaagr/polybar) module to show unread messages from Gmail.

![preview](https://github.com/vyachkonovalov/polybar-gmail/raw/master/preview.png)

## Dependencies

```sh
sudo pip install --upgrade google-api-python-client
```

**Fonts: Siji** - for email badge

**canberra-gtk-play** - for new email sound

You can change the badge or turn off sound, for more info see [script arguments](#script-arguments)

Obtain/refresh credentials

```sh
~/.config/polybar/gmail/auth.py
```

### Module

```ini
[module/gmail]
type = custom/script
exec = ~/.config/polybar/scripts/polybar-gmail/launch.py
tail = true
click-left = xdg-open https://mail.google.com
```

## Script arguments

`-p` or `--prefix` - to change email badge, default: 

`-c` or `--color` - to change new email badge color, default: #e06c75

`-ns` or `--nosound` - turn off new email sound

### Example

```sh
launch.py --prefix '📧' --color '#be5046' --nosound
```
