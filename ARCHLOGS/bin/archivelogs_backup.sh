#!/bin/bash

version="5.1 , date 2016-05-04 09:00"

### installation path
mypath=/opt/netapp/snapcreator/scripts/ARCHLOGS

### END installation path
. $mypath/etc/archivelogs_backup.conf || exit 1

###### BEGGINING function usage
function usage {

cat << EOF

 valid options:

 requiered options:
 -c  <configuration name>
 optional:
 -n  telling the script to take nearstore snapshot and manage archivelogs retention. If specified, must be always specified with -c option.
 -v  verbose
 -t  no ticket will be generated if error will occure
 -V  print version
 -i  will not disable the instance from next run if error will occure
 -e  <interface to use for ndmp>
 -s  initial setup needed for fresh installation (or even if ARCHLOGS directory was moved or renamed)

EOF

}
###### END function usage

###### BEGGINING getopts 
### n - doesn't require argument. Telling the script to take nearstore snapshot and manage archivelogs retention. Must be always specified with -c option
### c - requires an argument. Argument is configuration file name
while getopts "siVvntc:e:" STRING; do
 case $STRING in
  n)

### sets that snapshot on nearstore and archivelog management is required to perform even if time do not match 0-23/6
    nearstore_snapshot=yes
    ;;
  c)

### configuration file that contains the ndmp relations
    config_name=$OPTARG

###### BEGGINING if I
### check if configuration exists, if not print usage and exit
    if [ -z $(find $path_to_archlogs_dir/configs/ -iname $config_name) ]
    then
     echo
     echo " specified configuration file doesn't exist in $path_to_archlogs_dir/configs"
     usage
     exit 1
    fi
###### END if I

### get the path to this configuration file
    config_path=$(find $path_to_archlogs_dir/configs/ -iname $config_name)

### occurance or how often ndmpcopy has to be run
    occurance=$(echo $config_name | cut -d _ -f 1)

