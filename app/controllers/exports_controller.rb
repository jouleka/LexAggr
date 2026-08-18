class ExportsController < ApplicationController
  allow_unauthenticated_access

  CSV_FORMULA_PREFIX = /\A[=+\-@\t\r]/

  def legislation_csv
    @legislation = Legislation.includes(:jurisdiction, :legislation_versions).find(params[:id])
    csv_data = generate_legislation_csv(@legislation)

    send_data csv_data, filename: "#{@legislation.celex_number || @legislation.id}_export.csv", type: "text/csv"
  end

  def legislation_pdf
    @legislation = Legislation.includes(:jurisdiction, legislation_versions: :content).find(params[:id])
    pdf_data = generate_legislation_pdf(@legislation)

    send_data pdf_data, filename: "#{@legislation.celex_number || @legislation.id}_export.pdf", type: "application/pdf"
  end

  def search_csv
    query = params[:q]
    results = if query.present?
      Legislation.search_full_text(query).includes(:jurisdiction)
    else
      Legislation.includes(:jurisdiction).order(updated_at: :desc)
    end
    results = results.where(jurisdiction: Jurisdiction.find_by(code: params[:jurisdiction])) if params[:jurisdiction].present?
    results = results.by_type(params[:type]) if params[:type].present?
    results = results.limit(1000)

    csv_data = generate_search_csv(results)
    send_data csv_data, filename: "lexaggr_search_export.csv", type: "text/csv"
  end

  private

  def generate_legislation_csv(legislation)
    require "csv"
    CSV.generate do |csv|
      csv << [ "Field", "Value" ]
      csv << [ "Title", csv_cell(legislation.title) ]
      csv << [ "FRBR URI", csv_cell(legislation.frbr_uri) ]
      csv << [ "CELEX", csv_cell(legislation.celex_number) ]
      csv << [ "ELI URI", csv_cell(legislation.eli_uri) ]
      csv << [ "Jurisdiction", csv_cell(legislation.jurisdiction.name) ]
      csv << [ "Type", csv_cell(legislation.legislation_type) ]
      csv << [ "Year", legislation.year ]
      csv << [ "Status", legislation.status ]
      csv << []
      csv << [ "Versions" ]
      csv << [ "Version URI", "Language", "Valid From", "Valid To", "Type" ]
      legislation.legislation_versions.each do |v|
        csv << [ v.version_uri, v.language, v.valid_from, v.valid_to, v.version_type ].map { |value| csv_cell(value) }
      end
    end
  end

  def generate_legislation_pdf(legislation)
    require "prawn"
    Prawn::Document.new do |pdf|
      pdf.text "LexAggr Export", size: 10, color: "999999"
      pdf.move_down 10
      pdf.text legislation.title, size: 18, style: :bold
      pdf.move_down 10

      metadata = [
        [ "Jurisdiction", legislation.jurisdiction.name ],
        [ "Type", legislation.legislation_type&.humanize ],
        [ "Year", legislation.year.to_s ],
        [ "Status", legislation.status&.humanize ],
        [ "CELEX", legislation.celex_number.to_s ],
        [ "FRBR URI", legislation.frbr_uri ]
      ]
      pdf.table(metadata, width: pdf.bounds.width) do |t|
        t.cells.borders = [ :bottom ]
        t.cells.border_color = "DDDDDD"
        t.columns(0).font_style = :bold
        t.columns(0).width = 120
      end

      # Add full text if available
      version = legislation.legislation_versions.first
      content = version&.content
      if content&.raw_xml.present?
        pdf.move_down 20
        pdf.text "Full Text", size: 14, style: :bold
        pdf.move_down 10
        # Strip HTML tags for plain text rendering
        plain_text = ActionController::Base.helpers.strip_tags(content.raw_xml)
        pdf.text plain_text.truncate(50000), size: 9, leading: 3
      end
    end.render
  end

  def generate_search_csv(results)
    require "csv"
    CSV.generate do |csv|
      csv << [ "Title", "Jurisdiction", "Type", "Year", "Status", "CELEX", "FRBR URI" ]
      results.each do |leg|
        csv << [ leg.title, leg.jurisdiction.code.upcase, leg.legislation_type, leg.year, leg.status, leg.celex_number, leg.frbr_uri ].map { |value| csv_cell(value) }
      end
    end
  end

  def csv_cell(value)
    return value unless value.is_a?(String) && value.match?(CSV_FORMULA_PREFIX)

    "'#{value}"
  end
end
