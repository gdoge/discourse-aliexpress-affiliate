# frozen_string_literal: true

# name: discourse-aliexpress-affiliate
# about: Automatically converts AliExpress URLs into affiliate links using the AliExpress Affiliate API
# meta_topic_id: TODO
# version: 1.0.0
# authors: Your Name
# url: TODO
# required_version: 2.7.0

enabled_site_setting :aliexpress_affiliate_enabled

module ::AliexpressAffiliatePlugin
  PLUGIN_NAME = "discourse-aliexpress-affiliate"
end

require_relative "lib/aliexpress_affiliate_plugin/engine"

after_initialize do
  require_relative "lib/aliexpress_affiliate_plugin/affiliate_link_converter"

  on(:post_process_cooked) do |doc, post|
    next unless SiteSetting.aliexpress_affiliate_enabled
    converter = AliexpressAffiliatePlugin::AffiliateLinkConverter.new
    converter.process_document(doc)
  end
end
