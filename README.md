**ARCHIVELOG management on SnapCreator Framework**
--------------------------------------------------


**Filer prerequisities:**

-       ndmp access need to be granted
-       ndmpd.tcpwinsize             65536
-       enable sis on nearstore

**Volume prerequisities:**
-       volumes (on online and on nearstore) exported to SnapCreator server storage IP address
*Example:*

    /vol/saptdms_arch       -sec=sys,rw=@wnadm:10.173.73.1,root=@wnadm:10.173.73.1
    vol option <archlog volume> nosnapdir on

**Basic backup configuration:**

There is one basic configuration file in SnapCreator that is always needed and must stay untouch:

    /opt/netapp/snapcreator/scServer/engine/configs/ARCH_LOGS/manage_archivelogs.conf

This file does serve as template to create temporary configurations for SnapCreator backup jobs to particular instance. Its example is under scf_template directory.

**Directory structure  is:**

    $ ls -1 /opt/netapp/snapcreator/scripts/ARCHLOGS/
    bin
    configs
    disabled_configs
    etc
    logs
    logs/check_arch_seq
    scf_template

**Directories and configurations files purposes:**
*bin* - Archivelog management framework scripts

*configs* - configurations files for DBs archivelogs backup

*disabled_configs* - disabled configurations  of DBs archivelogs backup

*etc* - Archivelogs management configurations files

*logs* - instance.s NDMP logs

*logs/check_arch_seq* - sequence check log files

*scf_template* - configuration files templates

**Configurations files:**
*etc/filer_acc_info* - filer access informations

*etc/nst_job.db* - already done nearstores operations per day (do not edit this file)

*etc/listdb* - used by archmonitord daemon - do not edit this file

*etc/root_cron* - used by archmonitord daemon - do not edit this file

*etc/listdb_temp* - used by archmonitord daemon - do not edit this file

*etc/archivelogs_backup.conf* - setup configuration file for Archivelogs management framework

**Example of archivelogs_backup.conf:**

    ### path to ARCHLOGS management directory
    # path_to_archlogs_dir=
    path_to_archlogs_dir=/opt/netapp/snapcreator/scripts/ARCHLOGS
    ### Path to SnapCreator ARCHLOGS profile directory
    # scf_config_path=
    scf_config_path=/opt/netapp/snapcreator/scServer/engine/configs/ARCH_LOGS
    ### path to SnapCreator ARCHLOGS log directory
    # sc_logfile=
    sc_logfile=/opt/netapp/snapcreator/scServer/engine/logs/ARCH_LOGS
    ### SnapCreator Framework install directory
    # sc_dir=
    sc_dir=/opt/netapp/snapcreator/scServer
    ### SnapCreator Agent install directory
    # sca_dir=
    sca_dir=/opt/netapp/snapcreator/scAgent
    ### default interface for ndmp
    # core_interface=
    core_interface=core-1824
    ### monitoring server
    # monitor_server=
    monitor_server=kassandra
    ### server public IP
    #public_ip=
    public_ip=10.254.8.84
    ### filer access info file
    # filer_acc_info=
    filer_acc_info=/opt/netapp/snapcreator/scripts/ARCHLOGS/etc/filer_acc_info
    ### ndmp tries count if ndmp fails (for volume)
    # ndmp_tcount=
    ndmp_tcount=4
    ### path to trapgen executable
    # trapgen=
    trapgen=/opt/netapp/snapcreator/trapgen/trapgen
    ### SnapCreator user
    # sc_user=
    sc_user=backupmanager
    ### SnapCreator user password hash
    # sc_user_pwd=
    sc_user_pwd=34516b4b6947532b434143504269634b7a5038646a673d3d0a
    ### SnapCreator server port
    # sc_port=
    sc_port=8443
    ### SnapCreator server policy to keep the retention days on DR volume
    #### EXAMPLE: To keep the retention for 10 days on DR volume, create the
    ####          variable: sc_policy_10days and assign to it existing SnapCreator
    ####          policy (Archivelog management run the job on DR volume every 6 hours
    ####          so calculate the policy schedule accordingly)
    ####          examples: sc_policy_10days=nst_40_every_6_hours (config file name example 15min_10days_ORA_DMZ)
    ####                    sc_policy_15days=nst_60_every_6_hours (config file name example 30min_15days_ORA_DMZ)
    sc_policy_28days=nst_112_every_6_hours
    sc_policy_42days=nst_168_every_6_hours

