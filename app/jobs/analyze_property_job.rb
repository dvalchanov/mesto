class AnalyzePropertyJob < ApplicationJob
  queue_as :analysis

  def perform(property_analysis_id)
    analysis = PropertyAnalysis.find(property_analysis_id)
    return if analysis.status.in?(%w[ready partial])

    Analysis::Runner.new(analysis).call
  end
end
