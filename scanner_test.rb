require "date"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

require_relative "overdue_debt"

def assert(condition, message)
  raise message unless condition
end

Dir.mktmpdir do |directory|
  source = File.join(directory, "source.py")
  File.write(source, <<~PYTHON)
    # TODO: generic marker
    # TODO(debt: 2000-01-01): overdue
    # FIXME(debt: 2026-02-01): due today
    # TODO(debt: 2026-02-02): due tomorrow
    # TODO(debt: 2026-02-30): invalid date
    print("# TODO(debt: 2000-01-01)")
  PYTHON

  findings = OverdueDebt.scan([["source.py", source]], today: Date.new(2026, 2, 1))
  assert(findings.map { |finding| finding[:line] } == [2], "expected only the overdue annotation")

  scanner = File.expand_path("pitaiya-scan.rb", __dir__)
  command = [RbConfig.ruby, scanner, "--directory", directory]
  _, _, status = Open3.capture3(*command)
  assert(status.exitstatus == 2, "expected status 2 outside a Git checkout")

  assert(system("git", "init", "--quiet", chdir: directory), "git init failed")
  assert(system("git", "add", "source.py", chdir: directory), "git add failed")
  File.write(File.join(directory, "untracked.py"), "# TODO(debt: 2000-01-01)\n")

  output_path = File.join(directory, "report.json")
  stdout, _, status = Open3.capture3(*command, "--output", output_path)
  assert(status.success? && stdout.empty?, "expected an informational scan to write only to the report")
  report = JSON.parse(File.read(output_path))
  assert(report.fetch("schema_version") == 1, "expected report schema version 1")
  assert(report.fetch("checks") == ["overdue-debt"], "expected the overdue debt check to run")
  assert(report.fetch("findings").map { |finding| finding.fetch("path") }.uniq == ["source.py"],
         "expected findings only in tracked source files")

  stdout, _, status = Open3.capture3(*command, "--fail-on-findings")
  assert(status.exitstatus == 1 && !JSON.parse(stdout).fetch("findings").empty?,
         "expected findings and status 1 in blocking mode")

  File.write(source, "# no debt annotations\n")
  stdout, _, status = Open3.capture3(*command, "--fail-on-findings")
  assert(status.success? && JSON.parse(stdout).fetch("findings").empty?,
         "expected status 0 and an empty report for a clean checkout")
end

puts "Scanner tests passed."
