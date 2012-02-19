
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
