namespace :admin do
  desc "Make a user admin by email"
  task :create, [:email] => :environment do |t, args|
    user = User.find_by(email: args[:email])
    
    if user
      user.update(admin: true)
      puts "User #{user.email} is now an admin"
    else
      puts "User with email #{args[:email]} not found"
    end
  end
  
  desc "List all admin users"
  task list: :environment do
    admins = User.where(admin: true)
    if admins.any?
      puts "Admin users:"
      admins.each do |admin|
        puts "- #{admin.email}"
      end
    else
      puts "No admin users found"
    end
  end
end 