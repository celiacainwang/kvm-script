#!/bin/sh

uname -r | grep rt
if [ $? != 0 ]; then
	echo "Guest is running on non-rt kernel"
	testpmd -d /usr/lib64/librte_pmd_virtio.so.1 -l 0,1,2 --socket-mem 1024 -n 1 --proc-type auto --file-prefix pg -w 00:04.0 -w 00:05.0 -- --portmask=3 --disabl    e-hw-vlan --disable-rss -i --rxq=1 --txq=1 --rxd=256 --txd=256 --auto-start --nb-cores=2
	if [ $? != 0 ]; then
		sleep 3
		testpmd -d /usr/lib64/librte_pmd_virtio.so.1 -l 0,1,2 --socket-mem 1024 -n 1 --proc-type auto --file-prefix pg -w 00:04.0 -w 00:05.0 -- --portmask=3 --disabl    e-hw-vlan --disable-rss -i --rxq=1 --txq=1 --rxd=256 --txd=256 --auto-start --nb-cores=2
	fi
else
	echo "Guest is running on rt kernel"
	chrt -f 95 testpmd -d /usr/lib64/librte_pmd_virtio.so.1 -l 0,1,2 --socket-mem 1024 -n 1 --proc-type auto --file-prefix pg -w 00:04.0 -w 00:05.0 -- --portmask=3 --disabl    e-hw-vlan --disable-rss -i --rxq=1 --txq=1 --rxd=256 --txd=256 --auto-start --nb-cores=2
	if [ $? != 0 ]; then
		sleep 3
		chrt -f 95 testpmd -d /usr/lib64/librte_pmd_virtio.so.1 -l 0,1,2 --socket-mem 1024 -n 1 --proc-type auto --file-prefix pg -w 00:04.0 -w 00:05.0 -- --portmask=3 --disabl    e-hw-vlan --disable-rss -i --rxq=1 --txq=1 --rxd=256 --txd=256 --auto-start --nb-cores=2
	fi
fi

