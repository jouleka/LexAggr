class LegislationsController < ApplicationController
  def index
    @legislations = Legislation.includes(:jurisdiction).order(created_at: :desc)
    @legislations = @legislations.where(jurisdiction: Jurisdiction.find_by(code: params[:jurisdiction])) if params[:jurisdiction].present?
    @legislations = @legislations.by_type(params[:type]) if params[:type].present?
    @legislations = @legislations.by_year(params[:year]) if params[:year].present?
    @legislations = @legislations.where(status: params[:status]) if params[:status].present?
  end

  def show
    @legislation = Legislation.find(params[:id])
    @versions = @legislation.legislation_versions.includes(:content).order(valid_from: :desc)
    @current_version = @versions.current.first || @versions.first
    @document_tree = @current_version&.document_nodes&.roots&.order(:position) || []
    @raw_content = @current_version&.content&.raw_xml
  end
end
