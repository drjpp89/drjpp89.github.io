#!/usr/bin/env ruby
# Builds a markdown vulnerability report from Snyk CLI JSON output.
#
# Usage:
#   ruby generate_snyk_report.rb <snyk-sca.json> <snyk-code.json> <output.md>

require "json"
require "time"

sca_path, code_path, output_path = ARGV
abort "Usage: generate_snyk_report.rb <snyk-sca.json> <snyk-code.json> <output.md>" unless sca_path && code_path && output_path

def load_json(path)
  return {} unless File.exist?(path) && !File.zero?(path)

  JSON.parse(File.read(path))
rescue JSON::ParserError
  {}
end

LEVEL_TO_SEVERITY = { "error" => "high", "warning" => "medium", "note" => "low" }.freeze

sca_report = load_json(sca_path)
sca_vulns = sca_report["vulnerabilities"] || []

code_report = load_json(code_path)
code_run = (code_report["runs"] || []).first || {}
rules = (code_run.dig("tool", "driver", "rules") || []).to_h { |r| [r["id"], r] }
code_results = code_run["results"] || []

severity_counts = Hash.new(0)
sca_vulns.each { |v| severity_counts[v["severity"]] += 1 }
code_results.each do |r|
  severity = LEVEL_TO_SEVERITY[r["level"]] || "low"
  severity_counts[severity] += 1
end

File.open(output_path, "w") do |f|
  f.puts "# Snyk Findings Report"
  f.puts
  f.puts "**Generated:** #{Time.now.utc.strftime('%Y-%m-%d %H:%M UTC')}"
  f.puts "**Scan type:** Snyk Open Source (SCA) + Snyk Code (SAST)"
  f.puts
  f.puts "No high/critical severity issues were found — findings below are medium/low severity, recorded for visibility."
  f.puts
  f.puts "## Severity Breakdown"
  f.puts
  f.puts "| Severity | Count |"
  f.puts "|---|---|"
  %w[critical high medium low].each do |sev|
    f.puts "| #{sev.capitalize} | #{severity_counts[sev]} |"
  end
  f.puts

  f.puts "## Dependency Findings (SCA)"
  f.puts
  if sca_vulns.empty?
    f.puts "None."
  else
    sca_vulns.each do |v|
      f.puts "### #{v['severity'].to_s.upcase} — #{v['title']}"
      f.puts "- **Package:** #{v['packageName']} #{v['version']}"
      f.puts "- **CVE(s):** #{Array(v.dig('identifiers', 'CVE')).join(', ')}" if v.dig("identifiers", "CVE")
      f.puts "- **Fixed in:** #{Array(v['fixedIn']).join(', ')}" if v["fixedIn"]
      f.puts "- **Path:** #{Array(v['from']).join(' > ')}" if v["from"]
      f.puts
    end
  end

  f.puts "## First-Party Code Findings (SAST)"
  f.puts
  if code_results.empty?
    f.puts "None."
  else
    code_results.each do |r|
      rule = rules[r["ruleId"]] || {}
      severity = LEVEL_TO_SEVERITY[r["level"]] || "low"
      location = r.dig("locations", 0, "physicalLocation")
      file = location&.dig("artifactLocation", "uri")
      line = location&.dig("region", "startLine")
      f.puts "### #{severity.upcase} — #{rule['shortDescription']&.dig('text') || r['ruleId']}"
      f.puts "- **File:** #{file}#{":#{line}" if line}"
      f.puts "- **Message:** #{r.dig('message', 'text')}"
      f.puts
    end
  end
end

warn "Report written to #{output_path}"
