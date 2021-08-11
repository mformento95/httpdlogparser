#!/bin/bash

alog=/var/log/goaccess/actions.log
webname=
delete=
logfile=false
persist=false
temp=false
out=false
if [[ ! -e "/var/log/goaccess/" ]]; then
    mkdir -p "/var/log/goaccess/"
fi



usage() {
	echo "Usage: weblog [-w <string>] [-p|-P] [-d] [-i <filename>] [-o <filename>] (-h for help)" 1>&2;
}


while getopts ":hpPdtw:o:i:" o; do
    case "${o}" in
        h)
	    echo "---------------------------------------------------------------------------------------------------------"
	    echo "-w <webname>."
	    echo "-p save data to db dir, by default appends new data to old"
	    echo "-P contrary to -p, overwrites old data"
	    echo "-t parse log file without saving it into db, with default name \$webname_temp.html"
	    echo "-d delete goaccess old db for website specified by -s flag (db located in /etc/goaccess/dbs/"
            echo "-o target html filename. if not specified defaults to : \$webname.html in /var/www/html/ dir"
            echo "-i specify if needed log file to parse e.g. /var/log/httpd/acess_log.log"
	    echo "---------------------------------------------------------------------------------------------------------"
	    usage
	    exit 0 
            ;;
        w)
            webname="$OPTARG"
            ;;
        t)
	    temp=true
	    ;;
	d)
	    delete=true
	    ;;
	p) 
	    persist=true
	    ;;
	P)
	    persist=true
	    delete=true
	    ;;
        i)
	    logfile="$OPTARG"
	    ;;
	o)
	    out="${OPTARG/.html/}"
	    ;;
        :)
            echo "ERROR: Please supply argument for flag $OPTARG"
	    usage
            exit 2
            ;;
        \?)
            echo "ERROR: Invalid option -$OPTARG"
            usage
            exit 2
            ;;
    esac
done

shift "$((OPTIND-1))"


#echo -e "Persist: $persist\nDelete: $delete\nWebname: $webname"



db_root=/etc/goaccess/dbs
logdate="$(date +%Y%m%d)"


if [ "$webname" = "<something>" ]; then
    server=10.20.30.40
    logwebname="<something>.access.log"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") webname $webname is not valid" >>$alog
    exit 2
fi        

if [ "$logfile" = false ]; then
    if [ "$temp" = true ]; then
        logfile="/var/log/httpd/$logwebname"
    else
        logfile="/var/log/httpd/$logwebname-$logdate"
    fi
fi


if [ "$delete" = true ] && [ "$temp" = false ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") DELETE DB $db_root/$webname/" >>$alog
    rm -rf "$db_root/$webname/" &>>$alog
fi


if [[ ! -e "$db_root/$webname" ]]; then
    mkdir -p "$db_root/$webname"
fi


transfer=$(scp root@$server:"$logfile" "$webname.access.log" 2>/dev/null)
check=$(ls "$webname.access.log" 2>/dev/null)


if [[ ! "$webname.access.log" == "$check" ]]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") couldn't find log file: $logfile on server $server" &>>$alog
    exit 1
fi

if [[ !  "$out" == "false" ]]; then
    filename="/var/www/html/$out.html"
elif [[ "$temp" == "true" ]]; then
    filename="/var/www/html/"$webname"_temp.html"
else
    filename="/var/www/html/$webname.html"
fi

if [ "$temp" = true ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") generating daily tmp page $filename with log: $logfile , for $server" >>$alog
    g=$(goaccess "$webname.access.log" -o "$filename" --log-format=COMBINED --ignore-crawlers >/dev/null 2>>$alog)
elif [ "$persist" = true ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") generating $filename and saving it to db with log: $logfile , for $server" >>$alog
    g=$(goaccess "$webname.access.log" --restore --persist --db="$db_root/$webname" -o "$filename" --log-format=COMBINED --ignore-crawlers >/dev/null 2>>$alog)
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") generating $filename without saving it to db with log: $logfile , for $server" >>$alog
    g=$(goaccess "$webname.access.log" --restore --db="$db_root/$webname" -o "$filename" --log-format=COMBINED --ignore-crawlers >/dev/null 2>>$alog)
fi

rm -f "$webname.access.log"

