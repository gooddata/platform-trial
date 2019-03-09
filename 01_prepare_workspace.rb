#!/usr/bin/env ruby

require 'gooddata'

GoodData.logging_http_on if ENV['HTTP_DEBUG']

project_title = ARGV.shift || raise("Usage: #{$0} <project_title> [<data_folder>]")
data_folder   = ARGV.shift || './data/step1'

def add_attribute(dataset, identifier_suffix, options = {})
  attr_id = "attr.#{identifier_suffix}"
  options[:anchor] ? dataset.add_anchor(attr_id, options) : dataset.add_attribute(attr_id, options)
  dataset.add_label("label.#{identifier_suffix}", options.merge({ reference: attr_id }))
end

blueprint = GoodData::Model::ProjectBlueprint.build(project_title) do |p|
  p.add_date_dimension('date', title: 'Date')

  p.add_dataset('dataset.orderlines', title: "Order Lines") do |d|
    add_attribute(d, "orderlines.order_line_id", title: "Order Line ID", anchor: true )
    add_attribute(d, "orderlines.order_id", title: "Order ID")
    d.add_date('date', format: 'yyyy-MM-dd')
    add_attribute(d, "orderlines.order_status", title: "Order Status")
    add_attribute(d, "orderlines.customer_id", title: "Customer ID")
    add_attribute(d, "orderlines.fullname", title: "Customer Name")
    add_attribute(d, "orderlines.state", title: "Customer State")
    add_attribute(d, "orderlines.product_id", title: "Product ID")
    add_attribute(d, "orderlines.product_name", title: "Product")
    add_attribute(d, "orderlines.category", title: "Product Category")    
    d.add_fact("fact.orderlines.price", title: "Price")
    d.add_fact("fact.orderlines.quantity", title: "Quantity")
  end
end

client  = GoodData.connect # reads credentials from ~/.gooddata
options = ENV['AUTHORIZATION'] ? { auth_token: ENV['AUTHORIZATION_TOKEN'] } : {}

pp options

begin
  project = ENV['WORKSPACE'] ? client.projects(ENV['WORKSPACE']) : client.create_project_from_blueprint(blueprint, options)

  data = [{
    data: "#{data_folder}/orders.csv",
    dataset: 'dataset.orderlines'
  }]

  result = project.upload_multiple(data, blueprint)
rescue => e
  response = JSON.parse e.response.body
  raise response['error']['message'] % response['error']['parameters']
end
pp result
puts "Done!"
