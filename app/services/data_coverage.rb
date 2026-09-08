module DataCoverage
  class OutsideSearchCoverage < StandardError; end
  class DatasetNotPrepared < StandardError; end
  class ImportAlreadyRunning < StandardError; end

  def self.profile
    Profile.current
  end
end
