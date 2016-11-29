#!/bin/bash

usage(){
cat << EOF

 script will update/configure deduplication for nearstore volume
 and will set threshold for volume full for archivelog volume
 on online filer to 60%.
 Usage:
 $0 <path configfile>

EOF
}

if [ -z $1 ];then echo -e " Missing configuration file \n $0 <config name or path to config>"; usage; exit 1;fi
if [ ! -f "$1" ]; then echo -e " $1 doesn't exist \n $0 <config name or path to config>"; usage; exit 1;fi

for nstrel in `grep -v "#" $1 | awk '{print $2}'`
do
 nstfil=`echo $nstrel | cut -d : -f 1`
 nstvol=`echo $nstrel | cut -d / -f 3`

 ssh $nstfil sis status | grep -w $nstvol
 if [ $? -eq 1 ]
 then
  echo " proceeding $nstrel"
  ssh $nstfil "sis on /$(echo $nstrel | cut -d / -f 2,3)"
  ssh $nstfil "sis config -s auto -C true -I true /$(echo $nstrel | cut -d / -f 2,3)"
  ssh $nstfil "sis start /$(echo $nstrel | cut -d / -f 2,3)"
 else
  echo " $nstrel already configured"
 fi
 echo " --- "
done

for nstrel in `grep -v "#" $1 | awk '{print $1}'`
do
 onfil=`echo $nstrel | cut -d : -f 1`
 onvol=`echo $nstrel | cut -d / -f 3`

 ssh $onfil "priv set advanced; registry walk options.thresholds"  2>&1 | grep -w $onvol
 if [ $? -eq 1 ]
 then
  echo " proceeding $nstrel"
  ssh $onfil "priv set advanced; registry set options.thresholds.${onvol}.fsFull 60" >/dev/null 2>&1
  ssh $onfil "priv set advanced; registry walk options.thresholds"  2>&1 | grep -w $onvol
 else
  echo " $nstrel already configured"
 fi
 echo "- - -"
done