### what is the snapshot retention on nearstores
    snap_retention_to_keep=$(echo $config_name | cut -d _ -f 2 | tr -d [:alpha:])
    ;;
   v) echo ;;
   V) echo "version $version"; exit 0 ;;
   t) noticket=yes ;;
   i) ignore=yes ;;
   e) core_interface=$OPTARG ;;
   s) sed -i '/^mypath=/d; /^\.\ \$mypath/d' ./*.sh ./archmonitord
      sed -i "/^### installation path/a mypath=$(dirname `pwd`)" ./*.sh ./archmonitord
      sed -i "/^### END installation path/a . \$mypath/etc/archivelogs_backup.conf || exit 1" ./*.sh ./archmonitord; exit;;
  \?) 

### if specified option is not rcognized by the script, print usage and exit 
     usage
     exit 1
    ;;
  esac

done
###### END getopts

####################################################################################################################
# this section can be modyfied by administrator to set proper paths
####################################################################################################################

### Solving the Panic: '/usr/lib64/perl5/CORE/libperl.so' is not an ActivePerl 5.16 library
test ! -d $sca_dir/tmp && mkdir -p $sca_dir/tmp
export TMPDIR=$sca_dir/tmp


####################################################################################################################


####################################################################################################################
# section for usage
#             check if all requiered options are specified
####################################################################################################################

###### BEGGINING function silentEcho
# Use `$echoLog` everywhere you print verbose logging messages to console
# By default, it is disabled and will be enabled with the `-v` or `--verbose` flags
declare echoLog='silentEcho'
function silentEcho() {
    :
}
###### END function silentEcho

###### BEGGINING function datestamp
function datestamp {
echo [`date +"%F %T,%3N"`]   "$@"
}
###### END function silentEcho

###### BEGGINNING function get_exit_status
get_exit_status(){
exitcode=`echo $?`
if [ $exitcode -ne $1 ]
then
 shift;
 if [ "$1" == error_log ]
 then
  shift;
  datestamp "$@" >> $logfile
  datestamp "$@" >> $(echo $logfile | sed 's/out/error/')
  $echoLog "$@"
  echo >> $logfile
  $echoLog
  if [ -z "$noticket" ]
  then
   $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "ARCHIVELOGS ERROR. Log is $(echo $logfile | rev | cut -d / -f 1 | rev)"
  fi
  exit 1
 else
  shift;
  datestamp "$@" >> $logfile
  $echoLog "$@"
  $echoLog
 fi
fi
}
###### END function get_exit_status

###### BEGGINNING function log_verbose_it
log_verbose_it(){
if [ "$1" == nodatestamp ]
then
 shift;
 echo "$@" >> $logfile
 $echoLog "$@"
elif [ "$1" == error_log ]
then
 shift;
 echo "$@" >> $logfile
 echo "$@" >> $(echo $logfile | sed 's/out/error/')
 $echoLog "$@"
else
 datestamp "$@" >> $logfile
 $echoLog "$@"
fi
echo >> $logfile
$echoLog
}
###### END function log_verbose_it


###### BEGGINING function remove_umount
function umount_it {
###### BEGGINING of loop mounted
### find all mounted volumes with $orts identifier
for mounted in $(mount | grep $config_name | grep $orts | awk '{print $3}')
do

### unmount each of them
### LOGGING & VERBOSE
log_verbose_it "### unmounting $mounted"
 umount -l $mounted >> $logfile 2>&1
 get_exit_status 0 "WARNING: failed to unmount $mounted"

done
###### END of loop mounted
}

remove_it () {

### remove mountpoints, nohup file and temporary snapcreator job configurations files
### LOGGING & VERBOSE
log_verbose_it "### removing temporary files and mountpoints"

### check if mountpoints are empty, if yes delete them
find /mnt/online_volumes/$config_name/$orts -type d -empty -delete >/dev/null 2>&1
find /mnt/nearstore_volumes/$config_name/$orts -type d -empty -delete >/dev/null 2>&1

### remove temporary configurations
rm -rf $scf_config_path/manage_archivelogs_*_$orts.conf >> $logfile 2>&1

}
###### END function remove_umount

###### BEGGINING if H
### check if all requiered options are specified
### if not print - usage and exit
if [[ -z $1 || -z $2 && $1 != "-V" && $1 != "-s" ]]
then 
 echo " Missing options"
 usage
 exit 1
fi
###### END if H


####################################################################################################################


####################################################################################################################
# orts - is used for job identyfier based on time HHMMSSmsmsms
# 
# on next steps script is handling with option arguments
####################################################################################################################

while read line
do
 for param in `echo $line | grep "/"`
 do
  test -e `echo $param | cut -d = -f 2` || (echo "`echo $line | cut -d = -f 1` doesnt exist"; kill $$)
 done
done < $mypath/etc/archivelogs_backup.conf | sed '/^#/d; /^$/d'

test ! -f /usr/local/bin/snapcreator && (log_verbose_it "file /usr/local/bin/snapcreator not found"; kill $$)
test ! -f $scf_config_path/manage_archivelogs.conf && (log_verbose_it "file $scf_config_path/manage_archivelogs.conf not found"; kill $$) 

### runtime specifier
orts=$(date +%H%M%S%3N)


### setting up the logfile path
logfile=${sc_logfile}/manual_ndmp_${config_name}.out.$(date +%Y%m%d%H%M%S).log
touch $logfile

###### BEGGINNING verbose_conf
while [[ $# > 0 ]]; do
 case  $1 in
 -v) echoLog='echo'; ;;
 esac
 shift;
done
###### END verbose_conf

### assign current hour and minute to variable that script knows if it should perform nearstore operation
current_hour=`date +%H`

###### BEGGINING case current_hour
### in case that is current time is 
case $current_hour in
00|06|12|18)

 grep -w $current_hour-$config_name $path_to_archlogs_dir/etc/nst_job.db >/dev/null 2>&1
 
 if [ `echo $?` -ne 0 ]
 then
  echo "$current_hour-$config_name" >> $path_to_archlogs_dir/etc/nst_job.db
  nearstore_snapshot=yes
 fi
 ;;
02) 
 echo "" > $path_to_archlogs_dir/etc/nst_job.db
 ;;
esac
###### END case current_hour

###### BEGGINING snap_retention_to_keep

sc_policy=sc_policy_${snap_retention_to_keep}days
sc_policy=$(eval echo \$$sc_policy)
nst_archive_log_retention=$snap_retention_to_keep

###### END snap_retention_to_keep

### LOGGING & VERBOSE
log_verbose_it "##########  STARTING JOB ##########"
if [ ! -z $nearstore_snapshot ]
then
  log_verbose_it "### operation on nearstore will be performed"
  log_verbose_it "### SnapCreator nearstore policy is $sc_policy"
fi
log_verbose_it "### configuration file is $config_name"
log_verbose_it "### occurance is $occurance"
log_verbose_it "### snapshot retention on nearstores $snap_retention_to_keep days"

####################################################################################################################


####################################################################################################################
# first script sequence
# for every online volume specified in the configuration file script will create snapshot 
####################################################################################################################


### tell 'for' loop to consider new line as separator
 SAVEIFS=$IFS
 IFS="
"
###### BEGGINNING loop checkline
### checking configuration file for previously ndmp failed instances (commented)
### and if volume is mounted will not be proceeded
for checkline in $(grep -v "#" $config_path)
do

###### BEGGINNING if N
### checking if volumes in config line are mounted
 if [[ ! -z $(mount | grep -w mnt | egrep -w "`echo "$checkline" | awk '{print $1}' | cut -d / -f 3`") ]] || [[ ! -z $(ps -ef | grep -w `echo "$checkline" | cut -d / -f 3` | grep -v grep) ]] || [[ ! -z $(snapcreator --server localhost --port $sc_port --user $sc_user --passwd $sc_user_pwd --action jobStatus | egrep -w 'running' | grep -w manage_archivelogs_$(echo "$checkline" | grep -v grep | awk '{print $1}' | cut -d / -f 3)_snapshot) ]]
 then

### if mounted add them to do not do list
  do_not_do+="$(echo $checkline | awk '{print $1}' | cut -d / -f 3)|"

### LOGGING & VERBOSE
log_verbose_it "### INFO: $checkline is already mounted, or disabled or job is still running - skipping archivelog management and online snapshot creation job"

 fi
###### END if N

done
###### END loop checkline

if [ -z "$do_not_do" ]
then
do_not_do="sjwsjhdjqdqdqkjdkedhudehd"
fi

### delete last character '|' from string
do_not_do=$(echo $do_not_do | sed 's/.$//')

###### BEGGINING for loop line
### proceed every line in current config
 for line in $(egrep -wv "$do_not_do|#" $config_path)
 do

### LOGGING & VERBOSE
log_verbose_it "### proceeding relation $line from $config_path"

###### BEGGINING if A
### do not go on if line is empty or if it is still running (from previous job?)
  if [[ ! -z "$line" && -z `ps -ef | grep "$line" | grep -v grep` ]]
  then

### find online filer in line
   online_filer=`echo "$line" | cut -d : -f 1`

### LOGGING & VERBOSE
log_verbose_it "### online filer is $online_filer"

### find instance name in config_path for relation in line
   instance_name=$(grep -B 1 "$line" $config_path | awk 'NR==1{print $2}')

### LOGGING & VERBOSE
log_verbose_it "### instance name is $instance_name"

### assign this value to started instances variable
   started_instances+=" $instance_name"

### find online volume in line 
online_volume=$(echo $line | cut -d / -f 3)

### LOGGING & VERBOSE
log_verbose_it "### online volume is $online_volume"

### sum of all proceeded online volumes
all_online_volumes+=" $online_volume"

### create SnapCreator job configuration for online volume
### script will ndmpcopy its content to nearstore
### LOGGING & VERBOSE

log_verbose_it "### creating temporary SnapCreator configuration file for online snapshot $scf_config_path/manage_archivelogs_${online_volume}_snapshot_$orts.conf"

cp $scf_config_path/manage_archivelogs.conf $scf_config_path/manage_archivelogs_${online_volume}_snapshot_$orts.conf
get_exit_status 0 "WARNING: Not able to create $scf_config_path/manage_archivelogs_${online_volume}_snapshot_$orts.conf"

### run snapcreator job from new configuration above
/usr/local/bin/snapcreator --server localhost --port $sc_port --user $sc_user --passwd $sc_user_pwd --action backup --profile ARCH_LOGS --config manage_archivelogs_${online_volume}_snapshot_$orts --params ARCHIVE_LOG_ENABLE=N NTAP_SNAPSHOT_DISABLE=N VOLUMES=$online_filer:$online_volume --policy hourly &

### LOGGING & VERBOSE
log_verbose_it "### running SnapCreator job "
sleep 3
log_verbose_it nodatestamp "$(ps -ef | grep -w "$online_filer:$online_volume" | grep -v grep)"

snapon_vols+="$online_volume|"
  fi
###### END if A

 done
###### END for loop line


### return separator for the loop back to default value
IFS=$SAVEIFS


####################################################################################################################


####################################################################################################################
# second script sequence is to wait untill all jobs for creating the snapshot are finished
####################################################################################################################


### wait untill SnapCreator finish snapshots on online volumes
###### BEGGINING loop wait until finish snapshots
until [[ -z $(pgrep -f $orts) ]]
do

snapon_vols=$(echo $snapon_vols | sed 's/.$//')

### LOGGING & VERBOSE
 log_verbose_it "############## waiting for online snapshots to be finished ##############"
 log_verbose_it nodatestamp "$(ps -ef | grep "$orts" | egrep -w "$snapon_vols" | egrep -v 'grep|ls -t')"
 sleep 15

done
###### END loop wait until finish snapshots


####################################################################################################################


####################################################################################################################
# next script sequence is to run ndmpcopy on every online volume to its DR site 
# from the snapshot created by the script in sequence before
####################################################################################################################


###### BEGGINING snapshoted_online_volume
### again proceed all online volumes where snapshot was created
for snapshoted_online_volume in $all_online_volumes
do

###### BEGGINING if L
### check if snapshot creation on online volume was successfull 
### if not then disable the relation to be run on next run, send ticket, exit
if [ -s $(ls -t $sc_logfile/manage_archivelogs_${snapshoted_online_volume}_snapshot*error* | head -1) ]
then

### LOGGING & VERBOSE
log_verbose_it error_log "######## ERROR: online snapshot job failed on volume $snapshoted_online_volume"
log_verbose_it error_log "######## INFO: sending the ticket . . . "

###### BEGGINNING if S
### do not send ticket if option -t is specified
if [ -z "$noticket" ]
then

### send PRIO 1 ticket with ndmplogfile name where error was founded
  $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "PRIO 1 ARCHIVELOGS online snapshot job failed on volume $snapshoted_online_volume"

fi
###### END if S

### comment the line with relation for failed instance to do not run it on next time
### LOGGING & VERBOSE
log_verbose_it "######## disabling the instance to not be proceeded on the next run"

if [ -z $ignore ]
then
 failed_snapshoted_volume_relation=$(grep -w $snapshoted_online_volume $config_path)
 sed -i "s|$failed_snapshoted_volume_relation|#\ $failed_snapshoted_volume_relation|g" $config_path
fi

umount_it
remove_it

exit

fi 
###### END if L

### LOGGING & VERBOSE
log_verbose_it "### proceeding $snapshoted_online_volume for ndmpcopy job"

### find online filer
 online_filer=$(grep -w $snapshoted_online_volume $config_path | cut -d : -f 1)

### LOGGING & VERBOSE
log_verbose_it "### online filer for ndmp job is $online_filer"

### find volume qtree
 online_volume_qtree=$(grep -w $snapshoted_online_volume $config_path | awk '{print $1}' | cut -d / -f 4)

### LOGGING & VERBOSE
log_verbose_it "### volume $snapshoted_online_volume qtree is $online_volume_qtree"

### find nearstore hostname in line
   nearstore_destination=$(grep -w $snapshoted_online_volume $config_path | awk '{print $2}')

### LOGGING & VERBOSE
log_verbose_it "### volume $snapshoted_online_volume nearstore destination is $nearstore_destination"

### get password for ndmp from online filer
   online_filer_ndmp=$(grep $online_filer $filer_acc_info | cut -d : -f 2)

### LOGGING & VERBOSE
log_verbose_it "### password for ndmp user on filer $online_filer found"

### find instance name in configuration file
   instance_name=$(grep -B 1 -w "$snapshoted_online_volume" $config_path | awk 'NR==1{print $2}')

### LOGGING & VERBOSE
log_verbose_it "### instance name for ndmp job is $instance_name located on volume $snapshoted_online_volume"

### find new snapshot on the volume created by SnapCreator
### continue until we get the snapname or at least ndmp_tcount number tries

### first try to find snapshot name in logfile
new_snap_on_online_volume=$(grep -i "STORAGE-02007: Creating Snapshot copy" $(ls -t $sc_logfile/manage_archivelogs_${snapshoted_online_volume}_snapshot*.out.* | head -1) | grep -o SNAPCREATOR.* | cut -d ] -f 1)

###### BEGGINNING if new_snap_on_online_volume
### if not found in logfile then find on volume
if [ -z $new_snap_on_online_volume ]
then

###### BEGGINNING until snap_find_try
until [[ ! -z "$new_snap_on_online_volume" || $ndmp_tcount -le "$snap_find_try" ]]
do
 let snap_find_try+=1
 new_snap_on_online_volume=$(ssh $online_filer snap list -b $snapshoted_online_volume | grep SNAPCREATOR | awk '{print $1}' | head -1 | sed 's/[ \t]*$//')
done
###### END until snap_find_try

fi
###### END if new_snap_on_online_volume

### clear the variable snap_find_try
unset snap_find_try 

### LOGGING & VERBOSE
log_verbose_it "### snapshot used for ndmpcopy is $new_snap_on_online_volume on volume $snapshoted_online_volume"

online_filer_core=$(grep $online_filer $filer_acc_info | cut -d : -f 3)

### run ndmp from this snapshot and write output to the log
   echo >> $path_to_archlogs_dir/logs/${instance_name}_${config_name}_`date +%F`.log
   echo "################################################################" >> $path_to_archlogs_dir/logs/${instance_name}_${config_name}_`date +%F`.log
   echo "[`date +"%F %T,%3N"`]" >> $path_to_archlogs_dir/logs/${instance_name}_${config_name}_`date +%F`.log

### LOGGING & VERBOSE
log_verbose_it "### ndmp command is:"
log_verbose_it nodatestamp "ssh -o TCPKeepAlive=no -o ServerAliveInterval=10 -f $(echo $nearstore_destination | cut -d : -f 1) ndmpcopy -mcd inet -sa ndmp:$online_filer_ndmp $online_filer_core:/vol/$snapshoted_online_volume/.snapshot/$new_snap_on_online_volume/$online_volume_qtree $nearstore_destination"

ssh -o TCPKeepAlive=no -o ServerAliveInterval=10 -f $(echo $nearstore_destination | cut -d : -f 1) ndmpcopy -mcd inet -sa ndmp:$online_filer_ndmp $online_filer_core:/vol/$snapshoted_online_volume/.snapshot/$new_snap_on_online_volume/$online_volume_qtree $nearstore_destination >> $path_to_archlogs_dir/logs/${instance_name}_${config_name}_`date +%F`.log 2>&1 &

### get ndmp jobs PIDs
sleep 6
ndmpjobs_pid+="$(pgrep -f $nearstore_destination)|"

### LOGGING & VERBOSE
log_verbose_it "### ndmp job is "

log_verbose_it nodatestamp "$(ps -ef | grep "$online_filer_core:/vol/$snapshoted_online_volume/.snapshot/$new_snap_on_online_volume/$online_volume_qtree $nearstore_destination" | grep -v grep)"

### clear the variable new_snap_on_online_volume
unset new_snap_on_online_volume

done
###### END snapshoted_online_volume

### LOGGING & VERBOSE
log_verbose_it "### instances where ndmp job is running: "
log_verbose_it nodatestamp "$(echo "$started_instances" | sort | xargs -n4)"

####################################################################################################################


####################################################################################################################
# sequence to check if all NDMPCOPY jobs finished successfully 
# if yes, run archivelog management job on the volumes
# if no, create the ticket, comment the line with fault relation in configuration file
# to do not proceed it in on next script run
####################################################################################################################


###### BEGGINING if B
### proceed only if some instances has been started
if [ ! -z "$started_instances" ]
then

test $(echo "${ndmpjobs_pid: -1}") == "|" && ndmpjobs_pid=$(echo "$ndmpjobs_pid" | sed 's/.$//')

###### BEGGINING until loop started_instances
### execute this loop untill all instances in started_instances will be finished
 until [ -z "$started_instances" ]
 do

###### BEGGINING for loop single_running_instance
### take every instance (single_running_instance) from started_instances separately
  for single_running_instance in $started_instances
  do

### find online filer relation
onlinefiler_relation=$(grep -A 1 -w "# $single_running_instance" $config_path | awk 'END{print $1}')
get_exit_status 0 "WARNING: Not able to find onlinefiler_relation in $config_path"

### find path
onlinefiler_path=$(echo $onlinefiler_relation | cut -d / -f 3)
get_exit_status 0 "WARNING: Not able to find onlinefiler_path in $onlinefiler_relation"

### find relation (still_running_relation_nearstore) for single_running_instance 
still_running_relation_nearstore=$(grep -A 1 -w "# $single_running_instance" $config_path | awk 'END{print $2}')

### find relation (still_running_relation_onlinefiler) for single_running_instance
still_running_relation_onlinefiler=$(grep -A 1 -w "# $single_running_instance" $config_path | awk 'END{print $1}')

### check processes if relation (still_running_relation_nearstore) is still running
   ps -ef | grep "$still_running_relation_nearstore" | grep -v grep 2>&1 > /dev/null

###### BEGGINING if C
### if relation (still_running_relation_nearstore) is not running then proceed
   if [[ `echo $?` -eq 1 ]]
   then

### LOGGING & VERBOSE
log_verbose_it "### instance $single_running_instance finished ndmpcopy job"

### finished relations that will be proceeded furter
    nearstore_relation_to_be_proceeded+="$still_running_relation_nearstore "

### check the ndmp log files for errors for all instances under proceeded configuration
### LOGGING & VERBOSE
log_verbose_it "### checking if the ndmp was successfull on instance $single_running_instance"

ls $path_to_archlogs_dir/logs/${single_running_instance}_${config_name}_$(date +%F).log >/dev/null 2>&1

###### BEGGINNING ndmplogfile_path 
### if path to ndmp log is empty take log from
### previous day as it was probably because NDMP transferr finished
### before the midnight
if [ `echo $?` -ne 0 ]
then
 ndmplogfile_path=$path_to_archlogs_dir/logs/${single_running_instance}_${config_name}_$(date "--date=day ago" +%F).log
 log_verbose_it "### INFO: NDMP logfile $path_to_archlogs_dir/logs/${single_running_instance}_${config_name}_$(date +%F).log wasn't found"
 log_verbose_it "### INFO: using NDMP logfile from latest day to check the ndmpcopy job success $ndmplogfile_path"
else
 ndmplogfile_path=$path_to_archlogs_dir/logs/${single_running_instance}_${config_name}_$(date +%F).log
fi
###### END ndmplogfile_path

ndmplogfile=$(echo "$ndmplogfile_path" | rev | cut -d / -f 1 | rev)

###### BEGGINING ndmpcopy success check
### find last run record in ndmplogfile_path and check if transfer was successfull
 tail -$(cat $ndmplogfile_path | tac | grep -n "#####" | head -1 | cut -d: -f1) $ndmplogfile_path | grep -i "Transfer successful" 2>&1 > /dev/null

### save ndmpjob exit status to variable 
ndmpjob_exit_status=$(echo $?)

### find if all files were copied 
tail -$(cat $ndmplogfile_path | tac | grep -n "#####" | head -1 | cut -d: -f1) $ndmplogfile_path | grep -i "RESTORE: File creation failed" 2>&1 > /dev/null

### save the "copied files" exit status
notcopied_file=$(echo $?)

###### BEGGINNING if K
### check if ndmpjob wasn't successfull AND it was first attempt
 if [[ $notcopied_file -eq 0 && $(echo "$secondtry_instance" | tr ' ' '\n' | grep -w "$single_running_instance" | wc -l) -le "$ndmp_tcount" || $ndmpjob_exit_status -eq 1 && $(echo "$secondtry_instance" | tr ' ' '\n' | grep -w "$single_running_instance" | wc -l) -le "$ndmp_tcount" ]]
 then

### WARN us 
  log_verbose_it "### INFO: ndmpcopy attempt didn't finished successfully, trying to run ndmpcopy again"

### find nearstore destination of failed relation
  secondtry_nearstore_destination=$(grep -w -A 1 "# $single_running_instance" $config_path | awk 'END{print $2}')

### find instance name of failed relation
  secondtry_instance_name=$(grep -w -B 1 $secondtry_nearstore_destination $config_path | awk 'NR==1{print $2}')

### find ndmpcopy command that failed in logfile
  failed_ndmp_cmd=$(grep -w $secondtry_nearstore_destination $logfile | grep -v "#" | tail -1 | grep -o "ssh.*")

### run this command
   echo >> $path_to_archlogs_dir/logs/${secondtry_instance_name}_${config_name}_`date +%F`.log
   echo "################################################################" >> $path_to_archlogs_dir/logs/${secondtry_instance_name}_${config_name}_`date +%F`.log
   echo "[`date +"%F %T,%3N"`]" >> $path_to_archlogs_dir/logs/${secondtry_instance_name}_${config_name}_`date +%F`.log
  $failed_ndmp_cmd >> $path_to_archlogs_dir/logs/${secondtry_instance_name}_${config_name}_`date +%F`.log 2>&1 &

### update ndmpjobs PID list
  sleep 6

###### BEGGINNING if OM
  if [ ! -z "$ndmpjobs_pid" ]
  then

### if variable is not empty use pipe
   ndmpjobs_pid+="|$(pgrep -f $secondtry_nearstore_destination)"
  else

### if variable isn't empty don't use pipe
   ndmpjobs_pid+=$(pgrep -f $secondtry_nearstore_destination)

  fi
###### END if OM

### LOGGING & VERBOSE
  log_verbose_it "### ndmp job is"
  log_verbose_it $(ps -ef | grep ssh | grep $secondtry_nearstore_destination | grep -v grep)

### save in variable the instance name that runs 2nd time
  secondtry_instance+="$single_running_instance "

### check if ndmpjob wasn't successfull AND it is second instance attempt 
### then create ticket and disable the instance from the next run and exit
 elif [[ $notcopied_file -eq 0 && "$ndmp_tcount" -lt $(echo "$secondtry_instance" | tr ' ' '\n' | grep -w "$single_running_instance" | wc -l) || $ndmpjob_exit_status -eq 1 && "$ndmp_tcount" -lt $(echo "$secondtry_instance" | tr ' ' '\n' | grep -w "$single_running_instance" | wc -l) ]]
 then

### LOGGING & VERBOSE
   log_verbose_it error_log "######## ERROR: NDMP transfer failed on instance $single_running_instance"
  log_verbose_it "######## INFO: sending the ticket . . . "

###### BEGGINNING if T
### do not send ticket if option -t is specified
  if [ -z "$noticket" ]
  then

### send PRIO 1 ticket with ndmplogfile name where error was founded
   $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "PRIO 1 Archivelogs ndmp backup job has failed. Log is $(echo $ndmplogfile | rev | cut -d / -f 1 | rev)."

  fi
###### END if T

### find failed instance name
  failed_instance=$(echo $ndmplogfile | cut -d _ -f 1)

### find failed instance configuration file
  failed_instance_config=$(echo $ndmplogfile | sed "s/_$(echo $ndmplogfile | rev | cut -d _ -f 1 | rev)//" | cut -d _ -f 2,3,4,5,6)

### find faild instance relation for ndmpcopy
  failed_instance_relation="$(grep -A 1 -w "# $failed_instance" ${path_to_archlogs_dir}/configs/${failed_instance_config} | tail -1)"

  if [ -z $ignore ]
  then
### comment the line with relation for failed instance to do not run it on next time
### LOGGING & VERBOSE
   log_verbose_it "######## disabling the instance to not be proceeded on the next run"
   sed -i "s|$failed_instance_relation|# $failed_instance_relation|g" $path_to_archlogs_dir/configs/$failed_instance_config
   $echoLog
  fi

###### BEGGINNING loop wait to finish ARCH
  until [[ -z "$(ps -ef | grep "$orts" | grep -v grep)" ]]
  do

   log_verbose_it "######## waiting till SnapCreator Archive log management will finish to remove mounts securely"
   sleep 15

  done
###### END loop wait to finish ARCH

### unmount volumes, remove mountpoints and configurations
  umount_it
  remove_it

### exit
  exit

### if ndmpjob was successfull
 elif [[ $notcopied_file -eq 1 && $ndmpjob_exit_status -eq 0 ]]
 then

### remove the instance name from list of secondtry
  secondtry_instance=$(echo "$secondtry_instance" | sed "s/$single_running_instance\ //")

 fi
###### END if K
###### END ndmpcopy success check

###### BEGGINNING if V
### proceed only if instance is not listed in secondtry list
### archivelog management
if [ -z "$(echo "$secondtry_instance" | grep "$single_running_instance")" ]
then

### LOGGING & VERBOSE
log_verbose_it "### $(echo $onlinefiler_relation | cut -d : -f 2,3) is not mounted"

### create directory under /mnt/*/<volume name>/<qtree name>

