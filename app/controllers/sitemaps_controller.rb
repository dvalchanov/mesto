class SitemapsController < ApplicationController
  def show
    catalog = Education::Catalog.instance
    @paths = [ guide_path, buying_guide_path, new_build_guide_path, education_documents_path, terms_path ]
    @paths += catalog.published("stage").map { |entry| new_build_stage_path(entry["slug"]) }
    @paths += catalog.published("document").map { |entry| education_document_path(entry["slug"]) }
    @paths += catalog.published("term").map { |entry| term_path(entry["slug"]) }
    render formats: :xml
  end
end
