#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# Небольшой helper, который используется в pre-receive-megaadmins-chef

require 'rubygems'

require 'erb'
require 'json'
require 'net/http'
require 'getoptlong'
require 'chef/cookbook/metadata'

WIKI_LOGIN = 'Sysop'
WIKI_PASSWORD = '123456'
WIKI_API_URI = 'http://wiki-staging-01.undev.cc/api.php'

class WikiAPI

  attr_reader :uri, :http, :auth_hash

  def initialize(login, password, uri)
    @login = login
    @password = password
    @uri = URI.parse(uri)

    @http = Net::HTTP.new(@uri.host, @uri.port)
  end

  def auth
    r = Net::HTTP::Post.new(@uri.path)
    r.add_field('Content-Type', 'application/json-rpc')

    # auth pt.1
    message = {
      :action => 'login',
      :lgname => @login,
      :lgpassword => @password,
      :format => 'json'
    }

    r.set_form_data(message)
    data = JSON.parse(@http.request(r).body)
    lgtoken=data['login']['token']
    wiki_session=data['login']['sessionid']

    # auth pt.2
    message[:lgtoken] = lgtoken # add lgtoken to login message
    cookie = "cookieprefix=none; wiki_session=#{wiki_session}; wikiToken=#{lgtoken}"
    headers = { 'Cookie' => cookie }

    r = Net::HTTP::Post.new(@uri.path, headers)
    r.add_field('Content-Type', 'application/json-rpc')
    r.set_form_data(message)
    d = JSON.parse(@http.request(r).body)
    lguserid = d['login']['lguserid']

    # auth pt. 3
    message = {
      :action => 'query',
      :format => 'json',
      :meta => 'userinfo',
      :uiprop => 'blockinfo|groups|rights|hasmsg|ratelimits|preferencestoken'
    }
    r = Net::HTTP::Post.new(@uri.path, headers)
    r.add_field('Content-Type', 'application/json-rpc')
    r.set_form_data(message)

    d = JSON.parse(@http.request(r).body)
    preferencestoken = d['query']['userinfo']['preferencestoken']

    @auth_hash = {
      :wikiUserID => lguserid,
      :wiki_session => wiki_session,
      :wikiToken => lgtoken,
      :token => preferencestoken
    }
  end

  def edit_page(name, text)

    # post page
    message = {
      :action => 'edit',
      :title => name,
      :text => text,
      :format => 'json',
      :token => @auth_hash[:token]
    }
    cookie = "wikiUserName=#{@login}; cookieprefix=None; " + \
             "wikiUserID=#{@auth_hash[:wikiUserID]}; wiki_session=#{@auth_hash[:wiki_session]}; " + \
             "wikiToken=#{@auth_hash[:wikiToken]}"

    headers = { 'Cookie' => cookie }
    r = Net::HTTP::Post.new(@uri.path, headers)
    r.add_field('Content-Type', 'application/json-rpc') 
    r.set_form_data(message)
    d = JSON.parse(@http.request(r).body)
  end

  def delete_page(name)

    # delete page
    message = {
      :action => 'delete',
      :title => name,
      :token => @auth_hash[:token]
    }
    cookie = "wikiUserName=#{@login}; cookieprefix=None; " + \
             "wikiUserID=#{@auth_hash[:wikiUserID]}; wiki_session=#{@auth_hash[:wiki_session]}; " + \
             "wikiToken=#{@auth_hash[:wikiToken]}"

    headers = { 'Cookie' => cookie }
    r = Net::HTTP::Post.new(@uri.path, headers)
    r.add_field('Content-Type', 'application/json-rpc')
    r.set_form_data(message)

    @http.request(r).body
  end
end

template = ERB.new <<-EOT
{{Tab red|'''Данная страница обновляется автоматически. Не редактируйте ее.'''}}

{{Chef_Cookbook|name=<%= @m.name %>|description=<%= @m.description %>|developers = [[DevOps|devops team]] ([mailto:<%= @m.maintainer_email %> <%= @m.maintainer %>])}}

<%= @m.long_description %>

[[Category:Chef_Cookbooks]]
EOT

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--cookbook', '-c', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--delete', '-d', GetoptLong::NO_ARGUMENT ]
)

cookbook = nil
delete_flag = false

opts.each do |opt, arg|
  case opt
    when '--help'
      puts "Usage: #{ARGV[0]} [--cookbook|-c] cookbook [--delete|-d]"
    when '--cookbook'
      cookbook = arg
    when '--delete'
      delete_flag = true
  end
end

# FIXME: Убрать хардкод пути
prefix = './cookbooks'

if cookbook.nil?
  COOKBOOK_LIST = Dir.glob(File.join(prefix, '*')).to_a
else
  COOKBOOK_LIST = [cookbook]
end

puts "=> Authenticating to wiki.undev.cc"

API = WikiAPI.new(WIKI_LOGIN, WIKI_PASSWORD, WIKI_API_URI)
API.auth()

puts "=> Uploading cookbook docs to wiki.undev.cc"
COOKBOOK_LIST.each do |cookbook_name|
  unless File.directory? File.join(prefix, cookbook_name)
    # Skip this fake `cookbook_name`
    puts "=> WARN: Skip fake #{cookbook_name}"
    next
  end

  unless File.exists? File.join(prefix, cookbook_name, 'metadata.rb')
    # Skip this bad `cookbook`
    puts "=> WARN: Cookbook #{cookbook_name} does not contain metadata.rb"
    next
  end

  page_name = "#{File.basename(cookbook_name)}_(Chef_Cookbooks)"

  if delete_flag
    puts "=> INFO: Deleting wikipage for #{cookbook_name}"
    begin
      API.delete_page(page_name)
    rescue
      puts "=> FAIL: Could not delete #{cookbook_name} docs from wiki.undev.cc. Skip and go ahead."
    end
  else
    puts "=> INFO: Generating wikipage for #{cookbook_name}"
    begin
      @m = Chef::Cookbook::Metadata.new()
      @m.from_file(File.join(prefix, cookbook_name , 'metadata.rb'))
      API.edit_page(page_name, template.result())
    rescue
      puts "=> FAIL: Could not upload #{cookbook_name} docs to wiki.undev.cc. Skip and go ahead."
    end
  end
end

