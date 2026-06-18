#!/bin/bash

display_help() {

  echo "Usage: $0 [-p|-h]              "
  echo
  echo "   -p Bicep parameters file path and name              "
  echo "   -h Show this help message and exit                  "
  echo 
  exit 1

}

do_exit()
{
  exit 1
}

if [[ $# -eq 0 ]]; then
  display_help
fi

PARAMETER_FILE=

OPTSTRING="p:h"

while getopts ${OPTSTRING} opt; do
  case "${opt}" in
    p)
      PARAMETER_FILE="${OPTARG}"
      if [ -z "$PARAMETER_FILE" ]; then
        echo 'one or more variables are undefined or empty'
        do_exit
      fi
      ;;
    h)
      display_help
      ;;
    *)
      display_help
      ;;
  esac
done

if [ ! -s "$PARAMETER_FILE" ]
then
   echo "Parameter file $PARAMETER_FILE does not exist, or is empty "
   do_exit
fi

DIRPATH=$(dirname $PARAMETER_FILE)
CLI_PARAMETER_FILE="${DIRPATH}/cli.json"
if [ ! -s "$CLI_PARAMETER_FILE" ]
then
   echo "Parameter file $CLI_PARAMETER_FILE does not exist, or is empty "
   do_exit
fi

SUBSCRIPTION=$(cat $CLI_PARAMETER_FILE | jq -r '.subscription')
if [ -z "$SUBSCRIPTION" ]; then
  echo 'one or more variables are undefined'
  do_exit
fi

LOCATION=$(cat $CLI_PARAMETER_FILE | jq -r '.location')
if [ -z "$LOCATION" ]; then
  echo 'one or more variables are undefined'
  do_exit
fi

NAME=$(cat $CLI_PARAMETER_FILE | jq -r '.deployment_name')
if [ -z "$NAME" ]; then
  echo 'one or more variables are undefined'
  do_exit
fi

TEMPLATE_FILE=$(cat $CLI_PARAMETER_FILE | jq -r '.template_file')
if [ -z "$TEMPLATE_FILE" ]; then
  echo 'one or more variables are undefined'
  do_exit
fi

echo ""
echo "Input Parameters:"
echo ""
echo "PARAMETER_FILE : $PARAMETER_FILE"
echo "SUBSCRIPTION   : $SUBSCRIPTION"
echo "LOCATION       : $LOCATION"
echo "NAME           : $NAME"
echo "TEMPLATE_FILE  : $TEMPLATE_FILE"
echo ""
echo ""

az deployment sub what-if \
    --subscription $SUBSCRIPTION \
    --name $NAME \
    --template-file $TEMPLATE_FILE \
    --location $LOCATION \
    --query properties.outputs.outputBlock.value \
    --parameters "@${PARAMETER_FILE}" \
    --output tsv

echo 
echo

while true; do

  echo -n "Do you want to apply the above changes? (y/n): "

  read -r response
  
  case "$response" in
    [Yy]* )
       echo "You selected Yes."

       az deployment sub create \
           --subscription $SUBSCRIPTION \
           --name $NAME \
           --template-file $TEMPLATE_FILE \
           --location $LOCATION \
           --query properties.outputs.outputBlock.value \
           --parameters "@${PARAMETER_FILE}" \
           --output tsv

       exit 0
       ;;
    [Nn]* )
       echo "You selected No."
       exit 1
       ;;
    * )
       echo "Invalid input. Please enter y, or n."
       exit 2
       ;;
  esac

done

