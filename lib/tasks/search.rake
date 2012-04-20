namespace :search do  
  
  desc "reindex solr"
  task :reindex => :environment do
    puts "reindexing Idea"
    Idea.rebuild_solr_index(100)
    puts "reindexing Point"
    Point.rebuild_solr_index(100)
    puts "reindexing Document"
    Document.rebuild_solr_index(100)
  end

end