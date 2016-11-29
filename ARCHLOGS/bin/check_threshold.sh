#!/bin/bash

### installation path
mypath=/opt/netapp/snapcreator/scripts/ARCHLOGS

### END installation path
. $mypath/etc/archivelogs_backup.conf || exit 1

archconfig="$path_to_archlogs_dir/configs"
path_to_log="$sc_dir/engine/logs/check_threshold.log"

for filer_and_volumes in `awk '{print $1}' $path_to_arch_log_profile/* | grep -v "#"`
 do
 filer=`echo $filer_and_volumes | cut -d : -f 1`
 volume=`echo $filer_and_volumes | cut -d / -f 3`
  #ssh $filer rdfile /vol/vol0/etc/registry | grep "options.thresholds.${volume}.fsFull=60" 2>&1 > /dev/null
  ssh $filer "priv set advanced; registry walk options.thresholds" 2>&1 | grep $volume 2>&1 > /dev/null
  if [[ `echo $?` = 1 ]]
   then
########## ENABLE THIS COMMAND ON YOUR OWN RISK ONLY AND IF YOU ARE LAZY !!! ##########
#   ssh $filer "priv set advanced; registry set options.thresholds.$volume.fsFull 60"
#######################################################################################
   not_configured_volume_threshold+=" [$filer - $volume]"
  fi 
### section for fsFull thresholds on nearstores
#  nst_destination=`ssh $filer snapvault destinations | grep -w $volume | awk '{print$(NF)}'`
#  if [ ! -z "$nst_destination" ]
#  then
#   nearstore=`echo $nst_destination | cut -d : -f 1`
#   sv_volume=`echo $nst_destination | cut -d / -f 3`
#   ssh $nearstore rdfile /vol/vol0/etc/registry | grep "options.thresholds.${sv_volume}.fsFull=80" 2>&1 > /dev/null
#   if [[ `echo $?` = 0 ]]
#   then
########## ENABLE THIS COMMAND ON YOUR OWN RISK ONLY AND IF YOU ARE LAZY !!! ###############
#   ssh $nearstore "priv set advanced; registry set options.thresholds.$sv_volume.fsFull 80"
############################################################################################
#    not_configured_volume_threshold+=" [$nearstore - $sv_volume]"
#   fi
#  fi
### END of section for fsFull thresholds on nearstores
done

if [ ! -z "$not_configured_volume_threshold" ]
 then
 echo "[`date +"%F %T,%3N"`] WARNING: threshold is not configured for following volume(s): $not_configured_volume_threshold" >> $path_to_log
 echo "[`date +"%F %T,%3N"`] INFO: run command to add the volume threshold: ssh <filer> \"priv set advanced; registry set options.thresholds.<volume name>.fsFull\" with value 60 for online and 80 for nearstore" >> $path_to_log
 echo "" >> $path_to_log
 $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "SNAPCREATOR archivelog threshold error. See log $sc_dir/engine/logs/check_threshold.log"
 else
 echo "[`date +"%F %T,%3N"`] INFO: volumes full threshold is configured correctly" >> $path_to_log 
fi
exit 0
