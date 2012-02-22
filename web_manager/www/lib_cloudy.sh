
cloudy_task()
{
    task_name="$1"
    shift
    cloudy_tasks_path="/tmp/cloudy/tasks"

    touch "/tmp/wsh/$PPID/forked"

    (
	task_pid="$(env | grep '^_=' | cut -d '*' -f 2)"
	task_path="$cloudy_tasks_path/$task_pid"
	
	rm -f "$task_path/"*
	mkdir -p "$task_path"
	date "+%s" > "$task_path/begin"
	echo "$task_name" > "$task_path/name"
	
	cmd=("$1")          #
	shift               #
	while [ $# -gt 0 ]  # 
	do                  # "${cmd[@]}" is the same thing than "$*"
	    cmd+=("$1")     # But handle 'spaces' in arguments
	    shift           #
	done                #
	("${cmd[@]}") 2>> "$task_path/log" >> "$task_path/log"
	
	echo $? > "$task_path/exit_code"
	date "+%s" > "$task_path/end"
    ) &
}

cloudy_scenario_count()
{
    ls "$1/play()" | wc -l
}

cloudy_scenario_machines()
{
    (
	cd "$1/play()"
	find -maxdepth 1 -type f | grep -q '^\./[0-9]*\.' && echo local
	find -maxdepth 1 -type d | sed 's!^\./!!g' | grep -v '^\.$' | grep '^[0-9]*\.'
    ) | sort -n 
} 

cloudy_scenario_uniq_machines()
{
    cloudy_scenario_machines "$1" | sed s/"^[0-9]*\."//g  | sort | uniq
}

cloudy_reachable_machines()
{
    echo local
    cloudy list registered machines 
}

cloudy_copy_scenario_and_replace_variables()
{
    (
    src_path="$1"
    dst_path="$2"
    tmp_path="/tmp/.cloudy_copy_scenario_and_replace_variables_$$"

    rm -rf "$tmp_path"
    mkdir -p "$dst_path"
    rmdir "$dst_path"
    cp -RL "$src_path" "$tmp_path"
    replace_command="sed"
    wsh_input_list | grep "^var_" | sed "s/^var_//" | while read -r input
    do
        val="$(wsh_input "var_$input")"
	hexa_val=$(echo -n "$val" | sed 's/\\/\\\\/g' | hexdump -v -e '"\\\x" 1/1 "%02x" ' | sed s/'\\x26'/'\\\&'/g)
	replace_command="$replace_command -e s/<CLOUDY:$input>/$hexa_val/g"
	echo "$input=$val" >> "$tmp_path/variables.ini"
    done

    find "$tmp_path" | grep '<CLOUDY:.*>' | while read -r path
    do
	new_path="$(echo "$path" | $replace_command)"
	mv "$path" "$new_path"
    done
    grep -rl '<CLOUDY:.*>' "$tmp_path" | while read -r path
    do
	$replace_command "$path" > "$path.cloudy_swap_$$"
	mv  "$path.cloudy_swap_$$" "$path"
    done
    mv "$tmp_path" "$dst_path"
    )
}

cloudy_search_scenario_variables()
{
    grep -roh '<CLOUDY:[^>]*>' "$1" | sort | uniq | sed 's/<CLOUDY:\(.*\)>/\1/g'
}

cloudy_list_default_scenario_variables()
{
    cur_path="$1"
    tmp_var_path="/tmp/.cloudy_load_scenario_variables_$$"

    rm -rf "$tmp_var_path"
    mkdir -p "$tmp_var_path"

    find "$cur_path/$2" -type d -name 'variables()' | while read -r var_path
    do
	cp -P "$var_path/"* "$tmp_var_path/."
    done

    echo "/$2" | tr '/' '\n' | while read -r path
    do
	cur_path="$cur_path/$path"
	cp -P "$cur_path/variables()/"* "$tmp_var_path/."
    done
    
    find "$tmp_var_path" -type f | while read var_path
    do
	var_name="$(basename "$var_path")"
	if [[ -x "$var_path" ]]
	then
            if [[ -n "$(echo "$var_name" | grep -E '^.*\..*$')" ]]
            then
	        var_default_val="$("$var_path")"
	        echo "\"default_$var_name\": $var_default_val,"
            else
	        var_default_val="$("$var_path" | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ',' | sed 's/,$//g')"
	        echo "\"default_$var_name\": [$var_default_val],"
            fi
	else
	    var_default_val="$(cat "$var_path" | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ',' | sed 's/,$//g')"
	    echo "\"default_$var_name\": [$var_default_val],"
	fi
    done
    rm -rf "$tmp_var_path"
}
