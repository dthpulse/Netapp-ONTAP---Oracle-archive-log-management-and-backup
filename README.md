# Netapp 7-Mode Oracle archive log management and backup

This framework was tested on high load with 200 Oracle instances. It is highly scalable, with high frequence copy pool times.
You need to install SnapCreator framework first and this is just its extension. You can manage to backup Archivelogs to DR site every few minutes depends on your environment.

### ARCHIVELOG management on SnapCreator Framework
#### Filer prerequisities:
-       ndmp access need to be granted
-       ndmpd.tcpwinsize             65536
- enable sis on nearstores

#### Volume prerequisities:
-       volumes (on online and on nearstore) exported to SnapCreator server storage IP address
##### Example:
```
/vol/saptdms_arch       -sec=sys,rw=@wnadm:10.173.73.1,root=@wnadm:10.173.73.1
-       vol option \<archlog volume> nosnapdir on
```
