# frozen_string_literal: true

require "rails_helper"

describe AliexpressAffiliatePlugin::AffiliateLinkConverter do
  subject(:converter) { described_class.new }

  describe "#sign" do
    it "returns an uppercase hex string" do
      params = {
        "method"              => "aliexpress.affiliate.link.generate",
        "app_key"             => "529034",
        "sign_method"         => "sha256",
        "timestamp"           => "1772899233318",
        "promotion_link_type" => "0",
        "source_values"       => "https://www.aliexpress.us/item/3256811383538689.html",
        "tracking_id"         => "default",
      }
      sign = converter.send(:sign, params)
      expect(sign).to match(/\A[0-9A-F]+\z/)
    end
  end

  describe "#process_document" do
    let(:affiliate_url) { "https://s.click.aliexpress.com/e/_AFFILIATE" }

    before do
      allow(converter).to receive(:fetch_affiliate_url).and_return(affiliate_url)
    end

    it "replaces hrefs in anchor tags" do
      doc = Nokogiri::HTML::DocumentFragment.parse(
        '<a href="https://www.aliexpress.com/item/12345.html">Product</a>'
      )
      converter.process_document(doc)
      expect(doc.at_css("a")["href"]).to eq(affiliate_url)
    end

    it "does not touch non-AliExpress links" do
      doc = Nokogiri::HTML::DocumentFragment.parse(
        '<a href="https://www.example.com/product">Other</a>'
      )
      converter.process_document(doc)
      expect(doc.at_css("a")["href"]).to eq("https://www.example.com/product")
    end
  end
end
