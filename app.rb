require 'bundler/setup'

require 'uri'
require 'cgi'
require 'pp'
require 'sinatra/base'
require 'mongo'
require 'indextank'

class OnMyWatch < Sinatra::Base

  configure do
    set :public, File.dirname(__FILE__) + '/public'
    set :views, File.dirname(__FILE__) + '/views'
    config = JSON.parse(File.read(File.dirname(__FILE__) + '/config/app.json'))
    set :create_index, ("true" == config['create_index'])

    index_tank = {
      :private_url => config['index_tank']['private_url'],
      :public_url => config['index_tank']['public_url'],
    }
    set :indextank, index_tank
    search_api = IndexTank::Client.new indextank[:private_url]
    set :search_api, search_api
  end

  configure :development do
    conn = Mongo::Connection.new
    db = conn.db('on_my_watch')
    watches = db['watches']
    set :watches, watches
  end

  configure :production do
    mongo_uri = ENV['MONGOHQ_URL']
    uri = URI.parse(mongo_uri)
    conn = Mongo::Connection.from_uri(mongo_uri)
    db = conn.db(uri.path.gsub(/^\//, ''))
    watches = db['watches']
    set :watches, watches
  end

  get '/' do
    erb :index, :locals => {:title => 'Search Watched Repos', :flash => []}
  end

  get '/search/' do
    login = params[:login]
    if settings.create_index
      index = search_api.indexes login
      unless index.exists?
        index = search_api.indexes login
        index.add
        while not index.running?
            sleep 0.5
        end
        refresh_index(login)
      end
    end
    redirect to("/search/#{params[:login]}"), 303
  end

  get '/search/:login' do |login|
    watch = watches.find_one('login' => login)
    refreshed_at = if watch
      watch['refreshed_at']
    else
      'never'
    end
    documents = if params[:query]
      index = search_api.indexes login
      res = index.search(params[:query], :fetch => 'name,text,language,html_url,owner_login,owner_avatar_url,owner_login')
      res['results']
    else
      []
    end
    erb :search, :locals => {:title => 'Search Watched Repos', :documents => documents, :refreshed_at => refreshed_at, :flash => []}
  end

  get '/refresh/:login' do |login|
    refresh_index(login)
    redirect to("/search/#{login}"), 303
  end

  private
  def watches
    settings.watches
  end

  def search_api
    settings.search_api
  end

  def refresh_index(login)
    watches.update({'login' => login}, {"$set" => {'action' => 'refreshing'}}, {:upsert => true})
    build_index(login)
    watches.update({'login' => login}, {"$set" => {'refreshed_at' => Time.now, 'action' => 'refreshed'}})
  end

  def build_index(login)
    per_page = 100
    page = 1
    response = invoke_watched_repos_api(login, page, per_page)
    index_page(login, response.body)
    link_header = response['Link']
    if link_header
      links = link_header.scan(/<([^>]+)>; rel="([^"]+),?/)
      last_page = CGI::parse(URI.parse(links[1][0]).query)['page'].first.to_i
      (2..last_page).each do |page|
        url = "https://api.github.com/users/#{login}/watched?page=#{page}&per_page=#{per_page}"
        response = invoke_api(url)
        index_page(login, response.body)
      end
    end
  end

  def index_page(login, json)
    index = search_api.indexes login
    documents = JSON.parse(json).map do |hash|
      owner = hash['owner'] || Hash.new(0)
      document = {
        :id => hash['id'],
        :name => hash['name'],
        :text => hash['description'] || '',
        :homepage => hash['homepage'] || '',
        :clone_url => hash['clone_url'],
        :url => hash['url'],
        :language => hash['language'] || '',
        :ssh_url => hash['ssh_url'] || '',
        :pushed_at => hash['pushed_at'] || '',
        :owner_url => owner['url'] || '',
        :owner_login => owner['login'] || '',
        :owner_id => owner['id'],
        :owner_avatar_url => owner['avatar_url'] || '',
        :git_url => hash['git_url'],
        :created_at => hash['created_at'],
        :html_url => hash['html_url'] || '',
        :timestamp => Time.parse(hash['created_at']).to_i
      }
      {:docid => hash['id'], :fields => document}
    end
    response = index.batch_insert(documents)
  end

  def invoke_watched_repos_api(login, page=1, per_page=100)
    url = "https://api.github.com/users/#{login}/watched?page=#{page}&per_page=#{per_page}"
    invoke_api(url)
  end

  def invoke_api(url)
    # response = Net::HTTP.get_response(URI.parse(url))
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
  end
end
