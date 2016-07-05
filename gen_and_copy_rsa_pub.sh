#!/bin/sh

PEER_IP="$1"
PEER_HOST_KEY_PATH="/root/.ssh"

function usage_check()
{
	if [ -z "$1" ]; then
		echo "Usage: need peer ip as parameter"
		exit 1;
	fi
}

function check_rsa_key_existance()
{
	if [ -f "${PEER_HOST_KEY_PATH}/id_rsa" ]; then
		rm -f ${PEER_HOST_KEY_PATH}/id_rsa*
	fi
}

function generate_key()
{
/usr/bin/expect << EOF
spawn ssh-keygen -t rsa
expect "Enter*"
send "\r"
expect "Enter passphrase*"
send "\r"
expect "Enter same passphrase again*"
send "\r"
expect EOF
exit
EOF
}


function copy_pub_key_to_peer()
{
/usr/bin/expect << EOF
spawn scp ${1}/id_rsa.pub root@$2:/root/.ssh/authorized_keys
expect "*password*"
send "$3\r"
expect "*]#*" {send "exit\r"}
EOF
}

function create_ssh_folder_on_peer()
{
	rm -f ~/.ssh/known_hosts
/usr/bin/expect << EOF
set timeout 10
spawn ssh root@$1
expect {
	"*yes/no*" {send "yes\r"}
}
expect "*password*"
send "$2\r"
expect "*]#*" {send "rm -rf /root/.ssh\r"}
expect "*]#*" {send "mkdir /root/.ssh\r"}
expect "*]#*" {send "exit\r"}
expect EOF
exit
EOF
}

usage_check $1
check_rsa_key_existance
generate_key
create_ssh_folder_on_peer $PEER_IP $2
copy_pub_key_to_peer $PEER_HOST_KEY_PATH $PEER_IP $2
sleep 1