### LOGGING & VERBOSE
log_verbose_it "### creating mountpoint "

      mkdir -p /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation| cut -d / -f 3,4)

### insert filer hostname to the variable
      online_filer=`echo $onlinefiler_relation | cut -d : -f 1`
get_exit_status 0 "WARNING: couldn't find online_filer"
### insert volume name to the variable
      volume_name=`echo $onlinefiler_relation | cut -d / -f 3`
get_exit_status 0 "WARNING: couldn't find volume_name"

### find storage IP from same subnet as SnapCreator is using
      volume_ip=`echo $onlinefiler_relation | cut -d : -f 2`
get_exit_status 0 "WARNING: couldn't find volume_ip"

### new snapshot name created by SnapCreator


scf_snap_on_online_volume=$(grep -i "STORAGE-02007: Creating Snapshot copy" $(ls -t $sc_logfile/manage_archivelogs_${volume_name}_snapshot*.out.* | head -1) | grep -o SNAPCREATOR.* | cut -d ] -f 1)

###### BEGGINNING if scf_snap_on_online_volume
### if not found in logfile then find on volume
if [ -z $scf_snap_on_online_volume ]
then

###### BEGGINNING until scf_snap_find_try
until [[ ! -z "$scf_snap_on_online_volume" || $ndmp_tcount -le "$snap_find_try" ]]
do
 let snap_find_try+=1
 scf_snap_on_online_volume=$(ssh $online_filer snap list -b $volume_name | grep SNAPCREATOR | head -1 | awk '{print $1}')
