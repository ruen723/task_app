require "rails_helper"

RSpec.describe "Home page" do
  before do
    service = Selenium::WebDriver::Service.chrome(
      path: ENV.fetch("CHROMEDRIVER_PATH", "/usr/bin/chromedriver")
    )

    driven_by :selenium, using: :headless_chrome, options: { service: service } do |options|
      options.binary = ENV.fetch("CHROME_BIN", "/usr/bin/chromium")
      options.add_argument("--disable-dev-shm-usage")

      if ENV["SYSTEM_SPEC_CHROMIUM_NO_SANDBOX"] == "1"
        raise "The Chromium sandbox override requires a non-root user" if Process.uid.zero?

        options.add_argument("--no-sandbox")
        options.add_argument("--disable-background-networking")
        # Chromium bypasses the proxy for loopback requests to the test server.
        options.add_argument("--proxy-server=http://127.0.0.1:9")
      end
    end
  end

  it "shows the main heading" do
    visit root_path

    expect(page).to have_selector("h1", text: "時間を見える化して、自分で時間を使いこなそう。")
  end
end
