#!/bin/ksh

usage()
{
    echo "Usage: $0 STACK NODE" 1>&2
    exit 1
}

node="$2"
stack="$(readlink -f "$1")"
done_scenario="$stack.done/$node"
running_scenario="$stack.running/$node"

if [[ ! -d "$stack" ]] || [[ -z "$node" ]]
then
    usage
fi

cd $(dirname $0)
SCRIPT_PATH=$(pwd)

echo $$

mkdir -p "$done_scenario"
mkdir -p "$running_scenario"

run_in_vm()
{(
    vm_name="$1"
    cmd="$2"

    echo "MACHINE NAME: $vm_name"
    echo "COMMAND: $cmd"
    vm_ip="192.168.56."$(($(echo "$vm_name" | cut -d : -f 3) + 100))
    echo "MACHINE IP: $vm_ip"
    ssh-keyscan -t rsa1,rsa,dsa "$vm_ip" >> ~/.ssh/known_hosts 2>/dev/null
    $SCRIPT_PATH/ssh-pass  ssh "$vm_ip" "$cmd"
)}

poweroff_vm()
{(
    vm_name="$1"

    echo "POWEROFF: [$vm_name]"
    VBoxManage controlvm "$vm_name" poweroff
)}

start_vm_from_snapshot()
{(
    vm_name="$1"

    echo "MACHINE NAME: $vm_name"

    vm_ip="192.168.56."$(($(echo "$vm_name" | cut -d : -f 3) + 100))

    echo "MACHINE IP: $vm_ip"
    
    VBoxManage controlvm "$vm_name" poweroff
    VBoxManage controlvm "$vm_name" poweroff
    VBoxManage snapshot "$vm_name"  restore READY_TO_GO_SNAPSHOT
    VBoxManage startvm --type headless "$vm_name"
    
    while [ 1 ]
    do 
	ssh-keyscan -t rsa1,rsa,dsa "$vm_ip" >> /root/.ssh/known_hosts 2>/dev/null
	$SCRIPT_PATH/ssh-pass ssh "$vm_ip" id | grep root >/dev/null && break
	echo -n "^"
	sleep 1
    done
    
)}

copy_to_vm()
{(

    file="$1"
    vm_name="$2"
    path="$3"

    echo "MACHINE NAME: $vm_name"
    echo "FILE: $file"
    echo "PATH: $path"
    vm_ip="192.168.56."$(($(echo "$vm_name" | cut -d : -f 3) + 100))
    echo "MACHINE IP: $vm_ip"

    ssh-keyscan -t rsa1,rsa,dsa "$vm_ip" >> ~/.ssh/known_hosts 2>/dev/null        
    $SCRIPT_PATH//ssh-pass scp -r "$file" "$vm_ip:$path"
)}

while [[ 1 ]]
do
    scenario_path="$(find "$stack" -type d -name "play()" | head -n 1)"

    if [[ -d "$scenario_path" ]]
    then
	scenario="$(basename "$(dirname "$scenario_path")")"
	scenario_node="$(ls "$scenario_path")"
	echo
	echo "SCENARIO NODE: [$scenario_node]"
	echo
	if [[ "$scenario_node" = "$node" ]]
	then
	    echo "RUN SCENARIO : $scenario [$scenario_path]"
	    
	    echo mv "$stack/$scenario" "$running_scenario/$scenario"
	    mv "$stack/$scenario" "$running_scenario/$scenario"

	    scenario_path="$running_scenario/$scenario/play()"
	    tree $scenario_path

	    (cd "$scenario_path/$node" ; ls ) | while read -r cur_machine_path
	    do
		cur_machine="$(echo "$cur_machine_path" | sed s/"^[0-9]*\."//g)"

		echo "START MACHINE: $cur_machine [$cur_machine_path]"

		tree "$scenario_path/$node/$cur_machine_path"

		start_vm_from_snapshot "$cur_machine"
		
		tmp_scenario_path="/root/$(date "+%s")"
		copy_to_vm "$scenario_path/$node/$cur_machine_path" "$cur_machine" "$tmp_scenario_path"

		cur_scenario_log_path="$scenario_path/$node/$cur_machine_path/log/$(date "+%s")"
		mkdir -p "$cur_scenario_log_path"
		run_in_vm "$cur_machine" "cd $tmp_scenario_path ; chmod +x run ; ./run" > "$cur_scenario_log_path/run_log.txt"
		echo "$?" > "$cur_scenario_log_path/run.exit_code"
		
		poweroff_vm "$cur_machine"

		cat "$cur_scenario_log_path/run_log.txt" | ./ansi2html.sh --bg=dark > "$cur_scenario_log_path/run_log.html"

	    done
	    cur_scenario_done_path="$done_scenario/$(date "+%s")"
	    mkdir -p "$cur_scenario_done_path"
	    mv "$running_scenario/$scenario" "$cur_scenario_done_path/$scenario"
	fi
    fi
    echo -n .
    sleep 2
done
