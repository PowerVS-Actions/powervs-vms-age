#!/bin/bash

: '
    Copyright (C) 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

function check_dependencies() {

    DEPENDENCIES=(ibmcloud curl sh wget jq)
    check_connectivity
    for i in "${DEPENDENCIES[@]}"
    do
        if ! command -v "$i" &> /dev/null; then
            echo "$i could not be found, exiting!"
            exit
        fi
    done
}

function check_connectivity() {

    if ! curl --output /dev/null --silent --head --fail http://cloud.ibm.com; then
        echo
        echo "ERROR: please, check your internet connection."
        exit 1
    fi
}

function authenticate() {
    
    local APY_KEY="$1"
    
    if [ -z "$APY_KEY" ]; then
        echo "API KEY was not set."
        exit
    fi
    ibmcloud login --no-region --apikey "$APY_KEY"
}

function get_all_crn(){
	rm -f /tmp/crns
	ibmcloud pi service-list --json | jq -r '.[] | "\(.CRN),\(.Name)"' >> /tmp/crns
}

function set_powervs() {

    local CRN="$1"

    if [ -z "$CRN" ]; then
        echo "CRN was not set."
        exit
    fi
    ibmcloud pi st "$CRN" > /dev/null 2>&1
}

function vm_age() {

    rm -f /tmp/vms
	PVS_NAME=$1
	IBMCLOUD_ID=$2
	IBMCLOUD_NAME=$3

    ibmcloud pi ins --json | jq -r '.Payload.pvmInstances[] | "\(.pvmInstanceID),\(.serverName),\(.networks[].ip),\(.status),\(.sysType),\(.creationDate)"' > /tmp/vms

    TODAY=$(date '+%Y%m%d')

    while read -r line; do 
        VM_ID=$(echo "$line" | awk -F ',' '{print $1}')
        VM_NAME=$(echo "$line" | awk -F ',' '{print $2}')
        VM_CREATION_DATE=$(echo "$line" | awk -F ',' '{print $6}')
        
        Y=$(echo "$VM_CREATION_DATE" | awk -F '-' '{print $1}')
        M=$(echo "$VM_CREATION_DATE" | awk -F '-' '{print $2}' | sed 's/^0*//')
        D=$(echo "$VM_CREATION_DATE" | awk -F '-' '{print $3}' | awk -F 'T' '{print $1}' | sed 's/^0*//')
        DIFF=$(python3 -c "from datetime import date as d; print(d.today() - d($Y, $M, $D))" | awk -F ',' '{print $1}')
	#$VM_CREATION_DATE
		
	DIFF=$(echo $DIFF | tr -d "days" | tr -d " ")
		
	if [[ "$DIFF" == "0:00:00" ]]; then
		DIFF="0"
	fi
        echo "$IBMCLOUD_ID,$IBMCLOUD_NAME,$PVS_NAME,$VM_ID,$VM_NAME,$DIFF" >> all_vms_$TODAY.csv
    done < /tmp/vms
}

function get_vms_per_crn(){
	while read -r line; do
        CRN=$(echo "$line" | awk -F ',' '{print $1}')
        NAME=$(echo "$line" | awk -F ',' '{print $2}')
        echo "****************************************"
        echo "$NAME"
		set_powervs "$CRN"
        vm_age "$NAME" "$1" "$2"
	done < /tmp/crns
}

function run (){

	ACCOUNTS=()
	while IFS= read -r line; do
		clean_line=$(echo "$line" | tr -d '\r')
		ACCOUNTS+=("$clean_line")
	done < ./cloud_accounts

	for i in "${ACCOUNTS[@]}"; do
		IBMCLOUD=$(echo "$i" | awk -F "," '{print $1}')
		IBMCLOUD_ID=$(echo "$IBMCLOUD" | awk -F ":" '{print $1}')
		IBMCLOUD_NAME=$(echo "$IBMCLOUD" | awk -F ":" '{print $2}')
		API_KEY=$(echo "$i" | awk -F "," '{print $2}')

		echo "$IBMCLOUD","$IBMCLOUD_ID","$IBMCLOUD_NAME","$API_KEY"

		if [ -z "$API_KEY" ]; then
		    echo
			  echo "ERROR: please, set your IBM Cloud API Key."
			  echo "		 e.g ./vms-age.sh API_KEY"
			  echo
			  exit 1
		else
			  #API_KEY=$1
			  echo
			  check_dependencies
			  check_connectivity
			  authenticate "$API_KEY"
			  get_all_crn
			  get_vms_per_crn "$IBMCLOUD_ID" "$IBMCLOUD_NAME"
		fi
	done
}

run "$@"
