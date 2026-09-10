require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::OwnershipArchiveImporter do
  let(:identifier) { "68134.1000.2000" }
  let(:source_archive_key) { "област София/район Студентски/собственост ПИ.zip" }
  let(:source_url) { "https://kais.cadastre.bg/bg/OpenData/Download?fixture=rights" }

  before do
    CadastralProperty.create!(
      cadastral_identifier: identifier,
      identifier_level: "parcel",
      source_archive_key: "област София/район Студентски/поземлени имоти.zip",
      source_url:,
      source_relevant_at: Time.zone.parse("2026-09-01")
    )
  end

  it "imports exact company and public-body rights while omitting masked natural persons" do
    archive = build_archive([
      row(identifier:, holder_identifier: "200370069", holder_type: "Юридическо лице", holder_name: "ПРИМЕР ПРОЕКТ ЕООД"),
      row(identifier:, holder_identifier: "200370069", holder_type: "Юридическо лице", holder_name: "ПРИМЕР ПРОЕКТ ЕООД"),
      row(identifier:, holder_identifier: "0123456789abcdef0123456789abcdef", holder_type: "Физическо лице", holder_name: "****** ******"),
      row(identifier:, holder_identifier: "000696327", holder_type: "Община", holder_name: "СТОЛИЧНА ОБЩИНА")
    ])

    result = described_class.new(
      archive_path: archive.path,
      source_archive_key:,
      source_url:,
      archive_kind: :parcel_rights,
      relevant_at: Time.zone.parse("2026-09-02"),
      coverage_profile: nil
    ).call

    expect(result).to have_attributes(status: "succeeded", records_seen: 4, records_imported: 2)
    expect(result.outcome_counts).to include("imported" => 2, "duplicate" => 1, "natural_person_omitted" => 1)
    expect(CadastreRight.where(cadastral_identifier: identifier).pluck(:holder_name, :holder_entity_type)).to contain_exactly(
      [ "ПРИМЕР ПРОЕКТ ЕООД", "company" ],
      [ "СТОЛИЧНА ОБЩИНА", "organization" ]
    )
    company = CadastreRight.find_by!(holder_name: "ПРИМЕР ПРОЕКТ ЕООД")
    expect(company).to have_attributes(
      holder_identifier: "200370069",
      right_type: "Право на собственост",
      document_type: "Нотариален акт",
      document_description: "№ 1 от 01.09.2026 г."
    )
    expect(CadastreRight.where("holder_name LIKE ?", "%*%")).to be_empty
  ensure
    archive&.close!
  end

  private

  def row(identifier:, holder_identifier:, holder_type:, holder_name:)
    [
      "Поземлен имот", identifier, "1", "Право на собственост", "Ид. част 100%",
      holder_identifier, "2", holder_type, holder_name, nil,
      "1", "Нотариален акт", "№ 1 от 01.09.2026 г.", nil
    ]
  end

  def build_archive(rows)
    headers = DataSources::CadastreOpenData::OwnershipArchiveImporter::HEADERS.values
    worksheet = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.worksheet(xmlns: "http://schemas.openxmlformats.org/spreadsheetml/2006/main") do
        xml.sheetData do
          [ headers, *rows ].each_with_index do |values, row_index|
            xml.row(r: row_index + 1) do
              values.each_with_index do |value, column_index|
                reference = "#{column_name(column_index)}#{row_index + 1}"
                xml.c(r: reference, t: "str") { xml.v(value.to_s) }
              end
            end
          end
        end
      end
    end.to_xml

    workbook = Tempfile.new([ "rights-workbook", ".xlsx" ])
    workbook.close
    Zip::File.open(workbook.path, create: true) do |zip|
      zip.get_output_stream("xl/worksheets/sheet1.xml") { |io| io.write(worksheet) }
    end
    archive = Tempfile.new([ "rights-archive", ".zip" ])
    archive.close
    Zip::File.open(archive.path, create: true) do |zip|
      zip.get_output_stream("собственост ПИ.xlsx") { |io| IO.copy_stream(workbook.path, io) }
    end
    archive
  ensure
    workbook&.close!
  end

  def column_name(index)
    value = index + 1
    result = +""
    while value.positive?
      value -= 1
      result.prepend((65 + (value % 26)).chr)
      value /= 26
    end
    result
  end
end