done
###### END until scf_snap_find_try

fi
###### END if scf_snap_on_online_volume

### clear the variable snap_find_try
unset snap_find_try

### mount the volume to the created directory

### LOGGING & VERBOSE
log_verbose_it "### mounting the volume"

###### GETTING LIST of NDMPIED files
mount $volume_ip:/vol/$volume_name/.snapshot/$scf_snap_on_online_volume /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3)
get_exit_status 0 "WARNING: couldn't mount $volume_name $scf_snap_on_online_volume"

unset scf_snap_on_online_volume

ndmpied_files=$(find /mnt/online_volumes/$config_name/$orts/`echo $onlinefiler_relation | cut -d / -f 3` -type f -exec ls -1 {} \; | rev | cut -d / -f 1 | rev)
echo "List of files copied:" >> $ndmplogfile_path
echo "$ndmpied_files" >> $ndmplogfile_path

umount -l /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3)
get_exit_status 0 "WARNING: couldn't unmount /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3)"

###### END GETTING LIST of NDMPIED files

      mount $volume_ip:/$(echo $onlinefiler_relation | cut -d / -f 2,3) /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3) >> $logfile 2>&1
get_exit_status 0 error_log "ERROR: couldn't mount $onlinefiler_relation"

###### BEGGINNING case extension
### find what extension archlogs are using based on application
case $config_name in
*ORA*) extension=arc
       maxdepth=5
       ;;
