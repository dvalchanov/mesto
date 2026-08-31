module ApplicationHelper
  CADASTRE_COMMON_FIELDS = %w[
    settlement_name address district locality street_name street_number place old_identifier
    ownership_type validation_document geometry_available technical_components
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
    return source_record_count(run).positive? ? "records_found" : "no_match" if run.source_key.start_with?("nag_", "arcgis_")
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
    features = []
    if analysis.centroid
      features << map_feature(analysis.centroid, kind: "selected", label: analysis.submitted_identifier)
    end
    if analysis.parcel_geometry
      features << map_feature(analysis.parcel_geometry, kind: "parcel", label: analysis.parcel_identifier)
    end
    acts.where.not(geometry: nil).limit(100).each do |act|
      features << map_feature(act.geometry, kind: "act", label: act.title.presence || act.act_number, source_url: act.source_url)
    end
    if analysis.full_report_unlocked? && analysis.centroid
      SpatialFeature.within(analysis.centroid, 2_000).includes(:spatial_dataset).limit(250).each do |feature|
        features << map_feature(
          feature.geometry, kind: "amenity", category: feature.category,
          label: feature.name, source_url: feature.spatial_dataset.source_url
        )
      end
    end
    Array(analysis.summary["planning"]).each do |layer|
      Array(layer["features"]).each do |feature|
        features << feature.deep_dup.tap do |entry|
          entry["properties"] = entry.fetch("properties", {}).merge(
            "kind" => "planning", "source_key" => layer["source_key"]
          )
        end
      end
    end
    { type: "FeatureCollection", features: }
  end

  private

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

  def map_feature(geometry, properties)
    {
      type: "Feature",
      geometry: RGeo::GeoJSON.encode(geometry),
      properties: properties.compact
    }
  end
end
