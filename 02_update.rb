#!/usr/bin/env ruby
# (C) 2007-2019 GoodData Corporation

# Script for refactoring and reloading the data model from the
# GoodData platform tutorial.
#
# See https://developer.gooddata.com/platform-tutorial

require 'gooddata'

GoodData.logging_http_on if ENV['HTTP_DEBUG']

project_id    = ARGV.shift || raise("Usage: #{$0} <project_id> [<data_folder>]")
data_folder   = ARGV.shift || './data/step2'

# Each attribute in this demo has just one visual representation (label)
# The "anchor" option signifies that the attribute also acts as a referencable
# primary key
def add_attribute(dataset, identifier_suffix, options = {})
  attr_id = "attr.#{identifier_suffix}"
  options[:anchor] ? dataset.add_anchor(attr_id, options) : dataset.add_attribute(attr_id, options)
  dataset.add_label("label.#{identifier_suffix}", options.merge({ reference: attr_id }))
end

# Define the updated logical data model. The new data model uses the
# the same attribute and fact identifiers even though some of them
# are moved to new data sets (e.g. orderlines.product_id).
# In addition, it creates new data elements for the marketing campaign
# data.
blueprint = GoodData::Model::ProjectBlueprint.build(project_id) do |p|
  p.add_date_dimension('date', title: 'Date')

  # Note some of the identifiers (generated from the first arguments
  # to the add_attribute method) are the same as in the 01_prepare_workspace.rb
  # script. This causes the logical attributes of GoodData model such as
  # customer or procuct information to stay the same while referencing columns
  # from different data sets (tables).
  p.add_dataset('dataset.customers', title: "Customers") do |d|
    add_attribute(d, "orderlines.customer_id", title: "Customer ID", anchor: true)
    add_attribute(d, "orderlines.fullname", title: "Customer Name")
    add_attribute(d, "orderlines.state", title: "Customer State")
  end

  p.add_dataset('dataset.products', title: "Products") do |d|
    add_attribute(d, "orderlines.product_id", title: "Product ID", anchor: true)
    add_attribute(d, "orderlines.product_name", title: "Product")
    add_attribute(d, "orderlines.category", title: "Product Category")    
  end

  p.add_dataset('dataset.campaigns', title: "Campaigns") do |d|
    add_attribute(d, "campaigns.campaign_id", title: "Campaign ID", anchor: true)
    add_attribute(d, "campaigns.campaign_name", title: "Campaign Name")
  end

  p.add_dataset('dataset.campaign_channels', title: "Campaigns / Channels") do |d|
    add_attribute(d, "campaign_channels.campaign_channel_id", title: "Campaign Channel ID", anchor: true)
    add_attribute(d, "campaign_channels.category", title: "Campaign Category")
    add_attribute(d, "campaign_channels.type", title: "Campaign Type")
    d.add_reference("dataset.campaigns")
    d.add_fact("fact.campaign_channels.budget", title: "Budget")
    d.add_fact("fact.campaign_channels.spend", title: "Spend")
  end

  p.add_dataset('dataset.order_lines', title: "Order Lines") do |d|
    add_attribute(d, "orderlines.order_line_id", title: "Order Line ID", anchor: true )
    add_attribute(d, "orderlines.order_id", title: "Order ID")
    d.add_date('date', format: 'yyyy-MM-dd')
    add_attribute(d, "orderlines.order_status", title: "Order Status")
    # The product and customer attributes have been replaced with references to the newly created Products and Customers dimension
    d.add_reference("dataset.products")
    d.add_reference("dataset.customers")
    d.add_reference("dataset.campaigns")
    d.add_fact("fact.orderlines.price", title: "Price")
    d.add_fact("fact.orderlines.quantity", title: "Quantity")
  end
end

client = GoodData.connect # reads credentials from ~/.gooddata

begin
  options = ENV['AUTHORIZATION'] ? { auth_token: ENV['AUTHORIZATION_TOKEN'] } : {}
  if ENV['CREATE_NEW'] then # creates new workspace instead of updating one - for testing only
    project = client.create_project_from_blueprint(blueprint, options)
  else
    GoodData.use project_id
    project = GoodData.project
    GoodData.project.update_from_blueprint(blueprint, update_preference: { cascade_drops: false, preserve_data: false })
  end

  data = [
    {
      data: "#{data_folder}/customers.csv",
      dataset: 'dataset.customers'
    }, {
      data: "#{data_folder}/products.csv",
      dataset: 'dataset.products'
    }, {
      data: "#{data_folder}/campaigns.csv",
      dataset: 'dataset.campaigns'
    }, {
      data: "#{data_folder}/order_lines.csv",
      dataset: 'dataset.order_lines'
    }, {
      data: "#{data_folder}/campaign_channels.csv",
      dataset: 'dataset.campaign_channels'
    }
  ]

  result = project.upload_multiple(data, blueprint)
  pp result
  puts "Done!"
rescue RestClient::Exception => e
  response = JSON.parse e.response.body
  raise response['error']['message'] % response['error']['parameters']
end
