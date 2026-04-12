class EurlexRssSyncJob < ApplicationJob
  queue_as :ingestion

  def perform
    jurisdiction = Jurisdiction.find_by!(code: "eu")
    service = Ingestion::EurlexRssService.new
    log = IngestionLog.create!(jurisdiction: jurisdiction, source_name: "eurlex_rss", status: "running")

    entries = service.fetch_new_entries

    entries.each do |entry|
      doc_ref = {
        celex_number: entry[:celex_number],
        title: entry[:title],
        frbr_uri: entry[:frbr_uri],
        legislation_type: detect_type_from_celex(entry[:celex_number]),
        date: entry[:published_at]&.to_date&.iso8601
      }
      ParseLegislationDocumentJob.perform_later("eu", doc_ref.to_json)
    end

    log.mark_completed!(documents_processed: entries.length)
  rescue StandardError => e
    log&.mark_failed!(e.message)
    Rails.logger.error("[EurlexRssSyncJob] Failed: #{e.message}")
  end

  private

  def detect_type_from_celex(celex)
    return "other" unless celex
    case celex[4]
    when "R" then "regulation"
    when "L" then "directive"
    when "D" then "decision"
    else "other"
    end
  end
end
