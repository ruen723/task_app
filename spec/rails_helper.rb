ENV["RAILS_ENV"] ||= "test"
abort "RSpec requires RAILS_ENV=test" unless ENV["RAILS_ENV"] == "test"

require_relative "../config/environment"

database = ActiveRecord::Base.connection_db_config
expected_host = ENV["GITHUB_ACTIONS"] == "true" ? "127.0.0.1" : "db"
unless Rails.env.test? && database.adapter == "mysql2" &&
    database.database == "task_app_test" && database.configuration_hash[:host] == expected_host
  abort "Expected MySQL test database task_app_test on #{expected_host}"
end

ActiveRecord::Base.connection_pool.with_connection do |connection|
  abort "Unexpected connected database" unless connection.select_value("SELECT DATABASE()") == "task_app_test"
end

# CI runs this file directly to check the connection before preparing its test schema.
if $PROGRAM_NAME != __FILE__
  require "spec_helper"
  require "rspec/rails"
  require_relative "support/system_browser"
  require_relative "support/capybara_chrome158_workaround"

  ActiveRecord::Migration.check_all_pending!

  RSpec.configure do |config|
    config.use_transactional_fixtures = true
    config.infer_spec_type_from_file_location!
  end
end
