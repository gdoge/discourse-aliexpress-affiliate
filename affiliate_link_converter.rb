# frozen_string_literal: true

require "digest"
require "net/http"
require "uri"
require "json"

module AliexpressAffiliatePlugin
  class AffiliateLinkConverter
    API_ENDPOINT = "https://api-sg.aliexpress.com/sync"
    APP_KEY      = SiteSetting.aliexpress_affiliate_app_key
    APP_SECRET   = SiteSetting.aliexpress_affiliate_app_secret
    METHOD       = "aliexpress.affiliate.link.generate"
    SIGN_METHOD  = "sha256"
    TRACKING_ID  = SiteSetting.aliexpress_affiliate_tracking_id

    ALIEXPRESS_URL_PATTERN = %r{
      https?://(?:www\.)?
      (?:
        aliexpress\.com|
        aliexpress\.us|
        aliexpress\.ru|
        a\.aliexpress\.com
      )
      [^\s"'<>]*
    }xi

    # Process a Nokogiri document in-place, replacing AliExpress anchor hrefs
    # and bare text URLs with affiliate versions.
    def process_document(doc)
      # 1) Replace href in existing <a> tags
      doc.css("a[href]").each do |node|
        href = node["href"]
        next unless aliexpress_url?(href)

        affiliate = fetch_affiliate_url(href)
        node["href"] = affiliate if affiliate
      end

      # 2) Replace bare URLs in text nodes (not already inside <a>)
      doc.xpath("//text()[not(ancestor::a)]").each do |text_node|
        content = text_node.content
        next unless content.match?(ALIEXPRESS_URL_PATTERN)

        new_html = content.gsub(ALIEXPRESS_URL_PATTERN) do |url|
          affiliate = fetch_affiliate_url(url)
          affiliate ? affiliate : url
        end

        next if new_html == content

        replacement = Nokogiri::HTML::DocumentFragment.parse(new_html)
        text_node.replace(replacement)
      end
    end

    private

    def aliexpress_url?(url)
      url.to_s.match?(ALIEXPRESS_URL_PATTERN)
    end

    # Call the AliExpress Affiliate API and return the promoted URL, or nil on failure.
    def fetch_affiliate_url(source_url)
      params = build_params(source_url)
      params["sign"] = sign(params)

      uri = URI(API_ENDPOINT)
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parse_affiliate_url(response.body)
    rescue StandardError => e
      Rails.logger.warn("[AliExpress Affiliate] Error fetching affiliate URL for #{source_url}: #{e.message}")
      nil
    end

    def build_params(source_url)
      {
        "method"               => METHOD,
        "app_key"              => APP_KEY,
        "sign_method"          => SIGN_METHOD,
        "timestamp"            => (Time.now.to_f * 1000).to_i.to_s,
        "promotion_link_type"  => "0",
        "source_values"        => source_url,
        "tracking_id"          => TRACKING_ID,
      }
    end

    # AliExpress HMAC-SHA256 signing:
    # 1. Sort params alphabetically by key
    # 2. Concatenate as key+value (no separators)
    # 3. Wrap with the app secret: SECRET + concat + SECRET
    # 4. Uppercase hex digest
    def sign(params)
      sorted_str = params.sort.map { |k, v| "#{k}#{v}" }.join
      payload    = "#{APP_SECRET}#{sorted_str}#{APP_SECRET}"
      OpenSSL::HMAC.hexdigest("SHA256", APP_SECRET, payload).upcase
    end

    def parse_affiliate_url(body)
      data = JSON.parse(body)

      # Navigate the nested AliExpress response structure
      result =
        data.dig("aliexpress_affiliate_link_generate_response", "resp_result", "result",
                 "promotion_links", "promotion_link")

      return nil unless result.is_a?(Array) && result.any?

      result.first["promotion_link"]
    rescue JSON::ParserError, NoMethodError => e
      Rails.logger.warn("[AliExpress Affiliate] Failed to parse API response: #{e.message}")
      nil
    end
  end
end