file **filer_acc_info:**

is used for filer ndmp access credentials. Syntax is as follows:

    <filer name>:<password for ndmp user>:<base filer IP in SnapCreator vlan>

**example:**

    filer1:E9swX191ChEW7o7Gh:10.172.73.101
    filer2:WJp3eCfumLkMhnbi:10.143.73.102
    filer3:Lh3bwsOmHoJMQ7qK:10.173.43.105

In Path
*/opt/netapp/snapcreator/scripts/ARCHLOGS/configs*
are stored configuration files with relations for ndmp data transfer. There can be used as many relations in one file as is needed.

**Configurations files for DBs archivelogs backup naming convention:**

    <copy pool time>_<retention time>_<Application>

*Example 1:*

**15min_28days_ORA** - ndmp transfer every 15minutes and nearstore retention 28 days for ORACLE DBs

This is always required. If you need to define anything more you can use underscore to separate it from this basic convention

*Example 2:*

**15min_28days_ORA_DMZ** - same as previous but for DMZ

*Example 3:*

**15min_28days_SAP_ignore** - By specifiing _ignore on the end of the config name you will tell the script scheduler to ignore 
this configuration file

**Supported retentions are now 28days and 42 days.**
**Configuration file input:**
-       line above the ndmp relation the instance name has to be specified - separated by space from the comment
- syntax is:

---

 filer_name:vfiler_IP_address_in_SnapCreator_vlan:path_to_qtree         nearstore_name:path_to_qtree

---

     # ASDBT
     filer1:10.173.73.82:/vol/arch_aebt/arch drfiler1:/vol/sv_arch_aebt/arch
     # CMDBT
     filer2:10.173.73.82:/vol/arch_cmdwt/arch drfiler2:/vol/sv_arch_cmdwt/arch
     # VPXDC1
     filer4:10.173.73.80:/vol/arch_vdc1/arch drfiler2:/vol/sv_arch_vdc1/arch
     # VPXDB
     filer2:10.173.73.88:/vol/arch_vdb/arch drfiler1:/vol/sv_arch_vdb/archt

To disable ndmp relation(s) in configuration file just comment the relation (separate it by space from the comment)
*Example:*

    # ASDBT
    # filer1:10.173.73.82:/vol/arch_aebt/arch drfiler1:/vol/sv_arch_aebt/arch

Script scheduler will add this configuration file to the cron. If you need the script to start the job on configuration file on different minute (scheduler counts from 0 minutes so for example 15min_28days_ORA will be added to the cron as */15 * * * *) you can add to the file following commented line (keep space between the comment and CRON_TIMES):

    # CRON_TIMES=

where you can specifiy the minutes you want the script to start the job from

*Example:*

    # CRON_TIMES=5,20,35,50

Cron entry willl look like this then (every 15 minutes starting from 5th minute):

    5,20,35,50 * * * *

It is always better if you need to add new backup relation to add it to the separate configuration file with _ignore first and run the script against this configuration manually to check if everything will pass.

