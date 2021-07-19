# CPU Powersave
<div align="center">
  <img alt="Shell Script" src="https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white"/>
  <img alt="Linux" src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black">
  <img alt="Kali Linux" src="https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge&logo=kali-linux&logoColor=white" />
</div>

> A small bash utility to scale down or up CPU power consumption
>
> Pequena utilidade escrita em bash para aumentar ou diminuir o consumo de energia da CPU
>
> <p textalign="right" align="right"> By wh1t3h47 </p>
>
> <p textalign="right" align="right"> (Antônio Martos Harres) </p>
> 
> <p textalign="right" align="right"> - https://github.com/wh1t3h47 </p>

## Features
1. Automatically detects if charger is plugged and acts accordingly to the context;
2. Set your own limits for maximium clock, core count and governor;
3. Control your CPU whenever a power source change and automatically apply the `battery` or `AC` profile.

## WARNINGS:
1. This script runs as **root**, so make sure it's owned by user and group root and it's not writable by any other user, otherwise you're installing a tick bomb inside your system;
2. Do **NEVER** set a script with suid bit: If your shell script has suid priviledge, it's a backdoor waiting to be exploited, any user could gain root without password.

## Dependencies:
- cpufreq
- cpufreqd
- lscpu
- Linux

## TODO
- [x] 1. Make disable_pstate a parameter
- [x] 2. Respect max pstate clock as well
- [x] 3. Find a better solution to detect max clock speed
- [ ] 4. Implement systemd service
- [x] 5. Make governor a parameter
- [ ] 6. modprobe all governors
- [ ] 7. Create a way to configure CPU settings for each amount of battery
