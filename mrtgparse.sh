#!/bin/bash

ip_file="/var/log/mrtg/mrtg_ips.log"
epoch_now="$(date +%s)"

find /var/log/mrtg/ -mtime +1 -type f -name 'mrtg_ips.log' -delete

regex="^(([0-9]{1,3}|\.)+) - - \[(.[^]]+)\] '([A-Z-]*) (.[^ ]*) (.[^']*)' ([0-9])?[0-9]+ "

IFS=$'\n'

set -f

traffic=0
unique_daily_users=0

for i in $(ssh root@10.20.30.40 'tac /var/log/httpd/mediascan.access.log-20210729' 2>/dev/null); do
    i=$(echo "$i" | sed "s/\"/'/g")
    if [[ "$i" =~ $regex ]]; then
        
	read -d '' -r -a ips < $ip_file

        request="${BASH_REMATCH[4]}"
	page="${BASH_REMATCH[5]}"
	rtype="${BASH_REMATCH[6]}"
        ip="${BASH_REMATCH[1]}"
	code="${BASH_REMATCH[7]}"
	timelog="${BASH_REMATCH[3]}"

	timelog="${timelog//\// }"
        timelog="${timelog/:/ }"
	formatted="$(date -d"$timelog" '+%m/%d/%Y %T')"
        epoch_time="$(date --date="$formatted" +"%s")"

	if (( "$(( $epoch_now - $epoch_time ))" > 300 )); then
	    break
	elif (( $code > 3 )); then
	    continue
        elif [[ $page =~ "favicon.ico" ]]; then
            continue
        elif [[ "$page" =~ (.+\.png|.+\.jpg|.+\.jpeg) ]]; then
            continue	
        fi

        #echo "$i"
        #echo "DATE $timelog epoch: $epoch_time"
	#echo -e "req: $request\nfor: $page\ntype: $rtype\nip: $ip\ncode: $code"
	#echo "---------------------------------------------------------------------------------------------"
        
	if [[ ! "${ips[@]}" =~ "$ip" ]]; then
            #echo "ADDED IP : $ip"
	    #echo "$ip" >> $ip_file
	    let unique_daily_users++
        fi	    
        let traffic++
    else
        #echo "REGEX NO MATCH ----- $i"
	continue
    fi
done

#echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "$traffic"
echo "$unique_daily_users"
echo "$(cut -d',' -f1 <<< $(ssh root@10.20.30.40 'uptime' 2>/dev/null))"
echo "<Website>"
