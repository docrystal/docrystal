xml.instruct!
xml.OpenSearchDescription(:xmlns => 'http://a9.com/-/spec/opensearch/1.1/', 'xmlns:moz' => 'http://www.mozilla.org/2006/browser/search/') do
  xml.ShortName('docrystal')
  xml.InputEncoding('UTF-8')
  xml.Description('Search the doc of crystal shards')
  xml.Contact('info@docrystal.org')
  xml.Image(image_url('favicon_96.png'), height: 96, width: 96, type: 'image/png')
  # escape route helper or else it escapes the '{' '}' characters. then search doesn't work
  xml.Url(type: 'text/html', method: 'get', template: CGI::unescape(search_url(q: '{searchTerms}' )))
  xml.moz(:SearchForm, search_url)
end
