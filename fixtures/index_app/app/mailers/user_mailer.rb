class UserMailer < ApplicationMailer
  def welcome
    mail to: params[:user].email
  end

  def receipt
    mail to: params[:user].email
  end
end
