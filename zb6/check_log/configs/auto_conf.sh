#!/bin/bash

list="api_cdn
API_CHARGING
API_IT_Connector
API_MO_VASCLOUD
logapi"



for i in $list 
do
 sed 's/AUTOSAMPLE/'${i}'/g' auto_sample.txt > ${i}_ERROR.conf
done

