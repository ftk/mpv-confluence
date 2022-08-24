# mpv-confluence
This script allows you to open magnet links using [confluence](https://github.com/anacrolix/confluence) torrent client.

It also tries to match external audio and subtitle files with video files.
1. Install and set up [confluence](https://github.com/ftk/confluence/releases/) on your PC or a server in your LAN
2. Clone this repo into your `mpv/scripts` directory or save `main.lua` as `mpv-confluence.lua`
3. (optional) Adjust `server` address in `main.lua` to your confluence HTTP address or put `server=http://[confluence ip]:[port]` in `mpv/script-settings/mpv-confluence.conf`
4. Open a magnet link in mpv.
5. (optional) Recommended mpv.conf options:
```
prefetch-playlist=yes
```