class AddFieldsToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :phage_found, :integer
    add_column :submissions, :description, :string
  end
end
