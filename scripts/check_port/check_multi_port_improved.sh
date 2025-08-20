#!/bin/bash

##### LIST PORT HERE:
list_port="127.0.0.1;8080;MySQL_Service;3
10.10.10.1;80;Apache_Web;2
192.168.1.100;443;HTTPS_Service;3"

########################################################################################################################################################################
path="/tmp/check_port_tmp"
if [ -d ${path} ]; then folder_exist=1 ; else mkdir ${path} ;fi
if [ -e /tmp/check_port_tmp/list_port_3.log  ]; then file_exist_3=1 ; else touch /tmp/check_port_tmp/list_port_3.log ; fi
if [ -e /tmp/check_port_tmp/list_port_2.log  ]; then file_exist_2=1 ; else touch /tmp/check_port_tmp/list_port_2.log ; fi
if [ -e /tmp/check_port_tmp/list_port_1.log  ]; then file_exist_1=1 ; else touch /tmp/check_port_tmp/list_port_1.log ; fi
echo "$list_port" > ${path}/list_port_1.log

###########################
#function check
check() {
for i in ${list_port}
do
 ip=`echo ${i} | awk -F ';' '{print $1}'`
 port=`echo ${i} | awk -F ';' '{print $2}'`
 service_name=`echo ${i} | awk -F ';' '{print $3}'`
 retry_count=`echo ${i} | awk -F ';' '{print $4}'`
 
 # Kiểm tra nếu đã retry đủ số lần quy định
 current_retry=${1}
 if [ ${current_retry} -le ${retry_count} ]; then
   status_port=`/etc/zabbix/scripts/check_multi_port/check_tcp -H ${ip} -p ${port} -t 1`
   count_status_port=`echo "$status_port" | grep "TCP OK" | wc -l`
   echo "$ip;$port;$service_name;$retry_count;$status_port;" >> ${path}/log1_${1}.log
   
   if [ ${count_status_port} -eq 1 ]
    then
     echo Check Port OK > /dev/null
    else 
     echo "$ip;$port;$service_name;$retry_count" >> ${path}/log2_${1}.log
   fi
 fi
done
}

#function post
post() {
text=`cat $path/log2_${1}.log | awk -F ";" '{print "Loi Ket Noi Toi Service:", $3, "- IP:", $1, "port", $2}'`

#send telegram or echo to zabbix
echo "$text"
cat /dev/null > $path/list_port_3.log #finish

cat /dev/null > ${path}/log1_3.log
cat /dev/null > ${path}/log2_3.log
}

#function up
up() {
# Chỉ chuyển lên những port còn trong retry range
while IFS= read -r line; do
  if [ -n "$line" ]; then
    retry_count=`echo ${line} | awk -F ';' '{print $4}'`
    if [ ${2} -le ${retry_count} ]; then
      echo "$line" >> $path/list_port_${2}.log
    fi
  fi
done < $path/log2_${1}.log
}
####################################################################################

#check_3
count_3=`cat $path/list_port_3.log | wc -l`
if [ ${count_3} -gt 0 ]
then
  list_port=`cat $path/list_port_3.log`
  
  check 3
  post 3
else
  echo 0
fi

#check_2
count_2=`cat $path/list_port_2.log | wc -l`
if [ ${count_2} -gt 0 ]
 then
  list_port=`cat $path/list_port_2.log`
  
  check 2
  up 2 3
  cat /dev/null > ${path}/log1_2.log
  cat /dev/null > ${path}/log2_2.log
fi
    
#check_1
count_1=`cat $path/list_port_1.log | wc -l`
if [ ${count_1} -gt 0 ]
then
  list_port=`cat $path/list_port_1.log`
  check 1
  up 1 2
  cat /dev/null > ${path}/log1_1.log
  cat /dev/null > ${path}/log2_1.log
else
  echo TUAN
fi