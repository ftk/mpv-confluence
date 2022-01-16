# mpv-confluence
This script allows you to open magnet links using [confluence](https://github.com/anacrolix/confluence).
It also tries to match external audio and subtitle files with video files.
1. Install and set up [confluence](https://github.com/ftk/confluence/releases/) on your PC or a server in your LAN
2. In your `mpv/scripts` directory:
```shell
git clone https://github.com/ftk/mpv-confluence
```
or save `main.lua` as `mpv-confluence.lua`
3. (optional) Adjust `server` address in `main.lua` to your confluence address or add add `script-opts=mpv_confluence-server=http://[confluence ip]:[port]` to mpv.conf.
4. Open a magnet link in mpv.
