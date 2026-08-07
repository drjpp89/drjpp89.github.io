#!/usr/bin/env ruby
# Patches the Gemfile with version floors for high/critical vulnerable
# packages found in a `snyk test --json-file-output=<path>` report.
#
# Usage:
#   ruby autofix_gems.rb <snyk-sca.json> <Gemfile>
#   ruby autofix_gems.rb --print-updated-packages <snyk-sca.json> <Gemfile>

require "json"

print_only = ARGV.delete("--print-updated-packages")
json_path, gemfile_path = ARGV

abort "Usage: autofix_gems.rb [--print-updated-packages] <snyk-sca.json> <Gemfile>" unless json_path && gemfile_path

report = JSON.parse(File.read(json_path))
vulnerabilities = report["vulnerabilities"] || []

HIGH_SEVERITIES = %w[high critical].freeze

fix_floor = {}
vulnerabilities.each do |vuln|
  next unless HIGH_SEVERITIES.include?(vuln["severity"])

  candidates = Array(vuln["fixedIn"])
  next if candidates.empty?

  highest = candidates.max_by { |v| Gem::Version.new(v) }
  package = vuln["packageName"]
  current = fix_floor[package]
  fix_floor[package] = highest if current.nil? || Gem::Version.new(highest) > Gem::Version.new(current)
end

if fix_floor.empty?
  warn "No high/critical dependency vulnerabilities with a known fix version — nothing to patch."
  puts "" if print_only
  exit 0
end

gemfile_lines = File.readlines(gemfile_path)
touched = []

fix_floor.each do |package, version|
  pattern = /^gem\s+["']#{Regexp.escape(package)}["']/
  line_index = gemfile_lines.find_index { |line| line.match?(pattern) }
  new_line = %(gem "#{package}", ">= #{version}"\n)

  if line_index
    next if gemfile_lines[line_index].strip == new_line.strip

    gemfile_lines[line_index] = new_line
  else
    gemfile_lines << %(\n# Snyk auto-fix — #{Time.now.strftime('%Y-%m-%d')}\n) unless gemfile_lines.any? { |l| l.include?("Snyk auto-fix") }
    gemfile_lines << new_line
  end
  touched << package
end

if print_only
  puts touched.join(" ")
  exit 0
end

File.write(gemfile_path, gemfile_lines.join) unless touched.empty?
warn "Patched Gemfile for: #{touched.join(', ')}" unless touched.empty?
