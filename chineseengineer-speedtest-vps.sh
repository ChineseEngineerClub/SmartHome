#!/usr/bin/env bash
if [[ ${1:-0} -eq 0 ]]; then
	echo "Missing VPS Argument"
	exit 1
elif [[ ! -d "~/$1" ]]; then
	mkdir "~/$1"
fi
if [[ ! -d "~/$1/finish" ]]; then
	mkdir -p "~/$1/finish"
fi
if [[ ! -d "~/$1" ]] || [[ ! -d "~/$1/finish" ]]; then
	echo "Mkdir wrong!"
	exit 1
fi

declare -i count=0
declare -i total=0
declare -i finish=0
function trapDo(){
	[ 1 -ne $finish ] && bash chineseengineer-speedtest-vps.sh ${1:-} ${2:-} ${3:-} ${4:-}
	[ 1 -eq $finish ] && echo "***Finished***"
}
trap trapDo EXIT
set -euo pipefail

if [[ -z "$(pip -h | grep -i "Usage:")" ]]; then
	apt-get install python-pip
fi

if [[ -z "$(speedtest-cli -h | grep -i "usage: speedtest-cli")" ]]; then
	pip install speedtest-cli
fi

if [[ -z "$(gawk -h | grep -i "Usage:")" ]]; then
	apt-get install gawk
fi

grep=${2:-china}
lines="$(speedtest-cli --list | grep -i $grep)" || cat <<< ""
if [[ -n $lines ]]; then
	echo $lines > ~/$1/speedtest-servers-$grep.txt
else
	cat /dev/null >> ~/$1/speedtest-servers-$grep.txt
fi
awk -F\) '{print $1}' ~/$1/speedtest-servers-$grep.txt > ~/$1/speedtest-ids-$grep.txt

declare -i total=0
for i in $(cat ~/$1/speedtest-ids-$grep.txt); do
	total=$((total + 1))
done
declare -i count=0
for i in $(cat ~/$1/speedtest-ids-$grep.txt); do
	count=$((count + 1))
	if [ ! -e "~/$1/speedtest-results-$grep-raw.csv" ] || [[ -z "$(awk -F# -vi=$i '$1==i {print $1}' ~/$1/speedtest-results-$grep-raw.csv)" ]]; then
		if [[ -n $(speedtest-cli --list | grep -i $i\)) ]]; then
			echo "$count/$total\($(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')\)"
			line=$(speedtest-cli --server $i --csv --csv-delimiter "#")
			if [[ "$line" =~ ^$i,.*$ ]]; then
				echo line >> ~/$1/speedtest-results-$grep-raw.csv
			fi
		fi
	fi
done

if [[ 0 -ne $total ]] && [[ $count -eq $total ]]; then
	date=$(TZ='Asia/Shanghai' date '+%Y-%m-%dT%H:%M:%S')
	awk -F# -v country=${3:-china} '{OFMT="%.0f"; gsub("[-T:]|\\..*"," ",$4); print $1,$2,$3,strftime("%Y-%m-%d %H:%M:%S", mktime($4)+8*3600),$7/1000000,$8/1000000,country}' OFS="#" ~/$1/speedtest-results-$grep-raw.csv > ~/$1/finish/speedtest-results-$grep_$date.csv && finish=1
	if [[ 1 -eq $finish ]]; then
		mv ~/$1/speedtest-results-$grep-raw.csv ~/$1/finish/speedtest-results-$grep-raw_$date.csv
		mv ~/$1/speedtest-servers-$grep.csv ~/$1/finish/speedtest-servers-$grep_$date.csv
		mv ~/$1/speedtest-ids-$grep.csv ~/$1/finish/speedtest-ids-$grep_$date.csv
	fi
fi