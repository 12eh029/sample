#!/usr/bin/sh

vlib work
vlog -f filelist.f -l log/compile.log

mode=${1}

echo "mode="$mode


if [ $mode = gui ]; then
   vsim test -do "run 1ns;" -l log/sim.log
else
   vsim -c test -do "run 10ms; quit" -l log/sim.log
fi
