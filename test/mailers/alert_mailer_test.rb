require "test_helper"

class AlertMailerTest < ActionMailer::TestCase
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @user = User.create!(email_address: "mailer@example.com", password: "password123", password_confirmation: "password123")
    @changes = [
      Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/test/mail/1", title: "Updated Regulation", legislation_type: "regulation", status: "in_force"),
      Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/test/mail/2", title: "Amended Directive", legislation_type: "directive", status: "in_force")
    ]
  end

  test "daily_digest sends email" do
    email = AlertMailer.daily_digest(@user, @changes)
    assert_equal ["mailer@example.com"], email.to
    assert_includes email.subject, "2 legislation updates"
  end

  test "daily_digest includes legislation titles in body" do
    email = AlertMailer.daily_digest(@user, @changes)
    assert_includes email.html_part.body.to_s, "Updated Regulation"
    assert_includes email.html_part.body.to_s, "Amended Directive"
  end
end
