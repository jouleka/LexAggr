json.data do
  json.code @jurisdiction.code
  json.name @jurisdiction.name
  json.jurisdiction_type @jurisdiction.jurisdiction_type
  json.legislation_count @legislation_count
  json.type_counts @type_counts
  json.status_counts @status_counts
end
