#!/bin/bash

# Auther: Krishna Waidande
# Title: Database User Password Expiry Notification
# Scheduling: 23:50 PM every night

property_file=$1
validation_error=""

ensurePropsFileSpecified() {
    if [ -z "$property_file" ]; then
        echo "Error: Please specify the absolute path of input properties file.";
        echo "Run Script as: $0 app.properties";
        exit 1;
    fi
}

validateOracleDetails() {
    if [[ ! -f $inputFile || ! -s $inputFile ]]
    then
    {   echo -e "Hello Team,\n"
        echo -e "The mentioned location '$inputFile' on $(hostname) does not longer exists or moved/renamed or empty or file not provided."
        echo -e "\nPlease check if correct database details input file path is mentioned or not into app.properties file."
        echo -e "\n\n Thank you"
        echo -e "\n $team_name AMS Team"
    } | mail -s "$emailSubject" $recipient
        exit 1;
    fi

    if [[ ! -f $reportFile || ! -s $reportFile ]]
    then
    {   echo -e "Hello Team,\n"
        echo -e "The mentioned location '$reportFile' on $(hostname) does not longer exists or moved/renamed or empty or file not provided."
        echo -e "\nPlease check if correct database user details report file path is mentioned or not into app.properties file."
        echo -e "\n\n Thank you"
        echo -e "\n $team_name AMS Team"
    } | mail -s "$emailSubject" $recipient
        exit 1;
    fi

    #Removing blank rows from input file.
    sed -i '/^$/d' $inputFile

}

sendValidationErrors() {
    if [ ! -z "$validation_error" ]
    then
    {
        echo -e "Hello Team,"
        echo -e "\n Below is/are list of errors/missing input values required to run script."
        echo -e "$validation_error"
        echo -e "\n\n Thank you"
        echo -e "\n $team_name AMS Team"
    } | mail -s "$emailSubject" $recipient
        echo -e "$validation_error"
        exit 1;
    fi
}

initAndValidateVariables() {
    
    inputFile=$(cat $property_file | grep "^oraUsrDetails=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$inputFile" ]; then
        validation_error+="\nError: Database User Details input script location is not specified. Specify the value for 'oraUsrDetails' in $property_file";
    fi  

    reportFile=$(cat $property_file | grep "^reportFile=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$reportFile" ]; then
        validation_error+="\nError: Database User Details Report data file location is not mentioned. Specify the value for 'reportFile' in $property_file";
    fi  

    recipient=$(cat $property_file | grep "^recipients=" | cut -d'=' -f2 | sed 's/ //g');
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
        emailSubject="Database User Password Expiry"
        validation_error+="\nError: For any custom emailSubject. Specify the value for 'emailSubject' in $property_file";
        validation_error+="\n If not specified, default mail subject is '$emailSubject'"
    fi

    days_threshold=$(cat $property_file | grep "^days_threshold=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$days_threshold" ]; then
        validation_error+="\nError: Please specify no of days(X) before script should send Database user password expiry alert. Specify the value for 'days_threshold' in $property_file";
    fi

    day_of_week=$(cat $property_file | grep "^day_of_week=" | cut -d'=' -f2 | sed 's/ //g');
    if [ -z "$day_of_week" ];then
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
    
    emailSubject="[$team_name] $emailSubject"
    sendValidationErrors;    
    validateOracleDetails;

    mailHeaderBody="Hello Team,"
    mailHeaderBody+="\n\nBelow mentioned database user(s) password is/are going to expire."
    mailHeaderBody+=" \nFor Oracle password renewal please refer to below confluence page link.\n"
    mailHeaderBody+="Link : $confluence_link"
    
    mailNoteBody+="\nNotes :" 
    mailNoteBody+="\n1. Negative number for 'No of days to expire password' denotes that, password has already expired N days ago."
    mailNoteBody+="\n2. If password is already renewed on database and still alert is coming then please make sure if you have updated the new expiry date at below location.\n"
    mailNoteBody+="\nServer \t \t : \t $(hostname)\n"
    mailNoteBody+="File location \t : \t $inputFile"
    
    mailSignBody="\n Thank you"
    mailSignBody+="\n $team_name AMS Team" 
}

