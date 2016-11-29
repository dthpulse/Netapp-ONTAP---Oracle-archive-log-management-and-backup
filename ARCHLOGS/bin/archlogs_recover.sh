#!/bin/bash

### installation path
mypath=/opt/netapp/snapcreator/scripts/ARCHLOGS

### END installation path
. $mypath/etc/archivelogs_backup.conf || exit 1

if [ ! -z "$1" ]
then
cat << EOF

Usage:
 Run the script $0 without any options and answer the questions.
 Script can recover only the archivelogs of instances backed up by the $HOSTNAME

EOF
exit
fi


archconfigs="$path_to_archlogs_dir/configs/*"

find $path_to_archlogs_dir -type d ! -name recover -exec mkdir /opt/netapp/snapcreator/scripts/ARCHLOGS/recover \; >/dev/null 2>&1

# show instances that backup is managed on this host
echo
read -p "display the instances? (y/n): " display_the_instances

case $display_the_instances in
''|y|Y)
 echo
 echo "Recovarable nstances:"
 /etc/init.d/archmonitord jobreview
 echo
 ;;
esac

# choose if recover has to be done based on time range or sequence number range
read -p "recover based on time range (t) or on range of sequences (s)?: " time_or_sequence
case $time_or_sequence in
t) ask_from="time from (example 2016-01-29 07:55:00):" 
   ask_to="time to (example 2016-01-29 10:10:00):"
   ;;
s) ask_from="sequence number start from:"
   ask_to="sequence number stop on:"
   ;;
*) echo "Please answer 's' or 't'"; exit ;;
esac

# provide name of instance to recover
read -p "instance name: " instance_name

# check if instance backup is managed on localhost
if [[ -z $(grep -w $instance_name $archconfigs) ]]
then 
 echo "Instance $instance_name wasn't found on $HOSTNAME"
 exit
fi

# user input criteria
read -p "$ask_from " answer_from
read -p "$ask_to " answer_to
read -p "Default recover path is archlog volume of the instance. (option r)
Files will be compressed to TGZ archive.
You can define the recover path to some path on the $HOSTNAME. (option u)
Then advise is local path /opt/netapp/snapcreator/scripts/ARCHLOGS/recover.(option h)
Please choose: " recover_to_path_option

# check ifall needed inputs were prvided
if [[ -z $instance_name || -z $answer_from || -z $answer_to || -z $recover_to_path_option ]]
then
 echo
 echo "not all inputs provided"
 echo
 exec "$0" "$@"
fi

# recover destination path based on user input 
case $recover_to_path_option in
r) echo "will recover to instance archlog volume"
# export source ip address of the online volume from config file
 recover_to_ip=$(grep -w -A 1 $instance_name $archconfigs | tail -1 | awk '{print $1}' | cut -d : -f 2)
# path to volume from config file
 recover_to_vol=$(grep -w -A 1 $instance_name $archconfigs | awk '{print $1}' | tail -1 | rev | cut -d : -f 1 | rev | cut -d / -f 1,2,3)
# qtree name from config file
 recover_to_qtree=$(grep -w -A 1 $instance_name $archconfigs | awk '{print $1}' | tail -1 | rev | cut -d : -f 1 | rev | cut -d / -f 4)
# local path online volume is mounted to
 recover_to_path="/mnt3/online/$recover_to_qtree"
 ;;
# store the user defined local path in variable
u) read -p "define path to recover on $HOSTNAME: " recover_to_path ;;
# default path to restore on localhost
h) recover_to_path="/opt/netapp/snapcreator/scripts/ARCHLOGS/recover" ;;
esac

# get the export source ip address for DR volume on nearstore from config file
nearstore_ip=$(nearstore=`grep -w -A 1 $instance_name $archconfigs | tail -1 | awk '{print $2}' | cut -d : -f 1` && grep $nearstore /opt/netapp/snapcreator/scripts/ARCHLOGS/etc/filer_acc_info | cut -d : -f 3)
# get the DR volume path from config file
dr_volume="/$(grep -w -A 1 $instance_name $archconfigs | tail -1 | awk '{print $2}' | cut -d / -f 2,3)"

# chceck if mountpoint is used before mounting the volume
# for DR volume
if find /mnt3 -type d -empty | read 
then 
 mkdir /mnt3/nearstore
 mount -o ro $nearstore_ip:$dr_volume /mnt3/nearstore
# for online volume - if wanted
 if [ $recover_to_path_option == r ]
 then
   mkdir /mnt3/online
   mount $recover_to_ip:$recover_to_vol /mnt3/online 
 fi
else 
 echo
# if it's in use, warn and exit
 echo "Cannot mount to /mnt3 - directory is not empty!"
 echo
 exit
fi

# find and print the files matching user criteria
echo "Files matching criteria:"
case $time_or_sequence in
# based on time range
t) find /mnt3/nearstore -type f -newermt "$answer_from" \! -newermt "$answer_to" | rev | cut -d / -f 1 | rev;;
# based on sequence range
s) for seq_num in `seq $answer_from $answer_to`;do  seq_found+="-or -name "*${seq_num}*" ";done
   seq_found=$(echo $seq_found | sed 's/-or//')
   find /mnt3/nearstore -type f $seq_found | rev | cut -d / -f 1 | rev
   ;;
esac

echo

# confirm the recover
read -p "Proceed with recover? (Y/n): " Proceed_with_recover
echo

# if recover is confirmed then recover
instance_name=$instance_name$(date +_%H%M%S)
case $Proceed_with_recover in
''|y|Y)
# if recover is based on time range
 if [ $time_or_sequence == t ]
 then
  echo "Compressing files to specified path ..."
  find /mnt3/nearstore -type f -newermt "$answer_from" \! -newermt "$answer_to" -print0 | tar -czf ${recover_to_path}/${instance_name}.tgz --null -T - >/dev/null 2>&1
 else
# if recover is based on sequence range
  echo "Compressing files to specified path ..."
  find /mnt3/nearstore -type f \( $seq_found \) -print0 | tar -czf ${recover_to_path}/${instance_name}.tgz --null -T - >/dev/null 2>&1
 fi

chmod 777 ${recover_to_path}/${instance_name}.tgz

# unmount the DR volume after recover
 umount /mnt3/nearstore

# if recover to online volume was selected then unmount online volume also
 if [ $recover_to_path_option == r ]
 then
   umount /mnt3/online
 fi

# check if the mountpoints are empty then delete them 
 if [[ ! "$(ls -A /mnt3/online)" && $recover_to_path_option == r ]] >/dev/null 2>&1
 then
  rm -rf /mnt3/online
 fi
 if [ ! "$(ls -A /mnt3/nearstore)" ] >/dev/null 2>&1
 then
  rm -rf /mnt3/nearstore
 fi

# print message with recover path based on user criteria
 if [ $recover_to_path_option == r ] 
 then
  echo "Recovered to"
  echo "$recover_to_vol/$recover_to_qtree/${instance_name}.tgz"
 else
  ls -1 ${recover_to_path}/${instance_name}.tgz
 fi
 ;;

# if recover wasn't confirmed by the user, then exit and unmount 
*) echo "exiting ..." 
  umount /mnt3/nearstore /mnt3/online
  if [[ ! "$(ls -A /mnt3/online)" && $recover_to_path_option == r ]] >/dev/null 2>&1
  then
   rm -rf /mnt3/online
  fi
  if [ ! "$(ls -A /mnt3/nearstore)" ] >/dev/null 2>&1
  then
   rm -rf /mnt3/nearstore
  fi
  exit ;;
esac

exit 0
