require File.dirname(__FILE__) + '/../vendor/maruku/maruku'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../vendor/syntax'
require 'syntax/convertors/html'

class Author < Sequel::Model
  
  one_to_many :posts
  
  unless table_exists?
    set_schema do
      primary_key :id
      text :email
      text :first_name
      text :last_name
      text :password
      timestamp :created_at
    end
    create_table
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def wrote?(post)
    self.id == post.author.id
  end
end
