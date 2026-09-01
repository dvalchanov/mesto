require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::ArchiveClient do
  let(:download_url) { "https://kais.cadastre.bg/bg/OpenData/Download" }
  let(:config) { { "download_url" => download_url, "download_timeout" => 1 } }
  let(:archive_key) do
    "област София (столица)/община Столична/гр. София (68134) - район Студентски/поземлени имоти.zip"
  end

  it "classifies an unpublished official archive separately from a generic network failure" do
    stub_request(:get, download_url).with(query: { "path" => archive_key }).to_return(status: 500)

    expect { described_class.new(config:).download(archive_key) { } }
      .to raise_error(DataSources::CadastreOpenData::ArchiveUnavailable) do |error|
        expect(error.status).to eq(500)
        expect(error.message).to include("район Студентски")
      end
  end
end
