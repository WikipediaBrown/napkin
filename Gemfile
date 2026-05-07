# frozen_string_literal: true

source "https://rubygems.org"

gem "danger"
# 2.233.1 fixes a parsing crash against Xcode 26's `xcrun simctl runtime`
# output that fired before the test destination was even resolved.
gem "fastlane", ">= 2.233.1"
gem "xcov"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
