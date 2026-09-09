class KnowledgeController < ApplicationController
  def guides = redirect_to(guide_path, status: :moved_permanently)
  def documents = redirect_to(education_documents_path, status: :moved_permanently)
  def glossary = redirect_to(terms_path, status: :moved_permanently)
end
