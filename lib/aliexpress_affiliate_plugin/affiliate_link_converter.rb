# frozen_string_literal: true
require "digest"
require "net/http"
require "uri"
require "json"

module AliexpressAffiliatePlugin
  class AffiliateLinkConverter
    API_ENDPOINT = "https://api-sg.aliexpress.com/sync"
    METHOD       = "aliexpress.affiliate.link.generate"
    SIGN_METHOD  = "sha256"

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

    def process_document(doc)
      doc.css("a[href]").each do |node|
        href = node["href"]
        next unless aliexpress_url?(href)
        affiliate = fetch_affiliate_url(href)
        node["href"] = affiliate if affiliate
      end

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

    def app_key
      SiteSetting.aliexpress_affiliate_app_key
    end

    def app_secret
      SiteSetting.aliexpress_affiliate_app_secret
    end

    def tracking_id
      SiteSetting.aliexpress_affiliate_tracking_id
    end

    def aliexpress_url?(url)
      url.to_s.match?(ALIEXPRESS_URL_PATTERN)
    end

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
        "method"              => METHOD,
        "app_key"             => app_key,
        "sign_method"         => SIGN_METHOD,
        "timestamp"           => (Time.now.to_f * 1000).to_i.to_s,
        "promotion_link_type" => "0",
        "source_values"       => source_url,
        "tracking_id"         => tracking_id,
      }
    end

    def sign(params)
      sorted_str = params.sort.map { |k, v| "#{k}#{v}" }.join
      payload    = "#{app_secret}#{sorted_str}#{app_secret}"
      OpenSSL::HMAC.hexdigest("SHA256", app_secret, payload).upcase
    end

    def parse_affiliate_url(body)
      data = JSON.parse(body)
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