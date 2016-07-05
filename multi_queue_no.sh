#!/bin/bash

if [ "$CPU_NO_TOTAL" -gt "26" ]; then
	multi_queue_setup "8"
	MQ_NO=8
elif [ "$CPU_NO_TOTAL" -gt "14" ]; then
	multi_queue_setup "4"
	MQ_NO=4
#else
#	# just for test
#	multi_queue_setup "2"
#	MQ_NO=1
fi

#echo -n 0 > /home/tmp.sr
#for((i=1;i<=$CPU_NO_TOTAL;i++));
#do
#	echo -n ",$i" >> /home/tmp.sr;
#done
