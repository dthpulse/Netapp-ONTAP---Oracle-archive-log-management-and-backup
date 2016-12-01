# Netapp 7-Mode Oracle archive log management and backup

This framework was tested on high load with 200 Oracle instances. It is highly scalable, with high frequence copy pool times.
You need to install SnapCreator framework first and this is just its extension. You can manage to backup Archivelogs to DR site every few minutes depends on your environment.

### ARCHIVELOG management on SnapCreator Framework
#### Filer prerequisities:
-       VLAN for DMZ: 1824
-       VLAN for intranet: 1818
-       VLAN for SGP DMZ: 643
-       ndmp access need to be granted
-       ndmpd.tcpwinsize             65536
- enable sis on nearstore + on polly
