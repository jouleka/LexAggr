module Admin
  class IngestionLogsController < ApplicationController
    def index
      @logs = IngestionLog.recent.includes(:jurisdiction).limit(100)
    end
  end
end
