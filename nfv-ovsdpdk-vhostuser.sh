#!/bin/bash

START_OVSDPDK_SH_FILE="/usr/sbin/start-ovsdpdk.sh"
HUGETLB_PATH="/mnt/hugetlbfs/"
GUEST_NAME="rhel7.2-rt-355"
GUEST_BOOTUP_METHOD="libvirt" # or "qemu-kvm"
#GUEST_BOOTUP_METHOD="qemu-kvm" # or "qemu-kvm"

#MOONGEN_ETH1="em1"
#MOONGEN_ETH2="em2"
#MOONGEN_IP="10.73.64.241"
#MOONGEN_PWD="realtime"
MOONGEN_ETH1="p6p1"
MOONGEN_ETH2="p6p2"
MOONGEN_PATH="/home/MoonGen"
MOONGEN_IP="10.73.72.154"
MOONGEN_PWD="kvmautotest"
LOCALHOST_IP="10.73.72.152"

OPENVSWITCH_DPDK_PATH="http://download.eng.bos.redhat.com/brewroot/packages/openvswitch-dpdk/2.5.0/4.el7/x86_64/openvswitch-dpdk-2.5.0-4.el7.x86_64.rpm"

RT_GUEST_2VCPU_NAME="rhel7_rt_guest_2vcpu"
RT_GUEST_MULTIVCPU_NAME="rhel7_rt_guest_multivcpu"
NONRT_GUEST_2VCPU_NAME="rhel7_nonrt_guest_2vcpu"
NONRT_GUEST_MULTIVCPU_NAME="rhel7_nonrt_guest_multivcpu"

QEMU_RHEV_FOLDER="/home/qemu-kvm-rhev"
QEMU_IMG_RHEV_PATH="http://download.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.6.0/7.el7/x86_64/qemu-img-rhev-2.6.0-7.el7.x86_64.rpm"
QEMU_KVM_COMMON_RHEV_PATH="http://download.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.6.0/7.el7/x86_64/qemu-kvm-common-rhev-2.6.0-7.el7.x86_64.rpm"
QEMU_KVM_TOOLS_RHEV_PATH="http://download.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.6.0/7.el7/x86_64/qemu-kvm-tools-rhev-2.6.0-7.el7.x86_64.rpm"
QEMU_KVM_RHEV_PATH="http://download.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.6.0/7.el7/x86_64/qemu-kvm-rhev-2.6.0-7.el7.x86_64.rpm"

PYTHON_LINUX_PROCFS_PATH="http://download.eng.bos.redhat.com/brewroot/packages/python-linux-procfs/0.4.6/3.el7/noarch/python-linux-procfs-0.4.6-3.el7.noarch.rpm"
PYTHON_SCHEDUTILS_PATH="http://download.eng.bos.redhat.com/brewroot/packages/python-schedutils/0.4/5.el7/x86_64/python-schedutils-0.4-5.el7.x86_64.rpm"
TUNA_PATH="http://download.eng.bos.redhat.com/brewroot/packages/tuna/0.13/5.el7/noarch/tuna-0.13-5.el7.noarch.rpm"

MEMORY_SIZE=`cat /proc/meminfo  | grep MemTotal | awk '{print $2}'`
HUGEPAGES=$(echo "scale=1; $MEMORY_SIZE / 2 / 1024 / 1024 + 0.5" | bc)
HUGEPAGES_PER_NODE=`expr ${HUGEPAGES%.*} / 2 + 1` # ovs-dpdk need 1G per node
HUGEPAGES_TOTAL=`expr $HUGEPAGES_PER_NODE \* 2`


TFTP_ENABLE=`cat /etc/xinetd.d/tftp  | grep disable | awk '{print $3}'`

NON_RT_REPO="http://download.devel.redhat.com/nightly/latest-RHEL-7/compose/Server/x86_64/os/"
RT_REPO="http://download.devel.redhat.com/nightly/latest-RHEL-7/compose/Server-RT/x86_64/os/"

