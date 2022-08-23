-- https://github.com/anacrolix/confluence


local confluence_server = "http://localhost:8080"


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

io = require "io"

local function get_magnet_info(url)
  return decode(io.read("*a"))
end


local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
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
        -- make audio first
        if (a.type == "audio" or b.type == "audio") and a.type ~= b.type then
            return a.type == "audio"
        end
        -- otherwise sort by path
        return a.fullpath < b.fullpath
    end);
	local playlist = {'#EXTM3U'}
	for  _, fileinfo in ipairs(magnet_info.files) do
		local path = table.concat(fileinfo.path, "/")
		--mp.msg.info(path)
		--table.insert(playlist, '#EXTINF:-1,'..path:match('[^/]+$'))
		table.insert(playlist, '#EXTINF:-1,'..path)
		table.insert(playlist, confluence_server .. "/data?magnet="..magnet_uri.."&path=" .. urlencode(path))
	end
	return table.concat(playlist, '\n')
end

function main(url)
	
	magnet_info = get_magnet_info(url)
	if type(magnet_info) == "table" then
	    --magnet_info.pieces = "(value optimised out)"
		if magnet_info.name then
			--mp.set_property("force-media-title", magnet_info.name)
		end
		if magnet_info.files then
			-- torrent has multiple files. open as playlist
			io.write(generate_m3u(url, magnet_info.files))
			return
		end
	end
    io.write(confluence_server .. "/data?magnet=" .. url)

end

local params = {...}
main(params[1])

