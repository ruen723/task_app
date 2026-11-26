disable_sandbox = ENV["SYSTEM_SPEC_CHROMIUM_NO_SANDBOX"] == "1"
if disable_sandbox
  abort "The Chromium sandbox override is not allowed in CI" if ENV["GITHUB_ACTIONS"] == "true" || ENV["CI"]
  abort "The Chromium sandbox override requires a non-root user" if Process.uid.zero?
end

RSpec.configure do |config|
  config.before(:example, type: :system) do
    service = Selenium::WebDriver::Service.chrome(
      path: ENV.fetch("CHROMEDRIVER_PATH", "/usr/bin/chromedriver")
    )

    driven_by :selenium, using: :headless_chrome, options: { service: service } do |options|
      options.binary = ENV.fetch("CHROME_BIN", "/usr/bin/chromium")
      options.add_argument("--disable-dev-shm-usage")

      if disable_sandbox
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-background-networking")
        # Chromium bypasses the proxy for loopback requests to the test server.
        options.add_argument("--proxy-server=http://127.0.0.1:9")
      end
    end
  end
end
