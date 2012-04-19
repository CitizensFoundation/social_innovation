module OpenID
  class StandardFetcher

    def fetch(url, body=nil, headers=nil, redirect_limit=REDIRECT_LIMIT)
      unparsed_url = url.dup
      url = URI::parse(url)
      if url.nil?
        raise FetchingError, "Invalid URL: #{unparsed_url}"
      end

      headers ||= {}
      headers['User-agent'] ||= USER_AGENT

      begin
        conn = make_connection(url)
        response = nil

        response = conn.start {
          # Check the certificate against the URL's hostname
          if supports_ssl?(conn) and conn.use_ssl?
            conn.post_connection_check(url.host)
          end

          if body.nil?
            conn.request_get(url.url, headers)
          else
            headers["Content-type"] ||= "application/x-www-form-urlencoded"
            conn.request_post(url.url, body, headers)
          end
        }
        setup_encoding(response)
        Rails.logger.info("IN PATCHED SETUP ENCODING")
      rescue Timeout::Error => why
        raise FetchingError, "Error fetching #{url}: #{why}"
      rescue RuntimeError => why
        raise why
      rescue OpenSSL::SSL::SSLError => why
        raise SSLFetchingError, "Error connecting to SSL URL #{url}: #{why}"
      rescue FetchingError => why
        raise why
      rescue Exception => why
        raise FetchingError, "Error fetching #{url}: #{why}"
      end

      case response
      when Net::HTTPRedirection
        if redirect_limit <= 0
          raise HTTPRedirectLimitReached.new(
            "Too many redirects, not fetching #{response['location']}")
        end
        begin
          return fetch(response['location'], body, headers, redirect_limit - 1)
        rescue HTTPRedirectLimitReached => e
          raise e
        rescue FetchingError => why
          raise FetchingError, "Error encountered in redirect from #{url}: #{why}"
        end
      else
        return HTTPResponse._from_net_response(response, unparsed_url)
      end
    end

    private
    def setup_encoding(response)
      return unless defined?(::Encoding::UTF_8)
      charset = response.type_params["charset"]
      return if charset.nil?
      encoding = nil
      begin
        encoding = Encoding.find(charset)
      rescue ArgumentError
      end
      encoding ||= ::Encoding::UTF_8
      body = response.body
      if body.respond_to?(:force_encoding)
        body.force_encoding(encoding)
      else
        body.set_encoding(encoding)
      end
    end    
  end
end