#!/bin/bash
# Author: Yeamin Rajeev
# Purpose: Fetch Resources data from AWS Accounts

ad_login_input()
{
  # AD credential
  echo ""
  echo "Your AD useranme:"
  read AD_NAME

  echo ""
  echo "Your AD password:"
  read -s AD_PASSWORD
}

get_creds_from_sentry()
{
  echo ""
  echo ">>>>>> Calling Sentry to get temporary access key, please wait ..."
  SAML=`curl -s -k -d "username=${AD_NAME}&password=${AD_PASSWORD}" https://prod.sentry.local/api/login | jq -r .SAMLResponse` 
	
#  sleep 2  
#  echo "SAML: " $SAML 
#  echo ""


# Backup current aws credentials
  TIMESTAMP=`date +%Y%m%d%H%M`
  #if [ -f ~/.aws/config ]; then cp ~/.aws/config ~/.aws/config.bak.$TIMESTAMP; fi
  if [ -f ~/.aws/credentials ]; then cp ~/.aws/credentials ~/.aws/credentials.bak.$TIMESTAMP; rm ~/.aws/credentials ; fi

  echo "getting credentials for all accounts from sentry ........ "

  while read acc_id iam_role
  do 
	CRED=`curl -s -k -H Content-Type:application/json -d "{\"samlResponse\" : \"$SAML\", \"aws_account\" : \"$acc_id\", \"aws_role\" : \"$iam_role\"}" https://prod.sentry.news.newslimited.local/api/getkey | jq -r .Credentials`
  	#echo "CRED: " $CRED

	#sleep 1
  	CRED_ACCESS_KEY=`echo $CRED | jq -r .AccessKeyId`
	#echo "CRED_ACCESS_KEY:   " $CRED_ACCESS_KEY
  	CRED_SECRET=`echo $CRED | jq -r .SecretAccessKey`
  	#echo "CRED_SECRET:   " $CRED_SECRET
  	CRED_TOKEN=`echo $CRED | jq -r .SessionToken`
  	#echo "CRED_TOKEN:    " $CRED_TOKEN

  	if [ -z $CRED_ACCESS_KEY ]; then echo "ERROR, pleaes check your sentry login."; echo ""; exit 1; fi

  	#sleep 1

	# Set up aws config
  	##cat ./file/aws_config > ~/.aws/config

  	echo "["$acc_id"]" >> ~/.aws/credentials
  	echo aws_access_key_id = ${CRED_ACCESS_KEY} >> ~/.aws/credentials
  	echo aws_secret_access_key = ${CRED_SECRET}  >> ~/.aws/credentials
  	echo aws_session_token = ${CRED_TOKEN}  >> ~/.aws/credentials
	echo "" >> ~/.aws/credentials
  	#sleep 1
  done < aws_accounts.txt

  i=0
  while read acc_id iam_role
  do
	(( i++ ))
	echo "Searching in account "$i" out of 35 ....." $acc_id $iam_role
        get_aws_resource "$acc_id" "$1" "$2"
  done < aws_accounts.txt

}

get_aws_resource()
{
  #aws ec2 describe-vpcs | grep CidrBlock
  #aws ec2 describe-vpcs | jq -r '.Vpcs[] | "CidrBlocK: \(.CidrBlock)"'

  if [ $3 -eq 1 ]; then
	var=$(aws s3api list-buckets --profile $1 | grep $2)
  	#echo "var is : " $var
  	if [ -n "$var" ]; then 
    		echo "FOUND IT YEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE !!!!!!!!!!!!"
    		exit 0
  	fi
  elif [ $3 -eq 2 ]; then   
  	hosted_zones=$(aws route53 list-hosted-zones --profile $1 | jq .HostedZones[].Id | awk -F\" '{print $2}' | awk -F/ '{print $3}')
	#echo "hosted zzzzones: " $hosted_zones
	for hz in $hosted_zones; do
		echo "searching Hosted Zone: " $hz
		var=$(aws route53 list-resource-record-sets --hosted-zone-id $hz --profile $1 | grep $2)	
		#echo "var is : " $var
		if [ -n "$var" ]; then
			echo "FOUND IT YEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE !!!!!!!!!!"
			#exit 0
		fi
	done
  elif [ $3 -eq 3 ]; then
	users="$(aws iam list-users --profile $1 | jq -r .Users[].UserName)"
	echo "users: " $users

	for search_user in $users
	do
	# comm="aws iam list-access-keys --user-name "$search_user" --profile NAPI-V3-PROD-ADMIN --region ap-southeast-2 | jq -r .Users[].UserId"
	# echo $comm
	# eval $comm

	# aws iam list-access-keys --user-name $search_user --profile NAPI-V3-PROD-ADMIN --region ap-southeast-2
	# access_keys="$(eval $comm | jq -r .Users[].UserId)"
	# access_keys="$(eval $comm)"

  	  access_keys="$(aws iam list-access-keys --user-name $search_user --profile $1 | jq -r .AccessKeyMetadata[].AccessKeyId)"
  	  echo "access keys: " $access_keys 

  	  for search_key in $access_keys
  	  do 
    		if [ $search_key == $2 ]; then 
      		  echo "YEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE found it !!!!.... in " $1
		  exit 0
    		fi
  	  done
 	done
  fi

}  


#Main

ad_login_input
echo "What do you want to do? "
echo "1. Find an S3 bucket (enter 1)"
echo "2. Find a Route53 entry (enter 2)"
echo "3. Find an Access Key (enter 3)"
read choice

if [ $choice -eq 1 ]; then
	echo "Bucket name you're looking for: "
	read bucket_name
	get_creds_from_sentry "$bucket_name" "$choice"
elif [ $choice -eq 2 ]; then
	echo "Domain name you're looking for: "
	read domain_name
	get_creds_from_sentry "$domain_name" "$choice"
elif [ $choice -eq 3 ]; then
	echo "Access_Key you're looking for: "
	read access_key
	get_creds_from_sentry "$access_key" "$choice"
fi

