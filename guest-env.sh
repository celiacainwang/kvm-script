#!/bin/sh

DPDK_PATH="http://download.eng.bos.redhat.com/brewroot/packages/dpdk/2.2.0/3.el7/x86_64/dpdk-2.2.0-3.el7.x86_64.rpm"
DPDK_TOOLS_PATH="http://download.eng.bos.redhat.com/brewroot/packages/dpdk/2.2.0/3.el7/x86_64/dpdk-tools-2.2.0-3.el7.x86_64.rpm"

rpm -qa | grep wget
if [ $? != 0 ]; then
	yum install wget -y
else
	echo "wget already installed."
fi

rpm -qa | grep dpdk | grep -v openvswitch | grep -v tools
if [ $? != 0 ]; then
	wget $DPDK_PATH
else
	echo "dpdk already installed."
fi

rpm -qa | grep dpdk-tools
if [ $? != 0 ]; then
	wget $DPDK_TOOLS_PATH
	rpm -Uvh dpdk-*.rpm
else
	echo "dpdk-tools already installed."
fi


echo -n "set hugepages..."
echo 1024 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
echo "done"

echo -n "hugepages: "
cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
