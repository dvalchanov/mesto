module ApplicationHelper
  AMENITY_DATA_MAX_AGE_YEARS = 2

  def localized_copy(bg, en)
    LocalizedCopy.call(bg, en)
  end

  def localized_page_path(locale)
    route_locale = locale.to_sym == I18n.default_locale ? nil : locale
    route_options = request.path_parameters.symbolize_keys.except(:format).merge(locale: route_locale, only_path: true)
    url_for(route_options)
  end

  def localized_page_url(locale)
    "#{seo_origin}#{localized_page_path(locale)}"
  end

  def seo_origin
    Rails.env.production? ? "https://#{Rails.application.config.x.app_host}" : request.base_url
  end

  def checkout_enabled?
    Rails.application.config.x.checkout_enabled
  end

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
    "refresh" => '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
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

  def property_graph_entity_type(entity_type)
    t("reports.property_graph.entity_types.#{entity_type}", default: entity_type.to_s.humanize)
  end

  def property_graph_relationship_type(relationship_type)
    t("reports.property_graph.relationship_types.#{relationship_type}", default: relationship_type.to_s.humanize)
  end

  def property_graph_relationship_graph_label(relationship_type)
    t(
      "reports.property_graph.graph_relationship_types.#{relationship_type}",
      default: property_graph_relationship_type(relationship_type)
    )
  end

  def property_graph_fact_label(key)
    t("reports.property_graph.fact_labels.#{key}", default: key.to_s.humanize)
  end

  def property_graph_fact_value(value)
    case value
    when Hash
      value.filter_map { |key, child| "#{property_graph_fact_label(key)}: #{property_graph_fact_value(child)}" if child.present? }.join(" · ")
    when Array
      value.map { |child| property_graph_fact_value(child) }.join(" · ")
    when true
      t("common.yes", default: "Yes")
    when false
      t("common.no", default: "No")
    else
      t("reports.property_graph.fact_values.#{value}", default: value)
    end
  end

  def property_graph_date(value)
    return t("common.unknown_date") if value.blank?

    parsed = value.respond_to?(:to_date) && !value.is_a?(String) ? value.to_date : Time.zone.parse(value.to_s).to_date
    l(parsed, format: :short)
  rescue ArgumentError, TypeError
    t("common.unknown_date")
  end

  def property_graph_relationship_statement(edge)
    date = property_graph_date(edge["source_date"])
    case edge["relationship_type"]
    when "cadastre_right_holder"
      t(
        "reports.property_graph.cadastre_right_holder_as_of",
        holder: edge["object_name"],
        right_type: edge.dig("evidence", "right_type"),
        date:
      )
    when "registered_owner"
      t("reports.property_graph.registered_owner_as_of", owner: edge["object_name"], date:)
    when "previous_registered_owner"
      t("reports.property_graph.previous_registered_owner_as_of", owner: edge["object_name"], date:)
    else
      statement = t(
        "reports.property_graph.relationship_statement",
        subject: edge["subject_name"],
        relationship: property_graph_relationship_type(edge["relationship_type"]),
        target: edge["object_name"]
      )
      edge["active"] ? statement : "#{statement} (#{t('reports.property_graph.historical')})"
    end
  end

  def property_graph_status_classes(status)
    {
      "exact" => "bg-emerald-50 text-emerald-800",
      "supported" => "bg-sky-50 text-sky-800",
      "conflicting" => "bg-rose-50 text-rose-800",
      "unresolved" => "bg-slate-100 text-slate-700"
    }.fetch(status, "bg-slate-100 text-slate-700")
  end

  def property_graph_limitation_text(value)
    t("reports.property_graph.limitations.#{value}", default: value)
  end

  def property_graph_diagram_positions(nodes)
    positions = {}
    remaining = Array(nodes).dup
    { "property" => [ 1, 1 ], "building" => [ 2, 1 ], "parcel" => [ 3, 1 ] }.each do |entity_type, position|
      node = remaining.find { |candidate| candidate["entity_type"] == entity_type }
      next unless node

      positions[node["key"]] = position
      remaining.delete(node)
    end

    organizations, remaining = remaining.partition { |node| node["entity_type"].in?(%w[company organization]) }
    people, remaining = remaining.partition { |node| node["entity_type"] == "person" }
    context, remaining = remaining.partition do |node|
      node["entity_type"].in?(%w[planning_record project administrative_act])
    end

    organizations.each_with_index do |node, index|
      positions[node["key"]] = [ index % 3 + 1, index / 3 + 3 ]
    end
    people_start_row = 3 + (organizations.length / 3.0).ceil
    people.each_with_index do |node, index|
      positions[node["key"]] = [ index % 3 + 1, people_start_row + index / 3 ]
    end
    context.each_with_index { |node, index| positions[node["key"]] = [ 4, index + 1 ] }
    remaining.each_with_index { |node, index| positions[node["key"]] = [ index % 3 + 1, people_start_row + (people.length / 3.0).ceil + index / 3 ] }
    positions
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
    if run.status.in?(%w[failed unavailable])
      return "not_applicable" if run.source_key.in?(%w[commercial_register vies]) && run.request_metadata["access"] == "not_attempted_without_eik"
      return "restricted_access" if run.source_key == "property_register" && run.error_class == "PublicRegistry::AutomationUnavailable"
      return "contract_required" if run.source_key == "commercial_register" && run.error_class == "PublicRegistry::AutomationUnavailable"
    end
    return "needs_location" if run.source_key.start_with?("sofiaplan_dataset_", "arcgis_", "openstreetmap_") && !analysis.location_point
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
      "not_applicable" => "bg-slate-100 text-slate-700 ring-slate-200",
      "restricted_access" => "bg-slate-100 text-slate-700 ring-slate-200",
      "contract_required" => "bg-slate-100 text-slate-700 ring-slate-200",
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
    return unless result_key.in?(%w[not_applicable restricted_access contract_required needs_location unavailable failed])

    if result_key.in?(%w[not_applicable restricted_access contract_required])
      t("reports.sources.issues.#{result_key}")
    elsif result_key == "needs_location"
      t("reports.sources.issues.needs_location")
    elsif cadastre_archive_unavailable?(run)
      t("reports.sources.issues.cadastre_archive_unavailable")
    elsif run.error_class == "DataCoverage::DatasetNotPrepared"
      t("reports.sources.issues.dataset_not_prepared")
    elsif run.error_class == "DataCoverage::OutsideSearchCoverage"
      t("reports.sources.issues.outside_dataset")
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

  def due_diligence_result_classes(result)
    {
      "found_in_report" => "due-diligence-status--confirmed",
      "verified_in_report" => "due-diligence-status--confirmed",
      "flood_assessed" => "due-diligence-status--confirmed",
      "partial_in_report" => "due-diligence-status--review",
      "checked_no_match" => "due-diligence-status--review",
      "source_unavailable" => "due-diligence-status--attention",
      "external_official_check" => "due-diligence-status--review",
      "request_document" => "due-diligence-status--attention",
      "professional_review" => "due-diligence-status--professional"
    }.fetch(result, "due-diligence-status--review")
  end

  def due_diligence_result_text(item)
    options = item["count"].nil? ? {} : { count: item["count"] }
    t("reports.due_diligence.results.#{item['result']}", **options)
  end

  def progress_icon(status)
    { "completed" => "✓", "active" => "•", "failed" => "!", "unavailable" => "-", "pending" => "·" }.fetch(status, "·")
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

  BUYER_STAGE_LABELS = {
    "researching" => "Само разглеждам и се подготвям", "shortlisting" => "Сравнявам варианти",
    "before_deposit" => "Преди резервация или капаро", "before_preliminary_contract" => "Преди предварителен договор",
    "preliminary_contract_signed" => "Имам подписан предварителен договор", "waiting_or_payment" => "Чакам следващ строителен етап или плащане",
    "before_notarial_transfer" => "Подготвям нотариалната сделка", "before_handover" => "Предстои ми предаване на имота",
    "owner" => "Вече съм собственик", "unknown" => "Не съм сигурен"
  }.freeze
  PROPERTY_TYPE_LABELS = {
    "new_build" => "Ново строителство", "completed_home" => "Завършено жилище", "house" => "Къща",
    "land" => "Парцел", "undecided" => "Още не съм решил"
  }.freeze
  BUILDING_STAGE_LABELS = {
    "land_planning" => "Терен, планиране и проект", "authorization" => "Разрешение за строеж",
    "commencement" => "Начало и основи", "act14" => "Конструкция и Акт 14",
    "installations_act15" => "Инсталации и довършване", "act15" => "Подготовка за приемане и Акт 15",
    "commissioning" => "Въвеждане в експлоатация", "handover" => "Предаване и поддръжка", "unknown" => "Не знам"
  }.freeze
  FINANCING_LABELS = {
    "mortgage" => "Ипотечно финансиране", "own_funds" => "Собствени средства", "undecided" => "Още не съм решил"
  }.freeze
  BUYER_STAGE_LABELS_EN = {
    "researching" => "I'm researching and preparing", "shortlisting" => "I'm comparing options",
    "before_deposit" => "Before a reservation or deposit", "before_preliminary_contract" => "Before the preliminary contract",
    "preliminary_contract_signed" => "I've signed a preliminary contract", "waiting_or_payment" => "I'm waiting for the next construction stage or payment",
    "before_notarial_transfer" => "I'm preparing for the notarial transfer", "before_handover" => "My property is about to be handed over",
    "owner" => "I'm already an owner", "unknown" => "I'm not sure"
  }.freeze
  PROPERTY_TYPE_LABELS_EN = {
    "new_build" => "New construction", "completed_home" => "Completed home", "house" => "House",
    "land" => "Land", "undecided" => "I haven't decided yet"
  }.freeze
  BUILDING_STAGE_LABELS_EN = {
    "land_planning" => "Site, planning and design", "authorization" => "Building permit",
    "commencement" => "Commencement and foundations", "act14" => "Structure and Act 14",
    "installations_act15" => "Installations and finishing", "act15" => "Acceptance preparation and Act 15",
    "commissioning" => "Commissioning", "handover" => "Handover and maintenance", "unknown" => "I don't know"
  }.freeze
  FINANCING_LABELS_EN = {
    "mortgage" => "Mortgage financing", "own_funds" => "Own funds", "undecided" => "I haven't decided yet"
  }.freeze
  TERM_CATEGORY_DETAILS = {
    "cadastre_identity" => {
      label: "Идентичност на имота",
      title: "Какво точно е имотът?",
      description: "Понятията, с които проверяваш дали обявата, кадастърът, проектът и договорът описват един и същ имот."
    }.freeze,
    "ownership_rights" => {
      label: "Собственост и ползване",
      title: "Кой какво притежава и използва?",
      description: "Как се различават собствеността, владението, общите части и правата на други лица върху имота."
    }.freeze,
    "transaction_risk" => {
      label: "Сделка и вписвания",
      title: "Какво може да засегне придобиването?",
      description: "Как плащанията, ипотеките, възбраните и другите вписвания могат да повлияят на сделката."
    }.freeze,
    "construction" => {
      label: "Ново строителство",
      title: "Какво означават строителните етапи?",
      description: "Разликите между търговските названия, строителните документи, участниците и реалното изпълнение."
    }.freeze,
    "handover_operation" => {
      label: "Предаване и експлоатация",
      title: "Какво да провериш при предаването?",
      description: "Дефекти, гаранции, партиди и управление на сградата - въпроси, които не приключват с получаването на ключовете."
    }.freeze
  }.freeze
  DOCUMENT_CATEGORY_DETAILS = {
    "planning_construction" => {
      label: "Планиране и строителство",
      title: "Как се планира, разрешава и приема строежът?",
      description: "Планове, проекти, разрешения и приемателни актове - какво доказва всеки от тях и кога е необходим."
    }.freeze,
    "property_identity" => {
      label: "Имот и собственост",
      title: "Какво се продава и кой може да го прехвърли?",
      description: "Сравни точното описание на имота, документите за собственост, вписванията и правото на продавача да сключи сделката. Един документ рядко отговаря на всички въпроси."
    }.freeze,
    "agreements_finance" => {
      label: "Договори и финансиране",
      title: "Какви задължения поемаш преди сделката?",
      description: "Резервацията, посредничеството, предварителният договор и банковата оценка имат различни цели и не се заместват взаимно."
    }.freeze,
    "handover_operation" => {
      label: "Предаване и управление",
      title: "Какво следва след получаването на ключовете?",
      description: "Документите за състоянието, дефектите, гаранциите, таксите и управлението на сградата."
    }.freeze
  }.freeze
  TERM_CATEGORY_DETAILS_EN = {
    "cadastre_identity" => { label: "Property identity", title: "What exactly is the property?", description: "Terms that help you check whether the listing, cadastre, plans and contract describe the same property." }.freeze,
    "ownership_rights" => { label: "Ownership and use", title: "Who owns and uses what?", description: "How ownership, possession, common parts and third-party rights over the property differ." }.freeze,
    "transaction_risk" => { label: "Transaction and registrations", title: "What could affect the acquisition?", description: "How payments, mortgages, attachments and other registered matters may affect the transaction." }.freeze,
    "construction" => { label: "New construction", title: "What do the construction stages mean?", description: "The differences between marketing labels, construction records, project participants and the work actually completed." }.freeze,
    "handover_operation" => { label: "Handover and operation", title: "What should you check at handover?", description: "Defects, warranties, utilities and building management: questions that do not end when you receive the keys." }.freeze
  }.freeze
  DOCUMENT_CATEGORY_DETAILS_EN = {
    "planning_construction" => { label: "Planning and construction", title: "How is a project planned, authorised and accepted?", description: "Plans, designs, permits and acceptance documents: what each proves and when it is needed." }.freeze,
    "property_identity" => { label: "Property and ownership", title: "What is being sold, and who may transfer it?", description: "Compare the exact property description, title documents, registrations and the seller's authority. One document rarely answers every question." }.freeze,
    "agreements_finance" => { label: "Contracts and finance", title: "What obligations do you take on before completion?", description: "Reservation, brokerage, the preliminary contract and the bank valuation serve different purposes and do not replace one another." }.freeze,
    "handover_operation" => { label: "Handover and management", title: "What happens after you receive the keys?", description: "Documents covering condition, defects, warranties, charges and building management." }.freeze
  }.freeze

  def buyer_stage_label(key)
    labels = localized_copy(BUYER_STAGE_LABELS, BUYER_STAGE_LABELS_EN)
    labels[key.to_s] || labels["unknown"]
  end

  def property_type_label(key)
    labels = localized_copy(PROPERTY_TYPE_LABELS, PROPERTY_TYPE_LABELS_EN)
    labels[key.to_s] || labels["undecided"]
  end

  def building_stage_label(key)
    labels = localized_copy(BUILDING_STAGE_LABELS, BUILDING_STAGE_LABELS_EN)
    labels[key.to_s] || labels["unknown"]
  end

  def financing_label(key)
    labels = localized_copy(FINANCING_LABELS, FINANCING_LABELS_EN)
    labels[key.to_s] || labels["undecided"]
  end

  def education_term_category_details = localized_copy(TERM_CATEGORY_DETAILS, TERM_CATEGORY_DETAILS_EN)
  def education_document_category_details = localized_copy(DOCUMENT_CATEGORY_DETAILS, DOCUMENT_CATEGORY_DETAILS_EN)

  def education_term_groups(entries)
    grouped_entries = entries.group_by { |entry| entry["category"] }
    education_term_category_details.filter_map do |key, details|
      next if grouped_entries[key].blank?

      details.merge(key:, entries: grouped_entries[key])
    end
  end

  def education_term_category_label(key)
    education_term_category_details.dig(key.to_s, :label) || localized_copy("Имотно понятие", "Property term")
  end

  def education_document_groups(entries)
    grouped_entries = entries.select { |entry| entry["kind"] == "document" }.group_by { |entry| entry["category"] }
    groups = education_document_category_details.filter_map do |key, details|
      next if grouped_entries[key].blank?

      details.merge(key:, entries: grouped_entries[key])
    end
    supplemental_groups = localized_copy([
      [ "stage", "related_stages", "Строителни етапи", "На кой етап е строежът?", "Виж какво обикновено се изпълнява, кои документи са свързани с етапа и какво още остава непроверено." ],
      [ "guide", "buyer_guides", "Път на купувача", "Какво да направиш на своя етап?", "Насоки за решенията, документите и проверките, които са важни за теб в момента." ],
      [ "term", "related_terms", "Свързани термини", "Търсиш значението на понятие?", "Кратки определения и примери за думите, които най-често ще срещнеш в документите." ]
    ], [
      [ "stage", "related_stages", "Construction stages", "What stage has the project reached?", "See what usually happens, which documents relate to the stage and what remains unverified." ],
      [ "guide", "buyer_guides", "Buyer's journey", "What should you do at your stage?", "Guidance on the decisions, documents and checks that matter to you right now." ],
      [ "term", "related_terms", "Related terms", "Looking for the meaning of a term?", "Short definitions and examples of the words you are most likely to encounter in property documents." ]
    ]).filter_map do |kind, key, label, title, description|
      related_entries = entries.select { |entry| entry["kind"] == kind }
      next if related_entries.blank?

      { key:, label:, title:, description:, entries: related_entries }
    end

    groups + supplemental_groups
  end

  def education_document_category_label(key)
    education_document_category_details.dig(key.to_s, :label) || localized_copy("Имотен документ", "Property document")
  end

  def education_path_for(entry)
    case entry["kind"] || entry["path_kind"]
    when "stage" then new_build_stage_path(stage: entry["slug"])
    when "document" then education_document_path(slug: entry["slug"])
    when "term" then term_path(slug: entry["slug"])
    when "guide" then buying_guide_path(anchor: entry["buyer_stage"].presence || entry["slug"])
    else guide_path
    end
  end

  def education_source_date(source)
    date = source["source_updated_at"].presence
    date ? "#{localized_copy("Последна актуализация на източника", "Source last updated")}: #{l(Date.iso8601(date), format: :short)}" : localized_copy("Източникът не посочва дата на актуализация", "The source does not state when it was last updated")
  end

  def education_prose(value, css_class: nil)
    paragraphs = value.to_s.split(/\n{2,}/).map(&:strip).reject(&:blank?)
    classes = [ "prose-p", css_class ].compact.join(" ")
    safe_join(paragraphs.map { |paragraph| content_tag(:p, paragraph, class: classes) })
  end

  def evidence_status_label(status)
    localized_copy({
      "directly_found" => "Открит е пряк запис", "referenced_indirectly" => "Открита е косвена препратка",
      "user_reported" => "Посочено от теб", "requested_from_seller" => "Поискай от продавача",
      "separate_official_check_needed" => "Нужна е отделна официална проверка",
      "professional_review_needed" => "Нужен е професионален преглед",
      "no_matching_record_found" => "Не открихме съвпадащ запис", "source_unavailable" => "Източникът не е достъпен"
    }, {
      "directly_found" => "Direct record found", "referenced_indirectly" => "Indirect reference found",
      "user_reported" => "Reported by you", "requested_from_seller" => "Request from the seller",
      "separate_official_check_needed" => "Separate official check needed", "professional_review_needed" => "Professional review needed",
      "no_matching_record_found" => "No matching record found", "source_unavailable" => "Source unavailable"
    }).fetch(status.to_s, localized_copy("Предстои проверка", "To be checked"))
  end

  def checklist_applicability_label(status)
    localized_copy({
      "relevant_now" => "Важно сега", "later" => "По-късно",
      "conditional" => "При определени условия", "not_applicable" => "Вече не е приложимо"
    }, {
      "relevant_now" => "Important now", "later" => "Later",
      "conditional" => "Under certain conditions", "not_applicable" => "No longer applicable"
    }).fetch(status.to_s, localized_copy("За преглед", "For review"))
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
    return payload["record_count"].to_i if payload.is_a?(Hash) && payload.key?("record_count")
    return payload["feature_count"].to_i if payload.is_a?(Hash) && payload.key?("feature_count")

    0
  end
end
