class SitemapsController < ApplicationController
  def show
    catalog = Education::Catalog.instance
    @paths = [ root_path, guide_path, buying_guide_path, new_build_guide_path, education_documents_path, terms_path,
      calculators_path, purchase_calculator_path, mortgage_calculator_path ]
    @paths += catalog.published("stage").map { |entry| new_build_stage_path(stage: entry["slug"]) }
    @paths += catalog.published("document").map { |entry| education_document_path(slug: entry["slug"]) }
    @paths += catalog.published("term").map { |entry| term_path(slug: entry["slug"]) }
    render formats: :xml
  end
end
