class JurisdictionSyncJob < ApplicationJob
  queue_as :ingestion

  def perform(jurisdiction_code)
    return unless Ingestion::IngestionServiceFactory.registered?(jurisdiction_code)

    jurisdiction = Jurisdiction.find_by!(code: jurisdiction_code)
    service = Ingestion::IngestionServiceFactory.for(jurisdiction_code)
    log = IngestionLog.create!(jurisdiction: jurisdiction, source_name: service.class.name.demodulize.underscore, status: "running")

    last_log = IngestionLog.where(jurisdiction: jurisdiction, status: "completed").order(created_at: :desc).where.not(id: log.id).first
    since = last_log&.created_at || 30.days.ago

    documents = service.fetch_document_list(since: since)

    documents.each do |doc_ref|
      ParseLegislationDocumentJob.perform_later(jurisdiction_code, doc_ref.to_json)
    end

    log.mark_completed!(documents_processed: documents.length)
  rescue StandardError => e
    log&.mark_failed!(e.message)
    Rails.logger.error("[JurisdictionSyncJob] #{jurisdiction_code} failed: #{e.message}")
  end
end
