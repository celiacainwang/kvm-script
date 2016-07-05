#!/bin/sh
virt-install \
-n $1 --os-variant=rhel7  \
--memory=4096,hugepages=yes \
--memorybacking hugepages=yes,size=1,unit=G,locked=yes,nodeset=1 \
--vcpus=4,cpuset=1,2,3,4 --numatune=1 --memtune=hard_limit=16777216  \
--disk path=/home/${1}.qcow2,bus=virtio,cache=none,format=qcow2,io=threads,size=20 \
--graphics type=spice,listen=0.0.0.0 \
-l $2 \
-x "ks=http://10.66.8.145/wxy-test-kickstart.cfg" \
--graphics vnc,port=5910 \
--noautoconsole
