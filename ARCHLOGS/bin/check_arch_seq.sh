#!/bin/bash

# version=1.3

### installation path
mypath=/opt/netapp/snapcreator/scripts/ARCHLOGS

### END installation path
. $mypath/etc/archivelogs_backup.conf || exit 1


path_to_configs="$path_to_archlogs_dir/configs"
logfile="$path_to_archlogs_dir/logs/check_arch_seq/check_arch_seq_`date +%F`.log"
timeframe="130"

datestamp(){
echo [ `date "+%F %H:%M:%S,%3N"` ] "###" "$@"
}

logit(){
case $1 in
0|1|2) 
if [ $? -ne $1 ]
then
 shift;
 datestamp "$@" >> $logfile
fi
;;
*)
datestamp "$@" >> $logfile
;;
esac
}

echo >> $logfile
logit " ### STARTING the script ###"
###### BEGGINNING loop config_file
for config_file in $(ls -1 $path_to_configs | egrep -v '_ignore|HANA')
do

logit "Taking $(echo $config_file | rev | cut -d / -f 1 | rev)"
 echo $config_file | grep ORA >/dev/null

###### BEGGINNING if A
 if [ $? -eq 0 ]
 then
  ext=".arc"
 else
  ext=".dbf"
 fi
###### END if A

###### BEGGINNING loop nst_dest
 for nst_dest in $(cat $path_to_configs/$config_file | grep -v "#" | awk '{print $2}' | grep -v pscp03)
 do
  logit "Proceeding $nst_dest"
  mkdir -p /mnt1/$(echo $nst_dest | cut -d / -f 3,4)
  nst_core=$(ssh $(echo $nst_dest | cut -d : -f 1) ifconfig $core_interface | grep inet | awk '{print $2}')
  mount -o ro $nst_core:$(echo $nst_dest | cut -d : -f 2) /mnt1/$(echo $nst_dest | cut -d / -f 3,4) >/dev/null
  logit 0 "Unable to mount $nst_dest" 

  listfilepath=`dirname $0`/tempfile.txt

  find /mnt1/$(echo $nst_dest | cut -d / -f 3,4) -maxdepth 1 -name "*$ext" -cmin -$timeframe | while read line; do basename $line | grep -v cntrl >> $listfilepath; done

  sort -u $listfilepath -o $listfilepath

  archlog_name=`head -1 $listfilepath`

###### BEGGINNING if B
  if [ -s "$listfilepath" ]
  then

   occurence=${archlog_name//_/}
   occurence_underscore=$[${#archlog_name}-${#occurence}+1]

###### BEGGINNING loop i
   for i in $(seq 1 $occurence_underscore)
   do

    echo $archlog_name | cut -d _ -f $i | grep [[:alpha:]] >/dev/null

###### BEGGINNING if C
    if [ $? -eq 1 ]
    then
     archlog_name_part=$(cut -d _ -f $i $listfilepath | sort -u | wc -l)
     archlog_name_part_digits=$(cut -d _ -f $i $listfilepath | head -1)
  
###### BEGGINNING if D
     if [[ $archlog_name_part -ge 1 && ${#archlog_name_part_digits} -eq 1 ]]
     then
      cluster_node=1
      cluster_cut=$i
      cluster_nodes_count_lowest=`cut -d _ -f $i $listfilepath | sort -u | head -1`
      cluster_nodes_count_highest=`cut -d _ -f $i $listfilepath | sort -u | tail -1`
     elif [[ $archlog_name_part -ge 1 && ${#archlog_name_part_digits} -ge 1 ]]
     then
      sequence=$i
     fi
###### END if D

    fi
###### END if C

   done
###### END loop i

###### BEGGINNING if E
   if [ ! -z $cluster_node ]
   then

###### BEGGINNING loop every_cluster_node
    for every_cluster_node in $(seq $cluster_nodes_count_lowest $cluster_nodes_count_highest)
    do
     lowest_sequence=`grep _${every_cluster_node}_  $listfilepath | head -1 | cut -d _ -f $sequence | cut -d . -f 1`
     highest_sequence=`grep _${every_cluster_node}_ $listfilepath | tail -1 | cut -d _ -f $sequence | cut -d . -f 1`

###### BEGGINNING loop check
     for check in $(seq $lowest_sequence $highest_sequence)
     do
      grep _${every_cluster_node}_ $listfilepath | grep $check >/dev/null

###### BEGGINNING if F
      if [ $? -ne 0 ]
      then
       missing+="$check "
      fi
###### END if F

     done
###### END loop check

    done
###### END loop every_cluster_node

   else
    lowest_sequence=`head -1 $listfilepath | cut -d _ -f $sequence | cut -d . -f 1`
    highest_sequence=`tail -1 $listfilepath | cut -d _ -f $sequence | cut -d . -f 1`

###### BEGGINNING loop check2
    for check in $(seq $lowest_sequence $highest_sequence)
    do
     grep $check $listfilepath >/dev/null
     if [ $? -ne 0 ]
     then
      missing+="$check "
     fi
    done
###### END loop check2

   fi
###### END if E

###### BEGGINNING if G
   if [ ! -z "$missing" ]
   then

    sleep 60
    for each_missing in $missing 
    do
     test `find /mnt1/$(echo $nst_dest | cut -d / -f 3,4) -name "*$each_missing*"` || missing2+="$each_missing "
    done
   fi 

  if [ ! -z "$missing2" ]
  then
    online_volume=`grep -w $nst_dest $path_to_configs/$config_file | cut -d / -f 3`
    online_filer=`grep -w $nst_dest $path_to_configs/$config_file | cut -d : -f 1`
    cp -rap $listfilepath $path_to_archlogs_dir/logs/check_arch_seq/${online_volume}_seqlist_$(date "+%F_%H%M%S").log
    logit "ERROR: missing sequences on [$nst_dest]: [$missing]"
    $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "ARCHLOG sequence check - $nst_dest missing sequence [$missing]"
    affected_relation=`grep -w $nst_dest $path_to_configs/$config_file`
###### BEGGINNING loop snap
    for snap in `ssh $online_filer snap list -b $online_volume | awk '{print $1}' | grep SNAPCREATOR | grep -v missing_seq`
    do
     ssh $online_filer snap rename $online_volume $snap missing_seq_$(date "+%F_%H%M%S")
     logit "WARNING: SNAP [$snap] on VOLUME [$online_volume]"
     unset missing missing2
    done
###### END loop snap
   else
    logit "INFO: [$nst_dest]: OK"

   fi
###### END if G

  else

   logit "INFO: [$nst_dest] doesn't contain logs created in last $timeframe minutes"

  fi
###### END if B
  umount -l /mnt1/$(echo $nst_dest | cut -d / -f 3,4)
  find /mnt1/$(echo $nst_dest | cut -d / -f 3) -type d -empty -delete
unset cluster_node missing

 rm -f $listfilepath

 done
###### END loop nst_dest

done
###### END loop config_file
logit "SCRIPT FINISHED"
find $path_to_archlogs_dir/logs/check_arch_seq/ -name "*.log" -type f -mtime 28 -delete
exit
  
