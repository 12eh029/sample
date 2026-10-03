#!/usr/bin/sh

vlib work
vlog -f filelist.f -l log/compile.log

mode=${1}

echo "mode="$mode


if [ $mode = gui ]; then
   vsim tb -do "add wave sim:/tb/i_CPU/*; \
                run -all;" -l log/sim.log
else
   vsim -c tb -do "run 10ms; quit" -l log/sim.log
fi
