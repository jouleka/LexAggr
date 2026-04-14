class EliController < ApplicationController
  allow_unauthenticated_access

  def resolve
    path = params[:path]

    # Try matching by eli_uri
    legislation = Legislation.find_by(eli_uri: "/eli/#{path}")
    legislation ||= Legislation.find_by(eli_uri: "http://data.europa.eu/eli/#{path}")

    # Try matching by frbr_uri
    legislation ||= Legislation.find_by(frbr_uri: "/eli/#{path}")
    legislation ||= Legislation.find_by(frbr_uri: "/#{path}")

    # Try matching by celex from path (e.g., /eli/celex/32016R0679)
    if path.start_with?("celex/")
      celex = path.sub("celex/", "")
      legislation ||= Legislation.find_by(celex_number: celex)
      legislation ||= Legislation.find_by(frbr_uri: "/eli/celex/#{celex}")
    end

    if legislation
      redirect_to legislation_path(legislation), status: :moved_permanently
    else
      render plain: "Legislation not found for ELI: /eli/#{path}", status: :not_found
    end
  end
end
