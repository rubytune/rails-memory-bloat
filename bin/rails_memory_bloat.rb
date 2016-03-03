#!/usr/bin/ruby
require 'optparse'
require 'rails_memory_bloat/request'

log = nil
output = './output'
options = OptionParser.new do |opts|
  opts.on('-o DIR', 'Output files to DIR') do |dir|
    output = dir
  end
end.tap(&:parse!)
log = ARGV.shift or (warn(options.help) || exit(1))

system('mkdir', '-p', "#{output}/data")
system('cp', '-r', 'assets', "#{output}/assets")

File.open(log, 'r').each_line do |line|
  next unless line[0, 14] == '[Memory Usage]'
  request = Request.new(line)
end

RailsProcess.instances.each do |process|
  File.open("#{output}/#{process.csv_path}", 'w') do |csv|
    process.requests.each_with_index do |r|
      csv.puts("#{r.rss}")
    end
  end
end

IO.popen('gnuplot', 'w') do |gp|
  gp.puts('set term pngcairo size 640,480')
  gp.puts('set grid')
  gp.puts('set datafile separator ","')
  RailsProcess.instances.each do |process|
    gp.puts(%(set output "#{output}/#{process.png_path}"))
    gp.puts("set title 'PID #{process.pid}'")
    gp.puts('set xlabel "Request #"')
    gp.puts('set ylabel "Memory (MB)"')
    gp.puts('set yrange [0:800]')
    gp.puts(%(plot "#{output}/#{process.csv_path}" using 0:($1/1024) with lines notitle))
  end
  gp.puts('quit')
  gp.close
end

File.open("#{output}/index.html", 'w') do |f|
  f.write(ProcessView.new(RailsProcess.instances).to_html)
end
