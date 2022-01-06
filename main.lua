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

local char_to_hex = function(c)
    return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w])", char_to_hex)
    --url = url:gsub(" ", "+")
    return url
end

local function load_files(magnet_uri, files)
    table.sort(files, function(a, b)
        -- make top-level files appear first in the playlist
        if (#a.path == 1 or #b.path == 1) and #a.path ~= #b.path then
            return #a.path < #b.path
        end
        -- otherwise sort by path
        return table.concat(a.path, "/") < table.concat(b.path, "/")
    end);

    local infohash = magnet_uri:match("magnet:%?xt=urn:btih:(%w+)")
    --local ignore_files = {}
    local flag = "replace"
    for _, fileinfo in ipairs(magnet_info.files) do
        if fileinfo.processed ~= true then
            local path = table.concat(fileinfo.path, "/")
            local basename, ext = path:match('([^/]+)%.(%w+)$')
            local add_files = {}
            if basename ~= nil and (ext == "mkv" or ext == "mp4" or ext == "avi" or ext == "wmv" or ext == "vob" or ext == "m2ts" or ext == "ogm") then
                mp.msg.info(basename .. " is " .. ext)

                for _, fileinfo2 in ipairs(magnet_info.files) do
                    local path2 = table.concat(fileinfo2.path, "/")
                    if path2 ~= path and path2:find(basename, 1, true) ~= nil then
                        mp.msg.info("->" .. path2)
                        table.insert(add_files, confluence_server .. "/data/infohash/" .. infohash .. "/" .. path2)
                        fileinfo2.processed = true
                    end
                end
            end
            local options = {}
            --if #add_files > 0 then
            options["external-files"] = table.concat(add_files, ';')
            --end
            --options["force-media-title"] = path
            mp.command_native { "loadfile",
                                confluence_server .. "/data/infohash/" .. infohash .. "/" .. path,
                                flag,
                                options
            }

            -- replace the current file(magnet), then append to playlist
            if flag == "replace" then
                flag = "append"
            end
        end
    end
end

mp.add_hook("on_load", 20, function()
    local url = mp.get_property("stream-open-filename")
    if url:find("^magnet:") == 1 then
        local suffix = ""
        magnet_info = get_magnet_info(url)
        if type(magnet_info) == "table" then
            --magnet_info.pieces = "(value optimised out)"
            if magnet_info.files then
                -- torrent has multiple files. open as playlist
                load_files(url, magnet_info.files)
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
