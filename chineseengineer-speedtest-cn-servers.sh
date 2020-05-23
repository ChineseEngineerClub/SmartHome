#!/usr/bin/env bash
trap 'echo "“Chinese Engineer 中国工程师”祝愿“科技让您的生活更美好”，再见！"' EXIT
set -euo pipefail

if [[ -z "$(pip -h | grep -i "Usage:")" ]]; then
	apt-get install python-pip
fi

if [[ -z "$(speedtest-cli -h | grep -i "usage: speedtest-cli")" ]]; then
	pip install speedtest-cli
fi

speedtest-cli --list | grep -i 'china' > ~/speedtest-cn-servers.md
awk -F\) '{print $1}' ~/speedtest-cn-servers.md > ~/speedtest-cn-ids.md

ls ~/speedtest-cn-results-raw.csv && mv ~/speedtest-cn-results-raw.csv ~/speedtest-cn-results-raw.csv."$(date '+%Y-%m-%d %H:%M:%S')"
count=0
for i in $(cat ~/speedtest-cn-ids.md); do
	speedtest-cli --server $i --csv --csv-delimiter "#" >> ~/speedtest-cn-results-raw.csv
    count=$((count + 1))
done

awk -F# '{print $1,$2,$3,$4,$7,$8}' OFS="#" ~/speedtest-cn-results-raw.csv > ~/speedtest-cn-results.csv

declare -a idArr
declare -a telecomArr
declare -a citiesArr
declare -a dateArr
declare -a timeArr
declare -a downloadArr
declare -a uploadArr
input="$(echo ~)/speedtest-cn-results.csv"
while IFS="#" read -r line
do
  IFS="#" read id telecom city time download upload <<< "$line"
  idArr+=($id)
  telecomArr["$id"]=$telecom
  citiesArr["$id"]=$city
  dateArr["$id"]="$(date -d "$time" +%Y-%m-%d)"
  timeArr["$id"]="$(date -d "$time" +%H:%M:%S)"
  downloadArr["$id"]=$(( ${download%.*}/1000000 ))
  uploadArr["$id"]=$(( ${upload%.*}/1000000 ))
done < "$input"

declare chartRows="['City', 'VPS-in', {type: 'string', role: 'annotation'}, 'VPS-out', {type: 'string', role: 'annotation'}],"
for i in "${idArr[@]}"; do
	declare -a chartRow
	chartRow[0]="${citiesArr[$i]}<br />${telecomArr[$i]}"
	chartRow[1]=$(( ${downloadArr[$i]} ))
	chartRow[2]="${downloadArr[$i]}Mbps ${dateArr[$i]}"
	chartRow[3]=$(( ${uploadArr[$i]} ))
	chartRow[4]="${uploadArr[$i]}Mbps ${timeArr[$i]}"
	chartRows+="[\"${chartRow[0]}\", ${chartRow[1]}, \"${chartRow[2]}\", ${chartRow[3]}, \"${chartRow[4]}\"]," 
done
chartRows="[${chartRows%,}]"

cat > /usr/share/nginx/html/index.html << _EOF_
<!DOCTYPE html>
<html>
  <head>
    <!--Load the AJAX API-->
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <script type="text/javascript">
    
    google.charts.load('current', {'packages':['corechart', 'bar']});
      
    google.charts.setOnLoadCallback(drawChart);
      
	const commonOptions = {
	  titleTextStyle: {
	    fontSize: 20,
	    color: '#000',
	    bold: true,
	    auraColor: 'none'
	  },
	  annotations: {
	    alwaysOutside: true,
	    textStyle: {
	      fontSize: 15,
	      color: '#000',
	      auraColor: 'none'
	    }
	  },
	  legend: {position: 'bottom', textStyle: {fontSize: 25}},
	  bars: 'horizontal',
	  colors: ['red', 'blue'],
	  backgroundColor: 'transparent',
	};

    function drawChart() {
	    var data = google.visualization.arrayToDataTable(${chartRows});

	    let options = {
	      title: '该VPS与国内城市网络节点的连接',
	      height: 999,
	    };
	    options = Object.assign({}, commonOptions, options);

	    var chart = new google.visualization.BarChart(document.getElementById('chart_div'));

	    chart.draw(data, google.charts.Bar.convertOptions(options));
	}
    </script>
  </head>

  <body>
    <div id="chart_div"></div>
  </body>
</html>
_EOF_