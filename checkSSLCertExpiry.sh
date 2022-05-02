#!/bin/bash

# Auther: Krishna Waidande
# Title: SSL Certificate Expiry Notification
# Scheduling: 23:55 PM every night

certInfo=""
property_file=$1
validation_error=""

ensurePropsFileSpecified() {
    if [ -z "$property_file" ]; then
        echo "Error: Please specify the absolute path of input properties file.";
        echo "Run Script as: $0 app.properties";
        exit 1;
    fi
}

sendValidationErrors() {
    if [ ! -z "$validation_error" ]
    then
    {
        echo -e "Hello Team,"
        echo -e "\nBelow is/are list of errors/missing input values required to run script."
        echo -e "$validation_error"
        echo -e "\n\n Thank you"
        echo -e "\n $team_name AMS Team"
    } | mail -s "$emailSubject" $recipient
        echo -e "$validation_error"
        exit 1;
    fi
}


initAndValidateVariables() {
    
    certDir=$(cat $property_file | grep "^certDir=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$certDir" ]; then
        validation_error+="\nError: Certificate Location is not specified. Specify the value for 'certDir' in $property_file";
    fi

    if [ ! -d "$certDir" ]; then
        validation_error+="\nError: Specified value for 'certDir' is not valid. '$certDir' path does not exists on file system."
    fi

    reportFile=$(cat $property_file | grep "^reportFile=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$reportFile" ]; then
        validation_error+="\nError: SSL Certificate Details Report data file location is not mentioned. Specify the value for 'reportFile' in $property_file";
    fi


    recipient=$(cat $property_file | grep "^recipient=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$recipient" ]; then
        recipient="krishna@gmail.com"
        validation_error+="\nError: Please specify the recipient of email alert. Specify the value for 'recipient' in $property_file";
        validation_error+="\n If not specified mail is sent to $recipient"
    fi

    team_name=$(cat $property_file | grep "^team_name=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$team_name" ]; then
       validation_error+="\nError: Please specify Project names which will be included in mail subject and signature. Specify the value for 'team_name' in $property_file";
    fi

    emailSubject=$(cat $property_file | grep "^emailSubject=" | cut -d'=' -f2);
    if [ -z "$emailSubject" ]; then
        emailSubject="SSL Certificate Expiry Notification"
        validation_error+="\nError: For any custom emailSubject. Specify the value for 'emailSubject' in $property_file";
        validation_error+="\n If not specified, default mail subject is '$emailSubject'"
    fi

    daysThreshold=$(cat $property_file | grep "^daysThreshold=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$daysThreshold" ]; then
        validation_error+="\nError: Please specify no of days(X) before script should send SSL certificate expiry alert. Specify the value for 'daysThreshold' in $property_file";
    fi
    
    day_of_week=$(cat $property_file | grep "^day_of_week=" | cut -d'=' -f2 | sed 's/ //g');

    if [ -z "$day_of_week" ]; then
        day_of_week=5
    fi

    days_interval=$(cat $property_file | grep "^days_interval=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$days_interval" ];then
        day_of_week=1
    fi

    confluence_link=$(cat $property_file | grep "^confluence_link=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$confluence_link" ]; then
        confluence_link="Not Available/Specified"
    fi

    if [[ ! -f $reportFile || ! -s $reportFile ]]
    then
    {   
        validation_error+="The mentioned location '$reportFile' on $(hostname) does not longer exists or moved/renamed or empty or file not provided."
        validation_error+="\nPlease check if correct SSL Certificate Details report file path is mentioned or not into app.properties file."
    } 
    fi


    emailSubject="[$team_name] $emailSubject"
    sendValidationErrors;  

    daysInSecs=$(( $daysThreshold*86400 ))
    certCount=$(ls -1 $certDir/*/*.pem $certDir/*/*.cer | wc -l)

    if [[ $certCount -eq 0 ]]
    then
    {   echo -e "Hello Team,\n"
        echo -e "\nThe location '$certDir' on server $(hostname) does not contain any certificate."
        echo -e "\nPlease check  if certificate files are present under mentioned location."
        echo -e "\n Thank you"
        echo -e "\n $team_name AMS Team"
    } | mail -s "$emailSubject" $recipient
        exit 1;
    fi

    mailHeaderBody="Hello Team,"
    mailHeaderBody+="\n\nBelow mentioned certficate(s) is/are going to expire."
    mailHeaderBody+="\nFollow link for Certificate renewal process : $confluence_link"

    mailNoteBody+="\n\n\nNote : "
    mailNoteBody+="\n1. Negative number for 'No of days to expire certificate' denotes that, certificate has already expired N days ago."
    mailNoteBody+="\n2. If certificate is already renewed on server and still alert is coming then "
    mailNoteBody+="please make sure if you have uploaded new certificate at below location:"
    mailNoteBody+="\nServer \t \t \t :\t $(hostname)\n"
    mailNoteBody+="Certificate location \t :\t $certDir"

    mailSignBody="\n Thank you"
    mailSignBody+="\n $team_name AMS Team"
}

