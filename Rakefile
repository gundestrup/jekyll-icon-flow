# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"
require "bundler/audit/task"
require "rubygems/package"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Bundler::Audit::Task.new

VERSION_FILE = "lib/jekyll/icon_flow/version.rb"
GEMSPEC = "jekyll-icon-flow.gemspec"

namespace :version do
  task :show do
    puts Gem::Specification.load(GEMSPEC).version
  end

  task :check do
    version = Gem::Specification.load(GEMSPEC).version.to_s
    changelog = File.read("CHANGELOG.md")
    abort "Missing changelog entry for #{version}" unless changelog.include?("## [#{version}]")
  end

  task :check_changelog do
    version = Gem::Specification.load(GEMSPEC).version.to_s
    abort "Add a dated changelog entry for #{version}" unless
      File.read("CHANGELOG.md").match?(/^## \[#{Regexp.escape(version)}\] - \d{4}-\d{2}-\d{2}$/)
  end
end

task "version:bump", [:part] do |_task, args|
  part = args[:part].to_s
  abort "Use patch, minor or major" unless %w[patch minor major].include?(part)

  current = Gem::Specification.load(GEMSPEC).version.segments
  index = { "major" => 0, "minor" => 1, "patch" => 2 }.fetch(part)
  current.fill(0, current.length...3)
  current[index] += 1
  current.fill(0, (index + 1)...current.length)
  next_version = current.join(".")
  updated = File.read(VERSION_FILE).sub(/VERSION = "[^"]+"/, "VERSION = \"#{next_version}\"")
  File.write(VERSION_FILE, updated)
  sh "bundle", "lock" unless ENV["SKIP_LOCK"]
  puts "Bumped to #{next_version}; add a CHANGELOG.md entry"
end

task :package do
  spec = Gem::Specification.load(GEMSPEC)
  file = Gem::Package.build(spec)
  contents = Gem::Package.new(file).contents
  required = %w[LICENSE.txt README.md CHANGELOG.md lib/jekyll-icon-flow.rb
                lib/jekyll/icon_flow/adapter.rb assets/icons/lucide/search.svg
                assets/icons/simple/github.svg]
  abort "Gem missing: #{(required - contents).join(', ')}" unless (required - contents).empty?
end

task :semgrep do
  # Scan "." not an explicit path: semgrep limits itself to git-tracked
  # files, and a stale scan root is a hard error if the dir is removed.
  sh "semgrep", "scan", "--config", ".semgrep.yml", "--error", "--metrics", "off", "."
end

task quick: %i[rubocop spec]
task ci: %i[rubocop bundle:audit semgrep spec version:check package]
task "version:pre_release" => %i[ci version:check_changelog]
task default: :quick
