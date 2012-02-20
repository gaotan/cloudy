
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
    VBoxManage list vms | cut -d '"' -f 2
}

cloudy_copy_scenario_and_replace_variables()
{
    src_path="$1"
    dst_path="$2"
    tmp_path="/tmp/.cloudy_copy_scenario_and_replace_variables_$$"

    rm -rf "$tmp_path"
    mkdir -p "$dst_path"
    rmdir "$dst_path"
    cp -RL "$src_path" "$tmp_path"
    replace_command="sed"
    set | grep PARAM_var_ | while read -r kv
    do
	key="$(echo "$kv" | cut -d '=' -f 1 | sed s/^PARAM_var_//)"

	val="$(echo "$kv" | sed s/'^[^=]*='//)"
	hexa_val=$(echo -n "$val" | sed 's/\\/\\\\/g' | hexdump -v -e '"\\\x" 1/1 "%02x" ' | sed s/'\\x26'/'\\\&'/g)
	echo "  [$key]  :  [$val]  ($hexa_val)"
	replace_command="$replace_command -e s/<CLOUDY:$key>/$hexa_val/g"
    done

    echo "$replace_command"
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
}

cloudy_search_scenario_variables()
{
    grep -roh '<CLOUDY:.*>' "$1" | sort | uniq | sed 's/<CLOUDY:\(.*\)>/\1/g'
}

cloudy_list_default_scenario_variables()
{
    cur_path="$1"
    tmp_var_path="/tmp/.cloudy_load_scenario_variables_$$"

    rm -rf "$tmp_var_path"
    mkdir -p "$tmp_var_path"

    cp -P "$cur_path/variables()/"* "$tmp_var_path/."
    echo "$2" | tr '/' '\n' | while read -r path
    do
	cur_path="$cur_path/$path"
	cp -P "$cur_path/variables()/"* "$tmp_var_path/."
    done

    find "$tmp_var_path" -type f | while read var_path
    do
	var_name="$(basename "$var_path")"
	var_delault_val="$(cat "$var_path" | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ',' | sed 's/,$//g')"
	echo "\"default_$var_name\": [$var_delault_val],"
    done
    rm -rf "$tmp_var_path"
}