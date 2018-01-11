class CreateBatchSubmissions < ActiveRecord::Migration
  def change
    create_table :batch_submissions do |t|
      t.references :batch, index: true
      t.references :submission, index: true

      t.timestamps null: false
    end
    add_foreign_key :batch_submissions, :batches
    add_foreign_key :batch_submissions, :submissions
  end
end
