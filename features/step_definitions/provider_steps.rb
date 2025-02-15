# frozen_string_literal: true

def import_simple_layout(provider)
  simple_layout = SimpleLayout.new(provider)
  simple_layout.import_pages!
  simple_layout.import_js_and_css! if @javascript
end

Given "a provider {string} signed up to {plan}" do |name, plan|
  @provider = FactoryBot.create(:provider_account_with_pending_users_signed_up_to_no_plan,
                      org_name: name,
                      domain: name,
                      self_domain: "admin.#{name}")
  @provider.application_contracts.delete_all

  unless @provider.bought?(plan)
    @provider.buy!(plan, name: 'Default', description: 'Default')
  end

  import_simple_layout(@provider)
end

Given(/^a provider "([^"]*)"$/) do |account_name|
  step %(a provider "#{account_name}" signed up to plan "Free")
end

Given(/^a provider "([^"]*)" with default plans$/) do |name|
  step %(a provider "#{name}")
  step %(a default service of provider "#{name}" has name "default")

  step %(a account plan "default_account_plan" of provider "#{name}")
  step %(account plan "default_account_plan" is default)

  step %(a service plan "default_service_plan" for service "default" exists)
  step %(service plan "default_service_plan" is default)

  step %(an application plan "Default" for service "default" exists)
  step %(application plan "Default" is default)
end

Given(/^the current provider is (.+?)$/) do |name|
  @provider = Account.providers.find_by_org_name!(name)
end

Given(/^a provider "(.*?)" with impersonation_admin admin$/) do |provider_name|
  step %(a provider "#{provider_name}")
  provider = Account.find_by_org_name(provider_name)
  if provider.admins.impersonation_admins.empty?
    FactoryBot.create :active_admin, username: ThreeScale.config.impersonation_admin['username'], account: provider
  end
end

Given(/^there is no provider with domain "([^"]*)"$/) do |domain|
  Account.find_by_domain(domain).try!(&:destroy)
end

When "{provider} creates sample data" do |provider|
  provider.create_sample_data!
end

Given(/^a provider signs up and activates his account$/) do
  step 'current domain is the admin domain of provider "master"'
  visit provider_signup_path

  user = FactoryBot.build_stubbed(:user)

  within signup_form do
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'supersecret'

    fill_in 'Organization/Group Name', with: 'provider'
    fill_in 'Developer Portal', with: 'foo'

    click_on 'Sign up'
  end

  page.should have_content('Thank you for signing up.')

  step 'current domain is the admin domain of provider "provider"'

  email = open_email(user.email, with_subject: 'Account Activation')
  click_first_link_in_email(email)

  stub_integration_errors_dashboard

  within login_form do
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'supersecret'

    click_on 'Sign in'
  end

  page.should have_content('Signed in successfully')

  @provider = Account.find_by_self_domain!(@domain)
end

Then(/^the provider should not have any notifications$/) do
  notifications = Notification.where(user_id: @provider.users)

  assert_equal 0, notifications.count
end

def signup_form
  find('#signup_form')
end

def login_form
  find('#new_session')
end

Given('a provider exists') do
  step 'a provider "foo.3scale.localhost"'
  @service ||= @provider.default_service
end

Given('Provider has setup RH SSO') do
  step 'a provider "foo.3scale.localhost"'
  steps <<-GHERKIN
  And the provider account allows signups
  And the provider has the authentication provider "Keycloak" published
  And current domain is the admin domain of provider "#{@provider.internal_domain}"
  And the current domain is "#{@provider.external_domain}"
  GHERKIN
end

And('As a developer, I login through RH SSO') do
  steps <<-GHERKIN
    And I go to the login page
    Then I should see the link "Authenticate with #{@authentication_provider.name}" containing "auth/realms/3scale/protocol/openid-connect/auth client_id= redirect_uri= response_type=code scope" in the URL
  GHERKIN
end

Given(/^a provider( is logged in)?$/) do |login|
  setup_provider(login)
end

Given(/^a provider( is logged in)? with a product "([^"]*)"$/) do |login, name|
  setup_provider(login)
  @service = @provider.services.create!(name: name, mandatory_app_key: false)
end

def setup_provider(login)
  step 'a provider "foo.3scale.localhost"'
  step 'current domain is the admin domain of provider "foo.3scale.localhost"'
  stub_integration_errors_dashboard
  step 'I log in as provider "foo.3scale.localhost"' if login

  @provider = Account.find_by_domain!('foo.3scale.localhost')
end

Given(/^master admin( is logged in)?/) do |login|
  @master = @provider = Account.master
  admin = @provider.admins.first!
  step %(the current domain is "#{Account.master.external_domain}")
  stub_integration_errors_dashboard
  step %(I log in as provider "#{admin.username}") if login
end

