module Analysis
  class DueDiligenceBuilder
    SOURCE_URLS = {
      "cadastre" => "https://kais.cadastre.bg/",
      "nag" => "https://nag.sofia.bg/pages/render/187",
      "eprut" => "https://eprutgis.mrrb.bg/",
      "dnsk_commissioning" => "https://dnsk.bg/registri/publichen-registar-na-razresheniyata-za-polzvane-izdadeni-ot-dnsk/",
      "dnsk_registers" => "https://dnsk.bg/",
      "property_registry" => "https://portal.registryagency.bg/home-pr",
      "commercial_registry" => "https://portal.registryagency.bg/CR/Reports/VerificationPersonOrg",
      "rios" => "https://www.registryagency.bg/bg/registri/rios/izvrashvane-na-spravki-za-izbran-rezhim-imushestveni-otnoshenia/",
      "court_cases" => "https://ecase.justice.bg/",
      "builders" => "https://register.ksb.bg/",
      "consultants" => "https://dnsk.bg/registri/registar-na-liczata-izvarshvasthi-dejnostta-konsultant-sagl-chl-166-al-1-t-1-ot-zut-2003/",
      "energy" => "https://portal.seea.government.bg/bg/IndustrialSystemsReport",
      "flood" => "https://isurn.moew.government.bg/ISURN.Web/BaseProject/homepage/index.html",
      "landslides" => "https://gis.mrrb.government.bg/",
      "protected_areas" => "https://eea.government.bg/zpo/bg/index_download.jsp",
      "heritage" => "https://ninkn.bg/",
      "openstreetmap" => "https://www.openstreetmap.org/",
      "sofia_open_data" => "https://urbandata.sofia.bg/"
    }.freeze

    REGISTRY_SOURCES = {
      "design_visas" => "nag_design_visas",
      "building_permits" => "nag_building_permits",
      "urban_planning_orders" => "nag_urban_planning_orders",
      "occupancy_certificates" => "nag_occupancy_certificates"
    }.freeze

    def initialize(analysis:, facts:)
      @analysis = analysis
      @facts = facts
    end

    def call
      [
        section("identity", [
          topic("cadastre_identity", cadastre_result, sources("cadastre", run_key: "cadastre")),
          topic("area_comparison", @facts["subject_area_sqm"] ? "partial_in_report" : "request_document", sources("cadastre", run_key: "cadastre")),
          topic("included_rights", "external_official_check", sources("cadastre", "property_registry")),
          topic("boundaries_access", @analysis.parcel_geometry ? "partial_in_report" : "external_official_check", sources("cadastre", "eprut"))
        ]),
        section("planning_construction", [
          topic("zoning_plans", planning_result, sources("nag", "eprut", run_key: planning_run_key)),
          registry_topic("design_visa", "design_visas"),
          registry_topic("building_permit", "building_permits"),
          topic("construction_stage", "request_document"),
          registry_topic("occupancy", "occupancy_certificates", additional_sources: [ "dnsk_commissioning" ]),
          topic("enforcement_changes", "external_official_check", sources("dnsk_registers", "nag", "eprut"))
        ]),
        section("legal_seller", [
          topic("title_chain", "external_official_check", sources("property_registry")),
          topic("encumbrances", "external_official_check", sources("property_registry")),
          topic("seller_company", "external_official_check", sources("commercial_registry")),
          topic("authority_family", "external_official_check", sources("commercial_registry", "rios")),
          topic("disputes_insolvency", "external_official_check", sources("commercial_registry", "court_cases"))
        ]),
        section("building_condition", [
          topic("approved_layout", "request_document"),
          topic("technical_inspection", "professional_review"),
          topic("technical_passport_warranties", "request_document"),
          topic("energy_certificate", "external_official_check", sources("energy")),
          topic("contractor_supervisor", "external_official_check", sources("builders", "consultants")),
          topic("condominium", "request_document")
        ]),
        section("location_context", [
          topic("flood_risk", flood_result, sources("flood", run_key: "sofiaplan_dataset_flood_risk"), count: flood_intersections),
          topic("geological_environmental", "external_official_check", sources("landslides", "protected_areas")),
          topic("cultural_heritage", "external_official_check", sources("heritage", "nag")),
          topic("surroundings", surroundings_result, surroundings_sources),
          topic("utilities_access", "request_document")
        ]),
        section("transaction", [
          topic("taxes_debts", "request_document"),
          topic("market_value", "professional_review"),
          topic("deposit_contract", "professional_review"),
          topic("final_day_controls", "professional_review", sources("property_registry"))
        ])
      ]
    end

    private

    def section(key, items)
      { "key" => key, "items" => items }
    end

    def topic(key, result, source_links = [], count: nil)
      {
        "key" => key,
        "result" => result,
        "count" => count,
        "sources" => source_links
      }.compact
    end

    def registry_topic(key, registry_kind, additional_sources: [])
      count = @analysis.administrative_acts.where(registry_kind:).count
      run_key = REGISTRY_SOURCES.fetch(registry_kind)
      result = if count.positive?
        "found_in_report"
      else
        source_result(run_key)
      end
      source_keys = [ "nag", *additional_sources ]
      topic(key, result, sources(*source_keys, run_key:), count: count.positive? ? count : nil)
    end

    def cadastre_result
      return "verified_in_report" if latest_source_status("cadastre") == "succeeded" && cadastral_facts?

      source_result("cadastre")
    end

    def cadastral_facts?
      @facts["subject_area_sqm"].present? || @facts["address"].present? || @facts.fetch("cadastre_records", {}).present?
    end

    def planning_result
      return "verified_in_report" if @analysis.summary.dig("planning_summary", "available") == true
      return "checked_no_match" if planning_run_key

      "source_unavailable"
    end

    def planning_run_key
      %w[arcgis_functional_zoning arcgis_development_potential].find do |key|
        latest_source_status(key) == "succeeded"
      end
    end

    def flood_result
      @analysis.metrics.dig("environment", "available") == true ? "flood_assessed" : "source_unavailable"
    end

    def flood_intersections
      @analysis.metrics.dig("environment", "flood_risk_intersections").to_i
    end

    def surroundings_result
      availability = @analysis.metrics.dig("amenities", "availability").to_h
      availability.value?(true) ? "verified_in_report" : "source_unavailable"
    end

    def surroundings_sources
      keys = %w[
        openstreetmap_nearby_amenities
        sofiaplan_dataset_schools
        sofiaplan_dataset_kindergartens
        sofiaplan_dataset_green_spaces
        sofiaplan_dataset_transit
      ]
      links = keys.filter_map do |key|
        run = latest_source_run(key)
        next unless run&.source_url.present?

        { "key" => key, "url" => run.source_url }
      end
      links.presence || sources("openstreetmap", "sofia_open_data")
    end

    def source_result(run_key)
      latest_source_status(run_key) == "succeeded" ? "checked_no_match" : "source_unavailable"
    end

    def sources(*keys, run_key: nil)
      keys.uniq.filter_map.with_index do |key, index|
        run_url = latest_source_run(run_key)&.source_url if index.zero? && run_key.present?
        url = run_url.presence || SOURCE_URLS[key]
        { "key" => key, "url" => url } if url.present?
      end
    end

    def latest_source_status(key)
      latest_source_run(key)&.status
    end

    def latest_source_run(key)
      return if key.blank?

      @latest_source_runs ||= {}
      @latest_source_runs[key] ||= @analysis.source_runs.where(source_key: key).order(id: :desc).first
    end
  end
end