*SAP*) extension=dbf
       maxdepth=2
       ;;
*HANA*) extension="[[:digit:]]"
        maxdepth=5
       ;;
esac
###### END case extension

###### BEGGINNING if deleting files
if [ ! -z "$(echo "$ndmpied_files" | grep -v cntrl)" ]
then
 log_verbose_it "### deleting files from path:"

###### BEGGINNING loop ndmpied_file_to_delete
 for ndmpied_file_to_delete in $(echo "$ndmpied_files" | grep $extension | grep -v cntrl)
 do
  $echoLog "/mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3)/$ndmpied_file_to_delete"

  if [[ $extension == "dbf" || $extension == "[[:digit:]]" ]]
  then
   find /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3) -maxdepth 2 -name $ndmpied_file_to_delete -print -exec rm -f {} \; 2>/dev/null >> $logfile 2>&1
  fi
  if [ $extension == "arc" ]
  then
   find /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation | cut -d / -f 3) -maxdepth 5 -name $ndmpied_file_to_delete -print -exec rm -f {} \; 2>/dev/null >> $logfile 2>&1
  fi

 done
###### END loop ndmpied_file_to_delete
echo >> $logfile
$echoLog

fi
###### END if deleting files

  mpoint=$(mount | grep -w $(echo $onlinefiler_relation | cut -d / -f 3) | awk '{print $3}')