generateReport() {
    cert_count=0
    for server in $(ls -1 "$certDir")
    do
        for cert_path in $(ls -1 $certDir/$server/*.pem $certDir/$server/*.cer 2> /dev/null)
        do
            cert_count=$(($cert_count+1))
            expiry_date=$(openssl x509 -enddate -noout -in $cert_path -checkend $daysInSecs)
            exp_date=$(echo $expiry_date | cut -d"=" -f2)
            curr_date=$(date +%d-%b-%y)
            days_diff=$(( ($(date -d "$exp_date" '+%s') - $(date -d "$curr_date" '+%s')) / 86400))
            certCN=$(openssl x509 -noout -subject -in $cert_path | awk -F '/CN=' '{print $2}' | awk -F '/' '{print $1}')

            reportRow+="\n\t\t\t\t\t<tr>"
            reportRow+="\n\t\t\t\t\t\t<td> $(echo $certCN | xargs ) </td>"
            reportRow+="\n\t\t\t\t\t\t<td> $server </td>"
            reportRow+="\n\t\t\t\t\t\t<td> $(echo $expiry_date | cut -d"=" -f2) </td>"
            reportRow+="\n\t\t\t\t\t\t<td> $days_diff </td>"
        done
    done
    
    reportRow+="\n\t\t\t\t</tbody>"
    reportRow+="\n\t\t\t</table>"
    reportRow+="\n\t\t</div>"
    reportRow+="\n\t</div>"
    reportRow+="\n</body>"
    reportRow+="\n"
    reportRow+="\n<script>"
    reportRow+="\n\tconst getExpiryDate = () => {"
    reportRow+="\n\t\tconst tableElement = document.getElementById('data').children;"
    reportRow+="\n\t\tfor (let i = 0; i < tableElement.length; i++) {"
    reportRow+="\n\t\t\tconst element = tableElement[i];"
    reportRow+="\n\t\t\tvar date = new Date(element.children[2].innerHTML);"
    reportRow+="\n\t\t\tvar today = new Date();"
    reportRow+="\n\t\t\ttoday.setDate(today.getDate() + $daysThreshold);"
    reportRow+="\n\t\t\tif (date < Date.now()) {"
    reportRow+="\n\t\t\t\telement.classList.add('expired');"
    reportRow+="\n\t\t\t} else if (date < today) {"
    reportRow+="\n\t\t\t\telement.classList.add('near-expiry');"
    reportRow+="\n\t\t\t} else {"
    reportRow+="\n\t\t\t\telement.children[2].classList.add('valid');"
    reportRow+="\n\t\t\t} \n\t\t} \n\t}"
    reportRow+="\ngetExpiryDate();"
    reportRow+="\n</script>"
    reportRow+="\n</html>"

    echo -e $reportRow >> $reportFile
}


mailContent() {
    certCN=$(openssl x509 -noout -subject -in $cert_path | awk -F '/CN=' '{print $2}' | awk -F '/' '{print $1}')

    certInfo+="\nServer Name \t \t \t :\t $server \n"
    certInfo+="Expiry Date \t \t \t :\t $(echo $expiry_date | cut -d"=" -f2)"
    certInfo+="\nNo of days to expire certificate \t :\t $days_diff"
    certInfo+="\nCertificate name \t \t :\t $(echo $certCN | xargs )\n"
    
    if [ $days_diff -le 0 ];
    then
        emailSubject="[$team_name] SSL Certificate Already Expired!!"
    fi
}

checkCerts() {
    exp_count=0
	for server in $(ls -1 "$certDir")
	do
	    for cert_path in $(ls -1 $certDir/$server/*.pem $certDir/$server/*.cer 2> /dev/null)
	    do
            #echo "Checking in $server for $cert_path"
            expiry_date=$(openssl x509 -enddate -noout -in $cert_path -checkend $daysInSecs)	
		    rc=$?

	  	    if [[ $rc -eq 1 ]]
		    then
                exp_date=$(echo $expiry_date | cut -d"=" -f2)
                curr_date=$(date +%d-%b-%y)
                days_diff=$(( ($(date -d "$exp_date" '+%s') - $(date -d "$curr_date" '+%s')) / 86400))

                if [ $days_diff -le $daysThreshold ];
                then
                    
                    exp_count=$((exp_count+1))
                    mailContent;
                fi
		    fi
	    done
	done
}

sendMailNotification() {
	if [ ! -z "$certInfo" ]
	then
    {
        echo -e "$mailHeaderBody"
		echo -e "$certInfo"
        echo -e "$mailNoteBody"
        echo -e "$mailSignBody"
	} |  mail -s "$emailSubject" $recipient
    fi
}

sendReport() {
    if [ 1 ];
    then
    {
        echo -e "Hello Team," 
        echo -e "\nPFA details of SSL certificate expiry."
        echo -e "\n\nThanks\n"
        echo -e "$team_name AMS Team" 
    } | mail -s "SSL Certificate Expiry Report" -a $reportFile $recipient
    fi
} 

main() {
    ensurePropsFileSpecified; 
    initAndValidateVariables;
	checkCerts;
	
    day=$(date +%u)
    if [ $(($day%$days_interval)) == 0 ];
    then
      sendMailNotification;
    fi
    
    today=$(date +%u)
    if [ $today -eq $day_of_week ];
    then
        rm $reportFile
        cp /home/easy4q/automation-scripts/cert-expiry/template.html $reportFile
        generateReport
        if [ -z $exp_count ];
        then
            exp_count=0
        fi
        sed -i "s/cert-count/$cert_count/g" $reportFile
        sed -i "s/exp-count/$exp_count/g" $reportFile
        sendReport;
    fi

}

main;
