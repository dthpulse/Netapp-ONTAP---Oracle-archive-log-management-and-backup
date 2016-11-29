#!/bin/bash

### installation path
mypath=/opt/netapp/snapcreator/scripts/ARCHLOGS

### END installation path
. $mypath/etc/archivelogs_backup.conf || exit 1

###### BEGGINNING case argument
### print enabled and disabled instances per file
case $1 in
--jobreview)
   for conigfile in $(grep archivelogs_backup.sh /var/spool/cron/root | grep -v "^#" | awk '{print $NF}')
   do
    instances_list=`grep "#" "$path_to_archlogs_dir/configs/$conigfile" | grep -v CRON_TIMES | awk '{print $2}'`
    disabled_relation=`echo "$instances_list" | grep ":"`
   if [ ! -z "$disabled_relation" ]
   then
    for single_disabled in `echo "$disabled_relation"`
    do
     disabled=$(grep -B 1 "$single_disabled" "$path_to_archlogs_dir/configs/$conigfile" | head -1 | awk '{print $2}')
     all_disabled+="$disabled|"
    done
   fi
   all_disabled=$(echo $all_disabled | sed 's/.$//')
   echo 
   ps -ef | grep -w "$conigfile" | grep -v grep >/dev/null 2>&1
   if [ `echo $?` -eq 0 ]
   then
    echo " Enabled instances in $conigfile: $(tput setaf 2)"Currently running since $(ps -ef | grep -w "$conigfile" | grep "archivelogs_backup.sh" | grep -v grep | awk '{print $5}' | sort | tr '\n' ' ')"$(tput sgr 0)"
    echo "cron entry: [$(grep -w $conigfile /var/spool/cron/root)]"
   else
    echo " Enabled instances in $conigfile:"
    echo "cron entry: [$(grep -w $conigfile /var/spool/cron/root)]"
   fi
   echo
   if [ ! -z "$all_disabled" ]
   then
    echo "$instances_list" | egrep -v "$all_disabled|:" | xargs -n 4 
   else
    echo "$instances_list" | sort | xargs -n 4
   fi
   echo
   echo " Disabled instances in $conigfile:"
   echo "cron entry: [$(grep -w $conigfile /var/spool/cron/root)]"
   echo
   echo "$(tput setaf 1)"$all_disabled"$(tput sgr 0)" | tr '|' ' ' | sort | xargs -n 4
   echo "- - - - - -"
   unset all_disabled 
   done
exit
;;
esac
###### END case argument

### check if file exist
### if not, create it
if [ ! -f "${path_to_archlogs_dir}/etc/listdb" ]
then 
# ls ${path_to_archlogs_dir}/configs > ${path_to_archlogs_dir}/etc/listdb
grep archivelogs_backup.sh /var/spool/cron/root | grep -v "^#" | awk '{print $NF}' > ${path_to_archlogs_dir}/etc/listdb

fi

###### BEGGINNING loop while true
while true
do
# sleep 300
grep archivelogs_backup.sh /var/spool/cron/root | grep -v "^#" | awk '{print $NF}' > ${path_to_archlogs_dir}/etc/listdb
### backup of crontab
 /bin/cp /var/spool/cron/root $path_to_archlogs_dir/etc/root_cron

### create updated temp list of configs context
 ls ${path_to_archlogs_dir}/configs | grep -v _ignore > ${path_to_archlogs_dir}/etc/listdb_temp

### check if there are differences
 diff -q ${path_to_archlogs_dir}/etc/listdb ${path_to_archlogs_dir}/etc/listdb_temp 2>&1 > /dev/null

###### BEGGINNING if A
### if there are differences
### update crontab
 if [ `echo $?` -eq 1 ]
 then 

### update base list of configs context file
  /bin/cp ${path_to_archlogs_dir}/etc/listdb_temp ${path_to_archlogs_dir}/etc/listdb

###### BEGGINNING loop conf_name
### proceed every config file in list
  for conf_name in `cat ${path_to_archlogs_dir}/etc/listdb`
  do

### if config exists but is commented (disabled)
### in crontab, then remove comment (enable it)
   grep -w $conf_name /var/spool/cron/root | grep "^#" 2>&1 > /dev/null
   
###### BEGGINNING if D
   if [ `echo $?` -eq 0 ]
   then

### get the line number where exact config is
    linenum=`grep -wn $conf_name /var/spool/cron/root | cut -d : -f 1` 

### remove comment from this line number
    sed -i "${linenum}s/#//g" /var/spool/cron/root

   fi
###### END if D

### check if it is listed in crontab
   grep -w $conf_name /var/spool/cron/root 2>&1 > /dev/null

###### BEGGINNING if B
### if not listed then update crontab
   if [ `echo $?` -eq 1 ]
   then

### extract the occurance number from config file name
    conf_occurance=$(echo $conf_name | cut -d "_" -f 1) 
    cron_occurance=$(printf "%s\n" "${conf_occurance//[!0-9]/}")
    crontimes=$(grep CRON_TIMES $path_to_archlogs_dir/configs/$conf_name | cut -d = -f 2 )

###### BEGGINNING case conf_occurance
### update the crontab based if hours or minutes are specified
    case $conf_occurance in
    *min)
      if [ -z "$crontimes" ]
      then
       echo "*/$cron_occurance * * * * /usr/local/bin/archivelogs_backup.sh -c $conf_name" >> /var/spool/cron/root
      else
       echo "$crontimes * * * * /usr/local/bin/archivelogs_backup.sh -c $conf_name" >> /var/spool/cron/root
      fi
    ;;
    *hour|*hours|*h)
      if [ -z "$crontimes" ]
      then
       echo "0 */$cron_occurance * * * /usr/local/bin/archivelogs_backup.sh -c $conf_name" >> /var/spool/cron/root
      else
       echo "$crontimes */$cron_occurance * * * /usr/local/bin/archivelogs_backup.sh -c $conf_name" >> /var/spool/cron/root
      fi
    ;;
    esac
###### END case conf_occurance

   fi
###### END if B

  done
###### END loop conf_name
  
###### BEGGINNING loop cron_config
### for every config in cron check if it is listed
### in current configs directory
  for cron_config in $(grep archivelogs_backup.sh /var/spool/cron/root | awk '{print $NF}')
  do

### check configs dir for the existing config
   grep -w $cron_config ${path_to_archlogs_dir}/etc/listdb 2>&1 > /dev/null

###### BEGGINNING if C
### if it is not in configs directory
   if [ `echo $?` -eq 1 ]
   then

### then delete it from crontab
    sed -i $(grep -wn $cron_config /var/spool/cron/root | cut -d : -f 1)d /var/spool/cron/root

   fi
###### END if C

  done
###### END loop cron_config

 fi 
###### END if A

sleep 300

done
###### END loop while true