### LOGGING & VERBOSE
  log_verbose_it "### unmounting the volume"

### unmount the volume
  umount -l $mpoint 2>&1 > /dev/null
get_exit_status 0 "WARNING: couldn't unmount $mpoint"

### LOGGING & VERBOSE
  log_verbose_it "### removing empty mountpoint /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation| cut -d / -f 3,4)"
  log_verbose_it "######## Archivelog management on volume $(echo $onlinefiler_relation | cut -d / -f 3) is finished"

### check if mountpoint is empty, then delete it
  find /mnt/online_volumes/$config_name/$orts/$(echo $onlinefiler_relation| cut -d / -f 3) -type d -empty -delete 

unset ndmpied_files

### update started instances (deleted already finished from variable)
    started_instances=$(echo "$started_instances" | tr ' ' '\n' | sed "s/^${single_running_instance}$//; /^$/d")

fi
###### END if V

   else

### LOGGING & VERBOSE
log_verbose_it "############## waiting for ndmpcopy to finish ##############"

### show running ndmp jobs 
if [ ! -z "$ndmpjobs_pid" ]
then
log_verbose_it nodatestamp "$(ps -ef | egrep -w "$ndmpjobs_pid" | grep -v grep)"
fi
 sleep 45

   fi
###### END if C

  done 
