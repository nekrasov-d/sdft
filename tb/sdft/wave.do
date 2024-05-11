onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix decimal -childformat {{{/tb/data_o[1]} -radix decimal} {{/tb/data_o[0]} -radix decimal}} -subitemconfig {{/tb/data_o[1]} {-height 26 -radix decimal} {/tb/data_o[0]} {-height 26 -radix decimal}} /tb/data_o
add wave -noupdate -radix decimal -childformat {{{/tb/reference_data[1]} -radix decimal} {{/tb/reference_data[0]} -radix decimal}} -subitemconfig {{/tb/reference_data[1]} {-height 26 -radix decimal} {/tb/reference_data[0]} {-height 26 -radix decimal}} /tb/reference_data
add wave -noupdate /tb/DUT/sob_o
add wave -noupdate /tb/DUT/eob_o
add wave -noupdate /tb/DUT/valid_o
add wave -noupdate -divider -height 50 <NULL>
add wave -noupdate -divider -height 50 <NULL>
add wave -noupdate -format Analog-Step -height 112 -max 18447.0 -min -18728.0 /tb/error_re
add wave -noupdate -format Analog-Step -height 112 -max 18314.999999999996 -min -18631.0 /tb/error_im
add wave -noupdate -divider -height 100 <NULL>
add wave -noupdate -radix binary /tb/DUT/FIX
add wave -noupdate /tb/DUT/sample_tick_i
add wave -noupdate /tb/DUT/xn
add wave -noupdate /tb/DUT/xz
add wave -noupdate /tb/DUT/comb
add wave -noupdate -radix decimal /tb/DUT/xz_addr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {90312 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 169
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {417720 ns}
