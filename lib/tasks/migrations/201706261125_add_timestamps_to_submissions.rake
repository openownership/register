namespace :migrations do
  desc "add any missing timestamps on submissions"
  task :timestamp_submissions => :environment do
    Submissions::Submission.each do |submission|
      submission.created_at = submission.id.generation_time
      submission.changed_at = submission.created_at
      submission.save!
    end
  end
end