function package_install()
{
	rpm -qa | grep $1
	if [ $? != 0 ]; then
		if [ ! -n "$2" ]; then
			yum install -y $1
		else
			wget $2
		fi
	fi
}

function rt_host_packages_install()
{
	package_install "tuned-profiles-realtime"
	package_install "python-linux-procfs" $PYTHON_LINUX_PROCFS_PATH
	package_install "python-schedutils" $PYTHON_SCHEDUTILS_PATH
	package_install "tuna" $TUNA_PATH
}

function remove_qemu_rhel()
{
	yum install -y qemu-kvm
	rpm -qa | grep qemu-kvm | grep -v rhev | awk 'END {print $1}'
	if [ $? == 0 ]; then
		yum remove -y qemu-kvm-common
		yum remove -y qemu-img
		yum remove -y qemu-kvm
	fi
}

function host_packages_install()
{
	rpm -qa | grep wget
	if [ $? != 0 ]; then
		yum install wget -y
	else
		echo "wget already installed."
	fi

	#package_install "qemu-img-rhev" $QEMU_IMG_RHEV_PATH
	#package_install "qemu-kvm-common-rhev" $QEMU_KVM_COMMON_RHEV_PATH
	#package_install "qemu-kvm-tools-rhev" $QEMU_KVM_TOOLS_RHEV_PATH
	#package_install "qemu-kvm-rhev" $QEMU_KVM_RHEV_PATH
	rpm -qa | grep qemu-kvm-rhev
	if [ $? != 0 ]; then
		if [ ! -d $QEMU_RHEV_FOLDER ]; then
			mkdir $QEMU_RHEV_FOLDER
		else
			rm -rf $QEMU_RHEV_FOLDER/*
		fi
		cd $QEMU_RHEV_FOLDER
		wget $QEMU_IMG_RHEV_PATH
		wget $QEMU_KVM_COMMON_RHEV_PATH
		wget $QEMU_KVM_TOOLS_RHEV_PATH
		wget $QEMU_KVM_RHEV_PATH
		remove_qemu_rhel
		rpm -Uvh qemu-*
		cd -
	fi
	package_install "virt-manager"
	package_install "virt-install"
	package_install "virt-viewer"
}

function start_ovsdpdk_exist()
{
	if [ -f $START_OVSDPDK_SH_FILE ]; then
		rm -f $START_OVSDPDK_SH_FILE
	fi
	return 0
}

function kill_qemu_kvm()
{
	KILL_CMD=`ps aux | grep qemu-kvm | grep -v grep | awk '{print $2}' | sed 's#^#kill -9 #g'`
	if [ -n "$KILL_CMD" ]; then
		echo "=====================$KILL_CMD"
		echo $KILL_CMD | sh
	else
		echo "=====================qemu-kvm is not running"
	fi
}

function export_start_ovsdpdk()
{
cat > $START_OVSDPDK_SH_FILE << EOF
#!/bin/bash -x

# . /root/watson/dpdk-env.sh

CPU_NO_TOTAL=\`cat /proc/cpuinfo  | grep processor | awk 'END {print \$3}'\`
MQ_NO=1
#prefix="/usr/local" # used with locally built src
prefix=""  # used with RPMs

vhost="user" # can be user or cuse
eth_model="X540-AT2" # use XL710 for 40Gb

export DB_SOCK="\$prefix/var/run/openvswitch/db.sock"
network_topology="physdev-to-vm" # two bridges, each with one physdev and one vhostuser

# load/unload modules and bind Ethernet cards to dpdk modules
for kmod in fuse vfio vfio-pci; do
	if lsmod | grep -q \$kmod; then
	echo "not loading \$kmod (already loaded)"
else
	if modprobe -v \$kmod; then
		echo "loaded \$kmod module"
	else
		echo "Failed to load \$kmmod module, exiting"
		exit 1
	fi
fi
done

dpdk_nics=\`lspci -D | grep \$eth_model | awk '{print \$1}'\`
echo DPDK adapters: \$dpdk_nics

dpdk_nic_kmod=vfio-pci # can be vfio or uio_pci_generic or igb_uio

# if using igb_uio, load the dpdk (out of kernel tree) igb module
if [ "\$dpdk_nic_kmod" == "igb_uio" ]; then
	load_kmod="insmod \$DPDK_BUILD/kmod/igb_uio.ko"
else
	load_kmod="modprobe -v \$dpdk_nic_kmod"
fi

if lsmod | grep -q \$dpdk_nic_kmod; then
	echo "not loading \$dpdk_nic_kmod (already loaded)"
else
	if \$load_kmod; then
		echo "loaded \$dpdk_nic_kmod module"
	else
		echo "Failed to load \$dpdk_nic_kmod module, exiting"
		exit 1
	fi
fi

# bind the devices to dpdk module
for nic in \$dpdk_nics; do
	/usr/local/sbin/dpdk_nic_bind --bind \$dpdk_nic_kmod \$nic
done
/usr/local/sbin/dpdk_nic_bind --status

# completely remove old ovs configuration
echo "remove old ovs configuration"
killall ovs-vswitchd
killall ovsdb-server
killall ovsdb-server ovs-vswitchd
sleep 3
rm -rf \$prefix/var/run/openvswitch/*
rm -rf \$prefix/etc/openvswitch/*db*
rm -rf \$prefix/var/log/openvswitch/*

# start new ovs
echo "start new ovs"
mkdir -p \$prefix/var/run/openvswitch
mkdir -p \$prefix/etc/openvswitch
\$prefix/bin/ovsdb-tool create \$prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema

rm -rf /dev/usvhost-1
\$prefix/sbin/ovsdb-server -v --remote=punix:\$DB_SOCK \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach || exit 1

# openvswitch must be run as user qemu in order for qemu to open the vhost sockets
# if you want to see output from ovs-vswitchd start, run "screen -x"
echo "openvswitch init"
screen -dmS ovs sudo su -g qemu -c "umask 002; \$prefix/sbin/ovs-vswitchd --dpdk \$cuse_dev_opt -c 0x1 -n 3 --socket-mem 1024,1024 -- unix:\$DB_SOCK --pidfile --mlockall --log-file=\$prefix/var/log/openvswitch/ovs-vswitchd.log"
\$prefix/bin/ovs-vsctl --no-wait init

case \$network_topology in
	"physdev-to-vm")
	echo "physdev-to-vm"
	\$prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
	echo "add br & port"
	\$prefix/bin/ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
	\$prefix/bin/ovs-vsctl add-port ovsbr0 dpdk0 -- set Interface dpdk0 type=dpdk
	\$prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
	echo "add flow"
	\$prefix/bin/ovs-ofctl del-flows ovsbr0
	\$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
	\$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"

	\$prefix/bin/ovs-vsctl --if-exists del-br ovsbr1
	echo "add br1 & port"
	\$prefix/bin/ovs-vsctl add-br ovsbr1 -- set bridge ovsbr1 datapath_type=netdev
	\$prefix/bin/ovs-vsctl add-port ovsbr1 dpdk1 -- set Interface dpdk1 type=dpdk
	\$prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user2 -- set Interface vhost-user2 type=dpdkvhostuser
	echo "add flow"
	\$prefix/bin/ovs-ofctl del-flows ovsbr1
	\$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
	\$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"
	\$perfix/bin/ovs-vsctl show
	;;
esac

function multi_queue_setup()
{
	ovs-vsctl set Open_vSwitch . other_config={}
	ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=\$1
#	ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=\$CPU_MASK_FOR_OVS_MQ
}

if [ "\$CPU_NO_TOTAL" -gt "26" ]; then
	MQ_NO=8
	multi_queue_setup "\$MQ_NO"
elif [ "\$CPU_NO_TOTAL" -gt "14" ]; then
	MQ_NO=4
	multi_queue_setup "\$MQ_NO"
fi
ovs-vsctl show
EOF
}

function check_ovsdpdk_exist()
{
#	rm -f openvswitch-dpdk*.rpm
#	package_install "openvswitch-dpdk" $OPENVSWITCH_DPDK_PATH
#	if [ -f "openvswitch-dpdk*.rpm" ]; then
#		rpm -Uvh openvswitch-dpdk*.rpm
#	fi
	rpm -qa | grep openvswitch-dpdk
	if [ $? != 0 ]; then
		wget $OPENVSWITCH_DPDK_PATH
		rpm -Uvh openvswitch-dpdk*
		rm -f openvswitch-dpdk*.rpm
	else
		echo "openvswitch-dpdk already installed."
	fi
	rm -f /usr/local/sbin/dpdk_nic_bind
	cp -u ./dpdk_nic_bind /usr/local/sbin/
}

function hugetlb_directory_exist()
{
	echo "check hugepage directory exist"
	if [ ! -d "$HUGETLB_PATH" ]; then
		mkdir $HUGETLB_PATH
	fi
}

function hugetlb_mount()
{
	echo "mount hugepage"
	PAGESIZE_1G=`cat /proc/cmdline | grep "default_hugepagesz=1G"`
	if [ ! -z "$PAGESIZE_1G" ]; then
		mount -t hugetlbfs hugetlbfs $HUGETLB_PATH -o size=$HUGEPAGES_TOTAL
		echo $HUGEPAGES_PER_NODE > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
		echo $HUGEPAGES_PER_NODE > /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
		echo -n "Hugepages on Node 0: "
		cat /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
		echo -n "Hugepages on Node 1: "
		cat /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
	else
		PAGESIZE_2M=`cat /proc/cmdline | grep "default_hugepagesz=2M"`
		if [ ! -z "$PAGESIZE_2M" ]; then
			mount -t  hugetlbfs -o pagesize=2048K none $HUGETLB_PATH
		else
			echo "please add hugepage setting in /boot/grub2/grub.cfg first."
			exit
		fi
	fi
}

function moongen_on_host()
{
echo "start MoonGen on Host"
/usr/bin/expect << EOF
set timeout 180
spawn ssh root@$1
expect "*]#*" {send "sh /home/check_moongen.sh $2\r"}
expect "*]#*" {send "cd $2\r"}
expect "*]#*" {send "rm -rf /var/run/.rte_config\r"}
expect "*]#*" {send "ifconfig $3 down\r"}
expect "*]#*" {send "ifconfig $4 down\r"}
expect "*]#*" {send "modprobe vfio\r"}
expect "*]#*" {send "modprobe vfio-pci\r"}
expect "*]#*" {send "dpdk_nic_bind -b vfio-pci 04:00.0 04:00.1\r"}
expect "*]#*" {send "rm -f $2/histogram.csv\r"}
expect "*]#*" {send "killall MoonGen\r"}
expect "*]#*" {send "sleep 5\r"}
expect "*]#*" {send "time ./build/MoonGen /home/l2-load-latency.lua 0 1 0.01 &\r"}
expect "*]#*" {send "sleep 30\r"}
expect "*]#*" {send "ls $2\r"}
expect "*]#*" {send "sh get_latency_result.sh $2\r"}
expect "*]#*" {send "sleep 15\r"}
expect "*]#*" {send "date >> $2/latency_result\r"}
expect "*]#*" {send "python $2/tiny.py $2/histogram.csv >> $2/latency_result\r"}
expect "*]#*" {send "echo \"\" >> $2/latency_result\r"}
expect "*]#*" {send "cat $2/latency_result\r"}
expect "*]#*" {send "ls\r"}
EOF
}
#expect "*]#*" {send "sleep 20\r"}
#expect "*]#*" {send "time chrt -f 95 ./build/MoonGen /home/rfc1242.lua 0 1 64 > $2/throughput_result &\r"}


#expect "*]#*" {send "MOONGENID=\$(ps aux | grep MoonGen | grep -v grep | awk \'{print \\\$2}\')\r"}
#expect "*]#*" {send "cat \$MOONGENPID\r"}
#expect "*]#*" {send "kill -15 \$MOONGENPID\r"}
#expect "*]#*" {send "sleep 18\r"}
#expect "*]#*" {send "python $2/tiny.py $2/histogram.csv | awk '{print \$4}' >> $2/result\r"}

function env_on_guest()
{
/usr/bin/expect << EOF
set timeout 120
spawn virsh console $1
expect {
	"*login:*" {send "root\r";exp_continue}
	"*Password:*" {send "redhat\r";exp_continue}
	"*]#*" {send "cd /home\r"}
	expect eof
}
expect "*]#*" {send "ls\r"}
expect "*]#*" {send "dhclient eth0\r"}
expect "*]#*" {send "yum install -y tftp\r"}
expect "*]#*" {send "tftp $3 -c get guest-env.sh\r"}
expect "*]#*" {send "sleep 5\r"}
expect "*]#*" {send "tftp $3 -c get testpmd-mq${2}.sh\r"}
expect "*]#*" {send "sh guest-env.sh\r"}
expect "*]#*" {send "sh testpmd-mq${2}.sh\r"}
expect eof
expect exit
EOF
}
#expect "*]#*" {send "chrt -f 95 testpmd -d /usr/lib64/librte_pmd_virtio.so.1 -l 1,2,3 --socket-mem 1024 -n 1 --proc-type auto --file-prefix pg -w 00:04.0 -w 00:05.0 -- --portmask=3 --disable-hw-vlan --disable-rss -i --rxq=1 --txq=1 --rxd=256 --txd=256 --auto-start --nb-cores=2\r"}

CPU_NO_TOTAL=`cat /proc/cpuinfo  | grep processor | awk 'END {print $3}'`
MQ_NO=1
function decide_mq()
{
	if [ "$CPU_NO_TOTAL" -gt "25" ]; then
		MQ_NO=8
	elif [ "$CPU_NO_TOTAL" -gt "13" ]; then
		MQ_NO=4
	fi
}
function start_guest()
{
	echo "start guest with $1" #libvirt or qemu-kvm
	echo "start guest $2" #guest name
	setenforce 0
	if [ "$1" == "libvirt" ]; then
		virsh start $2
		sleep 5
		###########################test##########
		#MQ_NO=1
		#########################################
		env_on_guest $2 $MQ_NO $LOCALHOST_IP
	else
		echo "only support libvirt currently!"
		exit
	fi
}

function copy_scripts_to_host()
{
	echo "creating pub key and copy to another host"
	sh ./gen_and_copy_rsa_pub.sh $1 $MOONGEN_PWD

	echo "copy scripts to Host"
	scp ./check_moongen.sh root@$1:/home/
	scp ./l2-load-latency.lua root@$1:/home/
	scp ./rfc1242.lua root@$1:/home/
	scp ./get_latency_result.sh root@$1:/home/
	scp ./tiny.py root@$1:/home/
	scp ./dpdk_nic_bind root@$1:/usr/local/sbin/
}

function start_tftp_server()
{
	package_install "tftp-server"
	package_install "tftp"
#	echo $TFTP_ENABLE
	if [ "$TFTP_ENABLE" == "yes" ]; then
		echo -n "patching /etc/xinetd.d/tftp..."
		cat > /home/tftp_config.patch << EOF
--- /etc/xinetd.d/tftp	2016-06-28 14:47:35.471648823 +0800
+++ /etc/xinetd.d/tftp.ori	2016-06-28 14:47:26.072425401 +0800
@@ -10,8 +10,8 @@
 	wait			= yes
 	user			= root
 	server			= /usr/sbin/in.tftpd
-	server_args		= -s /var/lib/tftpboot -c
-	disable			= no
+	server_args		= -s /var/lib/tftpboot
+	disable			= yes
 	per_source		= 11
 	cps			= 100 2
 	flags			= IPv4
EOF
		cd /etc/xinetd.d/
		patch -R tftp < /home/tftp_config.patch
		echo "done"
		cd -
	fi
	systemctl start tftp
	systemctl enable tftp
	service tftp restart
}

function copy_guest_script_to_tftpboot()
{
	rm -f /var/lib/tftpboot/testpmd*
	rm -f /var/lib/tftpboot/guest-env.sh
	cp -u ./testpmd* /var/lib/tftpboot
	cp -u ./guest-env.sh /var/lib/tftpboot
}

function start_web_server()
{
	package_install "httpd"
	service httpd start
	systemctl enable httpd
}


echo "Start TFTP server"
start_tftp_server

echo "Copy guest script to tftpboot"
copy_guest_script_to_tftpboot

echo "Start Web server"
start_web_server
rm -f /var/www/html/kickstart.cfg
cp -u ./kickstart.cfg /var/www/html

package_install "virt-manager"
yum install -y "libvirt*"
yum update device-mapper
systemctl restart libvirtd
service virtlogd start
package_install "expect"

uname -r | grep rt
if [ $? == 0 ]; then
	rt_host_packages_install
fi
host_packages_install
yum install -y "libvirt*"

start_ovsdpdk_exist
echo "Check if there's process running"
kill_qemu_kvm
echo "Creating $START_OVSDPDK_SH_FILE"
export_start_ovsdpdk
check_ovsdpdk_exist

hugetlb_directory_exist
hugetlb_mount

echo "Prepare ovsdpdk environment of test"
sh ${START_OVSDPDK_SH_FILE}

# boot up guest
uname -r | grep rt
#####################################################################################
##### only for testing
for i in $NONRT_GUEST_MULTIVCPU_NAME $NONRT_GUEST_2VCPU_NAME $RT_GUEST_MULTIVCPU_NAME $RT_GUEST_2VCPU_NAME
do
	virsh list --all | grep $i
	if [ $? == 0 ]; then
		if [ "virsh list --all | grep $i | awk '{print $3}'" == "running" ]; then
			virsh destroy $i
		fi
		virsh undefine $i
	fi
done
decide_mq

#####################################################################################
uname -r | grep rt
if [ $? != 0 ]; then
	echo "host is using non-rt kernel"
#	sh virt-install-guest.sh $NONRT_GUEST_2VCPU_NAME $NON_RT_REPO
#	start_guest $GUEST_BOOTUP_METHOD $NONRT_GUEST_2VCPU_NAME
#
	sh virt-install-guest.sh $NONRT_GUEST_MULTIVCPU_NAME $NON_RT_REPO
	virt-viewer $NONRT_GUEST_MULTIVCPU_NAME
	sleep 5
	virsh define ${NONRT_GUEST_MULTIVCPU_NAME}-$MQ_NO.xml
	sleep 10
	start_guest $GUEST_BOOTUP_METHOD $NONRT_GUEST_MULTIVCPU_NAME
else
	echo "host is using rt kernel"
#	sh virt-install-guest.sh $RT_GUEST_2VCPU_NAME $RT_REPO
#	start_guest $GUEST_BOOTUP_METHOD $RT_GUEST_2VCPU_NAME
#	sh virt-install-guest.sh $RT_GUEST_MULTIVCPU_NAME $RT_REPO
	virsh define ${RT_GUEST_MULTIVCPU_NAME}-$MQ_NO.xml
	sleep 10
	start_guest $GUEST_BOOTUP_METHOD $RT_GUEST_MULTIVCPU_NAME
#	start_guest $GUEST_BOOTUP_METHOD $GUEST_NAME
fi


# configuration on another host
copy_scripts_to_host $MOONGEN_IP $MOONGEN_PATH
moongen_on_host $MOONGEN_IP $MOONGEN_PATH $MOONGEN_ETH1 $MOONGEN_ETH2 $MOONGEN_PWD


