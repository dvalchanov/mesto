class HomeController < ApplicationController
  def show
    @identifier_value = params[:identifier]
  end
end