mailContent(){
    mailBody+="\n\nDatabase type \t \t \t : \t $database_type"
    mailBody+="\nApp Name \t \t \t :\t $app_name"
    mailBody+="\nNo of days to expire password \t :\t $days_diff"
    mailBody+="\nDB User \t \t \t :\t $user"
    mailBody+="\nExpiry Date \t \t \t :\t $expiry_date"
    mailBody+="\nHost \t \t \t \t :\t $hostname"

    if [ "$database_type" == "Oracle" ];
    then
        mailBody+="\nService Name \t \t \t :\t $service_name"
    else
        mailBody+="\nDatabase Name \t \t :\t $service_name"
    fi
    
    mailBody+="\nEnvironment \t \t \t :\t $environment"
    mailBody+="\nResponsible Person/Team \t : \t $responsible"

}

checkOraUserPwd() {
    while IFS='|' read -r db_type app_name user expiry_date hostname service_name environment responsible;
    do
        database_type=$(echo $db_type | xargs)
        app_name=$(echo $app_name | xargs)
        user=$(echo $user | xargs)
        expiry_date=$(echo $expiry_date | xargs)
        hostname=$(echo $hostname | xargs)
        service_name=$(echo $service_name | xargs)
        environment=$(echo $environment | xargs)
        responsible=$(echo $responsible | xargs)
    
        if [ -z "$responsible" ]; then
            responsible=$recipient
        fi
         
        curr_date=$(date +%d-%b-%y)
        days_diff=$(( ($(date -d "$expiry_date" '+%s') - $(date -d "$curr_date" '+%s')) / 86400))

        if [ $days_diff -lt $days_threshold ];
        then
            mailBody=""
            mailContent;
            exp_usr_count=$(($exp_usr_count+1)) 
          
            day=$(date +%u)
            if [ $(($day%$days_interval)) == 0 ];
            then
                sendNotification $responsible $days_diff
            fi
        fi
    done < $inputFile
}

generateReport() {
    user_count=0
    while IFS='|' read -r db_type app_name user expiry_date hostname service_name environment responsible;
    do
        reportRow+="\n\t\t\t\t\t<tr>"
        reportRow+="\n\t\t\t\t\t\t<td> $db_type  </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $app_name </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $user </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $expiry_date </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $hostname </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $service_name </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $environment </td>"
        reportRow+="\n\t\t\t\t\t\t<td> $responsible </td>"
        reportRow+="\n\t\t\t\t\t</tr>"
        
        user_count=$((user_count+1))
    done < $inputFile

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
    reportRow+="\n\t\t\tvar date = new Date(element.children[3].innerHTML);"
    reportRow+="\n\t\t\tvar today = new Date();"
    reportRow+="\n\t\t\ttoday.setDate(today.getDate() + $days_threshold);"
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

sendNotification() {
    responsiblePerson=$1
    dayDiff=$2 
    
    if [ $days_diff -le 0 ];
    then
        subject="[$team_name] Database User Password Already Expired!!"
    else
        subject=$emailSubject
    fi

    if [ ! -z "$mailBody" ]
    then
    {
        echo -e "$mailHeaderBody"
        echo -e "\nDatabase User(s) Details"
        echo -e "$mailBody"
        echo -e "$mailNoteBody"
        echo -e "$mailSignBody"
    } |  mail -s "$subject" -c "$recipient" $responsiblePerson
    fi
}

sendReport() {
    if [ 1 ];
    then
    {
        echo -e "Hello Team," 
        echo -e "\nPFA details of Database users password expiry."
        echo -e "\n\nThanks\n"
        echo -e "$team_name AMS Team" 
    } | mail -s "Database Expiry Password Report" -a $reportFile $recipient
    fi
} 

main() {
    ensurePropsFileSpecified;
    initAndValidateVariables;
    checkOraUserPwd;
    
    today=$(date +%u)
    if [ $today -eq $day_of_week ];
    then
        rm $reportFile
        cp /home/easy4q/automation-scripts/ora-user-expiry/template.html $reportFile
        generateReport;
        
        if [ -z $exp_usr_count ];
        then
            exp_usr_count=0
        fi
        
        sed -i "s/user-count/$user_count/g" $reportFile
        sed -i "s/exp-count/$exp_usr_count/g" $reportFile
        sendReport;
    fi
}

main;
