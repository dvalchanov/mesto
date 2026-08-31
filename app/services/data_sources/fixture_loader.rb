module DataSources
  class FixtureLoader
    class MissingFixture < StandardError; end

    def self.read(name)
      path = Rails.root.join("spec/fixtures/data_sources", name)
      raise MissingFixture, "Missing data-source fixture: #{name}" unless path.file?

      path.read
    end
  end
end
