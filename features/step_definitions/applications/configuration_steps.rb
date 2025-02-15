# frozen_string_literal: true

Given "the {provider} does not allow its partners to manage application keys" do |provider|
  provider.default_service.update_attribute :buyers_manage_apps, true
  provider.default_service.update_attribute :buyers_manage_keys, false
end
