imulation End!! :               100210 ns:
:

gui=$1

echo "gui=$gui"

vlib work
vlog -f filelist.f -l log/compile.log

if [ $gui -eq 1 ]; then
  echo "gui start"
  vsim test -do "do sim.do" -l log/sim.log
else
  echo "batch start"
  vsim -c test -do "run -all; quit;" -l log/sim.log
fi
