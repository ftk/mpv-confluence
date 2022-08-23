curl -s --max-time 60 "http://localhost:8080/info?magnet=$1" | lua standalone.lua "$1"
