# frozen_string_literal: true

AliexpressAffiliatePlugin::Engine.routes.draw do
  post "/convert" => "affiliate#convert"
end

Discourse::Application.routes.draw do
  mount ::AliexpressAffiliatePlugin::Engine, at: "aliexpress-affiliate"
end