###### END for loop single_running_instance

 done
###### END until loop started_instances


####################################################################################################################


####################################################################################################################
# section to create snapshot on nearstores and run archivelog management on nearstores DR volumes
####################################################################################################################


###### BEGGINING of do not proceed nearstores
### sleep until all ndmp transfers and SnapCreator operations are finished on online volumes
until [[ -z $(pgrep -f $orts ) ]]
do

 sleep 5

done
###### END of do not proceed nearstores

###### BEGGINING take care of nearstore
###### BEGGINING case nearstore_snapshot
  case $nearstore_snapshot in 
  yes|YES)

### LOGGING & VERBOSE
log_verbose_it "### starting nearstore snapshot creation and archivelogs management on nearstore DR"

###### BEGGINNING loop nearstore_relation
### arrange volumes and filers for SC snapshot job on nearstores
for nearstore_relation in $(echo "$nearstore_relation_to_be_proceeded" | tr ' ' '\n')
do

### find nearstore filer hostname and volumes names
 nearstore_filer_vol+=$(echo $nearstore_relation | cut -d : -f 1):$(echo $nearstore_relation | cut -d / -f 3)";"

done
###### END loop nearstore_relation

### arrange the list in order that SnapCreator understand - delete last ";"
   nearstore_filer_vol=$(echo $nearstore_filer_vol | sed 's/.$//')


### create SnapCreator job config for current snapshot retention on nearstore
### LOGGING & VERBOSE
log_verbose_it "### creating SnapCreator temporary configuration for operation on nearstore volumes"

   cp $scf_config_path/manage_archivelogs.conf $scf_config_path/manage_archivelogs_nearstore_mgmt_${config_name}_$orts.conf
get_exit_status 0 "WARNING: couldn't create $scf_config_path/manage_archivelogs.conf $scf_config_path/manage_archivelogs_nearstore_mgmt_${config_name}_$orts.conf"

### make our retention policy valid in new SnapCreator job file
   sed -i "s/NTAP_SNAPSHOT_RETENTIONS=.*/NTAP_SNAPSHOT_RETENTIONS=/; s/NTAP_SNAPSHOT_POLICIES=.*/NTAP_SNAPSHOT_POLICIES=$sc_policy/g" $scf_config_path/manage_archivelogs_nearstore_mgmt_${config_name}_$orts.conf

###### BEGGINNING archlog extension
### find what extension archlogs are using based on application
case $config_name in
*ORA*) ARCHIVE_LOG_EXT=arc
       ;;
*SAP*) ARCHIVE_LOG_EXT=dbf
       ;;
*HANA*) ARCHIVE_LOG_EXT="*"
       ;;
esac
###### END archlog extension

### create snapshot copy on nearstore volumes and manage the archivelogs
/usr/local/bin/snapcreator --server localhost --port $sc_port --user $sc_user --passwd $sc_user_pwd --action backup --profile ARCH_LOGS --config manage_archivelogs_nearstore_mgmt_${config_name}_$orts --params ARCHIVE_LOG_ENABLE=N NTAP_SNAPSHOT_DISABLE=N VOLUMES=$nearstore_filer_vol --policy $sc_policy --verbose | grep -i "NetApp Snap Creator Framework finished successfully" || log_verbose_it error_log "ERROR: nearstore operation failed $config_name logfile is $(echo "$logfile" | rev | cut -d / -f 1 | rev)" && del_nst_logs=N &

### LOGGING & VERBOSE
log_verbose_it "### running SnapCreator job on nearstores"
sleep 3
log_verbose_it nodatestamp "$(ps -ef | grep "manage_archivelogs_nearstore_mgmt_${config_name}_$orts" | grep -v grep)"

