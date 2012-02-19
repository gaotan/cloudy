#!/bin/ksh

usage()
{
    echo "Usage: $0 STACK" 1>&2
    exit 1
}

stack="$(readlink -f "$1")"
done_scenario="$stack.done"
running_scenario="$stack.running"

if [[ ! -d "$stack" ]]
then
    usage
fi

cd $(dirname $0)
SCRIPT_PATH=$(pwd)

export PATH="$PATH:$SCRIPT_PATH"

mkdir -p "$done_scenario"
mkdir -p "$running_scenario"

while [[ 1 ]]
do
    scenario_path="$(cd "$stack" ; find . -type d -name "play()" | head -n 1)"

    if [[ -n "$scenario_path" ]]
    then
	scenario_path="$(dirname "$scenario_path")"

	echo "RUN SCENARIO : [$scenario_path]"
	mkdir -p "$running_scenario/$scenario_path"
	rmdir "$running_scenario/$scenario_path"
	echo mv "$stack/$scenario_path" "$running_scenario/$scenario_path"
	mv "$stack/$scenario_path" "$running_scenario/$scenario_path"
	
	for i in $(seq 1 $(ls "$running_scenario/$scenario_path/play()" | wc -l))
	do
	    cur_machine_path="$(find "$running_scenario/$scenario_path/play()/$i."* -maxdepth 0 | head -n 1)"
	    echo
	    echo "############################################"
	    echo ">>>> $cur_machine_path"
	    echo "############################################"
	    echo

	    if [[ -d "$cur_machine_path" ]]
	    then
		cur_machine="$(basename "$cur_machine_path" | sed s/"^[0-9]*\."//g)"
		cur_scenario_log_path="$cur_machine_path/play()/"

		mkdir -p "$cur_scenario_log_path"

		if [[ "$cur_machine" = "local" ]]
		then
		    (
			cd "$cur_machine_path/play()"
			chmod +x run 
			./run 2>&1 > "$cur_scenario_log_path/run.log"
			echo "$?" > "$cur_scenario_log_path/run.exit_code"  
		    )
		    cat "$cur_scenario_log_path/run.log" | ./ansi2html.sh --bg=dark > "$cur_scenario_log_path/run.log.html"

		else
		    tmp_scenario_path="/root/$(date "+%s")"
		    cloudy copy local directory "/cloudy" to machine "$cur_machine" "/"
		    cloudy copy local directory "$cur_machine_path" to machine "$cur_machine" "$tmp_scenario_path"
		    cloudy run command "cd $tmp_scenario_path/play'()' ; chmod +x run ; ./run" in machine "$cur_machine" 2>&1 > "$cur_scenario_log_path/run.log"
		    echo "$?" > "$cur_scenario_log_path/run.exit_code"  
		    cat "$cur_scenario_log_path/run.log" | ./ansi2html.sh --bg=dark > "$cur_scenario_log_path/run.log.html"
		fi
	    fi
	done
	cur_scenario_done_path="$done_scenario/$(date "+%s")/$scenario_path"
	mkdir -p "$(dirname "$cur_scenario_done_path")"
	mv "$running_scenario/$scenario_path" "$cur_scenario_done_path"
    fi
    echo -n .
    sleep 2
done
