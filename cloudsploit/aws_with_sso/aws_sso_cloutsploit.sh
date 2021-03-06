#!/bin/bash

# REQURIES 
# jq
# aws-sso-util
# assumes cloudsploit is in ~/cloudsploit
# requires config_aws.js in ~/cloudsploit

CONFIG_FILE=~/.aws/config
CREDS=~/CREDS
date=$(date '+%Y-%m-%d')
REPORTS=~/REPORTS/$date/
cloudsploit=~/cloudsploit

mkdir $CREDS >/dev/null
mkdir $REPORTS >/dev/null

# read ~/.aws/config and create a list of roles 
declare -A conf
while IFS='=' read -r key value; do
   echo $key>>$CREDS/aws_config_list.txt
done < <(awk '/^\[/ { app=substr($0,10,length-10) } /=/ { print app }' $CONFIG_FILE)

sort $CREDS/aws_config_list.txt | uniq >$CREDS/aws_role_list.txt

# force a new login, if sso auth has expired.
aws-sso-util login

read -p "Press a key and enter to continue"

# generate temp SSO credentials for each profile, set them as environment vars and then run the tool
declare -A conf
while IFS='=' read -r key; do
   echo Processing $key

   export AWS_PROFILE=$key
   echo $AWS_PROFILE
   aws-sso-util credential-process --profile $AWS_PROFILE >$CREDS/CREDS.json
   cat $CREDS/CREDS.json | jq -r 

   export AWS_ACCESS_KEY_ID=$(cat $CREDS/CREDS.json | jq -r .AccessKeyId)
   export AWS_SECRET_ACCESS_KEY=$(cat $CREDS/CREDS.json | jq -r .SecretAccessKey)
   export AWS_SESSION_TOKEN=$(cat $CREDS/CREDS.json | jq -r .SessionToken)

   rm $CREDS/CREDS.json

   cd $cloudsploit

   ./index.js --csv $REPORTS/$AWS_PROFILE.csv --console=none --config=$cloudsploit/config_aws.js
done < $CREDS/aws_role_list.txt

#combine the csv files into one file
rm $REPORTS/cloudsploit_combined.csv -f
awk -v OFS=',' '
    NR == 1 { print "filename", $0 }
    FNR > 1 { print FILENAME, $0 }
' $REPORTS/*.csv >$REPORTS/cloudsploit_combined.csv

