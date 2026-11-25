require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
abort "RSpec requires RAILS_ENV=test" unless ENV["RAILS_ENV"] == "test"

require_relative "../config/environment"
require "rspec/rails"

database = ActiveRecord::Base.connection_db_config
abort "RSpec requires the task_app_test database" unless Rails.env.test? && database.database == "task_app_test"

ActiveRecord::Migration.check_all_pending!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
end
