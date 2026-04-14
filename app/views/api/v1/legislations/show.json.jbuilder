json.data do
  json.id @legislation.id
  json.frbr_uri @legislation.frbr_uri
  json.celex_number @legislation.celex_number
  json.eli_uri @legislation.eli_uri
  json.title @legislation.title
  json.legislation_type @legislation.legislation_type
  json.year @legislation.year
  json.status @legislation.status
  json.content_hash @legislation.content_hash
  json.jurisdiction do
    json.code @legislation.jurisdiction.code
    json.name @legislation.jurisdiction.name
  end
  json.versions @versions do |version|
    json.id version.id
    json.version_uri version.version_uri
    json.language version.language
    json.valid_from version.valid_from
    json.valid_to version.valid_to
    json.publication_date version.publication_date
    json.version_type version.version_type
    json.has_content version.content.present?
  end
  json.created_at @legislation.created_at
  json.updated_at @legislation.updated_at
end
