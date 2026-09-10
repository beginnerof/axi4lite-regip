# axi4lite-regip — Icarus Verilog flow
#   make test   # run self-checking TB
#   make wave   # dump VCD then run
#   make clean

IVERILOG ?= iverilog
VVP      ?= vvp

RTL = \
	rtl/reg_bank.v \
	rtl/axi4lite_if.v \
	rtl/axil_regip_top.v

.PHONY: all test wave clean sim

all: test

sim:
	@mkdir -p sim 2>/dev/null || mkdir sim 2>NUL || exit 0

sim/tb_axil_regip.vvp: $(RTL) tb/tb_axil_regip.v | sim
	$(IVERILOG) -g2001 -o sim/tb_axil_regip.vvp $(RTL) tb/tb_axil_regip.v

test: sim/tb_axil_regip.vvp
	cd sim && $(VVP) tb_axil_regip.vvp

wave: sim/tb_axil_regip.vvp
	cd sim && $(VVP) tb_axil_regip.vvp +dump

clean:
	rm -rf sim/*.vvp sim/*.vcd 2>/dev/null || powershell -c "Remove-Item -Force sim\*.vvp,sim\*.vcd -ErrorAction SilentlyContinue"
