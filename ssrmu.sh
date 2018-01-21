#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the ShadowsocksR mudbjson server
#	Version: 1.0.25
#	Author: Zach Chan
#	Blog: https://blog.zachchan.com/
#=================================================

sh_ver="1.0.25"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
ssr_folder="/usr/local/shadowsocksr"
config_file="${ssr_folder}/config.json"
config_user_file="${ssr_folder}/user-config.json"
config_user_api_file="${ssr_folder}/userapiconfig.py"
config_user_mudb_file="${ssr_folder}/mudb.json"
ssr_log_file="${ssr_folder}/ssserver.log"
Libsodiumr_file="/usr/local/lib/libsodium.so"
Libsodiumr_ver_backup="1.0.15"
Server_Speeder_file="/serverspeeder/bin/serverSpeeder.sh"
LotServer_file="/appex/bin/serverSpeeder.sh"
BBR_file="${file}/bbr.sh"
jq_file="${ssr_folder}/jq"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[��Ϣ]${Font_color_suffix}"
Error="${Red_font_prefix}[����]${Font_color_suffix}"
Tip="${Green_font_prefix}[ע��]${Font_color_suffix}"
Separator_1="������������������������������������������������������������"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} ��ǰ�˺ŷ�ROOT(��û��ROOTȨ��)���޷�������������ʹ��${Green_background_prefix} sudo su ${Font_color_suffix}����ȡ��ʱROOTȨ�ޣ�ִ�к����ʾ���뵱ǰ�˺ŵ����룩��" && exit 1
}
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_pid(){
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
}
check_crontab(){
	[[ ! -e "/usr/bin/crontab" ]] && echo -e "${Error} ȱ������ Crontab ���볢���ֶ���װ CentOS: yum install crond -y , Debian/Ubuntu: apt-get install cron -y !" && exit 1
}
SSR_installation_status(){
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} û�з��� ShadowsocksR �ļ��У����� !" && exit 1
}
Server_Speeder_installation_status(){
	[[ ! -e ${Server_Speeder_file} ]] && echo -e "${Error} û�а�װ ����(Server Speeder)������ !" && exit 1
}
LotServer_installation_status(){
	[[ ! -e ${LotServer_file} ]] && echo -e "${Error} û�а�װ LotServer������ !" && exit 1
}
BBR_installation_status(){
	if [[ ! -e ${BBR_file} ]]; then
		echo -e "${Error} û�з��� BBR�ű�����ʼ����..."
		cd "${file}"
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/bbr.sh; then
			echo -e "${Error} BBR �ű�����ʧ�� !" && exit 1
		else
			echo -e "${Info} BBR �ű�������� !"
			chmod +x bbr.sh
		fi
	fi
}
# ���� ����ǽ����
Add_iptables(){
	if [[ ! -z "${ssr_port}" ]]; then
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
		iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
		ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
		ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
	fi
}
Del_iptables(){
	if [[ ! -z "${port}" ]]; then
		iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
		iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
		ip6tables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
		ip6tables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
	fi
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
		chkconfig --level 2345 iptables on
		chkconfig --level 2345 ip6tables on
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
# ��ȡ ������Ϣ
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Get_User_info(){
	Get_user_port=$1
	user_info_get=$(python mujson_mgr.py -l -p "${Get_user_port}")
	match_info=$(echo "${user_info_get}"|grep -w "### user ")
	if [[ -z "${match_info}" ]]; then
		echo -e "${Error} �û���Ϣ��ȡʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	fi
	user_name=$(echo "${user_info_get}"|grep -w "user :"|awk -F "user : " '{print $NF}')
	port=$(echo "${user_info_get}"|grep -w "port :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	password=$(echo "${user_info_get}"|grep -w "passwd :"|awk -F "passwd : " '{print $NF}')
	method=$(echo "${user_info_get}"|grep -w "method :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	protocol=$(echo "${user_info_get}"|grep -w "protocol :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	protocol_param=$(echo "${user_info_get}"|grep -w "protocol_param :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	[[ -z ${protocol_param} ]] && protocol_param="0(����)"
	obfs=$(echo "${user_info_get}"|grep -w "obfs :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	#transfer_enable=$(echo "${user_info_get}"|grep -w "transfer_enable :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}'|awk -F "ytes" '{print $1}'|sed 's/KB/ KB/;s/MB/ MB/;s/GB/ GB/;s/TB/ TB/;s/PB/ PB/')
	#u=$(echo "${user_info_get}"|grep -w "u :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	#d=$(echo "${user_info_get}"|grep -w "d :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	forbidden_port=$(echo "${user_info_get}"|grep -w "forbidden_port :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	[[ -z ${forbidden_port} ]] && forbidden_port="������"
	speed_limit_per_con=$(echo "${user_info_get}"|grep -w "speed_limit_per_con :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	speed_limit_per_user=$(echo "${user_info_get}"|grep -w "speed_limit_per_user :"|sed 's/[[:space:]]//g'|awk -F ":" '{print $NF}')
	Get_User_transfer "${port}"
}
Get_User_transfer(){
	transfer_port=$1
	#echo "transfer_port=${transfer_port}"
	all_port=$(${jq_file} '.[]|.port' ${config_user_mudb_file})
	#echo "all_port=${all_port}"
	port_num=$(echo "${all_port}"|grep -nw "${transfer_port}"|awk -F ":" '{print $1}')
	#echo "port_num=${port_num}"
	port_num_1=$(expr ${port_num} - 1)
	#echo "port_num_1=${port_num_1}"
	transfer_enable_1=$(${jq_file} ".[${port_num_1}].transfer_enable" ${config_user_mudb_file})
	#echo "transfer_enable_1=${transfer_enable_1}"
	u_1=$(${jq_file} ".[${port_num_1}].u" ${config_user_mudb_file})
	#echo "u_1=${u_1}"
	d_1=$(${jq_file} ".[${port_num_1}].d" ${config_user_mudb_file})
	#echo "d_1=${d_1}"
	transfer_enable_Used_2_1=$(expr ${u_1} + ${d_1})
	#echo "transfer_enable_Used_2_1=${transfer_enable_Used_2_1}"
	transfer_enable_Used_1=$(expr ${transfer_enable_1} - ${transfer_enable_Used_2_1})
	#echo "transfer_enable_Used_1=${transfer_enable_Used_1}"
	
	
	if [[ ${transfer_enable_1} -lt 1024 ]]; then
		transfer_enable="${transfer_enable_1} B"
	elif [[ ${transfer_enable_1} -lt 1048576 ]]; then
		transfer_enable=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_1}'/'1024'}')
		transfer_enable="${transfer_enable} KB"
	elif [[ ${transfer_enable_1} -lt 1073741824 ]]; then
		transfer_enable=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_1}'/'1048576'}')
		transfer_enable="${transfer_enable} MB"
	elif [[ ${transfer_enable_1} -lt 1099511627776 ]]; then
		transfer_enable=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_1}'/'1073741824'}')
		transfer_enable="${transfer_enable} GB"
	elif [[ ${transfer_enable_1} -lt 1125899906842624 ]]; then
		transfer_enable=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_1}'/'1099511627776'}')
		transfer_enable="${transfer_enable} TB"
	fi
	#echo "transfer_enable=${transfer_enable}"
	if [[ ${u_1} -lt 1024 ]]; then
		u="${u_1} B"
	elif [[ ${u_1} -lt 1048576 ]]; then
		u=$(awk 'BEGIN{printf "%.2f\n",'${u_1}'/'1024'}')
		u="${u} KB"
	elif [[ ${u_1} -lt 1073741824 ]]; then
		u=$(awk 'BEGIN{printf "%.2f\n",'${u_1}'/'1048576'}')
		u="${u} MB"
	elif [[ ${u_1} -lt 1099511627776 ]]; then
		u=$(awk 'BEGIN{printf "%.2f\n",'${u_1}'/'1073741824'}')
		u="${u} GB"
	elif [[ ${u_1} -lt 1125899906842624 ]]; then
		u=$(awk 'BEGIN{printf "%.2f\n",'${u_1}'/'1099511627776'}')
		u="${u} TB"
	fi
	#echo "u=${u}"
	if [[ ${d_1} -lt 1024 ]]; then
		d="${d_1} B"
	elif [[ ${d_1} -lt 1048576 ]]; then
		d=$(awk 'BEGIN{printf "%.2f\n",'${d_1}'/'1024'}')
		d="${d} KB"
	elif [[ ${d_1} -lt 1073741824 ]]; then
		d=$(awk 'BEGIN{printf "%.2f\n",'${d_1}'/'1048576'}')
		d="${d} MB"
	elif [[ ${d_1} -lt 1099511627776 ]]; then
		d=$(awk 'BEGIN{printf "%.2f\n",'${d_1}'/'1073741824'}')
		d="${d} GB"
	elif [[ ${d_1} -lt 1125899906842624 ]]; then
		d=$(awk 'BEGIN{printf "%.2f\n",'${d_1}'/'1099511627776'}')
		d="${d} TB"
	fi
	#echo "d=${d}"
	if [[ ${transfer_enable_Used_1} -lt 1024 ]]; then
		transfer_enable_Used="${transfer_enable_Used_1} B"
	elif [[ ${transfer_enable_Used_1} -lt 1048576 ]]; then
		transfer_enable_Used=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_1}'/'1024'}')
		transfer_enable_Used="${transfer_enable_Used} KB"
	elif [[ ${transfer_enable_Used_1} -lt 1073741824 ]]; then
		transfer_enable_Used=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_1}'/'1048576'}')
		transfer_enable_Used="${transfer_enable_Used} MB"
	elif [[ ${transfer_enable_Used_1} -lt 1099511627776 ]]; then
		transfer_enable_Used=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_1}'/'1073741824'}')
		transfer_enable_Used="${transfer_enable_Used} GB"
	elif [[ ${transfer_enable_Used_1} -lt 1125899906842624 ]]; then
		transfer_enable_Used=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_1}'/'1099511627776'}')
		transfer_enable_Used="${transfer_enable_Used} TB"
	fi
	#echo "transfer_enable_Used=${transfer_enable_Used}"
	if [[ ${transfer_enable_Used_2_1} -lt 1024 ]]; then
		transfer_enable_Used_2="${transfer_enable_Used_2_1} B"
	elif [[ ${transfer_enable_Used_2_1} -lt 1048576 ]]; then
		transfer_enable_Used_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_2_1}'/'1024'}')
		transfer_enable_Used_2="${transfer_enable_Used_2} KB"
	elif [[ ${transfer_enable_Used_2_1} -lt 1073741824 ]]; then
		transfer_enable_Used_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_2_1}'/'1048576'}')
		transfer_enable_Used_2="${transfer_enable_Used_2} MB"
	elif [[ ${transfer_enable_Used_2_1} -lt 1099511627776 ]]; then
		transfer_enable_Used_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_2_1}'/'1073741824'}')
		transfer_enable_Used_2="${transfer_enable_Used_2} GB"
	elif [[ ${transfer_enable_Used_2_1} -lt 1125899906842624 ]]; then
		transfer_enable_Used_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_2_1}'/'1099511627776'}')
		transfer_enable_Used_2="${transfer_enable_Used_2} TB"
	fi
	#echo "transfer_enable_Used_2=${transfer_enable_Used_2}"
}
Get_User_transfer_all(){
	if [[ ${transfer_enable_Used_233} -lt 1024 ]]; then
		transfer_enable_Used_233_2="${transfer_enable_Used_233} B"
	elif [[ ${transfer_enable_Used_233} -lt 1048576 ]]; then
		transfer_enable_Used_233_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_233}'/'1024'}')
		transfer_enable_Used_233_2="${transfer_enable_Used_233_2} KB"
	elif [[ ${transfer_enable_Used_233} -lt 1073741824 ]]; then
		transfer_enable_Used_233_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_233}'/'1048576'}')
		transfer_enable_Used_233_2="${transfer_enable_Used_233_2} MB"
	elif [[ ${transfer_enable_Used_233} -lt 1099511627776 ]]; then
		transfer_enable_Used_233_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_233}'/'1073741824'}')
		transfer_enable_Used_233_2="${transfer_enable_Used_233_2} GB"
	elif [[ ${transfer_enable_Used_233} -lt 1125899906842624 ]]; then
		transfer_enable_Used_233_2=$(awk 'BEGIN{printf "%.2f\n",'${transfer_enable_Used_233}'/'1099511627776'}')
		transfer_enable_Used_233_2="${transfer_enable_Used_233_2} TB"
	fi
}
urlsafe_base64(){
	date=$(echo -n "$1"|base64|sed ':a;N;s/\n/ /g;ta'|sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
	echo -e "${date}"
}
ss_link_qr(){
	SSbase64=$(urlsafe_base64 "${method}:${password}@${ip}:${port}")
	SSurl="ss://${SSbase64}"
	SSQRcode="http://doub.pw/qr/qr.php?text=${SSurl}"
	ss_link=" SS    ���� : ${Green_font_prefix}${SSurl}${Font_color_suffix} \n SS  ��ά�� : ${Green_font_prefix}${SSQRcode}${Font_color_suffix}"
}
ssr_link_qr(){
	SSRprotocol=$(echo ${protocol} | sed 's/_compatible//g')
	SSRobfs=$(echo ${obfs} | sed 's/_compatible//g')
	SSRPWDbase64=$(urlsafe_base64 "${password}")
	SSRbase64=$(urlsafe_base64 "${ip}:${port}:${SSRprotocol}:${method}:${SSRobfs}:${SSRPWDbase64}")
	SSRurl="ssr://${SSRbase64}"
	SSRQRcode="http://doub.pw/qr/qr.php?text=${SSRurl}"
	ssr_link=" SSR   ���� : ${Red_font_prefix}${SSRurl}${Font_color_suffix} \n SSR ��ά�� : ${Red_font_prefix}${SSRQRcode}${Font_color_suffix} \n "
}
ss_ssr_determine(){
	protocol_suffix=`echo ${protocol} | awk -F "_" '{print $NF}'`
	obfs_suffix=`echo ${obfs} | awk -F "_" '{print $NF}'`
	if [[ ${protocol} = "origin" ]]; then
		if [[ ${obfs} = "plain" ]]; then
			ss_link_qr
			ssr_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				ss_link=""
			else
				ss_link_qr
			fi
		fi
	else
		if [[ ${protocol_suffix} != "compatible" ]]; then
			ss_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				if [[ ${obfs_suffix} = "plain" ]]; then
					ss_link_qr
				else
					ss_link=""
				fi
			else
				ss_link_qr
			fi
		fi
	fi
	ssr_link_qr
}
# ��ʾ ������Ϣ
View_User(){
	SSR_installation_status
	List_port_user
	while true
	do
		echo -e "������Ҫ�鿴�˺���Ϣ���û� �˿�"
		stty erase '^H' && read -p "(Ĭ��: ȡ��):" View_user_port
		[[ -z "${View_user_port}" ]] && echo -e "��ȡ��..." && exit 1
		View_user=$(cat "${config_user_mudb_file}"|grep '"port": '"${View_user_port}"',')
		if [[ ! -z ${View_user} ]]; then
			Get_User_info "${View_user_port}"
			View_User_info
			break
		else
			echo -e "${Error} ��������ȷ�Ķ˿� !"
		fi
	done
}
View_User_info(){
	ip=$(cat ${config_user_api_file}|grep "SERVER_PUB_ADDR = "|awk -F "[']" '{print $2}')
	[[ -z "${ip}" ]] && Get_IP
	ss_ssr_determine
	clear && echo "===================================================" && echo
	echo -e " �û� [${user_name}] ��������Ϣ��" && echo
	echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " �˿�\t    : ${Green_font_prefix}${port}${Font_color_suffix}"
	echo -e " ����\t    : ${Green_font_prefix}${password}${Font_color_suffix}"
	echo -e " ����\t    : ${Green_font_prefix}${method}${Font_color_suffix}"
	echo -e " Э��\t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
	echo -e " ����\t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
	echo -e " �豸������ : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
	echo -e " ���߳����� : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
	echo -e " �û������� : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}"
	echo -e " ��ֹ�Ķ˿� : ${Green_font_prefix}${forbidden_port} ${Font_color_suffix}"
	echo
	echo -e " ��ʹ������ : �ϴ�: ${Green_font_prefix}${u}${Font_color_suffix} + ����: ${Green_font_prefix}${d}${Font_color_suffix} = ${Green_font_prefix}${transfer_enable_Used_2}${Font_color_suffix}"
	echo -e " ʣ������� : ${Green_font_prefix}${transfer_enable_Used} ${Font_color_suffix}"
	echo -e " �û������� : ${Green_font_prefix}${transfer_enable} ${Font_color_suffix}"
	echo -e "${ss_link}"
	echo -e "${ssr_link}"
	echo -e " ${Green_font_prefix} ��ʾ: ${Font_color_suffix}
 ��������У��򿪶�ά�����ӣ��Ϳ��Կ�����ά��ͼƬ��
 Э��ͻ��������[ _compatible ]��ָ���� ����ԭ��Э��/������"
	echo && echo "==================================================="
}
# ���� ������Ϣ
Set_config_user(){
	echo "������Ҫ���õ��û� �û���(�����ظ�, ��������, ��֧������, �ᱨ�� !)"
	stty erase '^H' && read -p "(Ĭ��: doubi):" ssr_user
	[[ -z "${ssr_user}" ]] && ssr_user="doubi"
	echo && echo ${Separator_1} && echo -e "	�û��� : ${Green_font_prefix}${ssr_user}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_port(){
	while true
	do
	echo -e "������Ҫ���õ��û� �˿�(�����ظ�, ��������)"
	stty erase '^H' && read -p "(Ĭ��: 2333):" ssr_port
	[[ -z "$ssr_port" ]] && ssr_port="2333"
	expr ${ssr_port} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_port} -ge 1 ]] && [[ ${ssr_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	�˿� : ${Green_font_prefix}${ssr_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-65535)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-65535)"
	fi
	done
}
Set_config_password(){
	echo "������Ҫ���õ��û� ����"
	stty erase '^H' && read -p "(Ĭ��: doub.io):" ssr_password
	[[ -z "${ssr_password}" ]] && ssr_password="doub.io"
	echo && echo ${Separator_1} && echo -e "	���� : ${Green_font_prefix}${ssr_password}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_method(){
	echo -e "��ѡ��Ҫ���õ��û� ���ܷ�ʽ
 ${Green_font_prefix} 1.${Font_color_suffix} none
 ${Tip} ���ʹ�� auth_chain_* ϵ��Э�飬������ܷ�ʽѡ�� none (��ϵ��Э���Դ� RC4 ����)����������
 
 ${Green_font_prefix} 2.${Font_color_suffix} rc4
 ${Green_font_prefix} 3.${Font_color_suffix} rc4-md5
 ${Green_font_prefix} 4.${Font_color_suffix} rc4-md5-6
 
 ${Green_font_prefix} 5.${Font_color_suffix} aes-128-ctr
 ${Green_font_prefix} 6.${Font_color_suffix} aes-192-ctr
 ${Green_font_prefix} 7.${Font_color_suffix} aes-256-ctr
 
 ${Green_font_prefix} 8.${Font_color_suffix} aes-128-cfb
 ${Green_font_prefix} 9.${Font_color_suffix} aes-192-cfb
 ${Green_font_prefix}10.${Font_color_suffix} aes-256-cfb
 
 ${Green_font_prefix}11.${Font_color_suffix} aes-128-cfb8
 ${Green_font_prefix}12.${Font_color_suffix} aes-192-cfb8
 ${Green_font_prefix}13.${Font_color_suffix} aes-256-cfb8
 
 ${Green_font_prefix}14.${Font_color_suffix} salsa20
 ${Green_font_prefix}15.${Font_color_suffix} chacha20
 ${Green_font_prefix}16.${Font_color_suffix} chacha20-ietf
 ${Tip} salsa20/chacha20-*ϵ�м��ܷ�ʽ����Ҫ���ⰲװ���� libsodium ��������޷�����ShadowsocksR !" && echo
	stty erase '^H' && read -p "(Ĭ��: 5. aes-128-ctr):" ssr_method
	[[ -z "${ssr_method}" ]] && ssr_method="5"
	if [[ ${ssr_method} == "1" ]]; then
		ssr_method="none"
	elif [[ ${ssr_method} == "2" ]]; then
		ssr_method="rc4"
	elif [[ ${ssr_method} == "3" ]]; then
		ssr_method="rc4-md5"
	elif [[ ${ssr_method} == "4" ]]; then
		ssr_method="rc4-md5-6"
	elif [[ ${ssr_method} == "5" ]]; then
		ssr_method="aes-128-ctr"
	elif [[ ${ssr_method} == "6" ]]; then
		ssr_method="aes-192-ctr"
	elif [[ ${ssr_method} == "7" ]]; then
		ssr_method="aes-256-ctr"
	elif [[ ${ssr_method} == "8" ]]; then
		ssr_method="aes-128-cfb"
	elif [[ ${ssr_method} == "9" ]]; then
		ssr_method="aes-192-cfb"
	elif [[ ${ssr_method} == "10" ]]; then
		ssr_method="aes-256-cfb"
	elif [[ ${ssr_method} == "11" ]]; then
		ssr_method="aes-128-cfb8"
	elif [[ ${ssr_method} == "12" ]]; then
		ssr_method="aes-192-cfb8"
	elif [[ ${ssr_method} == "13" ]]; then
		ssr_method="aes-256-cfb8"
	elif [[ ${ssr_method} == "14" ]]; then
		ssr_method="salsa20"
	elif [[ ${ssr_method} == "15" ]]; then
		ssr_method="chacha20"
	elif [[ ${ssr_method} == "16" ]]; then
		ssr_method="chacha20-ietf"
	else
		ssr_method="aes-128-ctr"
	fi
	echo && echo ${Separator_1} && echo -e "	���� : ${Green_font_prefix}${ssr_method}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_protocol(){
	echo -e "��ѡ��Ҫ���õ��û� Э����
 ${Green_font_prefix}1.${Font_color_suffix} origin
 ${Green_font_prefix}2.${Font_color_suffix} auth_sha1_v4
 ${Green_font_prefix}3.${Font_color_suffix} auth_aes128_md5
 ${Green_font_prefix}4.${Font_color_suffix} auth_aes128_sha1
 ${Green_font_prefix}5.${Font_color_suffix} auth_chain_a
 ${Green_font_prefix}6.${Font_color_suffix} auth_chain_b
 ${Tip} ���ʹ�� auth_chain_* ϵ��Э�飬������ܷ�ʽѡ�� none (��ϵ��Э���Դ� RC4 ����)����������" && echo
	stty erase '^H' && read -p "(Ĭ��: 3. auth_aes128_md5):" ssr_protocol
	[[ -z "${ssr_protocol}" ]] && ssr_protocol="3"
	if [[ ${ssr_protocol} == "1" ]]; then
		ssr_protocol="origin"
	elif [[ ${ssr_protocol} == "2" ]]; then
		ssr_protocol="auth_sha1_v4"
	elif [[ ${ssr_protocol} == "3" ]]; then
		ssr_protocol="auth_aes128_md5"
	elif [[ ${ssr_protocol} == "4" ]]; then
		ssr_protocol="auth_aes128_sha1"
	elif [[ ${ssr_protocol} == "5" ]]; then
		ssr_protocol="auth_chain_a"
	elif [[ ${ssr_protocol} == "6" ]]; then
		ssr_protocol="auth_chain_b"
	else
		ssr_protocol="auth_aes128_md5"
	fi
	echo && echo ${Separator_1} && echo -e "	Э�� : ${Green_font_prefix}${ssr_protocol}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_protocol} != "origin" ]]; then
		if [[ ${ssr_protocol} == "auth_sha1_v4" ]]; then
			stty erase '^H' && read -p "�Ƿ����� Э��������ԭ��(_compatible)��[Y/n]" ssr_protocol_yn
			[[ -z "${ssr_protocol_yn}" ]] && ssr_protocol_yn="y"
			[[ $ssr_protocol_yn == [Yy] ]] && ssr_protocol=${ssr_protocol}"_compatible"
			echo
		fi
	fi
}
Set_config_obfs(){
	echo -e "��ѡ��Ҫ���õ��û� �������
 ${Green_font_prefix}1.${Font_color_suffix} plain
 ${Green_font_prefix}2.${Font_color_suffix} http_simple
 ${Green_font_prefix}3.${Font_color_suffix} http_post
 ${Green_font_prefix}4.${Font_color_suffix} random_head
 ${Green_font_prefix}5.${Font_color_suffix} tls1.2_ticket_auth
 ${Tip} ���ʹ�� ShadowsocksR ������Ϸ������ѡ�� ��������ԭ��� plain ������Ȼ��ͻ���ѡ�� plain������������ӳ� !
 ����, �����ѡ���� tls1.2_ticket_auth����ô�ͻ��˿���ѡ�� tls1.2_ticket_fastauth����������αװ���� �ֲ��������ӳ� !" && echo
	stty erase '^H' && read -p "(Ĭ��: 5. tls1.2_ticket_auth):" ssr_obfs
	[[ -z "${ssr_obfs}" ]] && ssr_obfs="5"
	if [[ ${ssr_obfs} == "1" ]]; then
		ssr_obfs="plain"
	elif [[ ${ssr_obfs} == "2" ]]; then
		ssr_obfs="http_simple"
	elif [[ ${ssr_obfs} == "3" ]]; then
		ssr_obfs="http_post"
	elif [[ ${ssr_obfs} == "4" ]]; then
		ssr_obfs="random_head"
	elif [[ ${ssr_obfs} == "5" ]]; then
		ssr_obfs="tls1.2_ticket_auth"
	else
		ssr_obfs="tls1.2_ticket_auth"
	fi
	echo && echo ${Separator_1} && echo -e "	���� : ${Green_font_prefix}${ssr_obfs}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_obfs} != "plain" ]]; then
			stty erase '^H' && read -p "�Ƿ����� �����������ԭ��(_compatible)��[Y/n]" ssr_obfs_yn
			[[ -z "${ssr_obfs_yn}" ]] && ssr_obfs_yn="y"
			[[ $ssr_obfs_yn == [Yy] ]] && ssr_obfs=${ssr_obfs}"_compatible"
			echo
	fi
}
Set_config_protocol_param(){
	while true
	do
	echo -e "������Ҫ���õ��û� �����Ƶ��豸�� (${Green_font_prefix} auth_* ϵ��Э�� ������ԭ�����Ч ${Font_color_suffix})"
	echo -e "${Tip} �豸�����ƣ�ÿ���˿�ͬһʱ�������ӵĿͻ�������(��˿�ģʽ��ÿ���˿ڶ��Ƕ�������)���������� 2����"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_protocol_param
	[[ -z "$ssr_protocol_param" ]] && ssr_protocol_param="" && echo && break
	expr ${ssr_protocol_param} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_protocol_param} -ge 1 ]] && [[ ${ssr_protocol_param} -le 9999 ]]; then
			echo && echo ${Separator_1} && echo -e "	�豸������ : ${Green_font_prefix}${ssr_protocol_param}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-9999)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-9999)"
	fi
	done
}
Set_config_speed_limit_per_con(){
	while true
	do
	echo -e "������Ҫ���õ��û� ���߳� ��������(��λ��KB/S)"
	echo -e "${Tip} ���߳����٣�ÿ���˿� ���̵߳��������ޣ����̼߳���Ч��"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_speed_limit_per_con
	[[ -z "$ssr_speed_limit_per_con" ]] && ssr_speed_limit_per_con=0 && echo && break
	expr ${ssr_speed_limit_per_con} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_con} -ge 1 ]] && [[ ${ssr_speed_limit_per_con} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	���߳����� : ${Green_font_prefix}${ssr_speed_limit_per_con} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-131072)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-131072)"
	fi
	done
}
Set_config_speed_limit_per_user(){
	while true
	do
	echo
	echo -e "������Ҫ���õ��û� ���ٶ� ��������(��λ��KB/S)"
	echo -e "${Tip} �˿������٣�ÿ���˿� ���ٶ� �������ޣ������˿��������١�"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_speed_limit_per_user
	[[ -z "$ssr_speed_limit_per_user" ]] && ssr_speed_limit_per_user=0 && echo && break
	expr ${ssr_speed_limit_per_user} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_user} -ge 1 ]] && [[ ${ssr_speed_limit_per_user} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	�û������� : ${Green_font_prefix}${ssr_speed_limit_per_user} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-131072)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-131072)"
	fi
	done
}
Set_config_transfer(){
	while true
	do
	echo
	echo -e "������Ҫ���õ��û� ��ʹ�õ�����������(��λ: GB, 1-838868 GB)"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_transfer
	[[ -z "$ssr_transfer" ]] && ssr_transfer="838868" && echo && break
	expr ${ssr_transfer} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_transfer} -ge 1 ]] && [[ ${ssr_transfer} -le 838868 ]]; then
			echo && echo ${Separator_1} && echo -e "	�û������� : ${Green_font_prefix}${ssr_transfer} GB${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-838868)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-838868)"
	fi
	done
}
Set_config_forbid(){
	echo "������Ҫ���õ��û� ��ֹ���ʵĶ˿�"
	echo -e "${Tip} ��ֹ�Ķ˿ڣ����粻������� 25�˿ڣ��û����޷�ͨ��SSR������� �ʼ��˿�25�ˣ������ֹ�� 80,443 ��ô�û����޷��������� http/https ��վ��
��������˿ڸ�ʽ: 25
�������˿ڸ�ʽ: 23,465
���  �˿ڶθ�ʽ: 233-266
������ָ�ʽ�˿�: 25,465,233-666 (����ð��:)"
	stty erase '^H' && read -p "(Ĭ��Ϊ�� ����ֹ�����κζ˿�):" ssr_forbid
	[[ -z "${ssr_forbid}" ]] && ssr_forbid=""
	echo && echo ${Separator_1} && echo -e "	��ֹ�Ķ˿� : ${Green_font_prefix}${ssr_forbid}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_enable(){
	user_total=$(expr ${user_total} - 1)
	for((integer = 0; integer <= ${user_total}; integer++))
	do
		echo -e "integer=${integer}"
		port_jq=$(${jq_file} ".[${integer}].port" "${config_user_mudb_file}")
		echo -e "port_jq=${port_jq}"
		if [[ "${ssr_port}" == "${port_jq}" ]]; then
			enable=$(${jq_file} ".[${integer}].enable" "${config_user_mudb_file}")
			echo -e "enable=${enable}"
			[[ "${enable}" == "null" ]] && echo -e "${Error} ��ȡ��ǰ�˿�[${ssr_port}]�Ľ���״̬ʧ�� !" && exit 1
			ssr_port_num=$(cat "${config_user_mudb_file}"|grep -n '"port": '${ssr_port}','|awk -F ":" '{print $1}')
			echo -e "ssr_port_num=${ssr_port_num}"
			[[ "${ssr_port_num}" == "null" ]] && echo -e "${Error} ��ȡ��ǰ�˿�[${ssr_port}]������ʧ�� !" && exit 1
			ssr_enable_num=$(expr ${ssr_port_num} - 5)
			echo -e "ssr_enable_num=${ssr_enable_num}"
			break
		fi
	done
	if [[ "${enable}" == "1" ]]; then
		echo -e "�˿� [${ssr_port}] ���˺�״̬Ϊ��${Green_font_prefix}����${Font_color_suffix} , �Ƿ��л�Ϊ ${Red_font_prefix}����${Font_color_suffix} ?[Y/n]"
		stty erase '^H' && read -p "(Ĭ��: Y):" ssr_enable_yn
		[[ -z "${ssr_enable_yn}" ]] && ssr_enable_yn="y"
		if [[ "${ssr_enable_yn}" == [Yy] ]]; then
			ssr_enable="0"
		else
			echo "ȡ��..." && exit 0
		fi
	elif [[ "${enable}" == "0" ]]; then
		echo -e "�˿� [${ssr_port}] ���˺�״̬Ϊ��${Green_font_prefix}����${Font_color_suffix} , �Ƿ��л�Ϊ ${Red_font_prefix}����${Font_color_suffix} ?[Y/n]"
		stty erase '^H' && read -p "(Ĭ��: Y):" ssr_enable_yn
		[[ -z "${ssr_enable_yn}" ]] && ssr_enable_yn = "y"
		if [[ "${ssr_enable_yn}" == [Yy] ]]; then
			ssr_enable="1"
		else
			echo "ȡ��..." && exit 0
		fi
	else
		echo -e "${Error} ��ǰ�˿ڵĽ���״̬�쳣[${enable}] !" && exit 1
	fi
}
Set_user_api_server_pub_addr(){
	addr=$1
	if [[ "${addr}" == "Modify" ]]; then
		server_pub_addr=$(cat ${config_user_api_file}|grep "SERVER_PUB_ADDR = "|awk -F "[']" '{print $2}')
		if [[ -z ${server_pub_addr} ]]; then
			echo -e "${Error} ��ȡ��ǰ���õ� ������IP������ʧ�ܣ�" && exit 1
		else
			echo -e "${Info} ��ǰ���õķ�����IP������Ϊ�� ${Green_font_prefix}${server_pub_addr}${Font_color_suffix}"
		fi
	fi
	echo "�������û�������Ҫ��ʾ�� ������IP������ (���������ж��IPʱ������ָ���û���������ʾ��IP��������)"
	stty erase '^H' && read -p "(Ĭ���Զ��������IP):" ssr_server_pub_addr
	if [[ -z "${ssr_server_pub_addr}" ]]; then
		Get_IP
		if [[ ${ip} == "VPS_IP" ]]; then
			while true
			do
			stty erase '^H' && read -p "${Error} �Զ��������IPʧ�ܣ����ֶ����������IP������" ssr_server_pub_addr
			if [[ -z "$ssr_server_pub_addr" ]]; then
				echo -e "${Error} ����Ϊ�գ�"
			else
				break
			fi
			done
		else
			ssr_server_pub_addr="${ip}"
		fi
	fi
	echo && echo ${Separator_1} && echo -e "	IP������ : ${Green_font_prefix}${ssr_server_pub_addr}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_all(){
	lal=$1
	if [[ "${lal}" == "Modify" ]]; then
		Set_config_password
		Set_config_method
		Set_config_protocol
		Set_config_obfs
		Set_config_protocol_param
		Set_config_speed_limit_per_con
		Set_config_speed_limit_per_user
		Set_config_transfer
		Set_config_forbid
	else
		Set_config_user
		Set_config_port
		Set_config_password
		Set_config_method
		Set_config_protocol
		Set_config_obfs
		Set_config_protocol_param
		Set_config_speed_limit_per_con
		Set_config_speed_limit_per_user
		Set_config_transfer
		Set_config_forbid
	fi
}
# �޸� ������Ϣ
Modify_config_password(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -k "${ssr_password}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û������޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û������޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_method(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -m "${ssr_method}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û����ܷ�ʽ�޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û����ܷ�ʽ�޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_protocol(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -O "${ssr_protocol}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û�Э���޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û�Э���޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_obfs(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -o "${ssr_obfs}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û������޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û������޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_protocol_param(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -G "${ssr_protocol_param}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û�Э�����(�豸������)�޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û������(�豸������)�޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_speed_limit_per_con(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -s "${ssr_speed_limit_per_con}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û����߳������޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û����߳������޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_speed_limit_per_user(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -S "${ssr_speed_limit_per_user}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û��˿��������޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û��˿��������޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_connect_verbose_info(){
	sed -i 's/"connect_verbose_info": '"$(echo ${connect_verbose_info})"',/"connect_verbose_info": '"$(echo ${ssr_connect_verbose_info})"',/g' ${config_user_file}
}
Modify_config_transfer(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -t "${ssr_transfer}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û��������޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û��������޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_forbid(){
	match_edit=$(python mujson_mgr.py -e -p "${ssr_port}" -f "${ssr_forbid}"|grep -w "edit user ")
	if [[ -z "${match_edit}" ]]; then
		echo -e "${Error} �û���ֹ���ʶ˿��޸�ʧ�� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} " && exit 1
	else
		echo -e "${Info} �û���ֹ���ʶ˿��޸ĳɹ� ${Green_font_prefix}[�˿�: ${ssr_port}]${Font_color_suffix} (ע�⣺������Ҫʮ�����ҲŻ�Ӧ����������)"
	fi
}
Modify_config_enable(){
	sed -i "${ssr_enable_num}"'s/"enable": '"$(echo ${enable})"',/"enable": '"$(echo ${ssr_enable})"',/' ${config_user_mudb_file}
}
Modify_user_api_server_pub_addr(){
	sed -i "s/SERVER_PUB_ADDR = '${server_pub_addr}'/SERVER_PUB_ADDR = '${ssr_server_pub_addr}'/" ${config_user_api_file}
}
Modify_config_all(){
	Modify_config_password
	Modify_config_method
	Modify_config_protocol
	Modify_config_obfs
	Modify_config_protocol_param
	Modify_config_speed_limit_per_con
	Modify_config_speed_limit_per_user
	Modify_config_transfer
	Modify_config_forbid
}
Check_python(){
	python_ver=`python -h`
	if [[ -z ${python_ver} ]]; then
		echo -e "${Info} û�а�װPython����ʼ��װ..."
		if [[ ${release} == "centos" ]]; then
			yum install -y python
		else
			apt-get install -y python
		fi
	fi
}
Centos_yum(){
	yum update
	cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
	if [[ $? = 0 ]]; then
		yum install -y vim unzip crond net-tools
	else
		yum install -y vim unzip crond
	fi
}
Debian_apt(){
	apt-get update
	cat /etc/issue |grep 9\..*>/dev/null
	if [[ $? = 0 ]]; then
		apt-get install -y vim unzip cron net-tools
	else
		apt-get install -y vim unzip cron
	fi
}
# ���� ShadowsocksR
Download_SSR(){
	cd "/usr/local"
	wget -N --no-check-certificate "https://github.com/ToyoDAdoubi/shadowsocksr/archive/manyuser.zip"
	#git config --global http.sslVerify false
	#env GIT_SSL_NO_VERIFY=true git clone -b manyuser https://github.com/ToyoDAdoubi/shadowsocksr.git
	#[[ ! -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR����� ����ʧ�� !" && exit 1
	[[ ! -e "manyuser.zip" ]] && echo -e "${Error} ShadowsocksR����� ѹ���� ����ʧ�� !" && rm -rf manyuser.zip && exit 1
	unzip "manyuser.zip"
	[[ ! -e "/usr/local/shadowsocksr-manyuser/" ]] && echo -e "${Error} ShadowsocksR����� ��ѹʧ�� !" && rm -rf manyuser.zip && exit 1
	mv "/usr/local/shadowsocksr-manyuser/" "/usr/local/shadowsocksr/"
	[[ ! -e "/usr/local/shadowsocksr/" ]] && echo -e "${Error} ShadowsocksR����� ������ʧ�� !" && rm -rf manyuser.zip && rm -rf "/usr/local/shadowsocksr-manyuser/" && exit 1
	rm -rf manyuser.zip
	cd "shadowsocksr"
	cp "${ssr_folder}/config.json" "${config_user_file}"
	cp "${ssr_folder}/mysql.json" "${ssr_folder}/usermysql.json"
	cp "${ssr_folder}/apiconfig.py" "${config_user_api_file}"
	[[ ! -e ${config_user_api_file} ]] && echo -e "${Error} ShadowsocksR����� apiconfig.py ����ʧ�� !" && exit 1
	sed -i "s/API_INTERFACE = 'sspanelv2'/API_INTERFACE = 'mudbjson'/" ${config_user_api_file}
	server_pub_addr="127.0.0.1"
	Modify_user_api_server_pub_addr
	#sed -i "s/SERVER_PUB_ADDR = '127.0.0.1'/SERVER_PUB_ADDR = '${ip}'/" ${config_user_api_file}
	sed -i 's/ \/\/ only works under multi-user mode//g' "${config_user_file}"
	echo -e "${Info} ShadowsocksR����� ������� !"
}
Service_SSR(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssrmu_centos -O /etc/init.d/ssrmu; then
			echo -e "${Error} ShadowsocksR���� ����ű�����ʧ�� !" && exit 1
		fi
		chmod +x /etc/init.d/ssrmu
		chkconfig --add ssrmu
		chkconfig ssrmu on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssrmu_debian -O /etc/init.d/ssrmu; then
			echo -e "${Error} ShadowsocksR���� ����ű�����ʧ�� !" && exit 1
		fi
		chmod +x /etc/init.d/ssrmu
		update-rc.d -f ssrmu defaults
	fi
	echo -e "${Info} ShadowsocksR���� ����ű�������� !"
}
# ��װ JQ������
JQ_install(){
	if [[ ! -e ${jq_file} ]]; then
		cd "${ssr_folder}"
		if [[ ${bit} = "x86_64" ]]; then
			mv "jq-linux64" "jq"
			#wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" -O ${jq_file}
		else
			mv "jq-linux32" "jq"
			#wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32" -O ${jq_file}
		fi
		[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ������ ������ʧ�ܣ����� !" && exit 1
		chmod +x ${jq_file}
		echo -e "${Info} JQ������ ��װ��ɣ�����..." 
	else
		echo -e "${Info} JQ������ �Ѱ�װ������..."
	fi
}
# ��װ ����
Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		Centos_yum
	else
		Debian_apt
	fi
	[[ ! -e "/usr/bin/unzip" ]] && echo -e "${Error} ���� unzip(��ѹѹ����) ��װʧ�ܣ�����������Դ�����⣬���� !" && exit 1
	Check_python
	#echo "nameserver 8.8.8.8" > /etc/resolv.conf
	#echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	if [[ ${release} == "centos" ]]; then
		/etc/init.d/crond restart
	else
		/etc/init.d/cron restart
	fi
}
Install_SSR(){
	check_root
	[[ -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR �ļ����Ѵ��ڣ�����( �簲װʧ�ܻ��ߴ��ھɰ汾������ж�� ) !" && exit 1
	echo -e "${Info} ��ʼ���� ShadowsocksR�˺�����..."
	Set_user_api_server_pub_addr
	Set_config_all
	echo -e "${Info} ��ʼ��װ/���� ShadowsocksR����..."
	Installation_dependency
	echo -e "${Info} ��ʼ����/��װ ShadowsocksR�ļ�..."
	Download_SSR
	echo -e "${Info} ��ʼ����/��װ ShadowsocksR����ű�(init)..."
	Service_SSR
	echo -e "${Info} ��ʼ����/��װ JSNO������ JQ..."
	JQ_install
	echo -e "${Info} ��ʼ��ӳ�ʼ�û�..."
	Add_port_user "install"
	echo -e "${Info} ��ʼ���� iptables����ǽ..."
	Set_iptables
	echo -e "${Info} ��ʼ��� iptables����ǽ����..."
	Add_iptables
	echo -e "${Info} ��ʼ���� iptables����ǽ����..."
	Save_iptables
	echo -e "${Info} ���в��� ��װ��ϣ���ʼ���� ShadowsocksR�����..."
	Start_SSR
	Get_User_info "${ssr_port}"
	View_User_info
}
Update_SSR(){
	SSR_installation_status
	echo -e "��������ͣ����ShadowsocksR����ˣ����Դ˹�����ʱ���á�"
	#cd ${ssr_folder}
	#git pull
	#Restart_SSR
}
Uninstall_SSR(){
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} û�а�װ ShadowsocksR������ !" && exit 1
	echo "ȷ��Ҫ ж��ShadowsocksR��[y/N]" && echo
	stty erase '^H' && read -p "(Ĭ��: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		user_info=$(python mujson_mgr.py -l)
		user_total=$(echo "${user_info}"|wc -l)
		if [[ ! -z ${user_info} ]]; then
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=$(echo "${user_info}"|sed -n "${integer}p"|awk '{print $4}')
				Del_iptables
			done
		fi
		if [[ ${release} = "centos" ]]; then
			chkconfig --del ssrmu
		else
			update-rc.d -f ssrmu remove
		fi
		rm -rf ${ssr_folder} && rm -rf /etc/init.d/ssrmu
		echo && echo " ShadowsocksR ж����� !" && echo
	else
		echo && echo " ж����ȡ��..." && echo
	fi
}
Check_Libsodium_ver(){
	echo -e "${Info} ��ʼ��ȡ libsodium ���°汾..."
	Libsodiumr_ver=$(wget -qO- "https://github.com/jedisct1/libsodium/tags"|grep "/jedisct1/libsodium/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
	[[ -z ${Libsodiumr_ver} ]] && Libsodiumr_ver=${Libsodiumr_ver_backup}
	echo -e "${Info} libsodium ���°汾Ϊ ${Green_font_prefix}${Libsodiumr_ver}${Font_color_suffix} !"
}
Install_Libsodium(){
	if [[ -e ${Libsodiumr_file} ]]; then
		echo -e "${Error} libsodium �Ѱ�װ , �Ƿ񸲸ǰ�װ(����)��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" yn
		[[ -z ${yn} ]] && yn="n"
		if [[ ${yn} == [Nn] ]]; then
			echo "��ȡ��..." && exit 1
		fi
	else
		echo -e "${Info} libsodium δ��װ����ʼ��װ..."
	fi
	Check_Libsodium_ver
	if [[ ${release} == "centos" ]]; then
		yum update
		echo -e "${Info} ��װ����..."
		yum -y groupinstall "Development Tools"
		echo -e "${Info} ����..."
		wget  --no-check-certificate -N "https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info} ��ѹ..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info} ���밲װ..."
		./configure --disable-maintainer-mode && make -j2 && make install
		echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	else
		apt-get update
		echo -e "${Info} ��װ����..."
		apt-get install -y build-essential
		echo -e "${Info} ����..."
		wget  --no-check-certificate -N "https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info} ��ѹ..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info} ���밲װ..."
		./configure --disable-maintainer-mode && make -j2 && make install
	fi
	ldconfig
	cd .. && rm -rf libsodium-${Libsodiumr_ver}.tar.gz && rm -rf libsodium-${Libsodiumr_ver}
	[[ ! -e ${Libsodiumr_file} ]] && echo -e "${Error} libsodium ��װʧ�� !" && exit 1
	echo && echo -e "${Info} libsodium ��װ�ɹ� !" && echo
}
# ��ʾ ������Ϣ
debian_View_user_connection_info(){
	format_1=$1
	user_info=$(python mujson_mgr.py -l)
	user_total=$(echo "${user_info}"|wc -l)
	[[ -z ${user_info} ]] && echo -e "${Error} û�з��� �û������� !" && exit 1
	IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
	user_list_all=""
	for((integer = 1; integer <= ${user_total}; integer++))
	do
		user_port=$(echo "${user_info}"|sed -n "${integer}p"|awk '{print $4}')
		user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep ":${user_port} " |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u`
		if [[ -z ${user_IP_1} ]]; then
			user_IP_total="0"
		else
			user_IP_total=`echo -e "${user_IP_1}"|wc -l`
			if [[ ${format_1} == "IP_address" ]]; then
				get_IP_address
			else
				user_IP=`echo -e "\n${user_IP_1}"`
			fi
		fi
		user_info_233=$(python mujson_mgr.py -l|grep -w "${user_port}"|awk '{print $2}'|sed 's/\[//g;s/\]//g')
		user_list_all=${user_list_all}"�û���: ${Green_font_prefix}"${user_info_233}"${Font_color_suffix}\t �˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����IP����: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t ��ǰ����IP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
		user_IP=""
	done
	echo -e "�û�����: ${Green_background_prefix} "${user_total}" ${Font_color_suffix} ����IP����: ${Green_background_prefix} "${IP_total}" ${Font_color_suffix} "
	echo -e "${user_list_all}"
}
centos_View_user_connection_info(){
	format_1=$1
	user_info=$(python mujson_mgr.py -l)
	user_total=$(echo "${user_info}"|wc -l)
	[[ -z ${user_info} ]] && echo -e "${Error} û�з��� �û������� !" && exit 1
	IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |wc -l`
	user_list_all=""
	for((integer = 1; integer <= ${user_total}; integer++))
	do
		user_port=$(echo "${user_info}"|sed -n "${integer}p"|awk '{print $4}')
		user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep ":${user_port} "|grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u`
		if [[ -z ${user_IP_1} ]]; then
			user_IP_total="0"
		else
			user_IP_total=`echo -e "${user_IP_1}"|wc -l`
			if [[ ${format_1} == "IP_address" ]]; then
				get_IP_address
			else
				user_IP=`echo -e "\n${user_IP_1}"`
			fi
		fi
		user_info_233=$(python mujson_mgr.py -l|grep -w "${user_port}"|awk '{print $2}'|sed 's/\[//g;s/\]//g')
		user_list_all=${user_list_all}"�û���: ${Green_font_prefix}"${user_info_233}"${Font_color_suffix}\t �˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����IP����: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t ��ǰ����IP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
		user_IP=""
	done
	echo -e "�û�����: ${Green_background_prefix} "${user_total}" ${Font_color_suffix} ����IP����: ${Green_background_prefix} "${IP_total}" ${Font_color_suffix} "
	echo -e "${user_list_all}"
}
View_user_connection_info(){
	SSR_installation_status
	echo && echo -e "��ѡ��Ҫ��ʾ�ĸ�ʽ��
 ${Green_font_prefix}1.${Font_color_suffix} ��ʾ IP ��ʽ
 ${Green_font_prefix}2.${Font_color_suffix} ��ʾ IP+IP������ ��ʽ" && echo
	stty erase '^H' && read -p "(Ĭ��: 1):" ssr_connection_info
	[[ -z "${ssr_connection_info}" ]] && ssr_connection_info="1"
	if [[ ${ssr_connection_info} == "1" ]]; then
		View_user_connection_info_1 ""
	elif [[ ${ssr_connection_info} == "2" ]]; then
		echo -e "${Tip} ���IP������(ipip.net)�����IP�϶࣬����ʱ���Ƚϳ�..."
		View_user_connection_info_1 "IP_address"
	else
		echo -e "${Error} ��������ȷ������(1-2)" && exit 1
	fi
}
View_user_connection_info_1(){
	format=$1
	if [[ ${release} = "centos" ]]; then
		cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
		if [[ $? = 0 ]]; then
			debian_View_user_connection_info "$format"
		else
			centos_View_user_connection_info "$format"
		fi
	else
		debian_View_user_connection_info "$format"
	fi
}
get_IP_address(){
	#echo "user_IP_1=${user_IP_1}"
	if [[ ! -z ${user_IP_1} ]]; then
	#echo "user_IP_total=${user_IP_total}"
		for((integer_1 = ${user_IP_total}; integer_1 >= 1; integer_1--))
		do
			IP=`echo "${user_IP_1}" |sed -n "$integer_1"p`
			#echo "IP=${IP}"
			IP_address=`wget -qO- -t1 -T2 http://freeapi.ipip.net/${IP}|sed 's/\"//g;s/,//g;s/\[//g;s/\]//g'`
			#echo "IP_address=${IP_address}"
			user_IP="${user_IP}\n${IP}(${IP_address})"
			#echo "user_IP=${user_IP}"
			sleep 1s
		done
	fi
}
# �޸� �û�����
Modify_port(){
	List_port_user
	while true
	do
		echo -e "������Ҫ�޸ĵ��û� �˿�"
		stty erase '^H' && read -p "(Ĭ��: ȡ��):" ssr_port
		[[ -z "${ssr_port}" ]] && echo -e "��ȡ��..." && exit 1
		Modify_user=$(cat "${config_user_mudb_file}"|grep '"port": '"${ssr_port}"',')
		if [[ ! -z ${Modify_user} ]]; then
			break
		else
			echo -e "${Error} ��������ȷ�Ķ˿� !"
		fi
	done
}
Modify_Config(){
	SSR_installation_status
	echo && echo -e "��Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix}  ��� �û�����
 ${Green_font_prefix}2.${Font_color_suffix}  ɾ�� �û�����
���������� �޸� �û����� ����������
 ${Green_font_prefix}3.${Font_color_suffix}  �޸� �û�����
 ${Green_font_prefix}4.${Font_color_suffix}  �޸� ���ܷ�ʽ
 ${Green_font_prefix}5.${Font_color_suffix}  �޸� Э����
 ${Green_font_prefix}6.${Font_color_suffix}  �޸� �������
 ${Green_font_prefix}7.${Font_color_suffix}  �޸� �豸������
 ${Green_font_prefix}8.${Font_color_suffix}  �޸� ���߳�����
 ${Green_font_prefix}9.${Font_color_suffix}  �޸� �û�������
 ${Green_font_prefix}10.${Font_color_suffix} �޸� �û�������
 ${Green_font_prefix}11.${Font_color_suffix} �޸� �û����ö˿�
 ${Green_font_prefix}12.${Font_color_suffix} �޸� ȫ������
���������� ���� ����������
 ${Green_font_prefix}13.${Font_color_suffix} �޸� �û���������ʾ��IP������
 
 ${Tip} �û����û����Ͷ˿����޷��޸ģ������Ҫ�޸���ʹ�ýű��� �ֶ��޸Ĺ��� !" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" ssr_modify
	[[ -z "${ssr_modify}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${ssr_modify} == "1" ]]; then
		Add_port_user
	elif [[ ${ssr_modify} == "2" ]]; then
		Del_port_user
	elif [[ ${ssr_modify} == "3" ]]; then
		Modify_port
		Set_config_password
		Modify_config_password
	elif [[ ${ssr_modify} == "4" ]]; then
		Modify_port
		Set_config_method
		Modify_config_method
	elif [[ ${ssr_modify} == "5" ]]; then
		Modify_port
		Set_config_protocol
		Modify_config_protocol
	elif [[ ${ssr_modify} == "6" ]]; then
		Modify_port
		Set_config_obfs
		Modify_config_obfs
	elif [[ ${ssr_modify} == "7" ]]; then
		Modify_port
		Set_config_protocol_param
		Modify_config_protocol_param
	elif [[ ${ssr_modify} == "8" ]]; then
		Modify_port
		Set_config_speed_limit_per_con
		Modify_config_speed_limit_per_con
	elif [[ ${ssr_modify} == "9" ]]; then
		Modify_port
		Set_config_speed_limit_per_user
		Modify_config_speed_limit_per_user
	elif [[ ${ssr_modify} == "10" ]]; then
		Modify_port
		Set_config_transfer
		Modify_config_transfer
	elif [[ ${ssr_modify} == "11" ]]; then
		Modify_port
		Set_config_forbid
		Modify_config_forbid
	elif [[ ${ssr_modify} == "12" ]]; then
		Modify_port
		Set_config_all "Modify"
		Modify_config_all
	elif [[ ${ssr_modify} == "13" ]]; then
		Set_user_api_server_pub_addr "Modify"
		Modify_user_api_server_pub_addr
	else
		echo -e "${Error} ��������ȷ������(1-13)" && exit 1
	fi
}
List_port_user(){
	user_info=$(python mujson_mgr.py -l)
	user_total=$(echo "${user_info}"|wc -l)
	[[ -z ${user_info} ]] && echo -e "${Error} û�з��� �û������� !" && exit 1
	user_list_all=""
	for((integer = 1; integer <= ${user_total}; integer++))
	do
		user_port=$(echo "${user_info}"|sed -n "${integer}p"|awk '{print $4}')
		user_username=$(echo "${user_info}"|sed -n "${integer}p"|awk '{print $2}'|sed 's/\[//g;s/\]//g')
		Get_User_transfer "${user_port}"
		transfer_enable_Used_233=$(expr $transfer_enable_Used_233 + $transfer_enable_Used_2_1)
		user_list_all=${user_list_all}"�û���: ${Green_font_prefix} "${user_username}"${Font_color_suffix}\t �˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����ʹ�����(����+ʣ��=��): ${Green_font_prefix}${transfer_enable_Used_2}${Font_color_suffix} + ${Green_font_prefix}${transfer_enable_Used}${Font_color_suffix} = ${Green_font_prefix}${transfer_enable}${Font_color_suffix}\n"
	done
	Get_User_transfer_all
	echo && echo -e "=== �û����� ${Green_background_prefix} "${user_total}" ${Font_color_suffix}"
	echo -e ${user_list_all}
	echo -e "=== ��ǰ�����û���ʹ�������ܺ�: ${Green_background_prefix} ${transfer_enable_Used_233_2} ${Font_color_suffix}\n"
}
Add_port_user(){
	lalal=$1
	if [[ "$lalal" == "install" ]]; then
		match_add=$(python mujson_mgr.py -a -u "${ssr_user}" -p "${ssr_port}" -k "${ssr_password}" -m "${ssr_method}" -O "${ssr_protocol}" -G "${ssr_protocol_param}" -o "${ssr_obfs}" -s "${ssr_speed_limit_per_con}" -S "${ssr_speed_limit_per_user}" -t "${ssr_transfer}" -f "${ssr_forbid}"|grep -w "add user info")
	else
		while true
		do
			Set_config_all
			match_port=$(python mujson_mgr.py -l|grep -w "port ${ssr_port}$")
			[[ ! -z "${match_port}" ]] && echo -e "${Error} �ö˿� [${ssr_port}] �Ѵ��ڣ������ظ���� !" && exit 1
			match_username=$(python mujson_mgr.py -l|grep -w "user \[${ssr_user}]")
			[[ ! -z "${match_username}" ]] && echo -e "${Error} ���û��� [${ssr_user}] �Ѵ��ڣ������ظ���� !" && exit 1
			match_add=$(python mujson_mgr.py -a -u "${ssr_user}" -p "${ssr_port}" -k "${ssr_password}" -m "${ssr_method}" -O "${ssr_protocol}" -G "${ssr_protocol_param}" -o "${ssr_obfs}" -s "${ssr_speed_limit_per_con}" -S "${ssr_speed_limit_per_user}" -t "${ssr_transfer}" -f "${ssr_forbid}"|grep -w "add user info")
			if [[ -z "${match_add}" ]]; then
				echo -e "${Error} �û����ʧ�� ${Green_font_prefix}[�û���: ${ssr_user} , �˿�: ${ssr_port}]${Font_color_suffix} "
				break
			else
				Add_iptables
				Save_iptables
				echo -e "${Info} �û���ӳɹ� ${Green_font_prefix}[�û���: ${ssr_user} , �˿�: ${ssr_port}]${Font_color_suffix} "
				echo
				stty erase '^H' && read -p "�Ƿ���� ����û����ã�[Y/n]:" addyn
				[[ -z ${addyn} ]] && addyn="y"
				if [[ ${addyn} == [Nn] ]]; then
					Get_User_info "${ssr_port}"
					View_User_info
					break
				else
					echo -e "${Info} ���� ����û�����..."
				fi
			fi
		done
	fi
}
Del_port_user(){
	List_port_user
	while true
	do
		echo -e "������Ҫɾ�����û� �˿�"
		stty erase '^H' && read -p "(Ĭ��: ȡ��):" del_user_port
		[[ -z "${del_user_port}" ]] && echo -e "��ȡ��..." && exit 1
		del_user=$(cat "${config_user_mudb_file}"|grep '"port": '"${del_user_port}"',')
		if [[ ! -z ${del_user} ]]; then
			port=${del_user_port}
			match_del=$(python mujson_mgr.py -d -p "${del_user_port}"|grep -w "delete user ")
			if [[ -z "${match_del}" ]]; then
				echo -e "${Error} �û�ɾ��ʧ�� ${Green_font_prefix}[�˿�: ${del_user_port}]${Font_color_suffix} "
			else
				Del_iptables
				Save_iptables
				echo -e "${Info} �û�ɾ���ɹ� ${Green_font_prefix}[�˿�: ${del_user_port}]${Font_color_suffix} "
			fi
			break
		else
			echo -e "${Error} ��������ȷ�Ķ˿� !"
		fi
	done
}
Manually_Modify_Config(){
	SSR_installation_status
	vi ${config_user_mudb_file}
	echo "�Ƿ���������ShadowsocksR��[Y/n]" && echo
	stty erase '^H' && read -p "(Ĭ��: y):" yn
	[[ -z ${yn} ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		Restart_SSR
	fi
}
Clear_transfer(){
	SSR_installation_status
	echo && echo -e "��Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix}  ���� �����û���ʹ������
 ${Green_font_prefix}2.${Font_color_suffix}  ���� �����û���ʹ������(�������)
 ${Green_font_prefix}3.${Font_color_suffix}  ���� ��ʱ�����û���������
 ${Green_font_prefix}4.${Font_color_suffix}  ֹͣ ��ʱ�����û���������
 ${Green_font_prefix}5.${Font_color_suffix}  �޸� ��ʱ�����û���������" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" ssr_modify
	[[ -z "${ssr_modify}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${ssr_modify} == "1" ]]; then
		Clear_transfer_one
	elif [[ ${ssr_modify} == "2" ]]; then
		echo "ȷ��Ҫ ���� �����û���ʹ��������[y/N]" && echo
		stty erase '^H' && read -p "(Ĭ��: n):" yn
		[[ -z ${yn} ]] && yn="n"
		if [[ ${yn} == [Yy] ]]; then
			Clear_transfer_all
		else
			echo "ȡ��..."
		fi
	elif [[ ${ssr_modify} == "3" ]]; then
		check_crontab
		Set_crontab
		Clear_transfer_all_cron_start
	elif [[ ${ssr_modify} == "4" ]]; then
		check_crontab
		Clear_transfer_all_cron_stop
	elif [[ ${ssr_modify} == "5" ]]; then
		check_crontab
		Clear_transfer_all_cron_modify
	else
		echo -e "${Error} ��������ȷ������(1-5)" && exit 1
	fi
}
Clear_transfer_one(){
	List_port_user
	while true
	do
		echo -e "������Ҫ������ʹ���������û� �˿�"
		stty erase '^H' && read -p "(Ĭ��: ȡ��):" Clear_transfer_user_port
		[[ -z "${Clear_transfer_user_port}" ]] && echo -e "��ȡ��..." && exit 1
		Clear_transfer_user=$(cat "${config_user_mudb_file}"|grep '"port": '"${Clear_transfer_user_port}"',')
		if [[ ! -z ${Clear_transfer_user} ]]; then
			match_clear=$(python mujson_mgr.py -c -p "${Clear_transfer_user_port}"|grep -w "clear user ")
			if [[ -z "${match_clear}" ]]; then
				echo -e "${Error} �û���ʹ����������ʧ�� ${Green_font_prefix}[�˿�: ${Clear_transfer_user_port}]${Font_color_suffix} "
			else
				echo -e "${Info} �û���ʹ����������ɹ� ${Green_font_prefix}[�˿�: ${Clear_transfer_user_port}]${Font_color_suffix} "
			fi
			break
		else
			echo -e "${Error} ��������ȷ�Ķ˿� !"
		fi
	done
}
Clear_transfer_all(){
	cd "${ssr_folder}"
	user_info=$(python mujson_mgr.py -l)
	user_total=$(echo "${user_info}"|wc -l)
	[[ -z ${user_info} ]] && echo -e "${Error} û�з��� �û������� !" && exit 1
	for((integer = 1; integer <= ${user_total}; integer++))
	do
		user_port=$(echo "${user_info}"|sed -n "${integer}p"|awk '{print $4}')
		match_clear=$(python mujson_mgr.py -c -p "${user_port}"|grep -w "clear user ")
		if [[ -z "${match_clear}" ]]; then
			echo -e "${Error} �û���ʹ����������ʧ�� ${Green_font_prefix}[�˿�: ${user_port}]${Font_color_suffix} "
		else
			echo -e "${Info} �û���ʹ����������ɹ� ${Green_font_prefix}[�˿�: ${user_port}]${Font_color_suffix} "
		fi
	done
	echo -e "${Info} �����û������������ !"
}
Clear_transfer_all_cron_start(){
	crontab -l > "$file/crontab.bak"
	sed -i "/ssrmu.sh/d" "$file/crontab.bak"
	echo -e "\n${Crontab_time} /bin/bash $file/ssrmu.sh clearall" >> "$file/crontab.bak"
	crontab "$file/crontab.bak"
	rm -r "$file/crontab.bak"
	cron_config=$(crontab -l | grep "ssrmu.sh")
	if [[ -z ${cron_config} ]]; then
		echo -e "${Error} ��ʱ�����û�������������ʧ�� !" && exit 1
	else
		echo -e "${Info} ��ʱ�����û��������������ɹ� !"
	fi
}
Clear_transfer_all_cron_stop(){
	crontab -l > "$file/crontab.bak"
	sed -i "/ssrmu.sh/d" "$file/crontab.bak"
	crontab "$file/crontab.bak"
	rm -r "$file/crontab.bak"
	cron_config=$(crontab -l | grep "ssrmu.sh")
	if [[ ! -z ${cron_config} ]]; then
		echo -e "${Error} ��ʱ�����û���������ֹͣʧ�� !" && exit 1
	else
		echo -e "${Info} ��ʱ�����û���������ֹͣ�ɹ� !"
	fi
}
Clear_transfer_all_cron_modify(){
	Set_crontab
	Clear_transfer_all_cron_stop
	Clear_transfer_all_cron_start
}
Set_crontab(){
		echo -e "��������������ʱ����
 === ��ʽ˵�� ===
 * * * * * �ֱ��Ӧ ���� Сʱ �շ� �·� ����
 ${Green_font_prefix} 0 2 1 * * ${Font_color_suffix} ���� ÿ��1��2��0�� ������ʹ������
 ${Green_font_prefix} 0 2 15 * * ${Font_color_suffix} ���� ÿ��15��2��0�� ������ʹ������
 ${Green_font_prefix} 0 2 */7 * * ${Font_color_suffix} ���� ÿ7��2��0�� ������ʹ������
 ${Green_font_prefix} 0 2 * * 0 ${Font_color_suffix} ���� ÿ��������(7) ������ʹ������
 ${Green_font_prefix} 0 2 * * 3 ${Font_color_suffix} ���� ÿ��������(3) ������ʹ������" && echo
	stty erase '^H' && read -p "(Ĭ��: 0 2 1 * * ÿ��1��2��0��):" Crontab_time
	[[ -z "${Crontab_time}" ]] && Crontab_time="0 2 1 * *"
}
Start_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ShadowsocksR �������� !" && exit 1
	/etc/init.d/ssrmu start
}
Stop_SSR(){
	SSR_installation_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ShadowsocksR δ���� !" && exit 1
	/etc/init.d/ssrmu stop
}
Restart_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/ssrmu stop
	/etc/init.d/ssrmu start
}
View_Log(){
	SSR_installation_status
	[[ ! -e ${ssr_log_file} ]] && echo -e "${Error} ShadowsocksR��־�ļ������� !" && exit 1
	echo && echo -e "${Tip} �� ${Red_font_prefix}Ctrl+C${Font_color_suffix} ��ֹ�鿴��־" && echo
	tail -f ${ssr_log_file}
}
# ����
Configure_Server_Speeder(){
	echo && echo -e "��Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix} ��װ ����
 ${Green_font_prefix}2.${Font_color_suffix} ж�� ����
����������������
 ${Green_font_prefix}3.${Font_color_suffix} ���� ����
 ${Green_font_prefix}4.${Font_color_suffix} ֹͣ ����
 ${Green_font_prefix}5.${Font_color_suffix} ���� ����
 ${Green_font_prefix}6.${Font_color_suffix} �鿴 ���� ״̬
 
 ע�⣺ ���ٺ�LotServer����ͬʱ��װ/������" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" server_speeder_num
	[[ -z "${server_speeder_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${server_speeder_num} == "1" ]]; then
		Install_ServerSpeeder
	elif [[ ${server_speeder_num} == "2" ]]; then
		Server_Speeder_installation_status
		Uninstall_ServerSpeeder
	elif [[ ${server_speeder_num} == "3" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} start
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "4" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} stop
	elif [[ ${server_speeder_num} == "5" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} restart
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "6" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} status
	else
		echo -e "${Error} ��������ȷ������(1-6)" && exit 1
	fi
}
Install_ServerSpeeder(){
	[[ -e ${Server_Speeder_file} ]] && echo -e "${Error} ����(Server Speeder) �Ѱ�װ !" && exit 1
	#����91yun.rog�Ŀ��İ�����
	wget --no-check-certificate -qO /tmp/serverspeeder.sh https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder.sh
	[[ ! -e "/tmp/serverspeeder.sh" ]] && echo -e "${Error} ���ٰ�װ�ű�����ʧ�� !" && exit 1
	bash /tmp/serverspeeder.sh
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "serverspeeder" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		rm -rf /tmp/serverspeeder.sh
		rm -rf /tmp/91yunserverspeeder
		rm -rf /tmp/91yunserverspeeder.tar.gz
		echo -e "${Info} ����(Server Speeder) ��װ��� !" && exit 1
	else
		echo -e "${Error} ����(Server Speeder) ��װʧ�� !" && exit 1
	fi
}
Uninstall_ServerSpeeder(){
	echo "ȷ��Ҫж�� ����(Server Speeder)��[y/N]" && echo
	stty erase '^H' && read -p "(Ĭ��: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "��ȡ��..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		chattr -i /serverspeeder/etc/apx*
		/serverspeeder/bin/serverSpeeder.sh uninstall -f
		echo && echo "����(Server Speeder) ж����� !" && echo
	fi
}
# LotServer
Configure_LotServer(){
	echo && echo -e "��Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix} ��װ LotServer
 ${Green_font_prefix}2.${Font_color_suffix} ж�� LotServer
����������������
 ${Green_font_prefix}3.${Font_color_suffix} ���� LotServer
 ${Green_font_prefix}4.${Font_color_suffix} ֹͣ LotServer
 ${Green_font_prefix}5.${Font_color_suffix} ���� LotServer
 ${Green_font_prefix}6.${Font_color_suffix} �鿴 LotServer ״̬
 
 ע�⣺ ���ٺ�LotServer����ͬʱ��װ/������" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" lotserver_num
	[[ -z "${lotserver_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${lotserver_num} == "1" ]]; then
		Install_LotServer
	elif [[ ${lotserver_num} == "2" ]]; then
		LotServer_installation_status
		Uninstall_LotServer
	elif [[ ${lotserver_num} == "3" ]]; then
		LotServer_installation_status
		${LotServer_file} start
		${LotServer_file} status
	elif [[ ${lotserver_num} == "4" ]]; then
		LotServer_installation_status
		${LotServer_file} stop
	elif [[ ${lotserver_num} == "5" ]]; then
		LotServer_installation_status
		${LotServer_file} restart
		${LotServer_file} status
	elif [[ ${lotserver_num} == "6" ]]; then
		LotServer_installation_status
		${LotServer_file} status
	else
		echo -e "${Error} ��������ȷ������(1-6)" && exit 1
	fi
}
Install_LotServer(){
	[[ -e ${LotServer_file} ]] && echo -e "${Error} LotServer �Ѱ�װ !" && exit 1
	#Github: https://github.com/0oVicero0/serverSpeeder_Install
	wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh"
	[[ ! -e "/tmp/appex.sh" ]] && echo -e "${Error} LotServer ��װ�ű�����ʧ�� !" && exit 1
	bash /tmp/appex.sh 'install'
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "appex" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		echo -e "${Info} LotServer ��װ��� !" && exit 1
	else
		echo -e "${Error} LotServer ��װʧ�� !" && exit 1
	fi
}
Uninstall_LotServer(){
	echo "ȷ��Ҫж�� LotServer��[y/N]" && echo
	stty erase '^H' && read -p "(Ĭ��: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "��ȡ��..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh" && bash /tmp/appex.sh 'uninstall'
		echo && echo "LotServer ж����� !" && echo
	fi
}
# BBR
Configure_BBR(){
	echo && echo -e "  ��Ҫ��ʲô��
	
 ${Green_font_prefix}1.${Font_color_suffix} ��װ BBR
����������������
 ${Green_font_prefix}2.${Font_color_suffix} ���� BBR
 ${Green_font_prefix}3.${Font_color_suffix} ֹͣ BBR
 ${Green_font_prefix}4.${Font_color_suffix} �鿴 BBR ״̬" && echo
echo -e "${Green_font_prefix} [��װǰ ��ע��] ${Font_color_suffix}
1. ��װ����BBR����Ҫ�����ںˣ����ڸ���ʧ�ܵȷ���(�������޷�����)
2. ���ű���֧�� Debian / Ubuntu ϵͳ�����ںˣ�OpenVZ��Docker ��֧�ָ����ں�
3. Debian �����ں˹����л���ʾ [ �Ƿ���ֹж���ں� ] ����ѡ�� ${Green_font_prefix} NO ${Font_color_suffix}" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" bbr_num
	[[ -z "${bbr_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${bbr_num} == "1" ]]; then
		Install_BBR
	elif [[ ${bbr_num} == "2" ]]; then
		Start_BBR
	elif [[ ${bbr_num} == "3" ]]; then
		Stop_BBR
	elif [[ ${bbr_num} == "4" ]]; then
		Status_BBR
	else
		echo -e "${Error} ��������ȷ������(1-4)" && exit 1
	fi
}
Install_BBR(){
	[[ ${release} = "centos" ]] && echo -e "${Error} ���ű���֧�� CentOSϵͳ��װ BBR !" && exit 1
	BBR_installation_status
	bash "${BBR_file}"
}
Start_BBR(){
	BBR_installation_status
	bash "${BBR_file}" start
}
Stop_BBR(){
	BBR_installation_status
	bash "${BBR_file}" stop
}
Status_BBR(){
	BBR_installation_status
	bash "${BBR_file}" status
}
# ��������
Other_functions(){
	echo && echo -e "  ��Ҫ��ʲô��
	
  ${Green_font_prefix}1.${Font_color_suffix} ���� BBR
  ${Green_font_prefix}2.${Font_color_suffix} ���� ����(ServerSpeeder)
  ${Green_font_prefix}3.${Font_color_suffix} ���� LotServer(����ĸ��˾)
  ${Tip} ����/LotServer/BBR ��֧�� OpenVZ��
  ${Tip} ���ٺ�LotServer���ܹ��棡
������������������������
  ${Green_font_prefix}4.${Font_color_suffix} һ����� BT/PT/SPAM (iptables)
  ${Green_font_prefix}5.${Font_color_suffix} һ����� BT/PT/SPAM (iptables)
������������������������
  ${Green_font_prefix}6.${Font_color_suffix} �л� ShadowsocksR��־���ģʽ
  ���� ˵����SSRĬ��ֻ���������־��������л�Ϊ�����ϸ�ķ�����־��
  ${Green_font_prefix}7.${Font_color_suffix} ��� ShadowsocksR���������״̬
  ���� ˵�����ù����ʺ���SSR����˾������̽����������ù��ܺ��ÿ���Ӽ��һ�Σ������̲��������Զ�����SSR����ˡ�" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" other_num
	[[ -z "${other_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${other_num} == "1" ]]; then
		Configure_BBR
	elif [[ ${other_num} == "2" ]]; then
		Configure_Server_Speeder
	elif [[ ${other_num} == "3" ]]; then
		Configure_LotServer
	elif [[ ${other_num} == "4" ]]; then
		BanBTPTSPAM
	elif [[ ${other_num} == "5" ]]; then
		UnBanBTPTSPAM
	elif [[ ${other_num} == "6" ]]; then
		Set_config_connect_verbose_info
	elif [[ ${other_num} == "7" ]]; then
		Set_crontab_monitor_ssr
	else
		echo -e "${Error} ��������ȷ������ [1-7]" && exit 1
	fi
}
# ��� BT PT SPAM
BanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh banall
	rm -rf ban_iptables.sh
}
# ��� BT PT SPAM
UnBanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh unbanall
	rm -rf ban_iptables.sh
}
Set_config_connect_verbose_info(){
	SSR_installation_status
	[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ������ �����ڣ����� !" && exit 1
	connect_verbose_info=`${jq_file} '.connect_verbose_info' ${config_user_file}`
	if [[ ${connect_verbose_info} = "0" ]]; then
		echo && echo -e "��ǰ��־ģʽ: ${Green_font_prefix}��ģʽ��ֻ���������־��${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�л�Ϊ ${Green_font_prefix}��ϸģʽ�������ϸ������־+������־��${Font_color_suffix}��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" connect_verbose_info_ny
		[[ -z "${connect_verbose_info_ny}" ]] && connect_verbose_info_ny="n"
		if [[ ${connect_verbose_info_ny} == [Yy] ]]; then
			ssr_connect_verbose_info="1"
			Modify_config_connect_verbose_info
			Restart_SSR
		else
			echo && echo "	��ȡ��..." && echo
		fi
	else
		echo && echo -e "��ǰ��־ģʽ: ${Green_font_prefix}��ϸģʽ�������ϸ������־+������־��${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�л�Ϊ ${Green_font_prefix}��ģʽ��ֻ���������־��${Font_color_suffix}��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" connect_verbose_info_ny
		[[ -z "${connect_verbose_info_ny}" ]] && connect_verbose_info_ny="n"
		if [[ ${connect_verbose_info_ny} == [Yy] ]]; then
			ssr_connect_verbose_info="0"
			Modify_config_connect_verbose_info
			Restart_SSR
		else
			echo && echo "	��ȡ��..." && echo
		fi
	fi
}
Set_crontab_monitor_ssr(){
	SSR_installation_status
	crontab_monitor_ssr_status=$(crontab -l|grep "ssrmu.sh monitor")
	if [[ -z "${crontab_monitor_ssr_status}" ]]; then
		echo && echo -e "��ǰ���ģʽ: ${Green_font_prefix}δ����${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ����Ϊ ${Green_font_prefix}ShadowsocksR���������״̬���${Font_color_suffix} ������(�����̹ر����Զ�����SSR�����)[Y/n]"
		stty erase '^H' && read -p "(Ĭ��: y):" crontab_monitor_ssr_status_ny
		[[ -z "${crontab_monitor_ssr_status_ny}" ]] && crontab_monitor_ssr_status_ny="y"
		if [[ ${crontab_monitor_ssr_status_ny} == [Yy] ]]; then
			crontab_monitor_ssr_cron_start
		else
			echo && echo "	��ȡ��..." && echo
		fi
	else
		echo && echo -e "��ǰ���ģʽ: ${Green_font_prefix}�ѿ���${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�ر�Ϊ ${Green_font_prefix}ShadowsocksR���������״̬���${Font_color_suffix} ������(�����̹ر����Զ�����SSR�����)[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" crontab_monitor_ssr_status_ny
		[[ -z "${crontab_monitor_ssr_status_ny}" ]] && crontab_monitor_ssr_status_ny="n"
		if [[ ${crontab_monitor_ssr_status_ny} == [Yy] ]]; then
			crontab_monitor_ssr_cron_stop
		else
			echo && echo "	��ȡ��..." && echo
		fi
	fi
}
crontab_monitor_ssr(){
	SSR_installation_status
	check_pid
	if [[ -z ${PID} ]]; then
		echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] ��⵽ ShadowsocksR����� δ���� , ��ʼ����..." | tee -a ${ssr_log_file}
		/etc/init.d/ssrmu start
		sleep 1s
		check_pid
		if [[ -z ${PID} ]]; then
			echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] ShadowsocksR����� ����ʧ��..." | tee -a ${ssr_log_file} && exit 1
		else
			echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] ShadowsocksR����� �����ɹ�..." | tee -a ${ssr_log_file} && exit 1
		fi
	else
		echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] ShadowsocksR����� ������������..." exit 0
	fi
}
crontab_monitor_ssr_cron_start(){
	crontab -l > "$file/crontab.bak"
	sed -i "/ssrmu.sh monitor/d" "$file/crontab.bak"
	echo -e "\n* * * * * /bin/bash $file/ssrmu.sh monitor" >> "$file/crontab.bak"
	crontab "$file/crontab.bak"
	rm -r "$file/crontab.bak"
	cron_config=$(crontab -l | grep "ssrmu.sh monitor")
	if [[ -z ${cron_config} ]]; then
		echo -e "${Error} ShadowsocksR���������״̬��ع��� ����ʧ�� !" && exit 1
	else
		echo -e "${Info} ShadowsocksR���������״̬��ع��� �����ɹ� !"
	fi
}
crontab_monitor_ssr_cron_stop(){
	crontab -l > "$file/crontab.bak"
	sed -i "/ssrmu.sh monitor/d" "$file/crontab.bak"
	crontab "$file/crontab.bak"
	rm -r "$file/crontab.bak"
	cron_config=$(crontab -l | grep "ssrmu.sh monitor")
	if [[ ! -z ${cron_config} ]]; then
		echo -e "${Error} ShadowsocksR���������״̬��ع��� ֹͣʧ�� !" && exit 1
	else
		echo -e "${Info} ShadowsocksR���������״̬��ع��� ֹͣ�ɹ� !"
	fi
}
Update_Shell(){
	echo -e "��ǰ�汾Ϊ [ ${sh_ver} ]����ʼ������°汾..."
	sh_new_ver=$(wget --no-check-certificate -qO- "https://softs.fun/Bash/ssrmu.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="softs"
	[[ -z ${sh_new_ver} ]] && sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssrmu.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="github"
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} ������°汾ʧ�� !" && exit 0
	if [[ ${sh_new_ver} != ${sh_ver} ]]; then
		echo -e "�����°汾[ ${sh_new_ver} ]���Ƿ���£�[Y/n]"
		stty erase '^H' && read -p "(Ĭ��: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			cd "${file}"
			if [[ $sh_new_type == "softs" ]]; then
				wget -N --no-check-certificate https://softs.fun/Bash/ssrmu.sh && chmod +x ssrmu.sh
			else
				wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssrmu.sh && chmod +x ssrmu.sh
			fi
			echo -e "�ű��Ѹ���Ϊ���°汾[ ${sh_new_ver} ] !"
		else
			echo && echo "	��ȡ��..." && echo
		fi
	else
		echo -e "��ǰ�������°汾[ ${sh_new_ver} ] !"
	fi
	exit 0
}
# ��ʾ �˵�״̬
menu_status(){
	if [[ -e ${ssr_folder} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e " ��ǰ״̬: ${Green_font_prefix}�Ѱ�װ${Font_color_suffix} �� ${Green_font_prefix}������${Font_color_suffix}"
		else
			echo -e " ��ǰ״̬: ${Green_font_prefix}�Ѱ�װ${Font_color_suffix} �� ${Red_font_prefix}δ����${Font_color_suffix}"
		fi
		cd "${ssr_folder}"
	else
		echo -e " ��ǰ״̬: ${Red_font_prefix}δ��װ${Font_color_suffix}"
	fi
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} ���ű���֧�ֵ�ǰϵͳ ${release} !" && exit 1
action=$1
if [[ "${action}" == "clearall" ]]; then
	Clear_transfer_all
elif [[ "${action}" == "monitor" ]]; then
	crontab_monitor_ssr
else
	echo -e "  ShadowsocksR MuJSONһ������ű� ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  ---- Toyo | doub.io/ss-jc60 ----

  ${Green_font_prefix}1.${Font_color_suffix} ��װ ShadowsocksR
  ${Green_font_prefix}2.${Font_color_suffix} ���� ShadowsocksR
  ${Green_font_prefix}3.${Font_color_suffix} ж�� ShadowsocksR
  ${Green_font_prefix}4.${Font_color_suffix} ��װ libsodium(chacha20)
������������������������
  ${Green_font_prefix}5.${Font_color_suffix} �鿴 �˺���Ϣ
  ${Green_font_prefix}6.${Font_color_suffix} ��ʾ ������Ϣ
  ${Green_font_prefix}7.${Font_color_suffix} ���� �û�����
  ${Green_font_prefix}8.${Font_color_suffix} �ֶ� �޸�����
  ${Green_font_prefix}9.${Font_color_suffix} ���� ��������
������������������������
 ${Green_font_prefix}10.${Font_color_suffix} ���� ShadowsocksR
 ${Green_font_prefix}11.${Font_color_suffix} ֹͣ ShadowsocksR
 ${Green_font_prefix}12.${Font_color_suffix} ���� ShadowsocksR
 ${Green_font_prefix}13.${Font_color_suffix} �鿴 ShadowsocksR ��־
������������������������
 ${Green_font_prefix}14.${Font_color_suffix} ��������
 ${Green_font_prefix}15.${Font_color_suffix} �����ű�
 "
	menu_status
	echo && stty erase '^H' && read -p "���������� [1-15]��" num
case "$num" in
	1)
	Install_SSR
	;;
	2)
	Update_SSR
	;;
	3)
	Uninstall_SSR
	;;
	4)
	Install_Libsodium
	;;
	5)
	View_User
	;;
	6)
	View_user_connection_info
	;;
	7)
	Modify_Config
	;;
	8)
	Manually_Modify_Config
	;;
	9)
	Clear_transfer
	;;
	10)
	Start_SSR
	;;
	11)
	Stop_SSR
	;;
	12)
	Restart_SSR
	;;
	13)
	View_Log
	;;
	14)
	Other_functions
	;;
	15)
	Update_Shell
	;;
	*)
	echo -e "${Error} ��������ȷ������ [1-15]"
	;;
esac
fi