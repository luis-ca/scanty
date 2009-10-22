require 'rubygems'
require 'sinatra'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/vendor/sequel'
require 'sequel'

configure do
  Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://blog.db')

  require 'ostruct'
  Blog = OpenStruct.new(
    :title => 'Blog Title',
    :url_base => 'http://localhost:4567/',
    :admin_cookie_key => 'scanty_author',
    :admin_cookie_value => '51d6d976913ace58'
  )
end

error do
  e = request.env['sinatra.error']
  puts e.to_s
  puts e.backtrace.join("\n")
  "Application error"
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'
require 'author'

helpers do
  
  def is_admin?
    true if author
  end
  
  def admin?
    is_admin?
  end
  
  def author
    author_id = request.cookies["author_id_cookie_key"]
    Author.filter(:id => author_id.to_i).first    
  end
  
  def auth
    redirect '/' unless is_admin?
  end

end

layout 'layout'

### Public

get '/' do
  posts = Post.reverse_order(:created_at).limit(10)
  haml :index, :locals => { :posts => posts }
end

get '/past/:year/:month/:day/:slug/' do
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  @title = post.title
  haml :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
  redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
  posts = Post.reverse_order(:created_at)
  @title = "Archive"
  haml :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
  tag = params[:tag]
  posts = Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).limit(30)
  @title = "Posts tagged #{tag}"
  haml :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/author/:author_id' do
  author = Author.filter(:id => params[:author_id]).first
  posts = Post.filter(:author_id => author.id).reverse_order(:created_at)
  @title = "All posts by #{author.full_name}"
  haml :archive, :locals => { :posts => posts }
end


get '/feed' do
  @posts = Post.reverse_order(:created_at).limit(20)
  content_type 'application/atom+xml', :charset => 'utf-8'
  builder :feed
end

get '/rss' do
  redirect '/feed', 301
end




### Admin

get '/admin/authors' do
  auth
  authors = Author.all
  haml :authors, :locals => {:authors => authors}
end

get '/login' do
  haml :auth
end

post '/auth' do
  author = Author.filter(:email => params[:email]).first
  if !author.nil? and params[:password] == author.password
    response.set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value)
    response.set_cookie(:author_id_cookie_key, author.id)
    redirect '/'
  else
    haml :auth, :locals => { :message => "Wrong email address or password" }
  end
end

get '/logout' do
  response.set_cookie(Blog.admin_cookie_key, "")
  response.set_cookie(:author_id_cookie_key, "")
  redirect '/'
end

get '/posts/new' do
  auth
  haml :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
  auth
  post = Post.new :author_id => author.id, :title => params[:title], :tags => params[:tags], :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
  post.save
  redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
  auth
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  haml :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
  auth
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  post.title = params[:title]
  post.tags = params[:tags]
  post.body = params[:body]
  post.save
  redirect post.url
end

