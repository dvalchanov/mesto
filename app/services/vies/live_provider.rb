module Vies
  class LiveProvider < Provider
    SOAP_NAMESPACE = "urn:ec.europa.eu:taxud:vies:services:checkVat:types".freeze

    def initialize(config:, client: DataSources::HttpClient.new)
      @config = config
      @client = client
    end

    def lookup(eik:)
      eik = BulgarianEik.normalize(eik)
      unless BulgarianEik.valid?(eik)
        return DataSources::Result.unavailable(
          source_url: service_url,
          error: PublicRegistry::NoReliableIdentifier.new("VIES requires an exact valid Bulgarian EIK")
        )
      end

      response = @client.post(
        service_url,
        request_xml(eik),
        "Content-Type" => "text/xml; charset=utf-8",
        "Accept" => "text/xml"
      )
      payload = parse_response(response.body, eik:)
      relevant_at = payload["request_date"].present? ? Time.zone.parse(payload.fetch("request_date")) : nil
      DataSources::Result.success(
        data: payload,
        source_url: service_url,
        relevant_at:,
        raw_response: response.body
      )
    rescue StandardError => error
      DataSources::Result.failure(source_url: service_url, error:)
    end

    private

    def service_url = @config.fetch("service_url")

    def request_xml(eik)
      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml["soapenv"].Envelope(
          "xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
          "xmlns:urn" => SOAP_NAMESPACE
        ) do
          xml["soapenv"].Body do
            xml["urn"].checkVat do
              xml["urn"].countryCode("BG")
              xml["urn"].vatNumber(eik)
            end
          end
        end
      end.to_xml
    end

    def parse_response(body, eik:)
      document = Nokogiri::XML(body) { |config| config.strict.nonet }
      fault = document.at_xpath("//*[local-name()='Fault']")
      raise ArgumentError, fault.text.squish if fault

      response = document.at_xpath("//*[local-name()='checkVatResponse']")
      raise ArgumentError, "VIES returned no checkVatResponse" unless response

      vat_number = text_at(response, "vatNumber")
      raise ArgumentError, "VIES returned a different VAT number" unless BulgarianEik.normalize(vat_number) == eik

      request_date = text_at(response, "requestDate").to_s[/\A\d{4}-\d{2}-\d{2}/]
      {
        "eik" => eik,
        "country_code" => text_at(response, "countryCode"),
        "vat_number" => vat_number,
        "vat_valid" => ActiveModel::Type::Boolean.new.cast(text_at(response, "valid")),
        "legal_name" => meaningful_name(text_at(response, "name")),
        "request_date" => request_date
      }.compact
    end

    def text_at(node, local_name)
      node.at_xpath("./*[local-name()='#{local_name}']")&.text&.squish
    end

    def meaningful_name(value)
      value if value.present? && !value.match?(/\A[-.\s]+\z/)
    end
  end
end
