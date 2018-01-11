class BatchSubmission < ActiveRecord::Base
  belongs_to :batch
  belongs_to :submission

  validates :batch_id, presence: true
  validates :submission_id, presence: true

  # validates_uniqueness_of :batch_id, :scope => [ :submission_id ]
  
  after_destroy :delete_empty_batches
  
  def delete_empty_batches
    batch = Batch.find_by(id: self.batch_id)
    if !BatchSubmission.find_by(batch_id: batch.id)
      batch.destroy!
    end
  end
  
end
