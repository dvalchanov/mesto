module ApplicationHelper
  AMENITY_DATA_MAX_AGE_YEARS = 2

  ICON_PATHS = {
    "arrow-right" => '<path d="M5 12h14M13 6l6 6-6 6"/>',
    "arrow-up-right" => '<path d="M7 17 17 7M7 7h10v10"/>',
    "book" => '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V4H6.5A2.5 2.5 0 0 0 4 6.5v13Z"/><path d="M8 7h8M8 11h6"/>',
    "building" => '<path d="M4 21h16M6 21V7l6-4 6 4v14M9 10h.01M15 10h.01M9 14h.01M15 14h.01M10 21v-3h4v3"/>',
    "check" => '<path d="m5 12 4 4L19 6"/>',
    "chevron-down" => '<path d="m6 9 6 6 6-6"/>',
    "document" => '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M8 13h8M8 17h5"/>',
    "layers" => '<path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5M3 17l9 5 9-5"/>',
    "lock" => '<rect width="16" height="12" x="4" y="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    "map-pin" => '<path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
    "menu" => '<path d="M4 6h16M4 12h16M4 18h16"/>',
    "route" => '<circle cx="6" cy="19" r="3"/><path d="M9 19h5.5a3.5 3.5 0 0 0 0-7h-5a3.5 3.5 0 0 1 0-7H15"/><circle cx="18" cy="5" r="3"/>',
    "search" => '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
    "shield" => '<path d="M20 13c0 5-3.5 7.5-8 9-4.5-1.5-8-4-8-9V5l8-3 8 3v8Z"/><path d="m9 12 2 2 4-4"/>',
    "spark" => '<path d="m12 3-1.4 4.1a5.5 5.5 0 0 1-3.5 3.5L3 12l4.1 1.4a5.5 5.5 0 0 1 3.5 3.5L12 21l1.4-4.1a5.5 5.5 0 0 1 3.5-3.5L21 12l-4.1-1.4a5.5 5.5 0 0 1-3.5-3.5L12 3Z"/>',
    "tree" => '<path d="M12 22v-7M9 18h6M5 13a4 4 0 0 0 4-4 3 3 0 1 1 6 0 4 4 0 0 0 4 4 4 4 0 0 1-4 4H9a4 4 0 0 1-4-4Z"/>'
  }.freeze

  def mesto_icon(name, css_class: "size-5")
    paths = ICON_PATHS.fetch(name)
    tag.svg(paths.html_safe, class: css_class, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.8, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": true)
  end

  CADASTRE_COMMON_FIELDS = %w[
    settlement_name address district locality street_name street_number place old_identifier
    ownership_type validation_document geometry_available source_crs technical_components
  ].freeze
  CADASTRE_LEVEL_FIELDS = {
    "individual_object" => %w[
      object_document_area outline_area_sqm perimeter_m object_number floor address_floor
      levels_count entrance block_number purpose additional_parts
    ],
    "building" => %w[
      building_footprint_area perimeter_m floors_count objects_count purpose
    ],
    "parcel" => %w[
      parcel_area perimeter_m regulation_parcel quarter territory_type permanent_use category_type
    ]
  }.freeze
  CADASTRE_CODE_FIELDS = {
    "purpose" => "purpose_code",
    "ownership_type" => "ownership_code",
    "territory_type" => "territory_code",
    "permanent_use" => "permanent_use_code"
  }.freeze
  CADASTRE_COMPONENT_KEYS = %w[
    settlement_code cadastre_area_code parcel_number building_number object_number
  ].freeze

  def source_name(source_key)
    t("reports.sources.names.#{source_key}", default: source_key.to_s.humanize)
  end

  def source_status_classes(status)
    {
      "succeeded" => "bg-emerald-50 text-emerald-700 ring-emerald-200",
      "failed" => "bg-rose-50 text-rose-700 ring-rose-200",
      "unavailable" => "bg-amber-50 text-amber-700 ring-amber-200",
      "running" => "bg-sky-50 text-sky-700 ring-sky-200",
      "pending" => "bg-slate-50 text-slate-600 ring-slate-200"
    }.fetch(status, "bg-slate-50 text-slate-600 ring-slate-200")
  end

  def source_result_key(run, analysis:)
    return "needs_location" if run.source_key.start_with?("sofiaplan_dataset_", "arcgis_") && !analysis.centroid
    return run.status unless run.status == "succeeded"
    return source_record_count(run).positive? ? "records_found" : "no_match" if run.source_key.start_with?("nag_", "arcgis_", "openstreetmap_")
    return "used_for_calculation" if run.source_key.start_with?("sofiaplan_dataset_")

    "data_returned"
  end

  def source_result_classes(result_key)
    {
      "records_found" => "bg-emerald-50 text-emerald-700 ring-emerald-200",
      "data_returned" => "bg-emerald-50 text-emerald-700 ring-emerald-200",
      "used_for_calculation" => "bg-sky-50 text-sky-700 ring-sky-200",
      "no_match" => "bg-slate-100 text-slate-700 ring-slate-200",
      "needs_location" => "bg-amber-50 text-amber-800 ring-amber-200",
      "unavailable" => "bg-amber-50 text-amber-800 ring-amber-200",
      "failed" => "bg-rose-50 text-rose-700 ring-rose-200",
      "running" => "bg-sky-50 text-sky-700 ring-sky-200",
      "pending" => "bg-slate-50 text-slate-600 ring-slate-200"
    }.fetch(result_key, "bg-slate-50 text-slate-600 ring-slate-200")
  end

  def source_result_text(run, analysis:)
    key = source_result_key(run, analysis:)
    options = key == "records_found" ? { count: source_record_count(run) } : {}
    t("reports.sources.results.#{key}", **options)
  end

  def source_issue_text(run, analysis:)
    result_key = source_result_key(run, analysis:)
    return unless result_key.in?(%w[needs_location unavailable failed])

    if result_key == "needs_location"
      t("reports.sources.issues.needs_location")
    elsif cadastre_archive_unavailable?(run)
      t("reports.sources.issues.cadastre_archive_unavailable")
    elsif run.source_key.start_with?("sofiaplan_dataset_")
      t("reports.sources.issues.spatial_dataset")
    else
      t("reports.sources.issues.#{result_key}")
    end
  end

  def dataset_relevance_text(metadata)
    date = dataset_relevance_date(metadata)
    return t("common.unknown_date") unless date

    t("common.relevant_at", date: l(date, format: :short))
  end

  def dataset_relevance_date(metadata)
    value = metadata.to_h["relevant_at"]
    Date.iso8601(value) if value.present?
  rescue ArgumentError, TypeError
    nil
  end

  def amenity_dataset_current?(metadata, as_of: Date.current)
    date = dataset_relevance_date(metadata)
    date.present? && date >= as_of.advance(years: -AMENITY_DATA_MAX_AGE_YEARS)
  end

  def checklist_status_classes(status)
    {
      "review" => "bg-emerald-50 text-emerald-800",
      "buyer_check" => "bg-sky-50 text-sky-800",
      "needs_document" => "bg-amber-50 text-amber-900",
      "not_checked" => "bg-slate-100 text-slate-700"
    }.fetch(status, "bg-slate-100 text-slate-700")
  end

  def progress_icon(status)
    { "completed" => "✓", "active" => "•", "failed" => "!", "unavailable" => "—", "pending" => "·" }.fetch(status, "·")
  end

  def formatted_price(amount_cents, currency)
    number_to_currency(amount_cents / 100.0, unit: currency == "EUR" ? "€" : currency, format: "%n %u", separator: ",", delimiter: " ")
  end

  def cadastral_record_fields(record, level)
    (CADASTRE_LEVEL_FIELDS.fetch(level) + CADASTRE_COMMON_FIELDS).filter_map do |field|
      value = cadastral_field_value(record, field)
      [ field, value ] if value.present?
    end
  end

  def cadastral_field_value(record, field)
    source_field = {
      "object_document_area" => "area_sqm",
      "building_footprint_area" => "area_sqm",
      "parcel_area" => "area_sqm"
    }.fetch(field, field)
    value = case source_field
    when "technical_components" then cadastral_components(record)
    when "source_crs" then record.dig("properties", "source_crs")
    else record[source_field]
    end
    return if value.blank?

    formatted = case source_field
    when "area_sqm", "outline_area_sqm"
      t("reports.cadastre_hierarchy.square_metres", value: number_with_precision(value, precision: 2, strip_insignificant_zeros: true))
    when "perimeter_m"
      t("reports.cadastre_hierarchy.metres", value: number_with_precision(value, precision: 2, strip_insignificant_zeros: true))
    when "geometry_available"
      value ? t("reports.cadastre_hierarchy.geometry_available") : nil
    else value
    end
    code = CADASTRE_CODE_FIELDS[source_field] && record[CADASTRE_CODE_FIELDS[source_field]]
    code.present? ? t("reports.cadastre_hierarchy.with_code", value: formatted, code:) : formatted
  end

  def report_map_payload(analysis, acts: AdministrativeAct.none)
    Analysis::ReportMapBuilder.new(analysis:, acts:).call
  end

  private

  def cadastre_archive_unavailable?(run)
    return false unless run.source_key == "cadastre"

    run.error_class == "DataSources::CadastreOpenData::ArchiveUnavailable" ||
      run.error_class == "Faraday::ServerError"
  end

  def cadastral_components(record)
    properties = record.fetch("properties", {})
    components = CADASTRE_COMPONENT_KEYS.filter_map do |key|
      value = properties[key]
      next if value.blank?

      label = t("reports.cadastre_hierarchy.component_labels.#{key}")
      "#{label}: #{value}"
    end
    components.join(" · ")
  end

  def source_record_count(run)
    payload = run.parsed_payload
    return payload.length if payload.is_a?(Array)
    return Array(payload["features"]).length if payload.is_a?(Hash) && payload.key?("features")
    return payload["count"].to_i if payload.is_a?(Hash) && payload.key?("count")

    0
  end
end
