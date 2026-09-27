# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"
require "bundler/audit/task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Bundler::Audit::Task.new

task quick: %i[rubocop spec]
task ci: %i[rubocop bundle:audit spec]
task default: :quick
