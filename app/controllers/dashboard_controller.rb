class DashboardController < ApplicationController
  def index
    @jurisdictions = Jurisdiction.all
    @legislation_count = Legislation.count
    @recent_logs = IngestionLog.recent.limit(10).includes(:jurisdiction)
    @stats = {
      total_legislations: @legislation_count,
      jurisdictions_active: Jurisdiction.joins(:legislations).distinct.count,
      last_sync: IngestionLog.where(status: "completed").order(created_at: :desc).first&.created_at
    }
  end
end
