require "rails_helper"

RSpec.describe Vies::LiveProvider do
  let(:service_url) { "https://ec.europa.eu/taxation_customs/vies/services/checkVatService" }
  let(:client) { instance_double(DataSources::HttpClient) }
  let(:response) { Struct.new(:body).new(response_xml) }
  let(:response_xml) do
    <<~XML
      <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Body>
          <checkVatResponse xmlns="urn:ec.europa.eu:taxud:vies:services:checkVat:types">
            <countryCode>BG</countryCode>
            <vatNumber>205479841</vatNumber>
            <requestDate>2026-09-10+03:00</requestDate>
            <valid>true</valid>
            <name>НЕКСТ БИЛД ИНВЕСТ ЕООД</name>
            <address>Public address intentionally not retained</address>
          </checkVatResponse>
        </env:Body>
      </env:Envelope>
    XML
  end

  it "checks an exact Bulgarian EIK without retaining the returned address" do
    expect(client).to receive(:post) do |url, body, headers|
      expect(url).to eq(service_url)
      expect(body).to include("<urn:countryCode>BG</urn:countryCode>", "<urn:vatNumber>205479841</urn:vatNumber>")
      expect(headers).to include("Content-Type" => "text/xml; charset=utf-8")
      response
    end

    result = described_class.new(config: { "service_url" => service_url }, client:).lookup(eik: "205479841")

    expect(result).to be_success
    expect(result.data).to eq(
      "eik" => "205479841",
      "country_code" => "BG",
      "vat_number" => "205479841",
      "vat_valid" => true,
      "legal_name" => "НЕКСТ БИЛД ИНВЕСТ ЕООД",
      "request_date" => "2026-09-10"
    )
    expect(result.data).not_to have_key("address")
  end
end
