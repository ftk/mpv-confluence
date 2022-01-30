-- https://github.com/anacrolix/confluence

-- add "script-opts=mpv_confluence-server=http://[confluence ip]:[port]" to mpv.conf
local opts = {
    server = "http://localhost:8080",
    search_for_external_tracks = true
}

(require 'mp.options').read_options(opts)
local luacurl_available, cURL = pcall(require, 'cURL')

-- from: https://github.com/ezdiy/lua-bencode
local function decode_integer(s, index)
    local a, b, int = string.find(s, "^(%-?%d+)e", index)
    if not int then return nil, "not a number", nil end
    int = tonumber(int)
    if not int then return nil, "not a number", int end
    return int, b + 1
end

local function decode_list(s, index)
    local t = {}
    while string.sub(s, index, index) ~= "e" do
        local obj, ev
        obj, index, ev = decode(s, index)
        if not obj then return obj, index, ev end
        table.insert(t, obj)
    end
    index = index + 1
    return t, index
end

local function decode_dictionary(s, index)
    local t = {}
    while string.sub(s, index, index) ~= "e" do
        local obj1, obj2, ev

        obj1, index, ev = decode(s, index)
        if not obj1 then return obj1, index, ev end

        obj2, index, ev = decode(s, index)
        if not obj2 then return obj2, index, ev end

        t[obj1] = obj2
    end
    index = index + 1
    return t, index
end

local function decode_string(s, index)
    local a, b, len = string.find(s, "^([0-9]+):", index)
    if not len then return nil, "not a length", len end
    index = b + 1

    local v = string.sub(s, index, index + len - 1)
    if #v < len - 1 then return nil, "truncated string at end of input", v end
    index = index + len
    return v, index
end


function decode(s, index)
    if not s then return nil, "no data", nil end
    index = index or 1
    local t = string.sub(s, index, index)
    if not t then return nil, "truncation error", nil end

    if t == "i" then
        return decode_integer(s, index + 1)
    elseif t == "l" then
        return decode_list(s, index + 1)
    elseif t == "d" then
        return decode_dictionary(s, index + 1)
    elseif t >= '0' and t <= '9' then
        return decode_string(s, index)
    else
        return nil, "invalid type", t
    end
end

-- bencode end

local function get_magnet_info(url)
    local info_url = opts.server .. "/info?magnet=" .. url
    local res
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
    if res and res ~= "" then
        return decode(res)
    else
        return nil, "no info response (timeout?)"
    end
end

local function edlencode(url)
    return "%" .. string.len(url) .. "%" .. url
end

local function guess_type_by_extension(ext)
    if ext == "mkv" or ext == "mp4" or ext == "avi" or ext == "wmv" or ext == "vob" or ext == "m2ts" or ext == "ogm" then
        return "video"
    end
    if ext == "mka" or ext == "mp3" or ext == "aac" or ext == "flac" or ext == "ogg" or ext == "wma" or ext == "mpg"
            or ext == "wav" or ext == "wv" or ext == "opus" or ext == "ac3" then
        return "audio"
    end
    if ext == "ass" or ext == "srt" or ext == "vtt" then
        return "sub"
    end
    return "other";
end

local function string_replace(str, match, replace)
    local s, e = string.find(str, match, 1, true)
    if s == nil or e == nil then
        return str
    end
    return string.sub(str, 1, s - 1) .. replace .. string.sub(str, e + 1)
end

-- https://github.com/mpv-player/mpv/blob/master/DOCS/edl-mpv.rst
local function generate_m3u(magnet_uri, files)
    for _, fileinfo in ipairs(files) do
        local ext = string.match(fileinfo.path[#fileinfo.path], "%.(%w+)$")
        fileinfo.type = guess_type_by_extension(ext)
        fileinfo.fullpath = table.concat(fileinfo.path, "/")
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
        return a.fullpath < b.fullpath
    end);

    local infohash = magnet_uri:match("^magnet:%?xt=urn:bt[im]h:(%w+)")

    local playlist = { '#EXTM3U' }

    for _, fileinfo in ipairs(files) do
        if fileinfo.processed ~= true then
            table.insert(playlist, '#EXTINF:0,' .. fileinfo.fullpath)
            local basename = string.match(fileinfo.path[#fileinfo.path], '^(.+)%.%w+$')

            local url = opts.server .. "/data/infohash/" .. infohash .. "/" .. fileinfo.fullpath
            local hdr = { "!new_stream", "!no_clip",
                          --"!track_meta,title=" .. edlencode(basename),
                          edlencode(url)
            }
            local edl = "edl://" .. table.concat(hdr, ";") .. ";"
            local external_tracks = 0

            fileinfo.processed = true
            if opts.search_for_external_tracks and basename ~= nil and fileinfo.type == "video" then
                mp.msg.info("!" .. basename)

                for _, fileinfo2 in ipairs(files) do
                    if #fileinfo2.path > 0 and
                            fileinfo2.type ~= "other" and
                            fileinfo2.processed ~= true and
                            string.find(fileinfo2.path[#fileinfo2.path], basename, 1, true) ~= nil
                    then
                        mp.msg.info("->" .. fileinfo2.fullpath)
                        local title = string_replace(fileinfo2.fullpath, basename, "%")
                        local url = opts.server .. "/data/infohash/" .. infohash .. "/" .. fileinfo2.fullpath
                        local hdr = { "!new_stream", "!no_clip", "!no_chapters",
                                      "!delay_open,media_type=" .. fileinfo2.type,
                                      "!track_meta,title=" .. edlencode(title),
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

mp.add_hook("on_load", 5, function()
    local url = mp.get_property("stream-open-filename")
    if url:find("^magnet:") == 1 then
        local magnet_info, err = get_magnet_info(url)
        if type(magnet_info) == "table" then
            if magnet_info.files then
                -- torrent has multiple files. open as playlist
                mp.set_property("stream-open-filename", "memory://" .. generate_m3u(url, magnet_info.files))
                return
            end
            -- if not a playlist and has a name
            if magnet_info.name then
                mp.set_property("stream-open-filename", "memory://#EXTM3U\n" ..
                        "#EXTINF:0," .. magnet_info.name .. "\n" ..
                        opts.server .. "/data?magnet=" .. url)
                return
            end
        else
            mp.msg.warn("magnet bencode error: " .. err)
        end
        mp.set_property("stream-open-filename", opts.server .. "/data?magnet=" .. url)
    end
end)
