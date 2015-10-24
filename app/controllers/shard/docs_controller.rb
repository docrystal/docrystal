class Shard::DocsController < ApplicationController
  HOSTING_REGEXP = %r{#{Shard::HOSTINGS.map { |h| Regexp.escape(h) }.join('|')}}x
  OWNER_REGEXP = Shard::GITHUB_USER_NAME_REGEXP
  NAME_REGEXP = Shard::GITHUB_REPO_NAME_REGEXP
  SHA_REGEXP = %r{[^/]+}
  FILE_REGEXP = %r{.+}

  CONSTRAINTS = {
    hosting: HOSTING_REGEXP,
    owner: OWNER_REGEXP,
    name: NAME_REGEXP,
    sha: SHA_REGEXP,
    file: FILE_REGEXP
  }

  after_action :append_exdoc_to_body, only: %i(file_serve)

  class FileNotFound < StandardError
  end

  def repository(hosting, owner, name)
    @shard = Shard.find_or_create_by!(hosting: hosting, owner: owner, name: name)
    @ref = @shard.lookup_ref(@shard.default_branch)

    redirect_to doc_serve_path(hosting: hosting, owner: owner, name: name, sha: @ref.name, file: 'index.html')
  end

  def show(hosting, owner, name, sha)
    @shard = Shard.find_or_create_by!(hosting: hosting, owner: owner, name: name)
    @ref = @shard.lookup_ref(sha)

    fail FileNotFound unless @ref

    redirect_to doc_serve_path(hosting: hosting, owner: owner, name: name, sha: @ref.name, file: 'index.html')
  end

  def file_serve(hosting, owner, name, sha, file)
    @shard = Shard.find_or_create_by!(hosting: hosting, owner: owner, name: name)
    @doc = @shard.lookup_ref(sha)

    fail FileNotFound unless @doc

    return(render('generating')) unless @doc.generated?
    return(render('error', status: 500)) if @doc.error?

    @file = @doc.storage.get(file)

    if @file
      track_event('Show Document', repository: @shard.full_name, sha: @doc.sha, file: file)
      mimetype = MimeMagic.by_path(file)
      render(inline: @file.body, content_type: mimetype) if stale?(last_modified: @file.last_modified, public: true)
    else
      fail FileNotFound, "File Not Found: #{@shard.full_name}##{@doc.sha} / #{file}"
    end
  end

  private

  def append_exdoc_to_body
    body = response.body

    return unless @file

    header_insert_at = body.index('</head')
    return unless header_insert_at

    @original_doc = Nokogiri::HTML(body)
    @original_title = @original_doc.xpath('//title').first.content
    @original_doc.xpath('//title').first.remove

    head_element = @original_doc.at_css('head')
    head_element.inner_html += render_to_string(partial: 'exdoc_header')

    footer_insert_at = body.index('</body')
    return unless footer_insert_at


    body_element = @original_doc.at_css('body')
    body_element.inner_html += render_to_string(partial: 'exdoc_footer')

    response.body = @original_doc.to_html
  end
end
