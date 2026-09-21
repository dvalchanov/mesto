class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Mesto <hi@mesto.bg>")
  layout "mailer"
end
