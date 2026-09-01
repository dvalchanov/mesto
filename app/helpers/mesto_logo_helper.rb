module MestoLogoHelper
  CELL_SIZE = 10
  CELL_GAP = 2
  LETTER_GAP = 1
  GRID_ROWS = 5

  LETTERFORMS = {
    "M" => %w[10001 11011 10101 10001 10001],
    "E" => %w[1111 1000 1110 1000 1111],
    "S" => %w[1111 1000 1111 0001 1111],
    "T" => %w[11111 00100 00100 00100 00100],
    "O" => %w[01110 10001 10001 10001 01110]
  }.freeze

  CELLS = begin
    column_offset = 0
    LETTERFORMS.flat_map do |letter, rows|
      cells = rows.each_with_index.flat_map do |row, row_index|
        row.chars.each_with_index.filter_map do |value, column_index|
          next unless value == "1"

          {
            key: "#{letter}:#{row_index}:#{column_index}",
            letter:,
            row: row_index,
            column: column_offset + column_index
          }.freeze
        end
      end
      column_offset += rows.first.length + LETTER_GAP
      cells
    end.freeze
  end

  GRID_COLUMNS = CELLS.map { |cell| cell.fetch(:column) }.max + 1
  TONES = %i[primary accent secondary tertiary].freeze
  VARIANT_TONES = {
    monochrome: {},
    accent: { "M:2:2" => :accent },
    campaign: {
      "M:2:2" => :accent,
      "E:2:2" => :tertiary,
      "T:0:4" => :secondary,
      "O:2:4" => :secondary
    }
  }.freeze

  def mesto_wordmark(variant: :accent, theme: :light, animate: false, highlighted_cells: {}, css_class: nil, title: "Mesto")
    variant = variant.to_sym
    theme = theme.to_sym
    raise ArgumentError, "Unknown Mesto logo variant: #{variant}" unless VARIANT_TONES.key?(variant)
    raise ArgumentError, "Unknown Mesto logo theme: #{theme}" unless %i[light dark].include?(theme)

    tones = VARIANT_TONES.fetch(variant).merge(normalize_logo_highlights(highlighted_cells))
    logo_sequence = (@mesto_logo_sequence = @mesto_logo_sequence.to_i + 1)
    logo_id = "mesto-wordmark-#{logo_sequence}"
    title_id = "#{logo_id}-title"
    step = CELL_SIZE + CELL_GAP
    viewbox_width = ((GRID_COLUMNS - 1) * step) + CELL_SIZE
    viewbox_height = ((GRID_ROWS - 1) * step) + CELL_SIZE

    cells = CELLS.each_with_index.map do |cell, index|
      tone = tones.fetch(cell.fetch(:key), :primary)
      tag.rect(
        x: cell.fetch(:column) * step,
        y: cell.fetch(:row) * step,
        width: CELL_SIZE,
        height: CELL_SIZE,
        rx: 0.7,
        class: "mesto-wordmark__cell mesto-wordmark__cell--#{tone}",
        id: "#{logo_id}-#{cell.fetch(:key).tr(':', '-')}",
        data: { cell: cell.fetch(:key), letter: cell.fetch(:letter), tone: },
        style: "--cell-index: #{index}"
      )
    end

    content = []
    content << tag.title(title, id: title_id) if title.present?
    content.concat(cells)

    tag.svg(
      safe_join(content),
      class: [
        "mesto-wordmark",
        "mesto-wordmark--#{variant}",
        "mesto-wordmark--theme-#{theme}",
        ("mesto-wordmark--animated" if animate),
        css_class
      ].compact.join(" "),
      viewBox: "0 0 #{viewbox_width} #{viewbox_height}",
      preserveAspectRatio: "xMinYMid meet",
      role: ("img" if title.present?),
      focusable: "false",
      "aria-labelledby": (title_id if title.present?),
      "aria-hidden": ("true" if title.blank?),
      data: { logo: "mesto", variant:, rows: GRID_ROWS }
    )
  end

  private

  def normalize_logo_highlights(highlighted_cells)
    highlighted_cells.to_h.transform_keys(&:to_s).transform_values do |tone|
      normalized_tone = tone.to_sym
      raise ArgumentError, "Unknown Mesto logo tone: #{tone}" unless TONES.include?(normalized_tone)

      normalized_tone
    end
  end
end
