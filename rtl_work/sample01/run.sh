#!/usr/bin/sh

vlib work
vlog -f filelist.f -l log/compile.log
vsim -c test -do "run 10ms; quit" -l log/sim.log
