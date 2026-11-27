require "rails_helper"

RSpec.describe "Home" do
  it "returns a successful response for the TOP page" do
    get root_path

    expect(response).to have_http_status(:ok)
  end
end
