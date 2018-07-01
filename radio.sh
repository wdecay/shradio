#!/bin/bash

declare -A STATIONS=(
  [mute]='tail -f /dev/null'
  [KEXP]='mpg321 http://50.31.180.202:80/'
  [SomaFM (Groove Salad)]='mpg321 http://ice1.somafm.com/groovesalad-128-mp3'
  [SomaFM (Cliqhop)]='mpg321 http://ice1.somafm.com/cliqhop-128-mp3'
  [UH radio]='mpg321 http://online.uhradio.com.ua:8001/efir'
  [San Diego\'s Jazz]='mpg321 http://ksds-ice.streamguys1.com/ksds.mp3'
  [Virgin RADIO]='mpg321 http://vr-live-mp3-128.scdn.arkena.com/virginradio.mp3'
);

SOCKET=`mktemp -u --suffix=shradio.sock`
DEFAULT_STATION=mute
DIRECTORY=$(dirname "$0")
CURRENT_FILE=`mktemp -u --suffix=shradio`
HOME_PAGE=`cat "$DIRECTORY/index.html"`

handle_request() {
    method=$1
    uri=$2
    uri=${uri:1:${#uri}-1}
		echo -e 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n'
    if [ -z $uri ]; then			
			echo "$HOME_PAGE"
    elif [[ $uri == "list" ]]; then
			CURRENT=`cat $CURRENT_FILE 2> /dev/null`
			for station in "${!STATIONS[@]}"; do
				if [ "$station" == "$CURRENT" ]; then
					echo -n "*"
				fi
				echo $station
			done		
    else		
			CMD=`echo $uri | sed 's/\%20\|\+/ /g'`		
			echo $CMD | nc -U $SOCKET
			echo "{}"
    fi
}

(
	while true; do
		PIPE=`mktemp -u --suffix=shradio`
		mkfifo $PIPE		
		cat $PIPE | stdbuf -oL nc -l -q 0 -p 8085 > >(			
			read line; handle_request $line > $PIPE
		)
		rm -f $PIPE
  done
) &

WEBSERVER_PID=$!

(
	INDEX=$DEFAULT_STATION

  while true; do		
		PLAY_CMD=${STATIONS["$INDEX"]}
		echo -n "$INDEX" > $CURRENT_FILE
		eval "$PLAY_CMD || [[ $? -ne 137 ]] && echo noop | nc -q 0 -U $SOCKET" &

		SUBSHELL_PID=$!

		while CMD=$(nc -q 0 -Ul $SOCKET) && [[ -z "$CMD" ]]; do :
		done

		pkill --signal KILL -P $SUBSHELL_PID
		case "$CMD" in
			exit)
				rm -f $CURRENT_FILE
				break
				;;
			play/?*)
				INDEX=${CMD:5:${#CMD}-1}
				;;
		esac
	done
) &

trap "echo exit | nc -U $SOCKET 2> /dev/null" SIGINT SIGTERM EXIT

wait $!

kill -- -$(ps -o pgid= $WEBSERVER_PID | grep -o [0-9]*) 2 2> /dev/null
