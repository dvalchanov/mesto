class HomeController < ApplicationController
  def show
    @identifier_value = params[:identifier]
    if params[:education_entry] == "guide"
      ProductEvent.record("education_to_property_check", metadata: { mode: current_buyer_journey ? "personalized" : "anonymous" })
    end
  end
end
