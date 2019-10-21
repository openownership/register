desc 'Sanitize the db for local / test / QA development'
task :sanitize => :environment do
  counter = 0

  User.all.each do |u|
    counter += 1

    u.skip_reconfirmation!

    u.update!(
      name: "User #{counter}",
      email: "user_#{counter}@example.org",
      company_name: "Company #{counter}",
      position: "Chief",
    )
  end
end
