#!/bin/bash

emailBody=""
emailSubject="Something went wrong."

initVariables() {
  to='krishna@gmail.com'
  from='krishna@demo.com'
  contentType='text/html'
  
  partitions="/dev/vda1"
  
  memThreshold=90
  cpuThreshold=90
  diskThreshold=2

  standerdPorts="22\|80\|443\|8009"
}

memMonitoring() {
  totalMem=$(free -m | awk '{ if (NR > 1) print $2 }' | head -1)
  usedMem=$(free -m | awk '{ if (NR > 1) print $3 }' | head -1)
  freeMem=$(free -m | awk '{ if (NR > 1) print $4+$7 }' | head -1)
  percentMemUsed=$(( (usedMem*100)/totalMem ))
  
  if [ $percentMemUsed -gt $memThreshold ]
  then  
    emailBody+="<h4> Memory report: </h4>"
    emailBody+="<table border=1 style=width:50%>"
    emailBody+="<tr> <td width=25%> Total Memory  </td> <td width=25%> $totalMem MB </td> </tr>"
    emailBody+="<tr> <td width=25%> Used Memory   </td> <td width=25%> $usedMem MB </td> </tr>"
    emailBody+="<tr> <td width=25%> Free Memory   </td> <td width=25%> $freeMem MB </td> </tr>"
    emailBody+="<tr> <td width=25%> Used Memory in (%) </td> <td width=25%>  $percentMemUsed % </td> <tr>"
    emailBody+="</table>"
    emailBody+="<br>"
    sortTopResourceConsumeProcesses "mem"
  fi
}

cpuMonitoring() {
  percentCpuUsed=$(top -b -n 1| head -3 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d"." -f1)
  cpuIdeal=$(top -b -n 1| head -3 | grep "Cpu(s)" | awk '{print $8}' | cut -d"." -f1)

  if [ $percentCpuUsed -gt $cpuThreshold ]
  then
    emailBody+="<h4> CPU report: </h4>"
    emailBody+="<table border=1 style=width:50%>"
    emailBody+="<tr> <td width=25%> CPU Used  </td> <td width=25%> $percentCpuUsed % </td> </tr>"
    emailBody+="<tr> <td width=25%> CPU Ideal </td> <td width=25%> $cpuIdeal % </td> </tr>"
    emailBody+="</table>"
    emailBody+="<br>"
    sortTopResourceConsumeProcesses "cpu"
  fi
}

diskMonitoring() {
  partition=$1;
  totalDisk=$(df -m | grep -w "$partition" | awk '{ print $2}')
  usedDisk=$(df -m | grep -w "$partition" | awk '{ print $3}')
  freeDisk=$(((totalDisk - usedDisk)/1000 ))
  mountedOn=$(df -m | grep -w "$partition" | awk '{ print $6}')

  if [ $diskThreshold -gt $freeDisk ]
  then
    emailBody+="<h4> Disk report for $partition: </h4>"
    emailBody+="<table border=1 style=width:50%>"
    emailBody+="<tr> <td width=25%> Partition Name  </td> <td width=25%> $partition  </td> </tr>"
    emailBody+="<tr> <td width=25%> Total Disk  </td> <td width=25%> "$(( $totalDisk/1000 ))" GB </td> </tr>"
    emailBody+="<tr> <td width=25%> Used Disk   </td> <td width=25%> "$(( $usedDisk/1000 ))" GB </td> </tr>"
    emailBody+="<tr> <td width=25%> Free Disk   </td> <td width=25%> $freeDisk  GB </td> </tr>"
    emailBody+="</table>"
    emailBody+="<br>"
    topMemConsumeDirs $mountedOn;
  fi
}

portMonitoring() {
  serverIp=$(hostname -I)
  allPorts=$(nmap -sT -p- $serverIp | awk 'NR>=7')
  usedPorts=$(nmap -sT -p- $serverIp | awk 'NR>=7' | grep -w $standerdPorts)
  diffPorts=$(diff <(echo "$usedPorts") <(echo "$allPorts"))
  openPorts=$(echo "$diffPorts" | sed 's/>//g' | sed 's/<//g' | sed '/\/tcp/!d' | uniq )

  if [ ! -z "$openPorts" ]
  then
    emailBody+="<h4> Port Monitoring </h4>"
    emailBody+="<p> The OpenSpecimen server's below ports are open. Contact system/network administrator to check why these ports are open. </p> \n"
    emailBody+="<table border=1 style=width:50%>"
    emailBody+="<tr> <th width=25% align=left> Port </th>  <th width=25% align=left> Service </th> </tr>"
    emailBody+="$(echo "$openPorts" | awk '{ print "<tr> <td width=25%>" $1 "</td> <td width=25%>" $3 "</td> </tr>" }')"
    emailBody+="</table>"
  fi
}

topMemConsumeDirs() {
  mount=$1
  emailBody+="<h4> Top 5 files by size  </h4>"
  emailBody+="<table border=1 style=width:50%>"
  emailBody+="<tr> <th> Directory </th> <th> Size </th> </tr>"
  emailBody+=$(find $mount -not -path "/proc/*" -type f -printf "%s\t%p\n" | sort -nr | head -5 | awk '{print "<tr> <td width=40%>" $2 "</td> <td width=10%>" (($1/1024)/1024) "MB </td> </tr>" }')
  emailBody+="</table>"
  emailBody+="<br>"
}

sortTopResourceConsumeProcesses() {
  resource=$1;
  emailBody+="<h4> Top 3 $resource consuming processes </h4>"
  emailBody+="<table border=1 style=width:50%>"
  emailBody+="$(ps -eo pid,%mem,%cpu,cmd --sort=-%$resource | head -4 | awk '{ print "<tr>" "<td width=5%>" $1 "</td>" "<td width=5%>" $2 "</td>" "<td width=5%>" $3 "</td>" "<td width=50%>" $4 $5 $6 "</td>" "</tr> \n" }')"
  emailBody+="</table>"
}

sendEmailReport() {
  if [ ! -z "$emailBody" ]
  then
  {
    echo "To: $to"
    echo "From: $from"
    echo "Content-Type: $contentType"
    echo "Subject: $emailSubject"
    echo "<html> <body>"
    echo "Hello Customer,"
    echo -e "$emailBody"
    echo "</body> </html>"
  } | sendmail -v -t
  fi
}

main() {
  initVariables;
  memMonitoring;
  cpuMonitoring;
  for partition in $partitions
  do
    diskMonitoring $partition
  done
  portMonitoring;
  sendEmailReport;
}
main;

