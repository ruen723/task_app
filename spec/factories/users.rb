FactoryBot.define do
  factory :user do
    sequence(:username) { |number| "user_#{number}" }
    password { "morning-plan-123" }
    password_confirmation { password }
  end
end
