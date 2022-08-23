#!/bin/bash

# Simple CGI script for getting playlists for confluence

# Usage: socat TCP-LISTEN:8081,fork,reuseaddr EXEC:./cgi.sh,stderr &
# then mpv http://localhost:8081/magnet/magnet:?xt=urn:btih:...

# Should only be used in local network


read request

while /bin/true; do
  read header
  [ "$header" == $'\r' ] && break;
done


if [[ "$request" =~ ^GET\ \/magnet\/(.*)\ HTTP\/.*$ ]]
then

url="${BASH_REMATCH[1]}"

echo -e "HTTP/1.1 200 OK\r"
echo -e "Content-Type: audio/x-mpegurl\r" # ??
echo -e "Access-Control-Allow-Origin: *\r" # allow ajax requests
echo -e "\r"
exec ./standalone.sh "$url"
exit 0

else
echo -e "HTTP/1.1 404 Not Found\r"
echo -e "Access-Control-Allow-Origin: *\r"
echo -e "\r"
echo 404

exit 0

fi
