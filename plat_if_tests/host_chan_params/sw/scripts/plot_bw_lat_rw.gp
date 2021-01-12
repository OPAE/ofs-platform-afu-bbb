if (! exists("data_file")) exit error "Data file not specified!"
if (! exists("platform")) platform = "SKX Xeon+FPGA"

# Cycle time in ns
afu_mhz = system("grep 'AFU MHz' " . data_file . " | sed -e 's/.*MHz: //'")
cycle_time = 1000.0 / afu_mhz
print sprintf("AFU cycle time: %f ns", cycle_time)
platform = platform . " (" . afu_mhz . "MHz)"

# Does data for 3 line requests exist?
mcl3_found = system("grep -c 'Burst size: 3' " . data_file) + 0

set term postscript color enhanced font "Helvetica" 17 butt dashed

set ylabel "Bandwidth (GiB/s)" offset 1,0 font ",15"
set y2label "Latency (ns)" offset -1.75,0 font ",15"
set xlabel "Maximum Outstanding Lines" font ",15"

set mxtics 3
set boxwidth 0.8
set xtics out font ",12"

set ytics out nomirror font ",12"
set mytics 4
set y2tics out font ",12"

set yrange [0:]
set y2range [0:]
#set size square
set bmargin 0.5
set tmargin 0.5
set lmargin 3.0
set rmargin 6.25

set grid ytics mytics
set grid xtics

set key on inside bottom right width 2 samplen 4 spacing 1.5 font ",14"
set style fill pattern
set style data histograms

set style line 1 lc rgb "red" lw 3
set style line 2 lc rgb "red" lw 3 dashtype "-"
set style line 3 lc rgb "blue" lw 3
set style line 4 lc rgb "blue" lw 3 dashtype "-"
set style line 5 lc rgb "green" lw 3
set style line 6 lc rgb "green" lw 3 dashtype "-"
set style line 7 lc rgb "magenta" lw 3
set style line 8 lc rgb "magenta" lw 3 dashtype "-"

set xrange [0:512]

mcl = 1
table_idx = 2
while (mcl <= 4) {
  if ((mcl != 3) || mcl3_found) {
    set output "| ps2pdf - rw_credit_vc_mcl" . mcl . ".pdf"
    set title platform . " RD+WR Varying Offered Load (MCL=" . mcl . ")" offset 0,1 font ",18"

    plot data_file index table_idx using ($3):($1) with lines smooth bezier ls 1 title "Read Bandwidth", \
         data_file index table_idx using ($3):($7) axes x1y2 with lines smooth bezier ls 2 title "Read Latency", \
         data_file index table_idx using ($6):($2) with lines smooth bezier ls 3 title "Write Bandwidth", \
         data_file index table_idx using ($6):($9) axes x1y2 with lines smooth bezier ls 4 title "Write Latency", \
         data_file index table_idx using ($3):($1 + $2) with lines smooth bezier ls 7 title "Total Bandwidth"

    table_idx = table_idx + 3
  }

  mcl = mcl + 1
}
