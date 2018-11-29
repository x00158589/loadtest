#!/bin/bash
# Student: Mindaugas Michalauskas
# XID: x00158589
#
conc_users=$1
t_seconds=5
start_date=$(date +%F)
start_time=$(date +%T)
error_msg="ERROR:" 
ok_msg="OK:"
vm_cpu=1
synth_data_file='synthetic.dat'
result_data_file='results.dat'
test_app='loadtest'

if [ -z "$conc_users" ]; then echo "Usage: $0 n, n - number of concurent users. Exit..."; exit 9; fi

cpu=$(grep "processor" /proc/cpuinfo | wc -l)
if [ $cpu -gt $vm_cpu ]; then echo $error_msg "No of CPUs > that" $vm_cpu; echo "According to the CA task VM has to have $vm_cpu CPU";  exit 9
   else echo $ok_msg "VM has $cpu CPUs"
fi

echo "Start:" $start_date $start_time
echo "Start:" $start_date $start_time > $result_data_file

# header of the result.dat file
printf "%4s" "CO" >> $result_data_file
printf "%3s" "N" >> $result_data_file
printf "%7s\n" "usr" >> $result_data_file

for ((i=1 ; i <= conc_users; i++))
do
	#echo "lets do it " $i "time" 
	# (cmdpid=$BASHPID; (sleep 10; kill $cmdpid) & exec './'$test_app $i &)
	exec './'$test_app $i & cmdpid=$!
	printf $test_app 
	printf " N=%3d" $i 
	printf " started Pid=%7s ..." $cmdpid
	sleep $t_seconds

	get_co_counted=$(grep 'Complete' $synth_data_file | wc -l)
	get_idle=$(mpstat | tail -n 1 | awk '{print $3}')

	printf "%3d" $get_co_counted >> $result_data_file
	printf " %3d" $i >> $result_data_file
	printf " %6.2f\n" $get_idle >> $result_data_file

	# Telling to shell not to send us a Termination message as we "do not own" the process
	disown $cmdpid
	kill -9 $cmdpid
	printf "%7s Terminated\n" $cmdpid
done
start_date=$(date +%F)
start_time=$(date +%T)
echo "Finished:" $start_date $start_time
echo "Finished:" $start_date $start_time >> $result_data_file
