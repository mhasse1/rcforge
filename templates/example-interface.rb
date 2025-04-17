#!/usr/bin/env ruby
# hello.rb - Simple greeting utility in Ruby
# RC Summary: Displays a customizable greeting message (Ruby version)

require 'optparse'

# Default options
options = {
  format: "Hello, NAME!",
  uppercase: false,
  name: "Friend"
}

# Parse command line options
parser = OptionParser.new do |opts|
  opts.banner = "Usage: hello [options] [name]"
  
  opts.on("--format FORMAT", "Greeting format (default: 'Hello, NAME!')") do |format|
    options[:format] = format
  end
  
  opts.on("-u", "--uppercase", "Convert to uppercase") do
    options[:uppercase] = true
  end
  
  opts.on("--summary", "Show summary for rc help") do
    puts "Displays a customizable greeting message (Ruby version)"
    exit 0
  end
  
  opts.on("--version", "Show version information") do
    puts "hello - rcForge Utility v0.4.1"
    exit 0
  end
  
  opts.on_tail("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end
end

# Parse arguments
begin
  parser.parse!
  
  # Get name from positional argument if provided
  options[:name] = ARGV[0] if ARGV[0]
  
  # Main functionality
  greeting = options[:format].gsub('NAME', options[:name])
  greeting.upcase! if options[:uppercase]
  
  puts greeting
  exit 0
rescue OptionParser::InvalidOption => e
  puts "Error: #{e}"
  puts parser
  exit 1
end