###### BEGGINING of sleep till end of SnapCreator operations nearstore on volumes
until [[ -z $(pgrep -f $orts) ]]
do
 sleep 5
done
###### END of sleep till end of SnapCreator operations nearstore on volumes

###### BEGGINING for loop nearstore_relation_retention_job
### loop for every relation nearstore_relation_retention_job in nearstore_relation_to_be_proceeded variable
   for nearstore_relation_retention_job in $(echo "$nearstore_relation_to_be_proceeded" | tr ' ' '\n')
   do

### LOGGING & VERBOSE
log_verbose_it "### proceeding $nearstore_relation_retention_job"

nearstore_path=$(echo $nearstore_relation_retention_job | cut -d : -f 2)

### LOGGING & VERBOSE
log_verbose_it "### it is not mounted"

### create directory naming convention /mnt/<retention>/<volume name>/<qtree name>
### LOGGING & VERBOSE
log_verbose_it "### creating mountpoint"

     mkdir -p /mnt/nearstore_volumes/$config_name/$orts/$(echo $nearstore_relation_retention_job | cut -d / -f 3,4)
get_exit_status 0 "WARNING: couldn't create /mnt/nearstore_volumes/$config_name/$orts/$(echo $nearstore_relation_retention_job | cut -d / -f 3,4)"

#nearstore_core=$(ssh $(echo $nearstore_relation_retention_job | cut -d : -f 1) ifconfig $core_interface | grep inet | awk '{print $2}')
nearstore_core=$(grep $(echo $nearstore_relation_retention_job | cut -d : -f 1) $filer_acc_info | cut -d : -f 3)


### mount nearstore_relation under created directory
### LOGGING & VERBOSE
log_verbose_it "### mounting the volume"

     mount $nearstore_core:$(echo $nearstore_relation_retention_job | cut -d : -f 2) /mnt/nearstore_volumes/$config_name/$orts/$(echo $nearstore_relation_retention_job | cut -d / -f 3,4) >> $logfile 2>&1
get_exit_status 0 "WARNING: couldn't mount $nearstore_relation_retention_job /mnt/nearstore_volumes/$config_name/$orts/$(echo $nearstore_relation_retention_job | cut -d / -f 3,4)"

###### BEGGINNING if R
### check mount success
### if wasn't print it to the log / output
if [ `echo $?` -eq 1 ]
then

 ### LOGGING & VERBOSE
 log_verbose_it "### ERROR: cannot mount $onlinefiler_relation"

fi
###### END if R


###### BEGGINNING if del_nst_logs
### proceed only if nearstore snaps were created successfuly
if [[ -z "$del_nst_logs" && ! -z "$nearstore_snapshot" ]]
then
 log_verbose_it "###### Deleting archivelogs under /mnt/nearstore_volumes/$config_name/$orts older then $nst_archive_log_retention days"
 echo >> $logfile
 $echoLog
 find /mnt/nearstore_volumes/$config_name/$orts -type f -name "*.$ARCHIVE_LOG_EXT" -mtime +$nst_archive_log_retention -print -delete 2>/dev/null >> $logfile 2>&1
 echo >> $logfile
 $echoLog
fi
###### END if del_nst_logs

### unmount volumes, remove mountpoints and configurations
umount_it

   done
###### END for loop nearstore_relation_retention_job
;;
  esac
###### END case nearstore_snapshot

### LOGGING & VERBOSE
echo >> $logfile
$echoLog

###### END take care of nearstore

fi
###### END if B

remove_it
####################################################################################################################

####################################################################################################################
# section to manage ndmpcopy logfiles - rotation, deletion
####################################################################################################################

###### BEGGINING ndmpcopy log management
### run every day at 7am
case $(date +%H) in
07)

### find all bz2 files older then 13 hours and delete them
find $path_to_archlogs_dir/logs -type f -name "*.log*" -mmin +800 -exec rm -f {} &> /dev/null \;
find ${sc_logfile}/ -type f -name "*.log*" -mmin +800 -exec rm -f {} &> /dev/null \;

;;
esac
###### END ndmpcopy log management


####################################################################################################################

### check the current logfile for any errors, warnings, fails
egrep -i 'error|fail|fatal|denied' $logfile 2>&1 >/dev/null
failed_status=$?
egrep -i 'warning|warn' $logfile 2>&1 >/dev/null
warning_status=$?

###### BEGGINNING if P
### based on exit status finish the job
### if not successfull send ticket with logfile name and print founded errors
if [ $failed_status -eq 0 ]
then 

 log_verbose_it error_log "######### JOB FAILED #########"
 egrep -i 'error|fail|fatal|denied' $logfile >> $(echo $logfile | sed 's/out/error/')
 egrep -i 'error|fail|fatal|denied' $logfile

###### BEGGINNING if U
### do not send ticket if option -t is specified
 if [ -z "$noticket" ]
 then

 $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "ARCHIVELOGS job has failed $(echo $logfile | rev | cut -d / -f 1 | rev)"

 fi
###### END if U
 exit 1

elif [ $warning_status -eq 0 ]
then

 log_verbose_it "######### JOB FINISHED WITH WARNINGS #########"
 egrep -i 'warning|warn' $logfile 

###### BEGGINNING if U
### do not send ticket if option -t is specified
 if [ -z "$noticket" ]
 then

 $trapgen -d $monitor_server -c public -i $public_ip -g 6 -v 1.3.6.1.4.1.1824.1.0.0.1 STRING "ARCHIVELOGS job finished with warnings $(echo $logfile | rev | cut -d / -f 1 | rev)"

 fi
###### END if U
 exit

else
 log_verbose_it "######### JOB FINISHED SUCCESSFULLY #########"
fi
###### END if P

exit 0
