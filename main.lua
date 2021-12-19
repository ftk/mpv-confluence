-- https://github.com/anacrolix/confluence

local bencode = require "bencode"

local confluence_server = "http://10.200.200.6:8000"

local function get_magnet_info(url)
	local luacurl_available, cURL = pcall(require,'cURL')
	local info_url = confluence_server .. "/info?magnet=" .. url
	if not(luacurl_available) then -- if Lua-cURL is not available on this system
		local curl_cmd = {
			"curl",
			"-L",
			"-s",
			info_url
		}
		local cmd = mp.command_native{
			name = "subprocess",
			capture_stdout = true,
			playback_only = false,
			args = curl_cmd
		}
		res = cmd.stdout
	else -- otherwise use Lua-cURL (binding to libcurl)
		local buf={}
		local c = cURL.easy_init()
		c:setopt_followlocation(1)
		c:setopt_url(info_url)
		c:setopt_writefunction(function(chunk) table.insert(buf,chunk); return true; end)
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
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

local function generate_m3u(magnet_uri, files)
	table.sort(files, function(a, b) 
		-- make top-level files appear first in the playlist
		if (#a.path == 1 or #b.path == 1) and #a.path ~= #b.path then
			return #a.path < #b.path
		end
		-- otherwise sort by path
		return table.concat(a.path, "/") < table.concat(b.path, "/") 
	end);
	local playlist = {'#EXTM3U'}
	for  _, fileinfo in ipairs(magnet_info.files) do
		local path = table.concat(fileinfo.path, "/")
		mp.msg.info(path)
		--table.insert(playlist, '#EXTINF:-1,'..path:match('[^/]+$'))
		table.insert(playlist, '#EXTINF:-1,'..path)
		table.insert(playlist, confluence_server .. "/data?magnet="..magnet_uri.."&path=" .. urlencode(path))
	end
	return table.concat(playlist, '\n')
end

mp.add_hook("on_load", 20, function ()
    local url = mp.get_property("stream-open-filename")
    if url:find("^magnet:") == 1 then
		magnet_info = get_magnet_info(url)
		if type(magnet_info) == "table" then
		    --magnet_info.pieces = "(value optimised out)"
			if magnet_info.files then
				-- torrent has multiple files. open as playlist
				-- TODO: detect matching subtitles, audio files by filename and add them (external-files)
				mp.set_property('stream-open-filename', 'memory://'..generate_m3u(url, magnet_info.files))
				return
			end
			-- if not a playlist and has a name
			if magnet_info.name then
				mp.set_property("force-media-title", magnet_info.name)
			end
		end
        mp.set_property("stream-open-filename", confluence_server .. "/data?magnet=" .. url)
    end
end)
