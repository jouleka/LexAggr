module ApplicationHelper
  # Extract the <body> content from CELLAR XHTML, stripping the outer HTML/head wrapper
  def extract_body_content(xhtml)
    return "" if xhtml.blank?

    doc = Nokogiri::HTML(xhtml)
    body = doc.at_css("body")
    return xhtml unless body

    # Remove any script/style tags for safety
    body.css("script, style, link").each(&:remove)

    body.inner_html.html_safe
  end
end
