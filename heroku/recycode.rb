require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'

include Mongo

COLLECTION = 'recycode'
DROPOFF = 'drop-off'

configure do
  if ENV['MONGOHQ_URL']
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    uri = URI.parse(ENV['MONGOHQ_URL'])
    set :mongo_connection, conn
    set :mongo_db, conn.db(uri.path.gsub(/^\//, ''))
  else
    conn = MongoClient.new("localhost", 27017)
    set :mongo_connection, conn
    set :mongo_db, conn.db('test')
  end
  coll = settings.mongo_db[DROPOFF]
  coll.create_index([['loc', Mongo::GEO2DSPHERE]])
end

get '/collections/?' do
  settings.mongo_db.collection_names
end

helpers do
  def object_id val
    BSON::ObjectId.from_string(val)
  end

  def document_by_id id
    id = object_id(id) if String === id
    settings.mongo_db[COLLECTION].find_one(:_id => id).to_json
  end
  
  def document_by_barcode barcode
      settings.mongo_db[COLLECTION].find_one(:barcode => barcode).to_json
  end
end

get '/documents/?' do
  content_type :json
  settings.mongo_db[COLLECTION].find.to_a.to_json
end

# find a document by its ID
get '/document/:id/?' do
  content_type :json
  document_by_id(params[:id]).to_json
end

post '/new_document/?' do
  content_type :json
  new_id = settings.mongo_db[COLLECTION].insert params
  document_by_id(new_id).to_json
end

put '/update/:id/?' do
  content_type :json
  id = object_id(params[:id])
#  settings.mongo_db['test'].update(:_id => id, params)
  document_by_id(id).to_json
end

put '/update_name/:id/?' do
  content_type :json
  id   = object_id(params[:id])
  name = params[:name]
#  settings.mongo_db['test'].update(:_id => id, {"$set" => {:name => name}})
  document_by_id(id).to_json
end

# delete the specified document and return success
delete '/remove/:id' do
  content_type :json
  settings.mongo_db[COLLECTION].remove(:_id => object_id(params[:id]))
  {:success => true}.to_json
end

### RECYCODE PRODUCT API
get '/' do
  "Recycode2"
end

post '/product/add' do
  content_type :json
  new_id = settings.mongo_db[COLLECTION].insert params
  document_by_id(new_id).to_json
end

get '/product/:barcode' do
  content_type :json
  #document_by_barcode(params[:barcode]).to_json
  document_by_barcode(params[:barcode])
end

post '/product/img/:barcode' do
  grid = Mongo::GridFileSystem.new(settings.mongo_db)
  grid.open("#{params[:barcode]}", 'w') do |f|
    f.write(request.env["rack.input"].read)
  end
  {:success => true}.to_json
end

get '/product/img/:barcode' do
  raw = ""
  grid = Mongo::GridFileSystem.new(settings.mongo_db)
  grid.open("#{params[:barcode]}", 'r') do |f|
    raw = f.read
  end
  content_type 'image/jpeg'
  raw
end

### RECYCODE GEO API

post '/place' do
  d = JSON.parse(request.env["rack.input"].string)
  settings.mongo_db[DROPOFF].insert(d)
  {:success => true}.to_json  
end

get '/places' do
  places = Array.new
  settings.mongo_db[DROPOFF].find.each {|row| places.push(row) }
  places.to_json
end

get '/places/near' do
  lat = params[:lat].to_f
  lng = params[:lng].to_f
  dst = params[:dist].to_i
  places = Array.new
  op ={"loc" => {"$near" => { "$geometry" => {"type" => "Point", "coordinates" => [lng, lat]},"$maxDistance" => dst}}}
  settings.mongo_db[DROPOFF].find(op).each {|row| places.push(row) }
  places.to_json
end

delete '/place/remove/:id' do
  content_type :json
  settings.mongo_db[DROPOFF].remove(:_id => object_id(params[:id]))
  {:success => true}.to_json
end