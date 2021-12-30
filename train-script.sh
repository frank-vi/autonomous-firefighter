#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $ -f filename -e epochs"
   echo -e "\t-f filename of argos script"
   echo -e "\t-e epochs of training (suggested value 50)"
   exit 1 # Exit script after printing help
}

while getopts "f:e:" opt
do
   case "$opt" in
      f ) filename="$OPTARG" ;;
      e ) epochs="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [ -z "$filename" ] || [ -z "$epochs" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

for i in $(seq "$epochs")
do
  argos3 -c $filename
  a='Simulation'
  b='ended'
  c="${a} ${i} ${b}"
  echo "${c}"
done