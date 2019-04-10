#!/usr/bin/env ruby
# (C) 2007-2019 GoodData Corporation

# Script for creating and loading the initial data model for
# GoodData platform tutorial.
#
# See https://developer.gooddata.com/platform-tutorial

require 'gooddata'

GoodData.logging_http_on if ENV['HTTP_DEBUG']

project_title = ARGV.shift || raise("Usage: #{$0} <project_title> [<data_folder>]")
data_folder   = ARGV.shift || './data/step1'

# Each attribute in this demo has just one visual representation (label)
# The "anchor" option signifies that the attribute also acts as a referencable
# primary key
def add_attribute(dataset, identifier_suffix, options = {})
  attr_id = "attr.#{identifier_suffix}"
  options[:anchor] ? dataset.add_anchor(attr_id, options) : dataset.add_attribute(attr_id, options)
  dataset.add_label("label.#{identifier_suffix}", options.merge({ reference: attr_id }))
end

# Define the logical data model in terms of attributes, date dimensions
# and facts.
blueprint = GoodData::Model::ProjectBlueprint.build(project_title) do |p|
  p.add_date_dimension('date', title: 'Date')

  p.add_dataset('dataset.csv_order_lines', title: "Order Lines") do |d|
    add_attribute(d, "csv_order_lines.order_line_id", title: "Order Line ID", anchor: true )
    add_attribute(d, "csv_order_lines.order_id", title: "Order ID")
    d.add_date('date', format: 'yyyy-MM-dd')
    add_attribute(d, "csv_order_lines.order_status", title: "Order Status")
    add_attribute(d, "csv_order_lines.customer_id", title: "Customer ID")
    add_attribute(d, "csv_order_lines.customer_name", title: "Customer Name")
    add_attribute(d, "csv_order_lines.state", title: "Customer State")
    add_attribute(d, "csv_order_lines.product_id", title: "Product ID")
    add_attribute(d, "csv_order_lines.product_name", title: "Product")
    add_attribute(d, "csv_order_lines.category", title: "Product Category")    
    d.add_fact("fact.csv_order_lines.price", title: "Price")
    d.add_fact("fact.csv_order_lines.quantity", title: "Quantity")
  end
end

client  = GoodData.connect # reads credentials from ~/.gooddata
options = ENV['AUTHORIZATION'] ? { auth_token: ENV['AUTHORIZATION_TOKEN'] } : {}

pp options

begin
  project = ENV['WORKSPACE'] ? client.projects(ENV['WORKSPACE']) : client.create_project_from_blueprint(blueprint, options)

  column_mapping = {
    'label.csv_order_lines.order_line_id': 'order_line_id',
    'label.csv_order_lines.order_id':      'order_id',
    'date': 'date',
    'label.csv_order_lines.order_status':  'order_status',
    'label.csv_order_lines.customer_id':   'customer_id',
    'label.csv_order_lines.customer_name': 'customer_name',
    'label.csv_order_lines.state':         'state',
    'label.csv_order_lines.product_id':    'product_id',
    'label.csv_order_lines.product_name':  'product_name',
    'label.csv_order_lines.category':      'category',
    'fact.csv_order_lines.price':          'price',
    'fact.csv_order_lines.quantity':       'quantity'
  }

  result = project.upload("#{data_folder}/order_lines.csv", blueprint, 'dataset.csv_order_lines', column_mapping: column_mapping)
rescue RestClient::Exception => e
  response = JSON.parse e.response.body
  raise response['error']['message'] % response['error']['parameters']
end
pp result
puts "Done!"
