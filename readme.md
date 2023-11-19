# mpv-torrserver
This script allows you to open magnet links using [TorrServer](https://github.com/YouROK/TorrServer) torrent client.

It also tries to match external audio and subtitle files with video files.
1. Install and set up [TorrServer](https://github.com/YouROK/TorrServer/releases/) on your PC or a server in your LAN
2. Clone this repo into your `mpv/scripts` directory or save `main.lua` as `mpv-torrserver.lua`:
```sh
git clone -b torrserver https://github.com/ftk/mpv-confluence mpv-torrserver
```
3. (optional) Adjust `server` address in `main.lua` to your TorrServer HTTP address or put `server=http://[TorrServer ip]:[port]` in `mpv/script-settings/mpv-torrserver.conf`
4. Open a magnet link in mpv.
5. (optional) Recommended mpv.conf options:
```
prefetch-playlist=yes
```
