# frozen_string_literal: true

module AliexpressAffiliatePlugin
  class AffiliateController < ::ApplicationController
    requires_plugin "discourse-aliexpress-affiliate"
    skip_before_action :verify_authenticity_token
    before_action :ensure_plugin_enabled

    def convert
      url = params.require(:url)
      unless valid_aliexpress_url?(url)
        return render json: { error: "Invalid AliExpress URL" }, status: :unprocessable_entity
      end

      affiliate_url = ::AliexpressAffiliatePlugin::AffiliateLinkConverter.new.fetch_affiliate_url(url)

      if affiliate_url
        render json: { affiliate_url: affiliate_url }
      else
        render json: { error: "Failed to convert URL" }, status: :unprocessable_entity
      end
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.aliexpress_affiliate_enabled
    end

    def valid_aliexpress_url?(url)
      uri = URI.parse(url)
      uri.host&.match?(/aliexpress\.(com|us|ru)$/i)
    rescue URI::InvalidURIError
      false
    end
  end
end