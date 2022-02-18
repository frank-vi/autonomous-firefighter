#!/bin/bash

eps=()
log_filename=training.txt
argos_filename=environment.argos
lua_filename=controller_firefighter.lua

[ ! -f $log_filename ] && touch $log_filename
cumulative_episodes=$(echo $(tail -1 $log_filename) | awk -F'[^0-9]+' '{ print $1 }')

function change_lua_code {
        local entire_line=$(sed -n '12p'  $lua_filename)
        local v=$(echo "$entire_line" | awk -F'=' '{ print $1 }')
        local new_line="$v= $1"
	sed -i "s/$entire_line/$new_line/g" $lua_filename
}

function log_start_batch { 
	echo -e "$1\t$2 episodes with e=$3 in running" >> $log_filename 
}

function log_end_batch {
	sed -i "s/running/done/g" $log_filename
}

read -p "Number of experiment: " experiment_excel_row
[ -z "$experiment_excel_row" ] && echo "Number of experiment is mandatory" && exit;

read -a episodes -p "Enter the episodes for batches: " 
[ -z "$episodes" ] && echo "At least one batch is mandatory" && exit;

for index in ${!episodes[@]};
do
	batch_number=$((${index} + 1))
	batch_episodes=${episodes[$index]}
	read -p "Enter epsilon for batch ${batch_number}  of ${batch_episodes} episodes: " -r 
	if  [ -z "$REPLY" ];
	then
		echo "No input detected";
		break;
	fi
	eps+=($REPLY)
done

for i in ${!episodes[@]};
do
	batch_epsilon=${eps[$i]}
	batch_episodes=${episodes[$i]}
	cumulative_episodes=$(($cumulative_episodes + $batch_episodes))
	
	change_lua_code $batch_epsilon
	log_start_batch $cumulative_episodes $batch_episodes $batch_epsilon
	./train-script.sh -f $argos_filename -e $batch_episodes
	log_end_batch
done