**Archivelog framework initial setup:**
- unpack the ARCHIVELOGS_FRAMEWORK.tgz package
- run initial setup
```
    $  archivelogs_backup.sh -s
```
You can run the script without the option to get the basic help:

    $ archivelogs_backup.sh

    Missing options
    valid options:
    requiered options:
    -c <configuration name>
    optional:
    -n telling the script to take nearstore snapshot and manage archivelogs retention. If specified, must be always specified with -c option.
    -v verbose
    -t no ticket will be generated if error will occure
    -V print version
    -i will not disable the instance from next run if error will occure
    -e <interface to use for ndmp>
    -s initial setup needed for fresh installation (or even if ARCHLOGS directory was moved or renamed)

Script creates 2 log files (besides logfiles from SnapCreator snapshot management jobs):
in path:

*/opt/netapp/snapcreator/scServer/engine/logs/ARCH_LOGS*

named:

    manual_ndmp_<config file name>.out.<date string>.log

if error will occure then besides this logfile another error log will be created:

    manual_ndmp_<config file name>.error.<same date string as out log>.log

NDMP logs (one per day):

    /opt/netapp/snapcreator/scripts/ARCHLOGS/logs

named:

    <instance name>_<config file name>_<date>.log

**Scripts creates following types of traps:**
-       *PRIO 1 ARCHIVELOGS* online snapshot job failed on volume
-          online snapshot failed- Script exited and has disabled the faulty instance in configuration file to avoid it from the next scheduled run
-       PRIO 1 Archivelogs ndmp backup job has failed. Log is `<logfile name>`
-          ndmp transfer failed. Script exited and has disabled the faulty instance in configuration file to avoid it from the next scheduled run
-       ARCHIVELOGS job has failed `<config name>`       

job has failed. For the cause you have to look to

    manual_ndmp_<config file name>.out.<date string>.log
    manual_ndmp_<config file name>.error.<same date string as out log>.log

and try to find the string .ERROR.
-       ARCHIVELOGS job finished with warnings <config name>
-       job didn't failed. Generally backup was susccessfull. Search manual* log files for string .WARNING.

**ARCHIVELOGD - script scheduler daemon**
daemon name: **archmonitord**
-         daemon is checking every 5 minutes for change in config directory (if new config file was added or if some config file was removed - disabled)
-     daemon hasno influence on running jobs, by stopping him jobs will run but new config files will not be added, will not run

Options:

    $ /etc/init.d/archmonitord
    Usage: /etc/init.d/archmonitord {start|stop|status|restart|jobreview}

- Basically if you create new configuration file under
*/opt/netapp/snapcreator/scripts/ARCHLOGS/configs*
daemon will recognize it and will run backup against these config files
- or if you move it to directory to disable the backup for volumes in the config
*/opt/netapp/snapcreator/scripts/ARCHLOGS/disabled_configs*
or rename the file by adding the _ignore to the end of the filename, daemon will recognize it and will not run backup against these config files

 It is always better to restart the daemon:

    $ /etc/init.d/archmonitord restart
    Shutting down archmonitord:
    archmonitord stopped
    Starting archmonitord:
    Checking Status of archmonitord:
    Running

Simple check of instances that are enabled or disabled in active configuration files is:

    $ /etc/init.d/archmonitord jobreview
    
    Enabled instances in 15min_28days_ORA: Currently running since 18:50
    cron entry: [5,20,35,50 * * * * /usr/local/bin/archlogs_management_for_dmz.sh -c 15min_28days_ORA]
    ADODB ASDBP CAMOS CLIXP
    CMDBP CRYPTA ECADDB ENG
    GANDALFDB KOFAX LEA MESDB
    MKS MKSIIP MKSPSDS MKSTOBY
    OLI OSFDB PATINFORM PDCDMDB
    POLLEX PROC PSCP01 PTC_SYMO
    RELEX RMK ROLLOUT SMCP
    SONAR TENG VCDB3 VPXDB2
    VUM1DB VUMDB3 WN1P
    
    Disabled instances in 15min_28days_ORA:
    cron entry: [5,20,35,50 * * * * /usr/local/bin/archlogs_management_for_dmz.sh -c 15min_28days_ORA]
    - - - - - -











