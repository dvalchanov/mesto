class KnowledgeController < ApplicationController
  PAGES = %w[guides documents glossary].freeze

  before_action :set_page

  def guides = render(:show)
  def documents = render(:show)
  def glossary = render(:show)

  private

  def set_page
    @page = action_name
    raise ActionController::RoutingError, "Not Found" unless @page.in?(PAGES)
  end
end