Given(/^a master admin with extra fields is logged in/) do
  step 'master admin is logged in'
  FactoryBot.create(:fields_definition, account: @master, target: 'Account', name: 'account_extra_field')
end

Given "the provider has spam protection set to suspicious only" do
  step %(provider "#{@provider.org_name}" has "spam protection level" set to "auto")
end

When /^new form to create a tenant is filled and submitted$/ do
  @username = 'usernamepro'
  fill_and_submit_form_to_create_tenant(username: @username)
end

When /^new form to create a tenant is filled and submitted with invalid data$/ do
  @expected_flash_errors = [attribute: :username, message: 'is too short'] # Empty username
  fill_and_submit_form_to_create_tenant(username: '')
end

def fill_and_submit_form_to_create_tenant(username:)
  visit new_provider_admin_account_path
  fill_in('account_user_username', :with => username, visible: true)
  fill_in('account_user_email', :with => 'provider@email.com', visible: true)
  fill_in('account_user_password', :with => '123456', visible: true)
  fill_in('account_user_password_confirmation', :with => '123456', visible: true)
  fill_in('account_org_name', :with => 'organizationprovider', visible: true)
  click_button 'Create'
end

Given(/^a provider with one active member is logged in$/) do
  step 'a provider is logged in'
  step %(an active user "alex" of account "#{@provider.internal_domain}")
end

When(/^I have opened edit page for the active member$/) do
  step 'I go to the provider users page'
  step 'I follow "Edit" for user "alex"'
  step 'I should see "Edit User"'
end

Then(/^no permissions should be checked$/) do
  within('.FeatureAccessList') do
    all('input[type=checkbox]').each do |input|
      refute(input.checked?) if input.value.present?
    end
  end
end

Given(/^the provider account allows signups$/) do
  step %(provider "#{@provider.internal_domain}" has multiple applications disabled)
  step %(provider "#{@provider.internal_domain}" has default service and account plan)
  step %(a default application plan "Base" of provider "#{@provider.internal_domain}")
end

And "the provider has a buyer with an application" do
  application_plan = create_plan(:application, name: 'Default', issuer: @provider, published: true, default: true)
  service_plan = create_plan(:service, name: 'Gold', issuer: @provider)

  @buyer = FactoryBot.create(:buyer_account, provider_account: @provider, org_name: 'The Buyer INC.')
  @buyer.buy!(@provider.account_plans.default)
  @buyer.buy!(service_plan)

  FactoryBot.create(:cinstance, user_account: @buyer, plan: application_plan, name: 'Test App')
end

When(/^the provider deletes the (account|application)(?: named "([^"]*)")?$/) do |account_or_service, account_or_application_name|
  account_or_application_name ||= account_or_service == 'application' ? "Alexisonfire" : "Alexander"

  step %(I am on the #{account_or_service}s admin page)
  step %(I follow "#{account_or_application_name}")
  step 'I follow "Edit"'
  step 'I follow "Delete" and I confirm dialog box'
  step %(I should see "The #{account_or_service} was successfully deleted.")
end

# This is a maze for your brain
# It means:
# - provider has a paid plan
# - provider enables the :require_cc_on_cc_signup switch in order force the buyer to fill in credit card first on paid plans.
When(/^the provider has credit card on signup feature in (automatic|manual) mode/) do |mode|
  @provider.stubs(:provider_can_use?).with(:require_cc_on_signup).returns(mode == 'manual')
end

When(/^the provider upgrades to plan "(.+?)"$/) do |name|
  plan = Plan.find_by_system_name(name)
  @provider.reload
  @provider.force_upgrade_to_provider_plan!(plan)
end

When(/I authenticate by Oauth2$/) do
  # it works for Oauth2, which is for what is being used. In case it wants to be used to Auth0, it needs the state param
  visit "/auth/#{@authentication_provider.system_name}/callback"
end

And(/^the provider has one buyer$/) do
  step %(a buyer "bob" signed up to provider "#{@provider.internal_domain}")
end

And(/^the provider enables credit card on signup feature manually/) do
  step %(provider "#{@provider.internal_domain}" has "require_cc_on_signup" switch visible)
  @provider.reload
end

Given(/^master is the provider$/) do
  @provider = Account.master
  @service ||= @provider.default_service
  step 'the provider has multiple applications enabled'
  step "a default application plan of provider \"#{provider_or_master_name}\""
end

Then(/^new tenant should be created$/) do
  @username ||= Account.providers.last!.users.first!.username
  assert_selector('.flash-message--notice', :text => 'Tenant account was successfully created.')
  step 'I go to the buyer accounts page'
  assert_selector(:xpath, './/table[@id="buyer_accounts"]//tr', :text => @username, :count => 1)
end

Then(/^new tenant should be not created$/) do
  @expected_flash_errors.each do |error_message|
    assert_selector('.inline-errors', :text => error_message[:message])
  end
end
