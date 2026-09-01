class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Mesto <hello@mesto.bg>")
  layout "mailer"
end
