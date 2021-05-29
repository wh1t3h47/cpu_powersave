#!/bin/env bash

# Start argument handling

function show_help() {
	echo "${0} -m \"AC\" -> AC Plugged, boost CPU accordingly"
	echo "${0} -m \"BAT\" -> Using battery, boost CPU accordingly"
	echo "${0} -j 2 -> Set two cores enabled when using battery"
	echo "${0} -c 1000 -> Set max clock to 1000 Mhz when using battery"
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

while getopts "h?m:j:c:" opt; do
	case "$opt" in
		h|\?)
			show_help
			exit 0
			;;
		m)
			if [ ${OPTARG} == "AC" ]; then
				AC_PLUGGED=true
			elif [ ${OPTARG} != "BAT" ]; then
				invalid_argument "\"${0} ${opt} ${OPTARG}\""
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
		*)
			# Ideally will not run as getopt handles it
			invalid_argument "${opt}"
			;;
	esac
done

# Start Power save logic

modprobe cpufreq_powersave
modprobe cpufreq_userspace

################################################
#  Controls Intel Turbo Boost                  #

disable_turbo=1
if [ ${AC_PLUGGED} == true ]; then
	disable_turbo=0
fi
echo ${disable_turbo} > /sys/devices/system/cpu/intel_pstate/no_turbo

################################################
#  Set powersave to all CPUs                   #
#  Set max clock to 1 Ghz for all cpus         #

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
		cpufreq-set -r --cpu ${cpu} --governor performance -d ${min_cpu_freq}Khz -u ${ac_max}
	else
		cpufreq-set -r --cpu ${cpu} --governor powersave -d ${min_cpu_freq} -u ${freq}
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

