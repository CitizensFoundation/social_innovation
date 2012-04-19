require "test/unit"
require "watir-webdriver"
require "test_helper"
require "#{Rails.root}/db/seeds.rb"

class CreatePriority < ActionController::IntegrationTest
  def setup
    if !!(RbConfig::CONFIG['host_os'] =~ /mingw|mswin32|cygwin/)
      @browser_types = [:firefox,:chrome,:ie]
    elsif ENV['HEADLESS']
      @browser_types = [:firefox]
    else
      @browser_types = [:firefox,:chrome]
    end

    if ENV['HEADLESS']
      require "headless"
      @headless = Headless.new
      @headless.start
    end

    @browser = Watir::Browser.new(@browser_types[rand(@browser_types.length)])
    #@instance = FactoryGirl.create(:instance)
    #@user = FactoryGirl.create(:user)
  end

  def teardown
    @browser.close
    @headless.destroy if ENV['HEADLESS']
  end

  test "create a priority" do
    @browser.goto "http://localhost:3000"
    @browser.text_field(:name => "instance[name]").set "foobar"
    @browser.text_field(:name => "instance[description]").set "foobar"
    @browser.text_field(:name => "instance[target]").set "foobar"
    @browser.text_field(:name => "instance[domain_name]").set "localhost"
    @browser.text_field(:name => "instance[admin_name]").set "foo"
    @browser.text_field(:name => "instance[admin_email]").set "foo@bar.com"
    @browser.button(:name => "commit").click
    @browser.text_field(:name => "user[first_name]").set "foo"
    @browser.text_field(:name => "user[last_name]").set "foo"
    @browser.text_field(:name => "user[email]").set "foo@bar.com"
    @browser.text_field(:name => "user[password]").set "foobar"
    @browser.text_field(:name => "user[password_confirmation]").set "foobar"
    @browser.text_field(:name => "user[login]").set "foo"
    @browser.button(:name => "commit").click
    @browser.goto "http://localhost:3000/priorities/new"
    @browser.text_field(:name => "priority[name]").set "Test priority"
    @browser.radio(:value => "7").set
    @browser.text_field(:name => "priority[points_attributes][0][name]").set "This is a fake headline"
    @browser.text_field(:name => "priority[points_attributes][0][content]").set "This is a fake point"
    @browser.button.click
    @browser.div(:class => "flash_notice").wait_until_present
  end
end
