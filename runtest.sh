#!/bin/bash
# Student: Mindaugas Michalauskas
# XID: x00158589
#
vm_cpu=1		#condition: no of CPUs VM runs on
conc_users=$1		#argument N passed from command line. N - concurrent users. Test will run for i in {1..N) 
t_seconds=5		# the total time each iterration runs with N users
par_coll='idle'		#mpstat -o JSON report column name
start_date=$(date +%F)	#test start date
start_time=$(date +%T)	#test start time
test_app='loadtest'	#application which stresses CPU with N concurent users
synth_data_file='synthetic.dat'	#Synthetic data file loadtest generates
result_data_file='results.dat'
error_msg="ERROR:" 
ok_msg="OK:"

# checking if argument with value of N>0 is keyed in (test will run up to N concurent users)
if [ -z "$conc_users" ]; then echo $error_msg "Usage: $0 n, n - number of concurent users > 0. Exit..."; exit 9; fi
if [ $conc_users -le 0 ]; then echo $error_msg "N - number of concurent users has to be > 0. Exit..."; exit 9; fi

#checking if VM has no of CPU according to the given conditions. If No - exit
cpu=$(grep "processor" /proc/cpuinfo | wc -l)
if [ $cpu -gt $vm_cpu ]; then echo $error_msg "No of CPUs > that" $vm_cpu; echo "According to the CA task VM has to have $vm_cpu CPU";  exit 9
   else echo $ok_msg "VM has $cpu CPUs"
fi

#Start of the test written in to the results.dad header. Remove before importing to Tableau or Excel.
echo "Start:" $start_date $start_time", Each N cycle time T=" $t_seconds "seconds."
echo "Start:" $start_date $start_time", VM has" $vm_cpu". Each N cycle time T=" $t_seconds "seconds."> $result_data_file

# header for data of the result.dat file
printf "%4s" "CO" >> $result_data_file
printf "%3s" "N" >> $result_data_file
printf "%7s\n" $par_coll >> $result_data_file

#Cycle tests the CPU with up N concurent users.
for ((i=1 ; i <= conc_users; i++))
do
	# starting the loadtest app in the background and taking its process number
	exec './'$test_app $i & cmdpid=$!

	# putting some information on the screen to see the progress
	printf $test_app 
	printf " N=%3d" $i 
	printf " started Pid=%7s ..." $cmdpid

	sleep $t_seconds    # giving some time for CPU stress. loadtest generates the data: how many were completed
	#Calculating how many times the N concurent users were completely served
	get_co_counted=$(grep 'Complete' $synth_data_file | wc -l)
	
	#if NOT using JSON format can do this way:
	#idleCPU=$(mpstat | tail -n 1 | awk '{print $12}') where 12 is a column number in mpstat

	#each time json_string assigned in each cycle - the new mpstat data collected
	json_string=$(mpstat -o JSON | grep '\"cpu\"')	#filtering only the string needed for data
	idleCPU=$(echo $json_string | jq -r '."'"$par_coll"'"')
	# if counting particular CPU utilization can use:
	#	utilCPU=$(echo $json_string | jq -r '.usr')
	#	utilCPU=$(echo "scale=2; $utilCPU + $(echo $json_string | jq -r '.sys')" | bc)
	#	utilCPU=$(echo "scale=2; $utilCPU + $(echo $json_string | jq -r '.irq')" | bc)
	#	utilCPU=$(echo "scale=2; $utilCPU + $(echo $json_string | jq -r '.soft')" | bc)

	#writing collected data to file
	printf "%3d" $get_co_counted >> $result_data_file
	printf " %3d" $i >> $result_data_file
	printf " %6.2f\n" $idleCPU >> $result_data_file

	# Telling to shell not to send us a Termination message as we "do not own" the process
	disown $cmdpid
	kill -9 $cmdpid	#killing the loadtest app process - analod of Ctrl+C on console
	printf "%7s Terminated\n" $cmdpid	#Showing that on the screen
done
start_date=$(date +%F)
start_time=$(date +%T)
echo "Finished:" $start_date $start_time
echo "Finished:" $start_date $start_time >> $result_data_file
filename=$(echo "${filename%.*}"$conc_users".dat")
cp $result_data_file "$filename"
