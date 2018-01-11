class AddContigsToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :contigs, :boolean, :default => 0
  end
end
