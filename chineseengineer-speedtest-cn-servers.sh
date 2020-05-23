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

read -p "重新测试[Y]/任意键继续：" input
input=${input,,}
case $input in
	y ) 
#        ls ~/speedtest-cn-results-raw.csv && mv ~/speedtest-cn-results-raw.csv ~/speedtest-cn-results-raw.csv."$(date '+%Y-%m-%d %H:%M:%S')"
        ls ~/speedtest-cn-results-raw.csv && rm ~/speedtest-cn-results-raw.csv
		;;
	* )
		;;
esac

for i in $(cat ~/speedtest-cn-ids.md); do
	if [[ -z "$(awk -F# -vi=$i '$1==i {print $1}' ~/speedtest-cn-results-raw.csv)" ]] && [[ -n $(speedtest-cli --list | grep -i $i\)) ]]; then
		speedtest-cli --server $i --csv --csv-delimiter "#" >> ~/speedtest-cn-results-raw.csv
	fi
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
declare -i count=0
for i in "${idArr[@]}"; do
	declare -a chartRow
	chartRow[0]="${citiesArr[$i]}\n${telecomArr[$i]}"
	chartRow[1]=$(( ${downloadArr[$i]} ))
	chartRow[2]="${downloadArr[$i]}Mbps ${dateArr[$i]}"
	chartRow[3]=$(( ${uploadArr[$i]} ))
	chartRow[4]="${uploadArr[$i]}Mbps ${timeArr[$i]}"
	chartRows+="[\"${chartRow[0]}\", ${chartRow[1]}, \"${chartRow[2]}\", ${chartRow[3]}, \"${chartRow[4]}\"],"
	count+=1
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
		hAxis: {
			textStyle: {
			    fontSize: 15,
			}
	    },
	    vAxis: {
			textStyle: {
			    fontSize: 20,
			}
	    },
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
	    legend: {position: 'top', textStyle: {fontSize: 25}},
	    bars: 'horizontal',
	    colors: ['lightblue', 'green'],
	    backgroundColor: 'transparent',
	};

    function drawChart() {
	    var data = google.visualization.arrayToDataTable(${chartRows});

	    let options = {
	      title: 'VPS-in, VPS-out Connecting with Chinese Cities',
	      height: $(( count*99 )),
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