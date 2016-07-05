#!/bin/sh

MOONGENPID=`ps aux | grep MoonGen | grep -v grep | awk '{print $2}'`

echo $1
if [ ! -f "$1/latency_result" ]; then
	touch "$1/latency_result"
fi
echo "result will be stored in $1/latency_result"
echo "kill MoonGen pid: $MOONGENPID"
kill -2 $MOONGENPID
#sleep 18
#python $1/tiny.py $1/histogram.csv | awk '{print $4}' >> $1/latency_result
#echo "" >> $1/latency_result
