class CreateSubmissions < ActiveRecord::Migration
  def change
    create_table :submissions do |t|
      t.string :accession
      t.string :gi
      t.string :category
      t.string :status
      t.string :job_id
      t.string :sidekiq_id
      t.integer :runtime
      t.text :error
      t.string :sequence_type
      t.attachment :sequence

      t.timestamps
    end
  end
end
