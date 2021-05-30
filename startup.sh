#!/bin/env bash

# Start argument handling

function show_help() {
	echo -e "Script to easily manage your CPU using cpufreq as a CPU power backend\n"
	echo -e "${0} -m \"AC\" -> AC Plugged, boost CPU accordingly"
	echo -e "${0} -m \"BAT\" -> Using battery, boost CPU accordingly"
	echo -e "${0} -m \"AUTO\" -> Will automatically detect if using battery or AC power"
	echo -e "${0} -j 2 -> Default behaviour: Set two cores enabled when using battery\n\t\tIf mode is AC, -j will specify the maximum number of cores to keep enabled at full power"
	echo -e "${0} -c 1000 -> Set max clock to 1000 Mhz when using battery\n\t\tIf mode is AC, -c will specify the maximum clock at full power\n"
	echo -e "Examples:\n"
	echo -e "1. The examples below are suitable when the AC adapter is connected\n"
	echo -e "${0} -m AC # Set CPU fully powered"
	echo -e "${0} -m AC -c 3200 # Set CPU fully powered, but ALWAYS under 3.2Ghz"
	echo -e "${0} -m AC -j 4 # Set CPU fully powered, but will never use more than 4 cores\n"
	echo -e "2. The examples below are suitable if you want to save battery\n"
	echo -e "${0} -m BAT # Set the cpu to dual core at 1Ghz with pstate enabled (default) and powersave/ ondemand governor"
	echo -e "${0} -m BAT -c 1800 -j 4 # Set the CPU to, at best, quad core at 1.8Ghz with pstate turbo disabled (intel power save) and powersave/ ondemand governor"
	echo -e "${0} -m BAT -c 1800 -j 4 -t # Set the CPU to, at best, quad core at 1.8Ghz with pstate turbo enabled (not using intel power save) and powersave/ ondemand governor\n"
	echo -e "3. The examples below are suitable when you are running this script periodically in an interval of time (chron or daemon) and want to automatically detect if AC is plugged (requires ACPI) \n"
	echo -e -n "${0} -m AUTO # If you unplug your AC and run this program, it will put CPU on powersave, at 1Ghz with 2 cores enabled"
}

function invalid_argument() {
	echo "Error, invalid argument ${1}" &> /dev/stderr
	exit 1;
}
# POSIX variable, reset for getopt usage
OPTIND=1

# Initialize our own variables:
AC_PLUGGED=false
AC_DISABLE_CORES=false
AC_SET_FREQ=false
num_cores=2
freq=1000
disable_turbo=1
governor=false

while getopts "h?m:j:c:d:t:" opt; do
	case "$opt" in
		h|\?)
			show_help
			exit 0
			;;
		m)
			if [ ${OPTARG} == "AC" ]; then
				AC_PLUGGED=true
			elif [ ${OPTARG} == "AUTO" ]; then
				supply_online=`cat /sys/class/power_supply/AC0/online`
				echo $supply_online
				if [ $supply_online == '0' ]; then
					AC_PLUGGED=false
				elif [ $supply_online == '1' ]; then
					AC_PLUGGED=true;
				fi
			elif [ ${OPTARG} != "BAT" ]; then
				invalid_argument "\"${0} -${opt} ${OPTARG}\""
			fi
			;;
		j)
			num_cores=${OPTARG}
			if [ ${AC_PLUGGED} == true ]; then
				AC_DISABLE_CORES=true
			fi
			;;
		c)
			freq=${OPTARG}
			if [ ${AC_PLUGGED} == true ]; then
				AC_SET_FREQ=true
			fi
			;;
		t)
			disable_turbo=0
			;;
		g)
			governor=${OPTARG}
			;;
		*)
			# Ideally will not run as getopt handles it
			invalid_argument "${0} -${opt}"
			;;
	esac
done

# Start Power save logic

modprobe cpufreq_powersave
modprobe cpufreq_ondemand
modprobe cpufreq_userspace

################################################
#  Controls Intel Turbo Boost                  #

# disable_turbo=1
if [ ${AC_PLUGGED} == true ]; then
	disable_turbo=0
fi
echo ${disable_turbo} > /sys/devices/system/cpu/intel_pstate/no_turbo

################################################
#  Set powersave to all CPUs                   #
#  Set max clock to n Ghz for all cpus         #

nprocessors_conf=`getconf _NPROCESSORS_CONF`
nprocessors_online=`getconf _NPROCESSORS_ONLN`
cpu_end=$((${nprocessors_conf} - 1))
max_cpu_freq=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
min_cpu_freq=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq`

# Test if CPU can run at specified frequency
if [ $((${freq} * 1000)) -gt ${max_cpu_freq} ]; then
	echo "Cannot set frequency: CPU cannot handle ${freq}Mhz, setting to ${max_cpu_freq}Khz"
	freq="${max_cpu_freq}Khz"
else
	freq="${freq}Mhz"
fi

# Test if number of cores specified is acceptable
if [ ${num_cores} -gt ${nprocessors_conf} ] ||
	[ ${num_cores} -lt 1 ]
then
	echo "Invalid number of cores specified, try to add \"-j 1\" if you're on a single core machine, or set a lower number in a multi core setup"
	exit 1;
fi


for cpu in `seq 0 ${cpu_end}`
do
	# Check if all CPUs are enabled
	if [ nprocessors_conf != nprocessors_online ]; then
		# Needs CPU enabled to set governor
		bash -c "echo 1 > /sys/devices/system/cpu/cpu${cpu}/online" &>/dev/null
	fi

	if [ $AC_PLUGGED == true ]; then
		ac_max=""
		if [ ${AC_SET_FREQ} == true ]; then
			ac_max="${freq}"
		else
			ac_max="${max_cpu_freq}Khz"
		fi
		if [ $governor == false ]; then
			governor='performance'
		fi
		cpufreq-set -r --cpu ${cpu} --governor ${governor} -d ${min_cpu_freq}Khz -u ${ac_max}
	else
		if [ $governor == false ]; then
			governor='powersave'
		fi
		cpufreq-set -r --cpu ${cpu} --governor $governor -d ${min_cpu_freq} -u ${freq}
	fi
	# echo 1000000 > /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_max_freq
	# echo 1000000 > /sys/devices/system/cpu/cpu${i}/cpufreq/cpuinfo_max_freq
done

################################################
#  Disable 6 CPUs on battery                   #
if [ ${AC_PLUGGED} == false ] ||
	[ ${AC_DISABLE_CORES} == true ]
then
	disable_cpu=0
	cpu_start=${num_cores}
	for i in `seq ${cpu_start} ${cpu_end}`
	do
		# Skip the first CPU, it's always online
		if [ $i == 0 ]; then continue; fi
		echo ${disable_cpu} > /sys/devices/system/cpu/cpu${i}/online
	done
fi

