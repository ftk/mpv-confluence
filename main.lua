-- https://github.com/anacrolix/confluence

local bencode = require "bencode"

local confluence_server = "http://10.200.200.6:8000"

local function get_magnet_info(url)
    local luacurl_available, cURL = pcall(require, 'cURL')
    local info_url = confluence_server .. "/info?magnet=" .. url
    if not (luacurl_available) then
        -- if Lua-cURL is not available on this system
        local curl_cmd = {
            "curl",
            "-L",
            "--silent",
            "--max-time", "10",
            info_url
        }
        local cmd = mp.command_native {
            name = "subprocess",
            capture_stdout = true,
            playback_only = false,
            args = curl_cmd
        }
        res = cmd.stdout
    else
        -- otherwise use Lua-cURL (binding to libcurl)
        local buf = {}
        local c = cURL.easy_init()
        c:setopt_followlocation(1)
        c:setopt_url(info_url)
        c:setopt_writefunction(function(chunk)
            table.insert(buf, chunk);
            return true;
        end)
        c:perform()
        res = table.concat(buf)
    end
    return bencode.decode(res)
end

local function edlencode(url)
    return "%" .. string.len(url) .. "%" .. url
end

local function guess_type_by_extension(ext)
    if ext == "mkv" or ext == "mp4" or ext == "avi" or ext == "wmv" or ext == "vob" or ext == "m2ts" or ext == "ogm" then
        return "video"
    end
    if ext == "mka" or ext == "mp3" or ext == "aac" or ext == "flac" or ext == "ogg" or ext == "wma" or ext == "mpg" or ext == "wav" or ext == "wv" or ext == "opus" then
        return "audio"
    end
    if ext == "ass" or ext == "srt" or ext == "vtt" then
        return "sub"
    end
    return "other";
end


-- https://github.com/mpv-player/mpv/blob/master/DOCS/edl-mpv.rst
local function generate_m3u(magnet_uri, files)
    for _, fileinfo in ipairs(files) do
        local ext = string.match(fileinfo.path[#fileinfo.path], "%.(%w+)$")
        fileinfo.type = guess_type_by_extension(ext)
    end
    table.sort(files, function(a, b)
        -- make top-level files appear first in the playlist
        if (#a.path == 1 or #b.path == 1) and #a.path ~= #b.path then
            return #a.path < #b.path
        end
        -- make videos first
        if (a.type == "video" or b.type == "video") and a.type ~= b.type then
            return a.type == "video"
        end
        -- otherwise sort by path
        return table.concat(a.path, "/") < table.concat(b.path, "/")
    end);

    local infohash = magnet_uri:match("magnet:%?xt=urn:btih:(%w+)")

    local playlist = { '#EXTM3U' }

    for _, fileinfo in ipairs(files) do
        if fileinfo.processed ~= true then
            local path = table.concat(fileinfo.path, "/")
            table.insert(playlist, '#EXTINF:-1,' .. path)
            local basename = string.match(fileinfo.path[#fileinfo.path], '^(.+)%.%w+$')

            local url = confluence_server .. "/data/infohash/" .. infohash .. "/" .. path
            local edl = "edl://!new_stream;!no_clip;!no_chapters;" .. edlencode(url) .. ";"
            local external_tracks = 0

            fileinfo.processed = true
            if basename ~= nil and fileinfo.type == "video" then
                mp.msg.info("!" .. basename)

                for _, fileinfo2 in ipairs(files) do
                    if #fileinfo2.path > 0 and
                            fileinfo2.type ~= "other" and
                            fileinfo2.processed ~= true and
                            string.find(fileinfo2.path[#fileinfo2.path], basename, 1, true) ~= nil
                    then
                        local path2 = table.concat(fileinfo2.path, "/")
                        mp.msg.info("->" .. path2)
                        local url = confluence_server .. "/data/infohash/" .. infohash .. "/" .. path2
                        local hdr = { "!new_stream", "!no_clip", "!no_chapters",
                                      "!delay_open,media_type=" .. fileinfo2.type,
                                      "!track_meta,title=" .. edlencode(path2),
                                      edlencode(url)
                        }
                        edl = edl .. table.concat(hdr, ";") .. ";"
                        fileinfo2.processed = true
                        external_tracks = external_tracks + 1
                    end
                end
            end
            if external_tracks == 0 then -- dont use edl
                table.insert(playlist, url)
            else
                table.insert(playlist, edl)
            end
        end
    end
    return table.concat(playlist, '\n')
end

mp.add_hook("on_load", 20, function()
    local url = mp.get_property("stream-open-filename")
    if url:find("^magnet:") == 1 then
        local suffix = ""
        local magnet_info = get_magnet_info(url)
        if type(magnet_info) == "table" then
            --magnet_info.pieces = "(value optimised out)"
            if magnet_info.files then
                -- torrent has multiple files. open as playlist
                mp.set_property("stream-open-filename", "memory://" .. generate_m3u(url, magnet_info.files))
                return
            end
            -- if not a playlist and has a name
            if magnet_info.name then
                suffix = "#/" .. magnet_info.name -- default file name
            end
        end
        mp.set_property("stream-open-filename", confluence_server .. "/data?magnet=" .. url .. suffix)
    end
end)
