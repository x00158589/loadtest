#!/bin/bash

synth_data_file='synthetic.dat'
result_data_file='results.dat'

test_app='loadtest'
get_test_app_pid=$(ps x -u $USER | grep -v 'grep' | grep $test_app | awk '{print $1}')
get_co_counted=$(grep 'Complete' synthetic.dat | wc -l)
get_idle_no=$(mpstat | tail -n 1 | awk '{print $12}')

for i in {1..2}
do
echo "lets do it " $i "time. Bash PID" $BASHPID 
# (cmdpid=$BASHPID; (sleep 10; kill $cmdpid) & exec './'$test_app $i &)
exec './'$test_app $i & cmdpid=$!
sleep 10
echo $(grep 'Complete' synthetic.dat | wc -l) $i $(mpstat | tail -n 1 | awk '{print $12}') >> results.dat

echo "Pid=" $cmdpid
kill $cmdpid

done








# terminate the load test
# kill $test_app_pid


