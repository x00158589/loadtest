#!/bin/bash
# Student: Mindaugas Michalauskas
# XID: x00158589
#
vm_cpu=1		# condition: no of CPUs VM runs on
conc_users=$1		# argument N passed from command line. N - concurrent users. Test will run for i in {1..N)
t_seconds=10		# the total time each iterration runs with N users
par_coll='idle'		# mpstat -o JSON report column name
start_date=$(date +%F)	# test start date
start_time=$(date +%T)	# test start time
test_app='loadtest'	# application which stresses CPU with N concurent users
synth_data_file='synthetic.dat'	# Synthetic data file loadtest generates
result_data_file='results.dat'
alltimesdata='allresults.dat' # gathering all the data from all runs of the loadtest, just without header "Co N Idle" for easier processing on tableau
error_msg="ERROR:" 
ok_msg="OK:"

# It makes sence to put extra column in the report, because sometimes when testing time is too short (1 sec)
# the results can be misleading. This modification would alow to proccess the test several times using different
# loadtest running time and collect more data (copying it to one file at the end to get the average value. 
# By default time=10sec, unles specified otherwise.
if [ -n $2 ] && [[ $2 -gt 0 ]]; then t_seconds=$2; fi

# checking if argument with value of N>0 is keyed in (test will run up to N concurent users)
if [ -z "$conc_users" ]; then echo $error_msg "Usage: $0 n t, n - number of concurent users > 0."; echo "t - time in seconds (optional), default t=10 sec. Exit..."; exit 9; fi

if [[ $conc_users -le 0 ]]; then echo $error_msg "N - number of concurent users has to be > 0. Exit..."; exit 9; fi

#checking if VM has no of CPU according to the given conditions. If No - exit
cpu=$(grep "processor" /proc/cpuinfo | wc -l)
if [ $cpu -gt $vm_cpu ]; then echo $error_msg "No of CPUs=$cpu > that" $vm_cpu
			 echo "According to the CA task, VM has to have $vm_cpu CPU";  exit 9
   else echo $ok_msg "VM has $cpu CPU(s)." "Test for N="$conc_users "cycles. From 1 to" $conc_users "concurent users"
fi

echo "Start:" $start_date $start_time". Time T=" $t_seconds "seconds for each cycle."

# starting to write into the results.dat file.  
echo "Co N Idle T" > $result_data_file

#Cycle tests the CPU with up N concurent users.
for ((i=1 ; i <= conc_users; i++))
do
	# starting the loadtest app in the background and taking its process number
	# or ps -ao pid,comm | grep "loadtest" | awk '{print $1}' would give the pid for command kill.
	exec './'$test_app $i & cmdpid=$!

	# putting some information on the screen to see the progress
	printf $test_app 
	printf " N=%3d" $i 
	printf " started Pid=%6s ..." $cmdpid
	
	# each time json_string assigned in each cycle - the new mpstat data collected
	json_string=$(mpstat $t_seconds 1 -o JSON | grep '\"cpu\"')	# filtering only the string needed for data
	idleCPU=$(echo $json_string | jq -r '."'"$par_coll"'"')

	# if NOT using JSON format can do this way:
	# idleCPU=$(mpstat | tail -n 1 | awk '{print $12}') where 12 is a column number in mpstat

	# Telling to shell not to send us a Termination message as we "do not own" the process
	disown $cmdpid
	kill -9 $cmdpid	  # killing the loadtest process - analog of Ctrl+C on console
	printf "%7s Terminated\n" $cmdpid	# informig about that on the screen

	# Calculating how many times the N concurent users were completely served
	get_co_counted=$(grep 'Complete' $synth_data_file | wc -l)

	# if counting particular CPU utilization can use:
	#	utilCPU=$(echo $json_string | jq -r '.usr')
	#	utilCPU=$(echo "scale=2; $utilCPU + $(echo $json_string | jq -r '.sys')" | bc)
	#	utilCPU=$(echo "scale=2; $utilCPU + $(echo $json_string | jq -r '.irq')" | bc)
	#	utilCPU=$(echo "scale=2; $utilCPU + $(echo $json_string | jq -r '.soft')" | bc)

	#writing collected data to the results.dat file
	#printf "%3d" $get_co_counted >> $result_data_file
	#printf " %3d" $i >> $result_data_file
	#printf " %6.2f\n" $idleCPU >> $result_data_file
	# This output formating (shown above) is nice to look at, but not good for the tableau to import. 
	# It has to be separated by space or semicolon
	
	# simply leaving separation by space
	echo $get_co_counted $i $idleCPU $t_seconds >> $result_data_file

done
start_date=$(date +%F)
start_time=$(date +%T)
echo "Finished:" $start_date $start_time
# echo "Finished:" $start_date $start_time >> $result_data_file
# copying the context of results.dat file to allresults.dat file without a header.
tail -$conc_users $result_data_file >> $alltimesdata
