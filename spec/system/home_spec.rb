require "rails_helper"

RSpec.describe "Home page" do
  it "shows the main heading" do
    visit root_path

    expect(page).to have_selector("h1", text: "時間を見える化して、自分で時間を使いこなそう。")
  end
end
