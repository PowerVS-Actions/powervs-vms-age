#!/bin/bash

: '
    Copyright (C) 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "Bye!"
    exit 0
}

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
    ibmcloud update -f > /dev/null 2>&1
    ibmcloud plugin update --all > /dev/null 2>&1
    ibmcloud login --no-region --apikey "$APY_KEY" > /dev/null 2>&1
}

function get_all_crn(){
    TODAY=$(date '+%Y%m%d')
	rm -f /tmp/crns-"$TODAY"
	ibmcloud pi service-list --json | jq -r '.[] | "\(.CRN),\(.Name)"' >> /tmp/crns-"$TODAY"
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

    TODAY=$(date '+%Y%m%d')
    rm -f /tmp/vms-"$TODAY"
	PVS_NAME=$1
	IBMCLOUD_ID=$2
	IBMCLOUD_NAME=$3
    PVS_ZONE=$4

    ibmcloud pi ins --json | jq -r '.Payload.pvmInstances[] | "\(.pvmInstanceID),\(.serverName),\(.networks[].ip),\(.status),\(.sysType),\(.creationDate),\(.osType),\(.processors),\(.memory),\(.health.status)"' > /tmp/vms-"$TODAY"

    while read -r line; do
        VM_ID=$(echo "$line" | awk -F ',' '{print $1}')
        VM_NAME=$(echo "$line" | awk -F ',' '{print $2}')
        STATUS=$(echo "$line" | awk -F ',' '{print $4}')
	SYSTYPE=$(echo "$line" | awk -F ',' '{print $5}')
	VM_CREATION_DATE=$(echo "$line" | awk -F ',' '{print $6}')
	
        Y=$(echo "$VM_CREATION_DATE" | awk -F '-' '{print $1}')
        M=$(echo "$VM_CREATION_DATE" | awk -F '-' '{print $2}' | sed 's/^0*//')
        D=$(echo "$VM_CREATION_DATE" | awk -F '-' '{print $3}' | awk -F 'T' '{print $1}' | sed 's/^0*//')
        DIFF=$(python3 -c "from datetime import date as d; print(d.today() - d($Y, $M, $D))" | awk -F ',' '{print $1}')

        OS=$(echo "$line" | awk -F ',' '{print $7}')
        PROCESSOR=$(echo "$line" | awk -F ',' '{print $8}')
        MEMORY=$(echo "$line" | awk -F ',' '{print $9}')
	HEALTH=$(echo "$line" | awk -F ',' '{print $10}')

	    DIFF=$(echo "$DIFF" | tr -d "days" | tr -d " ")

	    if [[ "$DIFF" == "0:00:00" ]]; then
		    DIFF="0"
	    fi
        echo "$IBMCLOUD_ID,$IBMCLOUD_NAME,$PVS_NAME,$PVS_ZONE,$VM_ID,$VM_NAME,$DIFF,$OS,$PROCESSOR,$MEMORY,$SYSTYPE,$STATUS,$HEALTH" >> all_vms_"$TODAY".csv
    done < /tmp/vms-"$TODAY"
}

function get_vms_per_crn(){
	while read -r line; do
        CRN=$(echo "$line" | awk -F ',' '{print $1}')
        NAME=$(echo "$line" | awk -F ',' '{print $2}')
        POWERVS_ZONE=$(echo "$line" | awk -F ':' '{print $6}')
		set_powervs "$CRN"
        vm_age "$NAME" "$1" "$2" "$POWERVS_ZONE"
	done < /tmp/crns-"$TODAY"
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
    awk 'NF' ./*.csv
}

run "$@"
