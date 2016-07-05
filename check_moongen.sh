#!/bin/sh

HOST_MOONGEN_PATH="/home"
MOONGEN_GIT_HUB="https://github.com/emmericp/MoonGen.git"

if [ ! -d "$1" ]; then
	echo "===============git installed"
	rpm -qa | grep git-
	if [ $? -ne 0 ]; then
		yum install -y git
	fi
	echo "===============patch installed"
	rpm -qa | grep patch-
	if [ $? -ne 0 ]; then
		yum install -y patch
	fi
	echo "===============cmake installed"
	rpm -qa | grep cmake-
	if [ $? -ne 0 ]; then
		yum install -y cmake
	fi
	mkdir $1
	cd $1/../
	rm -r MoonGen
	echo "===============git clone MoonGen"
	git clone $MOONGEN_GIT_HUB
	mv /home/get_latency_result.sh $1/
	mv /home/tiny.py $1/
	cd MoonGen
	echo "===============update MoonGen submodule"
	git submodule update --init
	echo "===============patch MoonGen kni Makefile"
	cat > /home/moongen_makefile.patch << EOF
--- deps/dpdk/lib/librte_eal/linuxapp/kni/Makefile	2016-06-03 17:50:38.065075873 +0800
+++ deps/dpdk/lib/librte_eal/linuxapp/kni/Makefile_ori	2016-06-03 17:51:34.137137986 +0800
@@ -77,7 +77,7 @@
 SRCS-y += ethtool/igb/e1000_phy.c
 SRCS-y += ethtool/igb/igb_ethtool.c
 SRCS-y += ethtool/igb/igb_hwmon.c
-#SRCS-y += ethtool/igb/igb_main.c
+SRCS-y += ethtool/igb/igb_main.c
 SRCS-y += ethtool/igb/igb_debugfs.c
 SRCS-y += ethtool/igb/igb_param.c
 SRCS-y += ethtool/igb/igb_procfs.c
EOF
	patch -R deps/dpdk/lib/librte_eal/linuxapp/kni/Makefile < /home/moongen_makefile.patch

	echo "===============patch MoonGen bind interface"
	cat > /home/moongen_bind.patch << EOF
--- bind-interfaces.sh	2016-06-03 17:46:41.808600722 +0800
+++ bind-interfaces-ori.sh	2016-06-03 17:46:30.195380745 +0800
@@ -8,7 +8,7 @@
 (lsmod | grep igb_uio > /dev/null) || insmod ./x86_64-native-linuxapp-gcc/kmod/igb_uio.ko
 
 i=0
-for id in \$(tools/dpdk_nic_bind.py --status | grep -v Active | grep drv=ixgbe | cut -f 1 -d " ")
+for id in \$(tools/dpdk_nic_bind.py --status | grep -v Active | grep unused=igb_uio | cut -f 1 -d " ")
 do
 	echo "Binding interface \$id to DPDK"
  	tools/dpdk_nic_bind.py --bind=igb_uio \$id
EOF
	patch -R bind-interfaces.sh < /home/moongen_bind.patch
	./build.sh
else
	echo "MoonGen installed"
fi
