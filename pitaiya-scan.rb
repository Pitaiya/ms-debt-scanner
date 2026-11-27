#!/usr/bin/env ruby

require "date"
require "json"
require "open3"
require "optparse"

require_relative "overdue_debt"

options = { directory: ".", fail_on_findings: false }
parser = OptionParser.new do |cli|
  cli.banner = "Usage: pitaiya-scan [options]"
  cli.on("--directory PATH", "Git checkout to scan (default: current directory)") { |path| options[:directory] = path }
  cli.on("--output PATH", "Write the JSON report to a file (default: stdout)") { |path| options[:output] = path }
  cli.on("--fail-on-findings", "Exit with status 1 when a check reports a finding") { options[:fail_on_findings] = true }
  cli.on("-h", "--help", "Show this help") { puts cli; exit }
end

begin
  parser.parse!
  raise OptionParser::InvalidArgument, ARGV.join(" ") unless ARGV.empty?

  directory = File.realpath(options[:directory])
  root, error, status = Open3.capture3("git", "rev-parse", "--show-prefix", chdir: directory)
  raise ArgumentError, error.strip unless status.success?
  raise ArgumentError, "--directory must point to the checkout root" unless root.chomp.empty?

  paths, error, status = Open3.capture3("git", "ls-files", "--cached", "--deduplicate", "-z", chdir: directory)
  raise ArgumentError, error.strip unless status.success?

  checks = [OverdueDebt]
  files = paths.split("\0").filter_map do |path|
    full_path = File.join(directory, path)
    next if File.symlink?(full_path) || !File.file?(full_path)

    resolved_path = File.realpath(full_path)
    next unless resolved_path.start_with?("#{directory.chomp("/")}/")

    [path, resolved_path]
  end

  findings = checks.flat_map { |check| check.scan(files, today: Time.now.utc.to_date) }
  report = JSON.pretty_generate({
    schema_version: 1,
    checks: checks.map { |check| check::ID },
    findings: findings
  }) + "\n"

  if options[:output]
    File.write(options[:output], report)
  else
    print report
  end
  warn "#{findings.length} debt finding(s)"
  exit 1 if options[:fail_on_findings] && !findings.empty?
rescue OptionParser::ParseError, ArgumentError, SystemCallError => error
  warn "pitaiya-scan: #{error.message}"
  exit 2
end
